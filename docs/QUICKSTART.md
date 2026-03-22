# Facebook Pages Plugin — Quick Start

## Prerequisites

- Agent Zero instance (Docker or local)
- A Facebook Page you manage
- A Facebook Developer account

## Installation

```bash
# From inside the Agent Zero container:
cd /tmp
# Copy plugin files, then:
./install.sh

# Or manually:
cp -r a0-facebook/ /a0/usr/plugins/facebook/
ln -sf /a0/usr/plugins/facebook /a0/plugins/facebook
python3 /a0/usr/plugins/facebook/initialize.py
touch /a0/usr/plugins/facebook/.toggle-1
```

## Configuration

1. Open Agent Zero WebUI
2. Go to **Settings** and find **Facebook Pages** in the plugin list
3. Enter your **Page Access Token** (see [Setup Guide](SETUP.md) for how to get one)
4. Optionally enter your **Page ID** (auto-resolved if blank)
5. Click "Save Facebook Pages Settings"
6. Click "Test Connection" on the dashboard

## First Use

Ask the agent:
> "Get info about our Facebook Page"

> "Show me the recent posts on our Facebook Page"

> "Post to Facebook: Hello from Agent Zero!"

> "Show me our Facebook Page insights for this week"

## Example Workflows

### Post Content
> "Create a Facebook post about our upcoming product launch on March 20th"

### Moderate Comments
> "Show me the comments on our latest Facebook post and reply to any questions"

### Analyze Performance
> "Get weekly insights for our Facebook Page and summarize the trends"

## Known Behaviors

- **Development Mode visibility:** When your Facebook App is in Development mode, API-created posts are only visible to users with a role on the app (admin, developer, tester). Add other accounts as testers in App Roles and have them accept the invitation.
- **Page Insights require 100+ followers:** Facebook restricts some insight metrics to Pages with at least 100 followers. The plugin handles this gracefully and reports when data is unavailable.
- **Post Insights need time:** Newly created posts have no analytics data. Insights become available after the post accumulates impressions and engagement.
- **Graph API v21.0 field changes:** The `type` field and `likes.summary()` aggregation are deprecated. This plugin uses `reactions.summary()` for engagement metrics.
- **Plugin YAML quoting:** The `description` field in `plugin.yaml` must be quoted if it contains colons (e.g., `description: "Manage Pages: post, read..."`).

## Troubleshooting

- **"No Page Access Token configured"** — Set the token in plugin settings
- **"Invalid OAuth access token"** — Token may have expired; generate a new one
- **"(#200) Requires pages_manage_posts permission"** — Token missing required permissions
- **Rate limiting** — The plugin automatically handles rate limits; wait and retry
- **Plugin not visible after install** — Run `supervisorctl restart run_ui` inside the container
- **Posts not visible to other accounts** — App is in Development mode; add the account as a tester (see Known Behaviors above)
