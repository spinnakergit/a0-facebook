## facebook_insights
Get analytics and insights for a Facebook Page and its posts.

**Arguments:**
- **action** (string): `page` or `post`
- **post_id** (string): Post ID (required for `post` action)
- **metric** (string): Comma-separated metrics (optional, defaults provided)
- **period** (string): `day`, `week`, or `days_28` (for `page` action, default: `day`)

~~~json
{"action": "page"}
~~~
~~~json
{"action": "page", "period": "week", "metric": "page_impressions,page_fan_adds"}
~~~
~~~json
{"action": "post", "post_id": "123456789_987654321"}
~~~

**Default page metrics:** page_impressions, page_engaged_users, page_fan_adds
**Default post metrics:** post_impressions, post_engaged_users, post_clicks

**Available page metrics:**
- `page_impressions` — Total page impressions
- `page_engaged_users` — Unique users who engaged
- `page_fan_adds` — New page likes/follows
- `page_views_total` — Total page views
- `page_post_engagements` — Total post engagements

**Available post metrics:**
- `post_impressions` — Post impressions
- `post_engaged_users` — Users who engaged with post
- `post_clicks` — Total post clicks
- `post_reactions_by_type_total` — Reactions breakdown
