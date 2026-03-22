---
name: "facebook-post"
description: "Create and publish content on a Facebook Page. Write text posts, share links, upload photos, and schedule posts for future publication."
version: "1.0.0"
author: "AgentZero Facebook Plugin"
license: "MIT"
tags: ["facebook", "social-media", "publishing", "content"]
triggers:
  - "post to facebook"
  - "facebook post"
  - "publish on facebook"
  - "share on facebook page"
allowed_tools:
  - facebook_post
  - facebook_media
  - facebook_page
metadata:
  complexity: "beginner"
  category: "social-media"
---

# Facebook Post Skill

Create and publish content on a Facebook Page.

## Workflow

### Step 1: Verify Connection
Check which page is connected:
```json
{"tool": "facebook_page", "args": {"action": "info"}}
```

### Step 2: Create a Post
Publish a text post:
```json
{"tool": "facebook_post", "args": {"action": "create", "message": "Your post content here"}}
```

Share a link:
```json
{"tool": "facebook_post", "args": {"action": "create_link", "message": "Check this out!", "link": "https://example.com"}}
```

Upload a photo:
```json
{"tool": "facebook_media", "args": {"action": "upload_photo", "image_url": "https://example.com/photo.jpg", "caption": "Great photo!"}}
```

### Step 3: Schedule for Later
Schedule a post for future publication:
```json
{"tool": "facebook_post", "args": {"action": "schedule", "message": "Upcoming event!", "scheduled_time": "1735689600"}}
```

## Tips
- Links automatically generate preview cards on Facebook
- Scheduled posts must be 10 minutes to 6 months in the future
- Use `facebook_page` with `action: info` to verify the connected page
- Photos support JPEG, PNG, GIF, BMP, TIFF, WebP (max 10MB)
