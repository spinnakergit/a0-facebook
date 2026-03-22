---
name: "facebook-research"
description: "Research and analyze Facebook Page performance. Read posts, review comments, check engagement metrics, and gather insights for content strategy."
version: "1.0.0"
author: "AgentZero Facebook Plugin"
license: "MIT"
tags: ["facebook", "analytics", "research", "insights"]
triggers:
  - "facebook analytics"
  - "analyze facebook page"
  - "facebook insights"
  - "facebook page performance"
allowed_tools:
  - facebook_read
  - facebook_insights
  - facebook_page
metadata:
  complexity: "intermediate"
  category: "research"
---

# Facebook Research Skill

Analyze Facebook Page performance and gather insights.

## Workflow

### Step 1: Get Page Overview
```json
{"tool": "facebook_page", "args": {"action": "info"}}
```

### Step 2: Review Recent Posts
```json
{"tool": "facebook_read", "args": {"action": "feed", "max_results": "20"}}
```

### Step 3: Check Page Insights
Daily performance:
```json
{"tool": "facebook_insights", "args": {"action": "page", "period": "day"}}
```

Weekly summary:
```json
{"tool": "facebook_insights", "args": {"action": "page", "period": "week"}}
```

### Step 4: Analyze Specific Posts
Get post details:
```json
{"tool": "facebook_read", "args": {"action": "post", "post_id": "PAGE_ID_POST_ID"}}
```

Get post engagement metrics:
```json
{"tool": "facebook_insights", "args": {"action": "post", "post_id": "PAGE_ID_POST_ID"}}
```

### Step 5: Review Audience Engagement
Read comments on top posts:
```json
{"tool": "facebook_read", "args": {"action": "comments", "post_id": "PAGE_ID_POST_ID"}}
```

## Tips
- Start with `facebook_read` `feed` to discover post IDs
- Use `facebook_insights` with different periods for trend analysis
- Post IDs are in format `{page_id}_{post_id}`
- Available insight periods: `day`, `week`, `days_28`
