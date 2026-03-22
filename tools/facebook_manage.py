from helpers.tool import Tool, Response


class FacebookManage(Tool):
    """Manage Facebook Page content: delete posts, edit posts, hide comments."""

    async def execute(self, **kwargs) -> Response:
        action = self.args.get("action", "")
        post_id = self.args.get("post_id", "")
        comment_id = self.args.get("comment_id", "")
        message = self.args.get("message", "")

        if not action:
            return Response(
                message="Error: 'action' is required (delete_post, edit_post, hide_comment, unhide_comment).",
                break_loop=False,
            )

        from plugins.facebook.helpers.facebook_auth import get_facebook_config
        config = get_facebook_config(self.agent)
        from plugins.facebook.helpers.facebook_client import FacebookClient
        client = FacebookClient(config)

        try:
            if action == "delete_post":
                if not post_id:
                    return Response(message="Error: 'post_id' is required.", break_loop=False)
                from plugins.facebook.helpers.sanitize import validate_post_id
                try:
                    post_id = validate_post_id(post_id)
                except ValueError as e:
                    return Response(message=f"Validation error: {e}", break_loop=False)

                self.set_progress("Deleting post...")
                result = await client.delete_post(post_id)
                if result.get("error"):
                    return Response(
                        message=f"Error deleting post: {result.get('detail', 'Unknown error')}",
                        break_loop=False,
                    )
                return Response(message="Post deleted successfully.", break_loop=False)

            elif action == "edit_post":
                if not post_id:
                    return Response(message="Error: 'post_id' is required.", break_loop=False)
                if not message:
                    return Response(message="Error: 'message' is required for editing.", break_loop=False)
                from plugins.facebook.helpers.sanitize import validate_post_id, sanitize_text, validate_post_length
                try:
                    post_id = validate_post_id(post_id)
                except ValueError as e:
                    return Response(message=f"Validation error: {e}", break_loop=False)
                message = sanitize_text(message)
                ok, count = validate_post_length(message)
                if not ok:
                    return Response(
                        message=f"Message too long: {count}/63206 characters.",
                        break_loop=False,
                    )

                self.set_progress("Editing post...")
                result = await client.edit_post(post_id, message)
                if result.get("error"):
                    return Response(
                        message=f"Error editing post: {result.get('detail', 'Unknown error')}",
                        break_loop=False,
                    )
                return Response(message="Post edited successfully.", break_loop=False)

            elif action == "hide_comment":
                if not comment_id:
                    return Response(message="Error: 'comment_id' is required.", break_loop=False)
                from plugins.facebook.helpers.sanitize import validate_comment_id
                try:
                    comment_id = validate_comment_id(comment_id)
                except ValueError as e:
                    return Response(message=f"Validation error: {e}", break_loop=False)

                self.set_progress("Hiding comment...")
                result = await client.hide_comment(comment_id, is_hidden=True)
                if result.get("error"):
                    return Response(
                        message=f"Error hiding comment: {result.get('detail', 'Unknown error')}",
                        break_loop=False,
                    )
                return Response(message="Comment hidden successfully.", break_loop=False)

            elif action == "unhide_comment":
                if not comment_id:
                    return Response(message="Error: 'comment_id' is required.", break_loop=False)
                from plugins.facebook.helpers.sanitize import validate_comment_id
                try:
                    comment_id = validate_comment_id(comment_id)
                except ValueError as e:
                    return Response(message=f"Validation error: {e}", break_loop=False)

                self.set_progress("Unhiding comment...")
                result = await client.hide_comment(comment_id, is_hidden=False)
                if result.get("error"):
                    return Response(
                        message=f"Error unhiding comment: {result.get('detail', 'Unknown error')}",
                        break_loop=False,
                    )
                return Response(message="Comment unhidden successfully.", break_loop=False)

            else:
                return Response(
                    message=f"Error: Unknown action '{action}'. Use: delete_post, edit_post, hide_comment, unhide_comment.",
                    break_loop=False,
                )
        finally:
            await client.close()
