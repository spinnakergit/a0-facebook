# Facebook Pages Plugin — Setup Guide

## Requirements

- Agent Zero v2026-03-13 or later
- Docker or local Python 3.10+
- A Facebook Page you admin (see [Create a Page](#prerequisite-create-a-facebook-page) below)
- A Facebook Developer account at [developers.facebook.com](https://developers.facebook.com)

> **New Facebook account?** Meta restricts some features (including Page creation) on brand-new accounts. If you hit issues, see the troubleshooting notes in the [Page creation section](#prerequisite-create-a-facebook-page) below.

## Dependencies

Installed automatically by `initialize.py`:
- `aiohttp` — Async HTTP client for Graph API calls
- `requests` — Sync HTTP client for authentication checks

## Installation

### Option A: Install Script

```bash
# Copy plugin to container and run install
docker cp a0-facebook/. a0-container:/a0/usr/plugins/facebook/
docker exec a0-container bash /a0/usr/plugins/facebook/install.sh
```

### Option B: Manual Installation

```bash
# Copy files
docker cp a0-facebook/. a0-container:/a0/usr/plugins/facebook/

# Create symlink
docker exec a0-container ln -sf /a0/usr/plugins/facebook /a0/plugins/facebook

# Install dependencies
docker exec a0-container /opt/venv-a0/bin/python /a0/usr/plugins/facebook/initialize.py

# Enable the plugin
docker exec a0-container touch /a0/usr/plugins/facebook/.toggle-1

# Restart
docker exec a0-container supervisorctl restart run_ui
```

## Prerequisite: Create a Facebook Page

You need a Facebook Page before you can generate a Page Access Token. If you already have one, skip to [Facebook Developer Setup](#facebook-developer-setup).

1. Go to [facebook.com/pages/create](https://www.facebook.com/pages/create)
2. Enter a **Page name** and **category** (e.g., "Software", "Technology")
3. Click **Create Page**

> **"An error occurred while creating the page"?** This is common with new Facebook accounts. Meta restricts Page creation as an anti-spam measure. Try these fixes:
> 1. **Complete your profile** — add a profile photo, bio, and some basic info
> 2. **Verify your account** — Settings → Accounts Center → Personal Details → confirm email and phone
> 3. **Wait 24-48 hours** — new accounts need some activity before Meta unlocks Page creation (browse, like a few posts)
> 4. **Try mobile** — the Facebook mobile app sometimes works when desktop doesn't
> 5. **Try an alternate URL** — [facebook.com/pages/creation](https://www.facebook.com/pages/creation) or from your profile click the **"Create"** section → **Page**

---

## Facebook Developer Setup

### 1. Register as a Meta Developer

If you haven't registered as a Meta developer before, you must do this first — otherwise the "Create App" button will not appear.

1. Go to [developers.facebook.com](https://developers.facebook.com/) and click **"Get Started"**
2. Accept the **Platform Terms** and **Developer Policies**
3. **Verify your phone number** (Meta sends a confirmation code)
4. **Verify your email address**
5. Select your occupation/role

> **Troubleshooting:** If you still don't see a "Create App" button after registering:
> - **15-app limit:** Meta caps you at 15 apps unless connected to a verified Business Portfolio. Delete unused apps at [developers.facebook.com/apps](https://developers.facebook.com/apps/) to free up slots.
> - **Browser issue:** Try incognito mode or clear your cache.
> - **Direct URL:** Navigate directly to [developers.facebook.com/apps/creation/](https://developers.facebook.com/apps/creation/) to bypass the dashboard.

### 2. Create a Facebook App

Meta now uses a **use-case-based flow** instead of the older "app type" selection.

1. Go to [developers.facebook.com/apps/creation/](https://developers.facebook.com/apps/creation/)
2. Enter an **app name** (e.g., "Agent Zero Page Manager") and **contact email**
3. Click **Next**
4. Select the use case: **"Manage everything on your Page"** — this enables the Facebook Pages API and auto-includes core permissions (`business_management`, `pages_show_list`, `public_profile`)
5. Optionally add compatible use cases (e.g., "Access Threads API" if you also use the Threads plugin)
6. **Business Portfolio:** You can select "I don't want to connect a business portfolio yet" for development/testing. A verified Business Portfolio is required later for App Review and going live.
7. Click **"Go to dashboard"**

> **Note:** Older guides reference selecting "Business" as the app type — Meta replaced this with the use-case flow. The functionality is the same.

> **Tip:** Facebook, Instagram, and Threads all use Meta's Graph API and can share a single app. If you plan to use multiple Meta plugins, create one app and add each product (Instagram Graph API, Threads API) from the dashboard instead of creating separate apps.

### 3. Configure Permissions

Your app needs these permissions for full plugin functionality:

| Permission | Purpose | Required | Included by use case? |
|---|---|---|---|
| `pages_show_list` | List Pages the user manages | Yes | Yes (required) |
| `business_management` | Manage business assets | Yes | Yes (required) |
| `public_profile` | Basic profile info | Yes | Yes (required) |
| `pages_manage_posts` | Create, edit, delete posts on managed Pages | Yes | Optional — add in use case |
| `pages_read_engagement` | Read likes, comments, shares, and reactions | Yes | Optional — add in use case |
| `pages_read_user_content` | Read user-generated content on the Page | Yes | Optional — add in use case |
| `pages_manage_metadata` | Read Page information and settings | Recommended | Optional — add in use case |
| `pages_manage_engagement` | Hide/unhide comments, manage engagement | Recommended | Optional — add in use case |

**How to add optional permissions:**

1. In the left sidebar of your app dashboard, click **"Use cases"**
2. Find **"Manage everything on your Page"** and click the **"Customize"** button next to it
3. You'll see a list of available permissions — add each optional permission from the table above
4. Save your changes

> **Note:** The old "App Review → Permissions and Features" path no longer exists. Permissions are now managed inside the use case itself.

> **Development vs. Production:**
> - **Development mode** (default): All permissions work immediately for users with a role on the app (admin, developer, tester). You can also just check permission boxes in the Graph API Explorer when generating a token — this works without configuring them in the dashboard first.
> - **Production mode**: Permissions require App Review approval. Go to **Publish** in the left sidebar to submit for review.

### 4. Generate a Page Access Token

Getting a Page Access Token is a two-step process: first generate a User Token with the right permissions, then exchange it for a Page Token.

**Step A — Generate a User Token with page permissions:**

1. Go to the [Graph API Explorer](https://developers.facebook.com/tools/explorer/)
2. Select your app from the **"Meta App"** dropdown
3. Click the **"Permissions"** button (or **"Generate Access Token"**)
4. **Check all of these permissions** before generating:
   - `pages_show_list`
   - `pages_manage_posts`
   - `pages_read_engagement`
   - `pages_read_user_content`
   - `pages_manage_engagement`
   - `pages_manage_metadata`
5. Click **"Generate Access Token"** and authorize when prompted
6. You now have a **User Token** — this is an intermediate step, not the final token

> **Common mistake:** If you generate a token without checking the page permissions first, it won't have access to your Pages. You'll need to regenerate with the correct permissions checked.

**Step B — Get the Page Access Token:**

7. In the Graph API Explorer query field, enter `/me/accounts` and click **Submit**
8. The response lists all Pages you manage, each with its own `access_token`
9. Copy the `access_token` value for your Page — **this is your Page Access Token**

Alternatively, if the Explorer shows a token-type dropdown, you can switch from **"User Token"** to your **Page name** to get the Page Access Token directly.

> **Important:** User Access Tokens and Page Access Tokens are different. You need a **Page Access Token** — it starts with `EAA...` and grants access to act as the Page.

> **"data":[] empty response?** This means either: (a) you don't have a Facebook Page yet — create one at [facebook.com/pages/create](https://facebook.com/pages/create), or (b) your User Token is missing the `pages_show_list` permission — regenerate with the correct permissions checked.

### 5. Extend Token Lifetime (Recommended)

Short-lived tokens expire in about 1 hour. For production use:

1. Go to the [Access Token Debugger](https://developers.facebook.com/tools/debug/accesstoken/)
2. Paste your Page Access Token and click **"Debug"**
3. Check the expiration — if it says "Expires," click **"Extend Access Token"**
4. A long-lived Page Access Token (60 days or never-expiring for Pages) will be generated
5. Copy the new long-lived token

Alternatively, exchange programmatically:
```
GET /oauth/access_token?
    grant_type=fb_exchange_token&
    client_id={app-id}&
    client_secret={app-secret}&
    fb_exchange_token={short-lived-token}
```

> **Page Access Tokens derived from long-lived User Tokens do not expire** for Pages you manage. This is the recommended approach.

## Credential Mapping Reference

| What You Need | Source | Plugin Config Field |
|---|---|---|
| Page Access Token | Graph API Explorer > Select Page | Settings > **Page Access Token** |
| Page ID | Page URL or /me endpoint (auto-resolved) | Settings > **Page ID** (optional) |

## Verifying Installation

1. Open Agent Zero WebUI
2. Go to **Settings** and find **Facebook Pages** in the plugin list
3. Click the plugin to open its settings
4. Confirm the configuration page loads
5. Enter your Page Access Token (and optionally Page ID)
6. Click "Save Facebook Pages Settings"
7. Click "Test Connection"
8. Expected: green "Connected as [Page Name] (ID: xxxxx)" badge

## How Authentication Works

1. Plugin stores the Page Access Token in `config.json` (0600 permissions)
2. All Graph API calls include `access_token` as a query parameter
3. Token validity is checked via `GET /v21.0/me` which returns page name and ID
4. If Page ID is not configured, it is auto-resolved from the `/me` endpoint
5. Token expiration is handled by Facebook — long-lived Page tokens do not expire
6. If the token becomes invalid, the plugin reports the error and prompts reconfiguration

## Graph API Version

This plugin uses **Facebook Graph API v21.0**. The base URL is:
```
https://graph.facebook.com/v21.0/
```

Key endpoints used:
| Endpoint | Method | Purpose |
|---|---|---|
| `/me` | GET | Validate token, get page info |
| `/{page-id}/feed` | GET/POST | Read feed, create posts |
| `/{post-id}` | GET/POST/DELETE | Read, edit, delete posts |
| `/{post-id}/comments` | GET | Read comments |
| `/{comment-id}/comments` | POST | Reply to comments |
| `/{comment-id}` | POST/DELETE | Hide/delete comments |
| `/{page-id}/photos` | POST | Upload photos |
| `/{page-id}/insights` | GET | Page analytics |
| `/{post-id}/insights` | GET | Post analytics |
| `/me/accounts` | GET | List managed pages |

## Rate Limits

Facebook enforces app-level and page-level rate limits:
- **App-level:** ~200 calls per user per hour
- **Page-level:** Tracked via `x-page-usage` response header
- The plugin includes a built-in rate limiter that tracks calls and backs off at 80% usage

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Plugin not visible | Check `.toggle-1` exists: `ls /a0/usr/plugins/facebook/.toggle-1` |
| Import errors | Run `initialize.py` again to install dependencies |
| "No Page Access Token configured" | Enter token in plugin settings |
| "Invalid OAuth access token" | Token expired or was revoked — regenerate via Graph API Explorer |
| "OAuthException (code 190)" | Token is invalid — check in Access Token Debugger |
| "(#10) This endpoint requires the 'pages_read_engagement' permission" | Missing permission — re-authorize with correct scopes |
| "Page ID not resolved" | Set Page ID explicitly in settings, or ensure token is a Page Access Token (not User token) |
| Insights return empty | Page must have at least 100 followers for some metrics; check the time period |
| Rate limit errors (429) | Plugin auto-retries with backoff; reduce request frequency if persistent |
| Photo upload fails | Max 10MB per image; check file path exists and is readable |
