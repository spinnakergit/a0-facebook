from helpers.tool import Tool, Response


class FacebookInsights(Tool):
    """Get analytics and insights for a Facebook Page and its posts."""

    async def execute(self, **kwargs) -> Response:
        action = self.args.get("action", "page")
        post_id = self.args.get("post_id", "")
        metric = self.args.get("metric", "")
        period = self.args.get("period", "day")

        from plugins.facebook.helpers.facebook_auth import get_facebook_config
        config = get_facebook_config(self.agent)
        from plugins.facebook.helpers.facebook_client import FacebookClient
        client = FacebookClient(config)

        try:
            if action == "page":
                if period not in ("day", "week", "days_28"):
                    return Response(
                        message=f"Error: Invalid period '{period}'. Use: day, week, days_28.",
                        break_loop=False,
                    )
                page_metric = metric or "page_impressions,page_engaged_users,page_fan_adds"
                self.set_progress("Fetching page insights...")
                result = await client.get_page_insights(metric=page_metric, period=period)
                if result.get("error"):
                    return Response(
                        message=f"Error: {result.get('detail', 'Unknown error')}",
                        break_loop=False,
                    )
                data = result.get("data", [])
                if not data:
                    return Response(message="No page insights data available.", break_loop=False)
                from plugins.facebook.helpers.sanitize import format_insights
                return Response(
                    message=f"Page Insights ({period}):\n\n{format_insights(data)}",
                    break_loop=False,
                )

            elif action == "post":
                if not post_id:
                    return Response(message="Error: 'post_id' is required for post insights.", break_loop=False)
                from plugins.facebook.helpers.sanitize import validate_post_id
                try:
                    post_id = validate_post_id(post_id)
                except ValueError as e:
                    return Response(message=f"Validation error: {e}", break_loop=False)

                post_metric = metric or "post_impressions,post_engaged_users,post_clicks"
                self.set_progress("Fetching post insights...")
                result = await client.get_post_insights(post_id, metric=post_metric)
                if result.get("error"):
                    return Response(
                        message=f"Error: {result.get('detail', 'Unknown error')}",
                        break_loop=False,
                    )
                data = result.get("data", [])
                if not data:
                    return Response(message="No post insights data available.", break_loop=False)
                from plugins.facebook.helpers.sanitize import format_insights
                return Response(
                    message=f"Post Insights:\n\n{format_insights(data)}",
                    break_loop=False,
                )

            else:
                return Response(
                    message=f"Error: Unknown action '{action}'. Use: page, post.",
                    break_loop=False,
                )
        finally:
            await client.close()
