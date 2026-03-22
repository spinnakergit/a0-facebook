"""
Facebook Graph API authentication module.

Supports:
- Page Access Token authentication (long-lived preferred)
- Token validation via GET /me endpoint

Authentication flow:
1. User creates a Facebook App at developers.facebook.com
2. User generates a Page Access Token with required permissions
3. Plugin stores page_access_token and page_id in config
4. On each request, token is passed as access_token query parameter
5. Token validity is checked via GET /me endpoint
"""

import os
import json
import time
import logging
from pathlib import Path

logger = logging.getLogger("facebook_auth")

GRAPH_API_BASE = "https://graph.facebook.com/v21.0"


def get_facebook_config(agent=None):
    """Load plugin config through A0's plugin config system."""
    try:
        from helpers import plugins
        return plugins.get_plugin_config("facebook", agent=agent) or {}
    except Exception:
        config_path = Path(__file__).parent.parent / "config.json"
        if config_path.exists():
            with open(config_path) as f:
                return json.load(f)
        return {}


def _data_dir(config: dict) -> Path:
    """Get the data directory for storing usage tracking."""
    try:
        from helpers import plugins
        plugin_dir = plugins.get_plugin_dir("facebook")
        data_dir = Path(plugin_dir) / "data"
    except Exception:
        data_dir = Path("/a0/usr/plugins/facebook/data")
    data_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    return data_dir


def _usage_path(config: dict) -> Path:
    """Path to the usage tracking file."""
    return _data_dir(config) / "usage.json"


def secure_write_json(path: Path, data: dict):
    """Atomic write with 0o600 permissions."""
    tmp = path.with_suffix(".tmp")
    fd = os.open(str(tmp), os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(data, f, indent=2)
    except Exception:
        os.unlink(str(tmp))
        raise
    os.replace(str(tmp), str(path))


def _read_json(path: Path) -> dict:
    """Read a JSON file, return empty dict if missing."""
    try:
        with open(path) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def get_page_access_token(config: dict) -> str:
    """Get the Page Access Token from config."""
    return config.get("page_access_token", "").strip()


def get_page_id(config: dict) -> str:
    """Get the Page ID from config."""
    return config.get("page_id", "").strip()


def has_credentials(config: dict) -> bool:
    """Check if page access token is configured."""
    return bool(get_page_access_token(config))


def get_auth_params(config: dict) -> dict:
    """Get query parameters for Graph API authentication."""
    token = get_page_access_token(config)
    if not token:
        return {}
    return {"access_token": token}


# --- Authentication Status ---

def is_authenticated(config: dict) -> tuple:
    """
    Check if credentials are valid by calling GET /me.
    Returns (authenticated: bool, info: str).
    """
    if not has_credentials(config):
        return (False, "No Page Access Token configured")

    try:
        import requests

        token = get_page_access_token(config)
        resp = requests.get(
            f"{GRAPH_API_BASE}/me",
            params={"access_token": token, "fields": "id,name"},
            timeout=10,
        )

        if resp.status_code == 200:
            data = resp.json()
            page_name = data.get("name", "unknown")
            page_id = data.get("id", "")
            info = page_name
            if page_id:
                info += f" (ID: {page_id})"
            return (True, info)
        else:
            error = resp.json().get("error", {})
            msg = error.get("message", f"HTTP {resp.status_code}")
            return (False, msg)
    except Exception as e:
        return (False, str(e))


def get_page_id_from_token(config: dict) -> str:
    """
    Resolve the Page ID from the token via GET /me.
    Useful when page_id is not explicitly set in config.
    """
    configured_id = get_page_id(config)
    if configured_id:
        return configured_id

    try:
        import requests

        token = get_page_access_token(config)
        if not token:
            return ""

        resp = requests.get(
            f"{GRAPH_API_BASE}/me",
            params={"access_token": token, "fields": "id"},
            timeout=10,
        )
        if resp.status_code == 200:
            return resp.json().get("id", "")
        return ""
    except Exception:
        return ""


# --- Usage Tracking ---

def get_usage(config: dict) -> dict:
    """Get current month's usage stats."""
    from datetime import datetime
    current_month = datetime.now().strftime("%Y-%m")
    usage = _read_json(_usage_path(config))
    if usage.get("month") != current_month:
        usage = {
            "month": current_month,
            "posts_created": 0,
            "posts_deleted": 0,
            "comments": 0,
            "photos_uploaded": 0,
        }
        secure_write_json(_usage_path(config), usage)
    return usage


def increment_usage(config: dict, field: str = "posts_created"):
    """Increment a usage counter for the current month."""
    usage = get_usage(config)
    usage[field] = usage.get(field, 0) + 1
    secure_write_json(_usage_path(config), usage)
