---
name: "facebook-engage"
description: "Engage with the Facebook Page community. Reply to comments, moderate discussions, and manage page content for community building."
version: "1.0.0"
author: "AgentZero Facebook Plugin"
license: "MIT"
tags: ["facebook", "community", "moderation", "engagement"]
triggers:
  - "facebook comments"
  - "moderate facebook"
  - "reply on facebook"
  - "facebook community management"
allowed_tools:
  - facebook_read
  - facebook_comment
  - facebook_manage
metadata:
  complexity: "intermediate"
  category: "communication"
---

# Facebook Engage Skill

Manage community engagement on a Facebook Page.

## Workflow

### Step 1: Find Recent Posts
```json
{"tool": "facebook_read", "args": {"action": "feed", "max_results": "10"}}
```

### Step 2: Review Comments on a Post
```json
{"tool": "facebook_read", "args": {"action": "comments", "post_id": "PAGE_ID_POST_ID", "max_results": "50"}}
```

### Step 3: Reply to a Comment
```json
{"tool": "facebook_comment", "args": {"action": "reply", "comment_id": "COMMENT_ID", "message": "Thank you for your feedback!"}}
```

### Step 4: Moderate Comments
Hide inappropriate comments:
```json
{"tool": "facebook_manage", "args": {"action": "hide_comment", "comment_id": "COMMENT_ID"}}
```

Delete spam:
```json
{"tool": "facebook_comment", "args": {"action": "delete", "comment_id": "COMMENT_ID"}}
```

### Step 5: Edit or Remove Posts
Edit a post:
```json
{"tool": "facebook_manage", "args": {"action": "edit_post", "post_id": "PAGE_ID_POST_ID", "message": "Updated content"}}
```

## Tips
- Always read comments before replying to understand context
- Use `hide_comment` instead of `delete` for borderline content (hides from public but preserves the comment)
- Reply thoughtfully — responses appear as the page, not a personal account
- Comment IDs are obtained from the `facebook_read` `comments` action
