from helpers.tool import Tool, Response


class FacebookPage(Tool):
    """Get Facebook Page details and list managed pages."""

    async def execute(self, **kwargs) -> Response:
        action = self.args.get("action", "info")

        from plugins.facebook.helpers.facebook_auth import get_facebook_config
        config = get_facebook_config(self.agent)
        from plugins.facebook.helpers.facebook_client import FacebookClient
        client = FacebookClient(config)

        try:
            if action == "info":
                self.set_progress("Fetching page info...")
                result = await client.get_page_info()
                if result.get("error"):
                    return Response(
                        message=f"Error: {result.get('detail', 'Unknown error')}",
                        break_loop=False,
                    )
                from plugins.facebook.helpers.sanitize import format_page_info
                return Response(message=format_page_info(result), break_loop=False)

            elif action == "pages_list":
                self.set_progress("Fetching managed pages...")
                result = await client.get_managed_pages()
                if result.get("error"):
                    return Response(
                        message=f"Error: {result.get('detail', 'Unknown error')}",
                        break_loop=False,
                    )
                pages = result.get("data", [])
                if not pages:
                    return Response(message="No managed pages found.", break_loop=False)
                lines = [f"Managed Pages ({len(pages)}):"]
                for page in pages:
                    name = page.get("name", "Unknown")
                    pid = page.get("id", "")
                    category = page.get("category", "")
                    fans = page.get("fan_count", 0)
                    line = f"  - {name} (ID: {pid})"
                    if category:
                        line += f" [{category}]"
                    line += f" — {fans} fans"
                    lines.append(line)
                return Response(message="\n".join(lines), break_loop=False)

            else:
                return Response(
                    message=f"Error: Unknown action '{action}'. Use: info, pages_list.",
                    break_loop=False,
                )
        finally:
            await client.close()
