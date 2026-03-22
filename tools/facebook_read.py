from helpers.tool import Tool, Response


class FacebookRead(Tool):
    """Read posts and comments from a Facebook Page."""

    async def execute(self, **kwargs) -> Response:
        action = self.args.get("action", "feed")
        post_id = self.args.get("post_id", "")
        max_results = int(self.args.get("max_results", "25"))

        from plugins.facebook.helpers.facebook_auth import get_facebook_config
        config = get_facebook_config(self.agent)
        from plugins.facebook.helpers.facebook_client import FacebookClient
        client = FacebookClient(config)

        try:
            if action == "feed":
                self.set_progress("Fetching page feed...")
                result = await client.get_page_feed(limit=max_results)
                if result.get("error"):
                    return Response(
                        message=f"Error: {result.get('detail', 'Unknown error')}",
                        break_loop=False,
                    )
                posts = result.get("data", [])
                if not posts:
                    return Response(message="No posts found in the page feed.", break_loop=False)
                from plugins.facebook.helpers.sanitize import format_posts
                return Response(
                    message=f"Page feed ({len(posts)} posts):\n\n{format_posts(posts)}",
                    break_loop=False,
                )

            elif action == "post":
                if not post_id:
                    return Response(message="Error: 'post_id' is required to read a specific post.", break_loop=False)
                from plugins.facebook.helpers.sanitize import validate_post_id
                try:
                    post_id = validate_post_id(post_id)
                except ValueError as e:
                    return Response(message=f"Validation error: {e}", break_loop=False)
                self.set_progress("Fetching post...")
                result = await client.get_post(post_id)
                if result.get("error"):
                    return Response(
                        message=f"Error: {result.get('detail', 'Unknown error')}",
                        break_loop=False,
                    )
                from plugins.facebook.helpers.sanitize import format_post
                return Response(message=format_post(result), break_loop=False)

            elif action == "comments":
                if not post_id:
                    return Response(message="Error: 'post_id' is required to read comments.", break_loop=False)
                from plugins.facebook.helpers.sanitize import validate_post_id
                try:
                    post_id = validate_post_id(post_id)
                except ValueError as e:
                    return Response(message=f"Validation error: {e}", break_loop=False)
                self.set_progress("Fetching comments...")
                result = await client.get_comments(post_id, limit=max_results)
                if result.get("error"):
                    return Response(
                        message=f"Error: {result.get('detail', 'Unknown error')}",
                        break_loop=False,
                    )
                comments = result.get("data", [])
                if not comments:
                    return Response(message="No comments found on this post.", break_loop=False)
                from plugins.facebook.helpers.sanitize import format_comments
                return Response(
                    message=f"Comments ({len(comments)}):\n\n{format_comments(comments)}",
                    break_loop=False,
                )

            else:
                return Response(
                    message=f"Error: Unknown action '{action}'. Use: feed, post, comments.",
                    break_loop=False,
                )
        except ValueError as e:
            return Response(message=f"Validation error: {e}", break_loop=False)
        finally:
            await client.close()
