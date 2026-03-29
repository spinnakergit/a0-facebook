"""
Facebook Graph API v21.0 async client with rate limiting and retry logic.

All Facebook Page operations go through the Graph API REST endpoints.
Base URL: https://graph.facebook.com/v21.0
"""

import asyncio
import time
import json
import logging
import aiohttp

logger = logging.getLogger("facebook_client")

GRAPH_API_BASE = "https://graph.facebook.com/v21.0"


class FacebookRateLimiter:
    """Track rate limits from Graph API response headers."""

    def __init__(self):
        self._call_count = 0
        self._window_start = time.time()
        self._lock = asyncio.Lock()
        # Facebook app-level rate limit: 200 calls per hour per user
        self._max_calls_per_hour = 200

    async def wait(self):
        """Block if approaching rate limit."""
        async with self._lock:
            now = time.time()
            if now - self._window_start >= 3600:
                self._call_count = 0
                self._window_start = now

            self._call_count += 1
            if self._call_count >= self._max_calls_per_hour:
                wait_time = 3600 - (now - self._window_start)
                if wait_time > 0:
                    logger.warning(f"Rate limit approaching, waiting {wait_time:.0f}s")
                    await asyncio.sleep(min(wait_time, 60))

    def update_from_headers(self, headers: dict):
        """Update rate limit state from response headers if available."""
        usage = headers.get("x-app-usage") or headers.get("x-page-usage")
        if usage:
            try:
                data = json.loads(usage)
                call_pct = data.get("call_count", 0)
                if call_pct > 80:
                    logger.warning(f"Facebook API usage at {call_pct}%")
            except (json.JSONDecodeError, TypeError):
                pass


class FacebookClient:
    """Async Facebook Graph API client."""

    def __init__(self, config: dict):
        self.config = config
        self._session = None
        self._rate_limiter = FacebookRateLimiter()

    @classmethod
    def from_config(cls, agent=None):
        """Factory: create client from A0 plugin config."""
        from usr.plugins.facebook.helpers.facebook_auth import get_facebook_config
        config = get_facebook_config(agent)
        return cls(config)

    def _get_token(self) -> str:
        """Get the page access token."""
        from usr.plugins.facebook.helpers.facebook_auth import get_page_access_token
        return get_page_access_token(self.config)

    def _get_page_id(self) -> str:
        """Get the page ID from config or by resolving from token."""
        from usr.plugins.facebook.helpers.facebook_auth import get_page_id_from_token
        return get_page_id_from_token(self.config)

    async def _get_session(self) -> aiohttp.ClientSession:
        if self._session is None or self._session.closed:
            self._session = aiohttp.ClientSession()
        return self._session

    async def close(self):
        if self._session and not self._session.closed:
            await self._session.close()

    async def _request(
        self,
        method: str,
        endpoint: str,
        params: dict = None,
        json_body: dict = None,
        data: aiohttp.FormData = None,
        max_retries: int = 3,
    ) -> dict:
        """Core Graph API request method with rate limiting and retry."""
        url = f"{GRAPH_API_BASE}/{endpoint.lstrip('/')}"
        token = self._get_token()
        if not token:
            return {"error": True, "detail": "No Page Access Token configured"}

        if params is None:
            params = {}
        params["access_token"] = token

        session = await self._get_session()

        for attempt in range(max_retries):
            await self._rate_limiter.wait()

            try:
                kwargs = {"params": params}
                if json_body is not None and data is None:
                    kwargs["json"] = json_body
                if data is not None:
                    kwargs["data"] = data

                async with session.request(method, url, **kwargs) as resp:
                    self._rate_limiter.update_from_headers(dict(resp.headers))

                    if resp.status == 429:
                        wait = min(60, 5 * (attempt + 1))
                        logger.warning(f"Rate limited, waiting {wait}s")
                        await asyncio.sleep(wait)
                        continue

                    body = await resp.text()
                    if resp.status >= 400:
                        try:
                            error_data = json.loads(body)
                            error_msg = error_data.get("error", {}).get("message", body)
                        except (json.JSONDecodeError, TypeError):
                            error_msg = body
                        return {
                            "error": True,
                            "status": resp.status,
                            "detail": error_msg,
                        }

                    if body:
                        return json.loads(body)
                    return {"ok": True}
            except aiohttp.ClientError as e:
                if attempt == max_retries - 1:
                    return {"error": True, "detail": str(e)}
                await asyncio.sleep(2 ** attempt)

        return {"error": True, "detail": "Max retries exceeded"}

    # --- Page Info ---

    async def get_me(self) -> dict:
        """Get authenticated page info via GET /me."""
        return await self._request(
            "GET", "me",
            params={"fields": "id,name,category,fan_count,link,picture"},
        )

    async def get_page_info(self, page_id: str = None) -> dict:
        """Get detailed page information."""
        if not page_id:
            page_id = self._get_page_id()
        if not page_id:
            return {"error": True, "detail": "No Page ID configured or resolved"}
        return await self._request(
            "GET", page_id,
            params={"fields": "id,name,category,about,description,fan_count,link,picture,website,phone,emails"},
        )

    async def get_managed_pages(self) -> dict:
        """List pages managed by the token owner via GET /me/accounts."""
        return await self._request(
            "GET", "me/accounts",
            params={"fields": "id,name,category,fan_count"},
        )

    # --- Post Operations ---

    async def create_post(
        self,
        message: str = "",
        link: str = "",
        page_id: str = None,
    ) -> dict:
        """
        Create a post on the page.
        POST /{page-id}/feed with message and/or link.
        """
        if not page_id:
            page_id = self._get_page_id()
        if not page_id:
            return {"error": True, "detail": "No Page ID configured or resolved"}

        body = {}
        if message:
            body["message"] = message
        if link:
            body["link"] = link
        if not body:
            return {"error": True, "detail": "Either message or link is required"}

        result = await self._request("POST", f"{page_id}/feed", json_body=body)
        if not result.get("error"):
            from usr.plugins.facebook.helpers.facebook_auth import increment_usage
            increment_usage(self.config)
        return result

    async def create_scheduled_post(
        self,
        message: str,
        scheduled_time: int,
        link: str = "",
        page_id: str = None,
    ) -> dict:
        """
        Create a scheduled post. scheduled_time is a Unix timestamp (>10 min, <6 months from now).
        """
        if not page_id:
            page_id = self._get_page_id()
        if not page_id:
            return {"error": True, "detail": "No Page ID configured or resolved"}

        body = {"message": message, "published": False, "scheduled_publish_time": scheduled_time}
        if link:
            body["link"] = link

        result = await self._request("POST", f"{page_id}/feed", json_body=body)
        if not result.get("error"):
            from usr.plugins.facebook.helpers.facebook_auth import increment_usage
            increment_usage(self.config)
        return result

    async def get_page_feed(self, page_id: str = None, limit: int = 25) -> dict:
        """Get posts from the page feed. GET /{page-id}/feed."""
        if not page_id:
            page_id = self._get_page_id()
        if not page_id:
            return {"error": True, "detail": "No Page ID configured or resolved"}
        return await self._request(
            "GET", f"{page_id}/feed",
            params={"fields": "id,message,created_time,permalink_url,shares,reactions.summary(true),comments.summary(true)", "limit": min(limit, 100)},
        )

    async def get_post(self, post_id: str) -> dict:
        """Get a single post by ID."""
        return await self._request(
            "GET", post_id,
            params={"fields": "id,message,created_time,permalink_url,shares,reactions.summary(true),comments.summary(true)"},
        )

    async def edit_post(self, post_id: str, message: str) -> dict:
        """Edit an existing post. POST /{post-id} with new message."""
        return await self._request(
            "POST", post_id,
            json_body={"message": message},
        )

    async def delete_post(self, post_id: str) -> dict:
        """Delete a post. DELETE /{post-id}."""
        result = await self._request("DELETE", post_id)
        if not result.get("error"):
            from usr.plugins.facebook.helpers.facebook_auth import increment_usage
            increment_usage(self.config, "posts_deleted")
        return result

    # --- Comments ---

    async def get_comments(self, post_id: str, limit: int = 25) -> dict:
        """Get comments on a post. GET /{post-id}/comments."""
        return await self._request(
            "GET", f"{post_id}/comments",
            params={"fields": "id,message,from,created_time,like_count,comment_count", "limit": min(limit, 100)},
        )

    async def reply_to_comment(self, comment_id: str, message: str) -> dict:
        """Reply to a comment. POST /{comment-id}/comments."""
        result = await self._request(
            "POST", f"{comment_id}/comments",
            json_body={"message": message},
        )
        if not result.get("error"):
            from usr.plugins.facebook.helpers.facebook_auth import increment_usage
            increment_usage(self.config, "comments")
        return result

    async def delete_comment(self, comment_id: str) -> dict:
        """Delete a comment. DELETE /{comment-id}."""
        return await self._request("DELETE", comment_id)

    async def hide_comment(self, comment_id: str, is_hidden: bool = True) -> dict:
        """Hide or unhide a comment. POST /{comment-id} with is_hidden."""
        return await self._request(
            "POST", comment_id,
            json_body={"is_hidden": is_hidden},
        )

    # --- Media ---

    async def upload_photo(
        self,
        page_id: str = None,
        image_url: str = "",
        image_path: str = "",
        caption: str = "",
    ) -> dict:
        """
        Upload a photo to the page.
        POST /{page-id}/photos with url or source (multipart).
        """
        if not page_id:
            page_id = self._get_page_id()
        if not page_id:
            return {"error": True, "detail": "No Page ID configured or resolved"}

        if image_url:
            body = {"url": image_url}
            if caption:
                body["message"] = caption
            result = await self._request("POST", f"{page_id}/photos", json_body=body)
        elif image_path:
            import os
            if not os.path.isfile(image_path):
                return {"error": True, "detail": f"File not found: {image_path}"}
            form = aiohttp.FormData()
            form.add_field("source", open(image_path, "rb"), filename=os.path.basename(image_path))
            if caption:
                form.add_field("message", caption)
            result = await self._request("POST", f"{page_id}/photos", data=form)
        else:
            return {"error": True, "detail": "Either image_url or image_path is required"}

        if not result.get("error"):
            from usr.plugins.facebook.helpers.facebook_auth import increment_usage
            increment_usage(self.config, "photos_uploaded")
        return result

    # --- Insights ---

    async def get_page_insights(
        self,
        page_id: str = None,
        metric: str = "page_impressions,page_engaged_users,page_fan_adds",
        period: str = "day",
    ) -> dict:
        """
        Get page-level insights. GET /{page-id}/insights.
        Metrics: page_impressions, page_engaged_users, page_fan_adds, page_views_total, etc.
        Periods: day, week, days_28
        """
        if not page_id:
            page_id = self._get_page_id()
        if not page_id:
            return {"error": True, "detail": "No Page ID configured or resolved"}
        return await self._request(
            "GET", f"{page_id}/insights",
            params={"metric": metric, "period": period},
        )

    async def get_post_insights(self, post_id: str, metric: str = "post_impressions,post_engaged_users,post_clicks") -> dict:
        """
        Get post-level insights. GET /{post-id}/insights.
        Metrics: post_impressions, post_engaged_users, post_clicks, post_reactions_by_type_total
        """
        return await self._request(
            "GET", f"{post_id}/insights",
            params={"metric": metric},
        )
