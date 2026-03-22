# Facebook Pages Plugin — Development Guide

## Project Structure

```
a0-facebook/
├── plugin.yaml           # Plugin manifest (name: facebook)
├── default_config.yaml   # Default settings
├── initialize.py         # Dependency installer (aiohttp)
├── install.sh            # Deployment script
├── .gitignore            # Excludes data/, config.json, __pycache__/
├── helpers/
│   ├── __init__.py       # Empty init
│   ├── facebook_auth.py  # Auth, token management, usage tracking
│   ├── facebook_client.py# Async Graph API client with rate limiting
│   └── sanitize.py       # Validation, formatting, sanitization
├── tools/
│   ├── facebook_post.py     # Create posts (text, link, scheduled)
│   ├── facebook_read.py     # Read feed, posts, comments
│   ├── facebook_comment.py  # Reply to / delete comments
│   ├── facebook_manage.py   # Delete/edit posts, hide comments
│   ├── facebook_media.py    # Upload photos
│   ├── facebook_insights.py # Page and post analytics
│   └── facebook_page.py     # Page info, managed pages list
├── prompts/              # Tool prompt definitions (8 files)
├── api/                  # API handlers (2 files)
├── webui/                # Dashboard and settings UI (2 files)
├── skills/               # Skill definitions (3 skills)
├── tests/                # Regression suite + human test plan
└── docs/                 # Documentation (4 files)
```

## Development Setup

1. Start the dev container:
   ```bash
   docker start agent-zero-dev
   ```

2. Install the plugin:
   ```bash
   docker cp a0-facebook/. agent-zero-dev:/a0/usr/plugins/facebook/
   docker exec agent-zero-dev ln -sf /a0/usr/plugins/facebook /a0/plugins/facebook
   docker exec agent-zero-dev /opt/venv-a0/bin/python3 /a0/usr/plugins/facebook/initialize.py
   docker exec agent-zero-dev touch /a0/usr/plugins/facebook/.toggle-1
   docker exec agent-zero-dev supervisorctl restart run_ui
   ```

3. Run tests:
   ```bash
   ./tests/regression_test.sh agent-zero-dev 50083
   ```

## Adding a New Tool

1. Create `tools/facebook_<action>.py` with a Tool subclass:
   ```python
   from helpers.tool import Tool, Response

   class FacebookNewTool(Tool):
       async def execute(self, **kwargs) -> Response:
           action = self.args.get("action", "default")
           # ... implementation
           return Response(message="Result", break_loop=False)
   ```

2. Create `prompts/agent.system.tool.facebook_<action>.md` with:
   - Tool description
   - Security notes
   - Arguments list
   - JSON examples

3. Add tests in `tests/regression_test.sh`

4. Update documentation

## Code Patterns

### Config Loading
```python
from plugins.facebook.helpers.facebook_auth import get_facebook_config
config = get_facebook_config(self.agent)
```

### Client Usage (always in try/finally)
```python
from plugins.facebook.helpers.facebook_client import FacebookClient
client = FacebookClient(config)
try:
    result = await client.create_post(message="Hello")
    if result.get("error"):
        return Response(message=f"Error: {result.get('detail')}", break_loop=False)
    return Response(message="Success", break_loop=False)
finally:
    await client.close()
```

### Input Validation
```python
from plugins.facebook.helpers.sanitize import validate_post_id, sanitize_text
post_id = validate_post_id(post_id)  # Raises ValueError if invalid
message = sanitize_text(message)      # Strips zero-width chars, normalizes unicode
```

### Progress Reporting
```python
self.set_progress("Posting to Facebook Page...")
```

## Code Style

- Follow existing patterns from Bluesky/Telegram plugins
- Use `async/await` for all I/O operations
- Always close client connections in `try/finally`
- Return `Response(message=..., break_loop=False)` from tools
- Use `logging.getLogger()` for logging, never `print()`
- Validate all external inputs (IDs, text content)
- Mask sensitive data in API responses
- Keep `requires_csrf() -> True` on all API handlers (NEVER False)

## Graph API Reference

- [Graph API Documentation](https://developers.facebook.com/docs/graph-api/)
- [Page API Reference](https://developers.facebook.com/docs/pages-api/)
- [Graph API Explorer](https://developers.facebook.com/tools/explorer/)
- [Access Token Debugger](https://developers.facebook.com/tools/accesstoken/)
