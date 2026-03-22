from helpers.tool import Tool, Response


class FacebookComment(Tool):
    """Reply to and delete comments on Facebook Page posts."""

    async def execute(self, **kwargs) -> Response:
        action = self.args.get("action", "reply")
        comment_id = self.args.get("comment_id", "")
        message = self.args.get("message", "")

        if not action:
            return Response(
                message="Error: 'action' is required (reply, delete).",
                break_loop=False,
            )

        if not comment_id:
            return Response(message="Error: 'comment_id' is required.", break_loop=False)

        from plugins.facebook.helpers.sanitize import validate_comment_id
        try:
            comment_id = validate_comment_id(comment_id)
        except ValueError as e:
            return Response(message=f"Validation error: {e}", break_loop=False)

        from plugins.facebook.helpers.facebook_auth import get_facebook_config
        config = get_facebook_config(self.agent)
        from plugins.facebook.helpers.facebook_client import FacebookClient
        client = FacebookClient(config)

        try:
            if action == "reply":
                if not message:
                    return Response(message="Error: 'message' is required for replies.", break_loop=False)
                from plugins.facebook.helpers.sanitize import sanitize_text, validate_comment_length
                message = sanitize_text(message)
                ok, count = validate_comment_length(message)
                if not ok:
                    return Response(
                        message=f"Reply too long: {count}/8000 characters.",
                        break_loop=False,
                    )

                self.set_progress("Replying to comment...")
                result = await client.reply_to_comment(comment_id, message)
                if result.get("error"):
                    return Response(
                        message=f"Error replying: {result.get('detail', 'Unknown error')}",
                        break_loop=False,
                    )
                new_id = result.get("id", "unknown")
                return Response(
                    message=f"Reply posted successfully.\nComment ID: {new_id}",
                    break_loop=False,
                )

            elif action == "delete":
                self.set_progress("Deleting comment...")
                result = await client.delete_comment(comment_id)
                if result.get("error"):
                    return Response(
                        message=f"Error deleting comment: {result.get('detail', 'Unknown error')}",
                        break_loop=False,
                    )
                return Response(message="Comment deleted successfully.", break_loop=False)

            else:
                return Response(
                    message=f"Error: Unknown action '{action}'. Use: reply, delete.",
                    break_loop=False,
                )
        finally:
            await client.close()
