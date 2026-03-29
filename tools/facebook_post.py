from helpers.tool import Tool, Response


class FacebookPost(Tool):
    """Create posts on a Facebook Page: text posts, link posts, and scheduled posts."""

    async def execute(self, **kwargs) -> Response:
        action = self.args.get("action", "create")
        message = self.args.get("message", "")
        link = self.args.get("link", "")
        scheduled_time = self.args.get("scheduled_time", "")

        if action not in ("create", "create_link", "schedule"):
            return Response(
                message=f"Error: Unknown action '{action}'. Use: create, create_link, schedule.",
                break_loop=False,
            )

        if not message and not link:
            return Response(message="Error: 'message' or 'link' is required.", break_loop=False)

        from usr.plugins.facebook.helpers.sanitize import sanitize_text, validate_post_length
        if message:
            message = sanitize_text(message)
            ok, count = validate_post_length(message)
            if not ok:
                return Response(
                    message=f"Post too long: {count}/63206 characters. Shorten the text.",
                    break_loop=False,
                )

        from usr.plugins.facebook.helpers.facebook_auth import get_facebook_config
        config = get_facebook_config(self.agent)
        from usr.plugins.facebook.helpers.facebook_client import FacebookClient
        client = FacebookClient(config)

        try:
            if action == "schedule":
                if not scheduled_time:
                    return Response(
                        message="Error: 'scheduled_time' is required for scheduled posts (Unix timestamp).",
                        break_loop=False,
                    )
                try:
                    ts = int(scheduled_time)
                except ValueError:
                    return Response(
                        message="Error: 'scheduled_time' must be a Unix timestamp (integer).",
                        break_loop=False,
                    )

                self.set_progress("Scheduling post...")
                result = await client.create_scheduled_post(
                    message=message,
                    scheduled_time=ts,
                    link=link,
                )
            else:
                self.set_progress("Posting to Facebook Page...")
                result = await client.create_post(
                    message=message,
                    link=link,
                )

            if result.get("error"):
                return Response(
                    message=f"Error posting: {result.get('detail', 'Unknown error')}",
                    break_loop=False,
                )

            post_id = result.get("id", "unknown")
            action_label = {
                "create": "Post",
                "create_link": "Link post",
                "schedule": "Scheduled post",
            }.get(action, "Post")
            return Response(
                message=f"{action_label} created successfully.\nPost ID: {post_id}",
                break_loop=False,
            )
        except ValueError as e:
            return Response(message=f"Validation error: {e}", break_loop=False)
        finally:
            await client.close()
