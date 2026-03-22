# Facebook Pages Plugin for Agent Zero

Manage Facebook Pages via the Graph API v21.0: create posts, read feeds, moderate comments, upload photos, and analyze page insights.

## Quick Start

1. Copy the plugin to your Agent Zero instance:
   ```bash
   ./install.sh
   ```
2. Configure your Page Access Token in the WebUI (Settings > Facebook Pages)
3. Restart Agent Zero

## Features

- **Post Management** — Create text posts, link posts, and scheduled posts
- **Feed Reading** — Read page feed, individual posts, and comments
- **Comment Moderation** — Reply to, hide, unhide, and delete comments
- **Photo Upload** — Upload photos from local files or URLs with captions
- **Page Insights** — Track impressions, engagement, fan growth, and post performance
- **Page Management** — View page info, list managed pages, edit and delete posts

## Tools

| Tool | Description |
|------|-------------|
| `facebook_post` | Create text, link, and scheduled posts |
| `facebook_read` | Read page feed, posts, and comments |
| `facebook_comment` | Reply to and delete comments |
| `facebook_manage` | Delete/edit posts, hide/unhide comments |
| `facebook_media` | Upload photos to the page |
| `facebook_insights` | Page and post analytics |
| `facebook_page` | Page info and managed pages list |

## Required Permissions

- `pages_manage_posts` — Create and manage page posts
- `pages_read_engagement` — Read likes, comments, shares
- `pages_read_user_content` — Read user-generated content on the page
- `pages_manage_metadata` — Manage page settings

## Documentation

- [Quick Start Guide](docs/QUICKSTART.md)
- [Setup Guide](docs/SETUP.md)
- [Development Guide](docs/DEVELOPMENT.md)
- [Full Documentation](docs/README.md)

## License

MIT — see [LICENSE](LICENSE)
