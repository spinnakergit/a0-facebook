from helpers.tool import Tool, Response


class FacebookMedia(Tool):
    """Upload photos to a Facebook Page."""

    async def execute(self, **kwargs) -> Response:
        action = self.args.get("action", "upload_photo")
        image_path = self.args.get("image_path", "")
        image_url = self.args.get("image_url", "")
        caption = self.args.get("caption", "")

        if action != "upload_photo":
            return Response(
                message=f"Error: Unknown action '{action}'. Use: upload_photo.",
                break_loop=False,
            )

        if not image_path and not image_url:
            return Response(
                message="Error: 'image_path' or 'image_url' is required.",
                break_loop=False,
            )

        if image_path:
            import os
            # Path traversal protection: resolve to real path and block directory escape
            real_path = os.path.realpath(image_path)
            if ".." in image_path or not os.path.isabs(real_path):
                return Response(message="Error: Invalid file path.", break_loop=False)

            if not os.path.isfile(real_path):
                return Response(message="Error: File not found.", break_loop=False)

            file_size = os.path.getsize(real_path)
            if file_size > 10_000_000:
                return Response(message="Error: Image too large (max 10MB).", break_loop=False)

            ext = os.path.splitext(real_path)[1].lower()
            allowed = {".png", ".jpg", ".jpeg", ".gif", ".bmp", ".tiff", ".webp"}
            if ext not in allowed:
                return Response(
                    message=f"Error: Unsupported image format '{ext}'. Use PNG, JPEG, GIF, BMP, TIFF, or WebP.",
                    break_loop=False,
                )
            image_path = real_path

        if caption:
            from usr.plugins.facebook.helpers.sanitize import sanitize_text
            caption = sanitize_text(caption)

        from usr.plugins.facebook.helpers.facebook_auth import get_facebook_config
        config = get_facebook_config(self.agent)
        from usr.plugins.facebook.helpers.facebook_client import FacebookClient
        client = FacebookClient(config)

        try:
            self.set_progress("Uploading photo to Facebook Page...")
            result = await client.upload_photo(
                image_url=image_url,
                image_path=image_path,
                caption=caption,
            )

            if result.get("error"):
                return Response(
                    message=f"Error uploading photo: {result.get('detail', 'Unknown error')}",
                    break_loop=False,
                )

            photo_id = result.get("id", "unknown")
            post_id = result.get("post_id", "")
            msg = f"Photo uploaded successfully.\nPhoto ID: {photo_id}"
            if post_id:
                msg += f"\nPost ID: {post_id}"
            return Response(message=msg, break_loop=False)
        finally:
            await client.close()
