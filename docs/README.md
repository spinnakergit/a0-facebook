# Facebook Pages Plugin Documentation

## Overview

Manage Facebook Pages via the Graph API v21.0: create posts, read feeds, moderate comments, upload photos, and analyze page insights.

## Contents

- [Quick Start](QUICKSTART.md) — Installation and first-use guide
- [Setup](SETUP.md) — Detailed Facebook Developer Console setup
- [Development](DEVELOPMENT.md) — Contributing and development setup

## Architecture

```
a0-facebook/
├── helpers/
│   ├── facebook_auth.py    # Token management, usage tracking, secure writes
│   ├── facebook_client.py  # Async Graph API client (aiohttp) with rate limiting
│   └── sanitize.py         # Input validation, content formatting
├── tools/
│   ├── facebook_post.py    # Create text/link/scheduled posts
│   ├── facebook_read.py    # Read feed, posts, comments
│   ├── facebook_comment.py # Reply to / delete comments
│   ├── facebook_manage.py  # Delete/edit posts, hide comments
│   ├── facebook_media.py   # Upload photos
│   ├── facebook_insights.py# Page and post analytics
│   └── facebook_page.py    # Page info, managed pages list
├── api/
│   ├── facebook_test.py    # Connection test endpoint (CSRF required)
│   └── facebook_config_api.py # Config read/write endpoint (CSRF required)
├── webui/
│   ├── main.html           # Dashboard with connection status
│   └── config.html         # Settings page for token and page ID
├── prompts/                # Tool prompt definitions for the LLM
├── skills/                 # Skill workflows (post, research, engage)
└── tests/                  # Regression suite + human test plan
```

## Data Flow

1. User asks agent to interact with their Facebook Page
2. Agent selects the appropriate `facebook_*` tool
3. Tool loads config via `get_facebook_config(agent)`
4. Tool creates `FacebookClient` with config
5. Client makes async HTTP requests to `https://graph.facebook.com/v21.0/`
6. All requests include `access_token` parameter
7. Responses are formatted via `sanitize.py` helpers and returned to agent

## Tools

| Tool | Actions | Description |
|------|---------|-------------|
| `facebook_post` | create, create_link, schedule | Create page posts |
| `facebook_read` | feed, post, comments | Read page content |
| `facebook_comment` | reply, delete | Comment management |
| `facebook_manage` | delete_post, edit_post, hide_comment, unhide_comment | Content moderation |
| `facebook_media` | upload_photo | Photo uploads |
| `facebook_insights` | page, post | Analytics |
| `facebook_page` | info, pages_list | Page metadata |

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/plugins/facebook/facebook_test` | GET/POST | Test connection |
| `/api/plugins/facebook/facebook_config_api` | GET/POST | Read/write config |

## Security

- All API endpoints require CSRF tokens
- Page Access Token is masked in config API responses
- Atomic file writes with 0o600 permissions for config and usage data
- Data directory created with 0o700 permissions
- Input validation on all IDs (page, post, comment) via strict regex
- Path traversal protection on file upload paths
- Unicode normalization (NFKC) and zero-width character stripping
- Rate limiting (200 calls/hour aligned with Graph API limits)
- Generic error messages (no stack traces or class names exposed)

**Security Assessment:** Stage 3a white-box completed 2026-03-22. 0 Critical, 0 High findings. See [SECURITY_ASSESSMENT_RESULTS.md](../tests/SECURITY_ASSESSMENT_RESULTS.md).
