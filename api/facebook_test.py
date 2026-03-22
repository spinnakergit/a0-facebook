"""API endpoint: Test Facebook Pages connection.
URL: POST /api/plugins/facebook/facebook_test
"""
from helpers.api import ApiHandler, Request, Response


class FacebookTest(ApiHandler):

    @classmethod
    def get_methods(cls) -> list[str]:
        return ["GET", "POST"]

    @classmethod
    def requires_csrf(cls) -> bool:
        return True

    async def process(self, input: dict, request: Request) -> dict | Response:
        try:
            from plugins.facebook.helpers.facebook_auth import (
                get_facebook_config,
                is_authenticated,
                has_credentials,
                get_usage,
            )

            config = get_facebook_config()
            if not has_credentials(config):
                return {"ok": False, "error": "No Page Access Token configured. Set it in plugin settings."}

            authenticated, info = is_authenticated(config)
            if authenticated:
                usage = get_usage(config)
                return {
                    "ok": True,
                    "user": info,
                    "usage": {
                        "month": usage.get("month", ""),
                        "posts_created": usage.get("posts_created", 0),
                        "comments": usage.get("comments", 0),
                        "photos_uploaded": usage.get("photos_uploaded", 0),
                    },
                }
            else:
                return {"ok": False, "error": info}
        except Exception:
            return {"ok": False, "error": "Connection failed. Check your Page Access Token and network connectivity."}
