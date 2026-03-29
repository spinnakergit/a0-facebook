#!/bin/bash
# Facebook Pages Plugin Regression Test Suite
# Runs against a live Agent Zero container with the Facebook plugin installed.
#
# Usage:
#   ./regression_test.sh                    # Test against default (agent-zero-dev-latest on port 50084)
#   ./regression_test.sh <container> <port> # Test against specific container
#
# Requires: curl, python3 (for JSON parsing)

CONTAINER="${1:-agent-zero-dev-latest}"
PORT="${2:-50084}"
BASE_URL="http://localhost:${PORT}"

PASSED=0
FAILED=0
SKIPPED=0
ERRORS=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

pass() {
    PASSED=$((PASSED + 1))
    echo -e "  ${GREEN}PASS${NC} $1"
}

fail() {
    FAILED=$((FAILED + 1))
    ERRORS="${ERRORS}\n  - $1: $2"
    echo -e "  ${RED}FAIL${NC} $1 — $2"
}

skip() {
    SKIPPED=$((SKIPPED + 1))
    echo -e "  ${YELLOW}SKIP${NC} $1 — $2"
}

section() {
    echo ""
    echo -e "${CYAN}━━━ $1 ━━━${NC}"
}

# Helper: acquire CSRF token + session cookie from the container
CSRF_TOKEN=""
setup_csrf() {
    if [ -z "$CSRF_TOKEN" ]; then
        CSRF_TOKEN=$(docker exec "$CONTAINER" bash -c '
            curl -s -c /tmp/test_cookies.txt \
                -H "Origin: http://localhost" \
                "http://localhost/api/csrf_token" 2>/dev/null
        ' | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))" 2>/dev/null)
    fi
}

# Helper: curl the container's internal API (with CSRF token)
api() {
    local endpoint="$1"
    local data="${2:-}"
    setup_csrf
    if [ -n "$data" ]; then
        docker exec "$CONTAINER" curl -s -X POST "http://localhost/api/plugins/facebook/${endpoint}" \
            -H "Content-Type: application/json" \
            -H "Origin: http://localhost" \
            -H "X-CSRF-Token: ${CSRF_TOKEN}" \
            -b /tmp/test_cookies.txt \
            -d "$data" 2>/dev/null
    else
        docker exec "$CONTAINER" curl -s "http://localhost/api/plugins/facebook/${endpoint}" \
            -H "Origin: http://localhost" \
            -H "X-CSRF-Token: ${CSRF_TOKEN}" \
            -b /tmp/test_cookies.txt 2>/dev/null
    fi
}

# Helper: run Python inside the container to test imports/modules
container_python() {
    echo "$1" | docker exec -i "$CONTAINER" bash -c 'cd /a0 && PYTHONPATH=/a0 PYTHONWARNINGS=ignore /opt/venv-a0/bin/python3 -' 2>&1
}

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     Facebook Pages Plugin Regression Test Suite     ║${NC}"
echo -e "${CYAN}║     Container: ${CONTAINER}${NC}"
echo -e "${CYAN}║     Port: ${PORT}${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"

# ============================================================
section "1. Container & Service Health"
# ============================================================

# T1.1: Container is running
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    pass "T1.1 Container is running"
else
    fail "T1.1 Container is running" "Container '${CONTAINER}' not found"
    echo "Cannot continue without a running container."
    exit 1
fi

# T1.2: run_ui service is running
STATUS=$(docker exec "$CONTAINER" supervisorctl status run_ui 2>/dev/null | awk '{print $2}')
if [ "$STATUS" = "RUNNING" ]; then
    pass "T1.2 run_ui service is running"
else
    fail "T1.2 run_ui service is running" "Status: $STATUS"
fi

# T1.3: WebUI is accessible
HTTP_CODE=$(docker exec "$CONTAINER" curl -s -o /dev/null -w '%{http_code}' http://localhost/ 2>/dev/null)
if [ "$HTTP_CODE" = "200" ]; then
    pass "T1.3 WebUI is accessible (HTTP 200)"
else
    fail "T1.3 WebUI is accessible" "HTTP $HTTP_CODE"
fi

# ============================================================
section "2. Plugin Installation"
# ============================================================

# T2.1: Plugin directory exists
if docker exec "$CONTAINER" test -d /a0/usr/plugins/facebook; then
    pass "T2.1 Plugin directory exists at /a0/usr/plugins/facebook"
else
    fail "T2.1 Plugin directory exists" "Directory not found"
fi

# T2.2: Symlink exists and is correct
LINK=$(docker exec "$CONTAINER" readlink /a0/plugins/facebook 2>/dev/null)
if [ "$LINK" = "/a0/usr/plugins/facebook" ]; then
    pass "T2.2 Symlink /a0/plugins/facebook -> /a0/usr/plugins/facebook"
else
    fail "T2.2 Symlink" "Points to: $LINK"
fi

# T2.3: Plugin is enabled
if docker exec "$CONTAINER" test -f /a0/usr/plugins/facebook/.toggle-1; then
    pass "T2.3 Plugin is enabled (.toggle-1 exists)"
else
    fail "T2.3 Plugin is enabled" ".toggle-1 not found"
fi

# T2.4: plugin.yaml is valid
TITLE=$(docker exec "$CONTAINER" /opt/venv-a0/bin/python3 -c "
import yaml
with open('/a0/usr/plugins/facebook/plugin.yaml') as f:
    d = yaml.safe_load(f)
print(d.get('title', ''))
" 2>/dev/null)
if [ "$TITLE" = "Facebook Pages" ]; then
    pass "T2.4 plugin.yaml valid (title: $TITLE)"
else
    fail "T2.4 plugin.yaml" "Title: '$TITLE'"
fi

# T2.5: plugin.yaml name field is correct
NAME=$(docker exec "$CONTAINER" /opt/venv-a0/bin/python3 -c "
import yaml
with open('/a0/usr/plugins/facebook/plugin.yaml') as f:
    d = yaml.safe_load(f)
print(d.get('name', ''))
" 2>/dev/null)
if [ "$NAME" = "facebook" ]; then
    pass "T2.5 plugin.yaml name field: $NAME"
else
    fail "T2.5 plugin.yaml name" "Got: '$NAME', expected: 'facebook'"
fi

# T2.6: Config file exists or defaults work
HAS_TOKEN=$(docker exec "$CONTAINER" /opt/venv-a0/bin/python3 -c "
import json, os
try:
    with open('/a0/usr/plugins/facebook/config.json') as f:
        c = json.load(f)
    token = c.get('page_access_token', '')
except FileNotFoundError:
    token = ''
print('yes' if len(token) > 10 else 'no')
" 2>/dev/null)
if [ "$HAS_TOKEN" = "yes" ]; then
    pass "T2.6 Page Access Token is configured"
    TOKEN_SET=true
else
    skip "T2.6 Page Access Token" "No token configured (set in WebUI)"
    TOKEN_SET=false
fi

# ============================================================
section "3. Python Imports"
# ============================================================

# T3.1: Auth module import
RESULT=$(container_python "from usr.plugins.facebook.helpers.facebook_auth import get_facebook_config, is_authenticated, has_credentials, get_auth_params, get_usage, increment_usage, secure_write_json; print('ok')")
if [ "$RESULT" = "ok" ]; then
    pass "T3.1 Import facebook_auth (all functions)"
else
    fail "T3.1 Import facebook_auth" "$RESULT"
fi

# T3.2: Client import
RESULT=$(container_python "from usr.plugins.facebook.helpers.facebook_client import FacebookClient; print('ok')")
if [ "$RESULT" = "ok" ]; then
    pass "T3.2 Import FacebookClient"
else
    fail "T3.2 Import FacebookClient" "$RESULT"
fi

# T3.3: Sanitize module import
RESULT=$(container_python "from usr.plugins.facebook.helpers.sanitize import sanitize_text, validate_page_id, validate_post_id, validate_comment_id, format_post, format_posts, format_comment, format_comments, format_insights, format_page_info; print('ok')")
if [ "$RESULT" = "ok" ]; then
    pass "T3.3 Import sanitize module (all functions)"
else
    fail "T3.3 Import sanitize module" "$RESULT"
fi

# T3.4: aiohttp dependency
RESULT=$(container_python "import aiohttp; print('ok')")
LAST_LINE=$(echo "$RESULT" | tail -1)
if [ "$LAST_LINE" = "ok" ]; then
    pass "T3.4 aiohttp dependency available"
else
    fail "T3.4 aiohttp dependency" "$RESULT"
fi

# ============================================================
section "4. API Endpoints"
# ============================================================

# T4.1: Facebook test endpoint (connection check — requires token)
if [ "$TOKEN_SET" = "true" ]; then
    RESPONSE=$(api "facebook_test")
    OK=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('ok',''))" 2>/dev/null)
    if [ "$OK" = "True" ]; then
        PAGE_NAME=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('user',''))" 2>/dev/null)
        pass "T4.1 Facebook test endpoint (page: $PAGE_NAME)"
    else
        ERROR=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error','unknown'))" 2>/dev/null)
        fail "T4.1 Facebook test endpoint" "$ERROR"
    fi
else
    skip "T4.1 Facebook test endpoint" "No token configured"
fi

# T4.2: Config API — GET
RESPONSE=$(api "facebook_config_api")
IS_DICT=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if isinstance(d, dict) else 'no')" 2>/dev/null)
if [ "$IS_DICT" = "yes" ]; then
    pass "T4.2 Config API GET returns config dict"
else
    fail "T4.2 Config API GET" "Response: $RESPONSE"
fi

# T4.3: Config API — token is masked (requires token)
if [ "$TOKEN_SET" = "true" ]; then
    MASKED=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); t=d.get('page_access_token',''); print('yes' if '****' in t else 'no')" 2>/dev/null)
    if [ "$MASKED" = "yes" ]; then
        pass "T4.3 Config API masks page_access_token in response"
    else
        fail "T4.3 Config API token masking" "Token not masked"
    fi
else
    skip "T4.3 Config API token masking" "No token configured"
fi

# T4.4: Test endpoint without token returns helpful error
if [ "$TOKEN_SET" != "true" ]; then
    RESPONSE=$(api "facebook_test")
    HAS_ERROR=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if d.get('error') and 'token' in d['error'].lower() else 'no')" 2>/dev/null)
    if [ "$HAS_ERROR" = "yes" ]; then
        pass "T4.4 Test endpoint returns helpful error without token"
    else
        fail "T4.4 Test endpoint error message" "Response: $RESPONSE"
    fi
else
    skip "T4.4 Unconfigured error check" "Token is set"
fi

# ============================================================
section "5. Sanitization & Validation"
# ============================================================

# T5.1: Unicode normalization (zero-width stripping)
RESULT=$(container_python "
from usr.plugins.facebook.helpers.sanitize import sanitize_text
test = 'Hello\u200b \u200dWorld\ufeff!'
result = sanitize_text(test)
print('clean' if result == 'Hello World!' else f'modified: {repr(result)}')
")
if [ "$RESULT" = "clean" ]; then
    pass "T5.1 Zero-width character stripping"
else
    fail "T5.1 Zero-width stripping" "Got: $RESULT"
fi

# T5.2: NFKC normalization
RESULT=$(container_python "
from usr.plugins.facebook.helpers.sanitize import sanitize_text
test = '\uff28\uff45\uff4c\uff4c\uff4f'  # Fullwidth 'Hello'
result = sanitize_text(test)
print('normalized' if result == 'Hello' else f'raw: {repr(result)}')
")
if [ "$RESULT" = "normalized" ]; then
    pass "T5.2 NFKC normalization (fullwidth characters)"
else
    fail "T5.2 NFKC normalization" "Got: $RESULT"
fi

# T5.3: Whitespace collapsing
RESULT=$(container_python "
from usr.plugins.facebook.helpers.sanitize import sanitize_text
test = 'Hello\n\n\n\n\nWorld'
result = sanitize_text(test)
print('collapsed' if result == 'Hello\n\nWorld' else f'raw: {repr(result)}')
")
if [ "$RESULT" = "collapsed" ]; then
    pass "T5.3 Whitespace collapsing (>2 newlines)"
else
    fail "T5.3 Whitespace collapsing" "Got: $RESULT"
fi

# T5.4: Clean messages pass through
RESULT=$(container_python "
from usr.plugins.facebook.helpers.sanitize import sanitize_text
test = 'Hello! Check out our new product launch today.'
result = sanitize_text(test)
print('clean' if result == test else 'modified')
")
if [ "$RESULT" = "clean" ]; then
    pass "T5.4 Clean messages pass through unmodified"
else
    fail "T5.4 Clean passthrough" "Got: $RESULT"
fi

# T5.5: Post length validation (valid)
RESULT=$(container_python "
from usr.plugins.facebook.helpers.sanitize import validate_post_length
ok, count = validate_post_length('Hello World')
print('ok' if ok and count == 11 else f'fail: ok={ok}, count={count}')
")
if [ "$RESULT" = "ok" ]; then
    pass "T5.5 Post length validation (short text passes)"
else
    fail "T5.5 Post length validation" "Got: $RESULT"
fi

# T5.6: Post length validation (too long)
RESULT=$(container_python "
from usr.plugins.facebook.helpers.sanitize import validate_post_length
text = 'A' * 70000
ok, count = validate_post_length(text)
print('rejected' if not ok and count == 70000 else f'fail: ok={ok}, count={count}')
")
if [ "$RESULT" = "rejected" ]; then
    pass "T5.6 Post length validation (>63206 chars rejected)"
else
    fail "T5.6 Post length rejection" "Got: $RESULT"
fi

# T5.7: Page ID validation (valid numeric)
RESULT=$(container_python "
from usr.plugins.facebook.helpers.sanitize import validate_page_id
try:
    result = validate_page_id('123456789012345')
    print('ok' if result == '123456789012345' else 'wrong')
except:
    print('error')
")
if [ "$RESULT" = "ok" ]; then
    pass "T5.7 Page ID validation (numeric)"
else
    fail "T5.7 Numeric page ID" "Got: $RESULT"
fi

# T5.8: Page ID validation (valid slug)
RESULT=$(container_python "
from usr.plugins.facebook.helpers.sanitize import validate_page_id
try:
    result = validate_page_id('my.page.name')
    print('ok' if result == 'my.page.name' else 'wrong')
except:
    print('error')
")
if [ "$RESULT" = "ok" ]; then
    pass "T5.8 Page ID validation (slug format)"
else
    fail "T5.8 Slug page ID" "Got: $RESULT"
fi

# T5.9: Page ID validation (injection attempt)
RESULT=$(container_python "
from usr.plugins.facebook.helpers.sanitize import validate_page_id
try:
    validate_page_id('123; DROP TABLE pages')
    print('passed')
except ValueError:
    print('rejected')
")
if [ "$RESULT" = "rejected" ]; then
    pass "T5.9 Page ID validation rejects injection"
else
    fail "T5.9 Page ID injection" "Got: $RESULT"
fi

# T5.10: Post ID validation
RESULT=$(container_python "
from usr.plugins.facebook.helpers.sanitize import validate_post_id
try:
    r1 = validate_post_id('123456789_987654321')
    valid_compound = r1 == '123456789_987654321'
except:
    valid_compound = False
try:
    r2 = validate_post_id('12345')
    valid_numeric = r2 == '12345'
except:
    valid_numeric = False
try:
    validate_post_id('not_a_valid_id!@#')
    invalid_passed = True
except:
    invalid_passed = False
print('ok' if valid_compound and valid_numeric and not invalid_passed else 'fail')
")
if [ "$RESULT" = "ok" ]; then
    pass "T5.10 Post ID validation (compound, numeric, rejects invalid)"
else
    fail "T5.10 Post ID validation" "Got: $RESULT"
fi

# T5.11: Comment ID validation
RESULT=$(container_python "
from usr.plugins.facebook.helpers.sanitize import validate_comment_id
try:
    r = validate_comment_id('123456789_987654321')
    print('ok' if r == '123456789_987654321' else 'wrong')
except:
    print('error')
")
if [ "$RESULT" = "ok" ]; then
    pass "T5.11 Comment ID validation"
else
    fail "T5.11 Comment ID validation" "Got: $RESULT"
fi

# T5.12: Comment length validation
RESULT=$(container_python "
from usr.plugins.facebook.helpers.sanitize import validate_comment_length
ok, count = validate_comment_length('A' * 9000)
print('rejected' if not ok and count == 9000 else 'fail')
")
if [ "$RESULT" = "rejected" ]; then
    pass "T5.12 Comment length validation (>8000 chars rejected)"
else
    fail "T5.12 Comment length" "Got: $RESULT"
fi

# ============================================================
section "6. Formatting Functions"
# ============================================================

# T6.1: format_post
RESULT=$(container_python "
from usr.plugins.facebook.helpers.sanitize import format_post
post = {'message': 'Hello World', 'created_time': '2026-03-15T10:00:00', 'id': '123_456', 'type': 'status',
        'likes': {'summary': {'total_count': 10}}, 'comments': {'summary': {'total_count': 5}}, 'shares': {'count': 2}}
result = format_post(post)
print('ok' if 'Hello World' in result and 'Likes: 10' in result and '123_456' in result else 'fail')
")
if [ "$RESULT" = "ok" ]; then
    pass "T6.1 format_post outputs message, metrics, and ID"
else
    fail "T6.1 format_post" "Got: $RESULT"
fi

# T6.2: format_posts
RESULT=$(container_python "
from usr.plugins.facebook.helpers.sanitize import format_posts
posts = [{'message': 'Post 1', 'created_time': '', 'id': '1', 'likes': {}, 'comments': {}, 'shares': {}},
         {'message': 'Post 2', 'created_time': '', 'id': '2', 'likes': {}, 'comments': {}, 'shares': {}}]
result = format_posts(posts)
print('ok' if 'Post 1' in result and 'Post 2' in result else 'fail')
")
if [ "$RESULT" = "ok" ]; then
    pass "T6.2 format_posts joins multiple posts"
else
    fail "T6.2 format_posts" "Got: $RESULT"
fi

# T6.3: format_comment
RESULT=$(container_python "
from usr.plugins.facebook.helpers.sanitize import format_comment
comment = {'message': 'Great post!', 'from': {'name': 'John'}, 'created_time': '2026-03-15T10:00:00',
           'id': '789', 'like_count': 3, 'comment_count': 1}
result = format_comment(comment)
print('ok' if 'John' in result and 'Great post!' in result and '789' in result else 'fail')
")
if [ "$RESULT" = "ok" ]; then
    pass "T6.3 format_comment outputs author, message, and ID"
else
    fail "T6.3 format_comment" "Got: $RESULT"
fi

# T6.4: format_insights
RESULT=$(container_python "
from usr.plugins.facebook.helpers.sanitize import format_insights
data = [{'name': 'page_impressions', 'title': 'Page Impressions', 'period': 'day', 'description': 'Total impressions',
         'values': [{'end_time': '2026-03-15', 'value': 1234}]}]
result = format_insights(data)
print('ok' if 'Page Impressions' in result and '1234' in result else 'fail')
")
if [ "$RESULT" = "ok" ]; then
    pass "T6.4 format_insights outputs metrics and values"
else
    fail "T6.4 format_insights" "Got: $RESULT"
fi

# T6.5: format_page_info
RESULT=$(container_python "
from usr.plugins.facebook.helpers.sanitize import format_page_info
page = {'name': 'My Page', 'id': '123', 'category': 'Business', 'fan_count': 5000, 'about': 'Test page'}
result = format_page_info(page)
print('ok' if 'My Page' in result and 'Business' in result and '5000' in result else 'fail')
")
if [ "$RESULT" = "ok" ]; then
    pass "T6.5 format_page_info outputs name, category, fans"
else
    fail "T6.5 format_page_info" "Got: $RESULT"
fi

# T6.6: format_posts handles empty list
RESULT=$(container_python "
from usr.plugins.facebook.helpers.sanitize import format_posts
result = format_posts([])
print('ok' if 'No posts' in result else 'fail')
")
if [ "$RESULT" = "ok" ]; then
    pass "T6.6 format_posts handles empty list gracefully"
else
    fail "T6.6 format_posts empty" "Got: $RESULT"
fi

# ============================================================
section "7. Tool Classes"
# ============================================================

TOOLS=(facebook_post facebook_read facebook_comment facebook_manage facebook_media facebook_insights facebook_page)
for i in "${!TOOLS[@]}"; do
    TOOL="${TOOLS[$i]}"
    NUM=$((i + 1))
    RESULT=$(container_python "
import warnings; warnings.filterwarnings('ignore')
import importlib
mod = importlib.import_module('plugins.facebook.tools.${TOOL}')
print('ok')
")
    LAST_LINE=$(echo "$RESULT" | tail -1)
    if [ "$LAST_LINE" = "ok" ]; then
        pass "T7.${NUM} Tool import: ${TOOL}"
    else
        fail "T7.${NUM} Tool import: ${TOOL}" "$RESULT"
    fi
done

# ============================================================
section "8. Prompt Files"
# ============================================================

# T8.1: Tool group prompt
if docker exec "$CONTAINER" test -f /a0/usr/plugins/facebook/prompts/agent.system.tool_group.md; then
    SIZE=$(docker exec "$CONTAINER" stat -c%s /a0/usr/plugins/facebook/prompts/agent.system.tool_group.md 2>/dev/null)
    if [ -n "$SIZE" ] && [ "$SIZE" -gt 50 ]; then
        pass "T8.1 Tool group prompt exists (${SIZE} bytes)"
    else
        fail "T8.1 Tool group prompt" "File too small (${SIZE} bytes)"
    fi
else
    fail "T8.1 Tool group prompt" "File not found"
fi

# T8.2-8.8: Individual tool prompts
for TOOL in "${TOOLS[@]}"; do
    PROMPT_FILE="/a0/usr/plugins/facebook/prompts/agent.system.tool.${TOOL}.md"
    if docker exec "$CONTAINER" test -f "$PROMPT_FILE"; then
        SIZE=$(docker exec "$CONTAINER" stat -c%s "$PROMPT_FILE" 2>/dev/null)
        if [ -n "$SIZE" ] && [ "$SIZE" -gt 50 ]; then
            pass "T8.x Prompt file exists: ${TOOL} (${SIZE} bytes)"
        else
            fail "T8.x Prompt file: ${TOOL}" "File too small (${SIZE} bytes)"
        fi
    else
        fail "T8.x Prompt file: ${TOOL}" "File not found"
    fi
done

# ============================================================
section "9. Skills"
# ============================================================

SKILL_COUNT=$(docker exec "$CONTAINER" bash -c 'ls -d /a0/usr/plugins/facebook/skills/*/SKILL.md 2>/dev/null | wc -l')
if [ "$SKILL_COUNT" -gt 0 ]; then
    pass "T9.1 Skills directory has $SKILL_COUNT skill(s)"
    docker exec "$CONTAINER" bash -c 'for s in /a0/usr/plugins/facebook/skills/*/SKILL.md; do d=$(dirname "$s"); echo "        $(basename $d)"; done' 2>/dev/null
else
    skip "T9.1 Skills" "No skills found"
fi

# T9.2: Check specific expected skills
for SKILL in facebook-post facebook-research facebook-engage; do
    if docker exec "$CONTAINER" test -f "/a0/usr/plugins/facebook/skills/${SKILL}/SKILL.md"; then
        pass "T9.2 Skill exists: ${SKILL}"
    else
        fail "T9.2 Skill: ${SKILL}" "SKILL.md not found"
    fi
done

# ============================================================
section "10. WebUI Files"
# ============================================================

# T10.1: Dashboard
if docker exec "$CONTAINER" test -f /a0/usr/plugins/facebook/webui/main.html; then
    pass "T10.1 WebUI dashboard (main.html) exists"
else
    fail "T10.1 WebUI dashboard" "main.html not found"
fi

# T10.2: Config page
if docker exec "$CONTAINER" test -f /a0/usr/plugins/facebook/webui/config.html; then
    pass "T10.2 WebUI config page (config.html) exists"
else
    fail "T10.2 WebUI config page" "config.html not found"
fi

# T10.3: WebUI uses data-fb attributes (not bare IDs)
HAS_DATA_FB=$(docker exec "$CONTAINER" grep -c 'data-fb=' /a0/usr/plugins/facebook/webui/config.html 2>/dev/null)
if [ "$HAS_DATA_FB" -gt 3 ]; then
    pass "T10.3 WebUI uses data-fb= attributes ($HAS_DATA_FB found)"
else
    fail "T10.3 data-fb attributes" "Only $HAS_DATA_FB found"
fi

# T10.4: WebUI uses fetchApi pattern
HAS_FETCH=$(docker exec "$CONTAINER" grep -c 'globalThis.fetchApi' /a0/usr/plugins/facebook/webui/main.html 2>/dev/null)
if [ "$HAS_FETCH" -gt 0 ]; then
    pass "T10.4 WebUI uses globalThis.fetchApi pattern"
else
    fail "T10.4 fetchApi pattern" "Not found in main.html"
fi

# T10.5: Config page uses Facebook brand color
HAS_COLOR=$(docker exec "$CONTAINER" grep -c '#1877F2' /a0/usr/plugins/facebook/webui/config.html 2>/dev/null)
if [ "$HAS_COLOR" -gt 0 ]; then
    pass "T10.5 Config page uses Facebook brand color (#1877F2)"
else
    fail "T10.5 Brand color" "#1877F2 not found in config.html"
fi

# ============================================================
section "11. Framework Compatibility"
# ============================================================

# T11.1: Plugin is recognized by A0 framework
RESULT=$(container_python "
from helpers import plugins
config = plugins.get_plugin_config('facebook')
print('ok' if config is not None else 'none')
" 2>&1)
if echo "$RESULT" | grep -q "ok"; then
    pass "T11.1 Framework recognizes plugin (get_plugin_config works)"
else
    fail "T11.1 Framework recognition" "$RESULT"
fi

# T11.2: infection_check plugin coexists
if docker exec "$CONTAINER" test -d /a0/plugins/infection_check; then
    pass "T11.2 infection_check plugin is present alongside Facebook plugin"
else
    skip "T11.2 infection_check coexistence" "infection_check not installed"
fi

# ============================================================
section "12. Security Hardening Checks"
# ============================================================

# T12.1: Secure file write function exists and uses atomic writes
RESULT=$(container_python "
from usr.plugins.facebook.helpers.facebook_auth import secure_write_json
import inspect
src = inspect.getsource(secure_write_json)
has_atomic = 'tmp' in src and ('replace' in src or 'rename' in src)
print('ok' if has_atomic else 'no_atomic')
")
if [ "$RESULT" = "ok" ]; then
    pass "T12.1 secure_write_json uses atomic writes"
else
    fail "T12.1 Atomic writes" "$RESULT"
fi

# T12.2: All API handlers require CSRF
RESULT=$(container_python "
import warnings; warnings.filterwarnings('ignore')
import importlib
apis = [
    'plugins.facebook.api.facebook_test',
    'plugins.facebook.api.facebook_config_api',
]
all_csrf = True
for api in apis:
    mod = importlib.import_module(api)
    for name in dir(mod):
        cls = getattr(mod, name)
        if isinstance(cls, type) and hasattr(cls, 'requires_csrf'):
            if not cls.requires_csrf():
                all_csrf = False
print('ok' if all_csrf else 'fail')
")
LAST_LINE=$(echo "$RESULT" | tail -1)
if [ "$LAST_LINE" = "ok" ]; then
    pass "T12.2 All API handlers require CSRF"
else
    fail "T12.2 CSRF requirement" "$RESULT"
fi

# T12.3: Config API masks sensitive fields
RESULT=$(container_python "
from usr.plugins.facebook.api.facebook_config_api import SENSITIVE_FIELDS
print('ok' if 'page_access_token' in SENSITIVE_FIELDS else 'missing')
")
if [ "$RESULT" = "ok" ]; then
    pass "T12.3 Config API has page_access_token in SENSITIVE_FIELDS"
else
    fail "T12.3 Sensitive fields" "$RESULT"
fi

# T12.4: Rate limiter exists
RESULT=$(container_python "
from usr.plugins.facebook.helpers.facebook_client import FacebookRateLimiter
rl = FacebookRateLimiter()
print('ok' if hasattr(rl, '_max_calls_per_hour') else 'missing')
")
if [ "$RESULT" = "ok" ]; then
    pass "T12.4 Rate limiter exists with call limit"
else
    fail "T12.4 Rate limiter" "$RESULT"
fi

# T12.5: Client from_config factory method
RESULT=$(container_python "
from usr.plugins.facebook.helpers.facebook_client import FacebookClient
print('ok' if hasattr(FacebookClient, 'from_config') else 'missing')
")
if [ "$RESULT" = "ok" ]; then
    pass "T12.5 FacebookClient has from_config factory"
else
    fail "T12.5 from_config" "$RESULT"
fi

# T12.6: Usage tracking
RESULT=$(container_python "
from usr.plugins.facebook.helpers.facebook_auth import get_usage, increment_usage, get_facebook_config
config = get_facebook_config()
usage = get_usage(config)
has_fields = all(k in usage for k in ('month', 'posts_created', 'posts_deleted', 'comments', 'photos_uploaded'))
print('ok' if has_fields else f'missing: {usage.keys()}')
")
LAST_LINE=$(echo "$RESULT" | tail -1)
if [ "$LAST_LINE" = "ok" ]; then
    pass "T12.6 Usage tracking has all required fields"
else
    fail "T12.6 Usage tracking" "$RESULT"
fi

# ============================================================
section "13. Documentation"
# ============================================================

for DOC in README.md docs/README.md docs/QUICKSTART.md docs/SETUP.md docs/DEVELOPMENT.md; do
    if docker exec "$CONTAINER" test -f "/a0/usr/plugins/facebook/${DOC}"; then
        SIZE=$(docker exec "$CONTAINER" stat -c%s "/a0/usr/plugins/facebook/${DOC}" 2>/dev/null)
        if [ -n "$SIZE" ] && [ "$SIZE" -gt 100 ]; then
            pass "T13.x Doc exists: ${DOC} (${SIZE} bytes)"
        else
            fail "T13.x Doc: ${DOC}" "File too small (${SIZE} bytes)"
        fi
    else
        fail "T13.x Doc: ${DOC}" "Not found"
    fi
done

# ============================================================
# Summary
# ============================================================

TOTAL=$((PASSED + FAILED + SKIPPED))
echo ""
echo -e "${CYAN}━━━ Results ━━━${NC}"
echo ""
echo -e "  Total:   ${TOTAL}"
echo -e "  ${GREEN}Passed:  ${PASSED}${NC}"
echo -e "  ${RED}Failed:  ${FAILED}${NC}"
echo -e "  ${YELLOW}Skipped: ${SKIPPED}${NC}"

if [ "$FAILED" -gt 0 ]; then
    echo ""
    echo -e "${RED}Failures:${NC}"
    echo -e "$ERRORS"
    echo ""
    exit 1
else
    echo ""
    echo -e "${GREEN}All tests passed!${NC}"
    echo ""
    exit 0
fi
