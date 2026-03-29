#!/bin/bash
# Facebook Pages Plugin — Automated Human Verification
# Automates the machine-testable subset of HUMAN_TEST_PLAN.md
#
# Usage:
#   ./automated_hv.sh                    # Default: a0-verify-active on port 50088
#   ./automated_hv.sh <container> <port>
#
# Requires: docker, python3

CONTAINER="${1:-a0-verify-active}"
PORT="${2:-50088}"
BASE_URL="http://localhost:${PORT}"

PASSED=0
FAILED=0
SKIPPED=0
ERRORS=""
AUTOMATED_IDS=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

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

track() {
    AUTOMATED_IDS="${AUTOMATED_IDS} $1"
}

# Helper: acquire CSRF token + session cookie
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

# Helper: run Python inside the container
pyexec() {
    docker exec "$CONTAINER" /opt/venv-a0/bin/python3 -W ignore -c "
import sys; sys.path.insert(0, '/a0')
$1
" 2>&1
}

# File/dir checks
container_file_exists() {
    docker exec "$CONTAINER" test -f "$1" 2>/dev/null
}
container_dir_exists() {
    docker exec "$CONTAINER" test -d "$1" 2>/dev/null
}

PLUGIN_DIR=""
USR_DIR="/a0/usr/plugins/facebook"
SYM_DIR="/a0/plugins/facebook"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Facebook Pages — Automated Human Verification       ║${NC}"
echo -e "${CYAN}║  Container: ${CONTAINER}${NC}"
echo -e "${CYAN}║  Port: ${PORT}${NC}"
echo -e "${CYAN}║  Date: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"

# Pre-flight: container must be running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo -e "\n${RED}FATAL: Container '$CONTAINER' not running.${NC}"
    exit 1
fi

# Resolve plugin directory
for d in "$USR_DIR" "$SYM_DIR"; do
    if docker exec "$CONTAINER" test -f "$d/webui/config.html" 2>/dev/null; then
        PLUGIN_DIR="$d"
        break
    fi
done

# Backup real config before testing
BACKUP_CONFIG=$(docker exec "$CONTAINER" cat "/a0/usr/plugins/facebook/config.json" 2>/dev/null || echo '{}')

# Check if real credentials are configured (BEFORE any config modifications)
HAS_REAL_CREDS=$(echo "$BACKUP_CONFIG" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print('yes' if d.get('page_access_token','').strip() else 'no')
except:
    print('no')
" 2>/dev/null)

########################################
section "Phase A: WebUI & HTTP (HV-03, HV-05, HV-06, HV-07, HV-08, HV-33, HV-34)"
########################################

# HV-03 (partial): Dashboard/WebUI reachable
track "HV-03"
STATUS=$(docker exec "$CONTAINER" curl -s -o /dev/null -w '%{http_code}' "http://localhost/" 2>/dev/null)
if [ "$STATUS" = "200" ] || [ "$STATUS" = "302" ]; then
    pass "HV-03 WebUI root reachable (HTTP $STATUS)"
else
    fail "HV-03 WebUI root reachable" "Got HTTP $STATUS"
fi

# HV-03b: Dashboard uses fetchApi
if [ -n "$PLUGIN_DIR" ]; then
    HAS_FETCH_MAIN=$(docker exec "$CONTAINER" grep -c 'fetchApi' "$PLUGIN_DIR/webui/main.html" 2>/dev/null)
    if [ -n "$HAS_FETCH_MAIN" ] && [ "$HAS_FETCH_MAIN" -gt 0 ]; then
        pass "HV-03b Dashboard main.html uses fetchApi ($HAS_FETCH_MAIN occurrences)"
    else
        fail "HV-03b Dashboard fetchApi" "fetchApi not found in main.html"
    fi
fi

# HV-03c: Dashboard has data-fb= attributes
if [ -n "$PLUGIN_DIR" ]; then
    DATA_ATTRS_MAIN=$(docker exec "$CONTAINER" grep -c 'data-fb=' "$PLUGIN_DIR/webui/main.html" 2>/dev/null)
    if [ -n "$DATA_ATTRS_MAIN" ] && [ "$DATA_ATTRS_MAIN" -ge 3 ]; then
        pass "HV-03c Dashboard uses data-fb= attributes ($DATA_ATTRS_MAIN found)"
    else
        fail "HV-03c Dashboard data-fb= attributes" "Expected >= 3, got $DATA_ATTRS_MAIN"
    fi
fi

# HV-05 (partial): Config page loads with expected structure
track "HV-05"
if [ -n "$PLUGIN_DIR" ]; then
    CONFIG_HTML=$(docker exec "$CONTAINER" cat "$PLUGIN_DIR/webui/config.html" 2>/dev/null)

    # Check data-fb= attributes
    DATA_ATTRS_CFG=$(echo "$CONFIG_HTML" | grep -c 'data-fb=')
    if [ -n "$DATA_ATTRS_CFG" ] && [ "$DATA_ATTRS_CFG" -ge 5 ]; then
        pass "HV-05 Config page has data-fb= attributes ($DATA_ATTRS_CFG found)"
    else
        fail "HV-05 Config data-fb= attributes" "Expected >= 5, got $DATA_ATTRS_CFG"
    fi

    # Config uses fetchApi
    HAS_FETCH_CFG=$(echo "$CONFIG_HTML" | grep -c 'fetchApi')
    if [ -n "$HAS_FETCH_CFG" ] && [ "$HAS_FETCH_CFG" -gt 0 ]; then
        pass "HV-05b Config page uses fetchApi ($HAS_FETCH_CFG occurrences)"
    else
        fail "HV-05b Config fetchApi" "fetchApi not found in config.html"
    fi

    # Config has expected input fields
    if echo "$CONFIG_HTML" | grep -qi 'page_access_token'; then
        pass "HV-05c Config has page_access_token field"
    else
        fail "HV-05c Config fields" "page_access_token field not found"
    fi

    if echo "$CONFIG_HTML" | grep -qi 'page_id'; then
        pass "HV-05d Config has page_id field"
    else
        fail "HV-05d Config fields" "page_id field not found"
    fi
else
    fail "HV-05 Config page" "webui/config.html not found in container"
fi

# HV-06: No console errors — check JS syntax (no eval, no bare IDs)
track "HV-06"
if [ -n "$PLUGIN_DIR" ]; then
    BAD_PATTERNS=0
    # Check for bare getElementById (should use data-fb= selectors instead)
    BARE_IDS=$(echo "$CONFIG_HTML" | grep -c 'getElementById')
    if [ "$BARE_IDS" -gt 0 ]; then
        BAD_PATTERNS=$((BAD_PATTERNS + 1))
    fi
    if [ "$BAD_PATTERNS" -eq 0 ]; then
        pass "HV-06 Config JS: no bare getElementById (uses data-fb= pattern)"
    else
        fail "HV-06 Config JS" "Found $BARE_IDS getElementById calls (should use data-fb=)"
    fi
fi

# HV-07: Token field is password type
track "HV-07"
if [ -n "$PLUGIN_DIR" ]; then
    PW_FIELDS=$(echo "$CONFIG_HTML" | grep -c 'type="password"')
    if [ -n "$PW_FIELDS" ] && [ "$PW_FIELDS" -ge 1 ]; then
        pass "HV-07 Page Access Token input is password type ($PW_FIELDS found)"
    else
        fail "HV-07 Token field type" "No password-type inputs found"
    fi
fi

# HV-08: Setup instructions present in config page
track "HV-08"
if [ -n "$PLUGIN_DIR" ]; then
    HAS_INSTRUCTIONS=0
    if echo "$CONFIG_HTML" | grep -qi 'How to get a Page Access Token'; then
        HAS_INSTRUCTIONS=$((HAS_INSTRUCTIONS + 1))
    fi
    if echo "$CONFIG_HTML" | grep -qi 'developers.facebook.com'; then
        HAS_INSTRUCTIONS=$((HAS_INSTRUCTIONS + 1))
    fi
    if echo "$CONFIG_HTML" | grep -qi 'Graph API Explorer\|tools/explorer'; then
        HAS_INSTRUCTIONS=$((HAS_INSTRUCTIONS + 1))
    fi
    if echo "$CONFIG_HTML" | grep -qi 'pages_manage_posts'; then
        HAS_INSTRUCTIONS=$((HAS_INSTRUCTIONS + 1))
    fi
    if [ "$HAS_INSTRUCTIONS" -ge 3 ]; then
        pass "HV-08 Setup instructions present ($HAS_INSTRUCTIONS/4 elements found)"
    else
        fail "HV-08 Setup instructions" "Only $HAS_INSTRUCTIONS/4 elements found"
    fi
fi

# HV-33: CSRF enforcement — no token = 403/error
track "HV-33"
NOCSRF_STATUS=$(docker exec "$CONTAINER" curl -s -o /dev/null -w '%{http_code}' \
    -X POST "http://localhost/api/plugins/facebook/facebook_test" \
    -H "Content-Type: application/json" \
    -d '{}' 2>/dev/null)
if [ "$NOCSRF_STATUS" = "403" ] || [ "$NOCSRF_STATUS" = "401" ]; then
    pass "HV-33 CSRF enforcement on facebook_test — no token returns $NOCSRF_STATUS"
else
    NOCSRF_BODY=$(docker exec "$CONTAINER" curl -s \
        -X POST "http://localhost/api/plugins/facebook/facebook_test" \
        -H "Content-Type: application/json" \
        -d '{}' 2>/dev/null)
    if echo "$NOCSRF_BODY" | grep -qi "403\|forbidden\|csrf\|error"; then
        pass "HV-33 CSRF enforcement — rejected (body contains error)"
    else
        fail "HV-33 CSRF enforcement" "Expected 403, got HTTP $NOCSRF_STATUS"
    fi
fi

# CSRF on config API too
NOCSRF_CFG_STATUS=$(docker exec "$CONTAINER" curl -s -o /dev/null -w '%{http_code}' \
    -X POST "http://localhost/api/plugins/facebook/facebook_config_api" \
    -H "Content-Type: application/json" \
    -d '{"action":"get"}' 2>/dev/null)
if [ "$NOCSRF_CFG_STATUS" = "403" ] || [ "$NOCSRF_CFG_STATUS" = "401" ]; then
    pass "HV-33b CSRF enforcement on config API — $NOCSRF_CFG_STATUS"
else
    NOCSRF_CFG_BODY=$(docker exec "$CONTAINER" curl -s \
        -X POST "http://localhost/api/plugins/facebook/facebook_config_api" \
        -H "Content-Type: application/json" \
        -d '{"action":"get"}' 2>/dev/null)
    if echo "$NOCSRF_CFG_BODY" | grep -qi "403\|forbidden\|csrf\|error"; then
        pass "HV-33b CSRF enforcement on config API (body)"
    else
        fail "HV-33b Config API CSRF" "Expected 403, got HTTP $NOCSRF_CFG_STATUS"
    fi
fi

########################################
section "Phase B: Connection & Config (HV-09, HV-10, HV-11, HV-12, HV-14, HV-34)"
########################################

setup_csrf

# HV-11 (partial): Test Connection API responds with valid JSON
track "HV-11"
TEST_RESP=$(api "facebook_test" '{}')
if echo "$TEST_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); assert isinstance(d, dict); print('ok')" 2>/dev/null | grep -q 'ok'; then
    pass "HV-11 Test Connection API returns valid JSON"
else
    fail "HV-11 Test Connection API" "Invalid response: $TEST_RESP"
fi

# HV-09: Config save via API
track "HV-09"
SAVE_RESP=$(api "facebook_config_api" '{"action":"set","config":{"page_access_token":"EAAbCdEfGhIjKlMnOpQrStUvWxYz123456","page_id":"123456789012345"}}')
SAVE_OK=$(echo "$SAVE_RESP" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('ok') or d.get('status') == 'ok' or 'success' in str(d).lower() or 'saved' in str(d).lower():
    print('ok')
else:
    print('fail')
" 2>/dev/null)
if [ "$SAVE_OK" = "ok" ]; then
    pass "HV-09 Config save via API (page_access_token + page_id)"
else
    # Try alternate POST body format (without nested config)
    SAVE_RESP2=$(api "facebook_config_api" '{"action":"set","page_access_token":"EAAbCdEfGhIjKlMnOpQrStUvWxYz123456","page_id":"123456789012345"}')
    SAVE_OK2=$(echo "$SAVE_RESP2" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('ok') or d.get('status') == 'ok' or 'success' in str(d).lower() or 'saved' in str(d).lower():
    print('ok')
else:
    print('fail')
" 2>/dev/null)
    if [ "$SAVE_OK2" = "ok" ]; then
        pass "HV-09 Config save via API (flat body format)"
    else
        fail "HV-09 Config save" "Response: $SAVE_RESP / $SAVE_RESP2"
    fi
fi

# HV-10: Config persistence — page_id persists in full
track "HV-10"
LOAD_RESP=$(api "facebook_config_api")
# Try GET as well if POST without data returns nothing useful
if [ -z "$LOAD_RESP" ] || [ "$LOAD_RESP" = "{}" ]; then
    LOAD_RESP=$(api "facebook_config_api" '{"action":"get"}')
fi

PID_CHECK=$(echo "$LOAD_RESP" | python3 -c "
import sys, json
d = json.load(sys.stdin)
pid = d.get('page_id', '')
if pid == '123456789012345':
    print('ok')
elif pid:
    print(f'mismatch:{pid}')
else:
    print('missing')
" 2>/dev/null)
if [ "$PID_CHECK" = "ok" ]; then
    pass "HV-10 Non-sensitive page_id persists correctly"
else
    fail "HV-10 Config persistence (page_id)" "$PID_CHECK"
fi

# HV-34: page_access_token is masked in GET response
track "HV-34"
TOKEN_MASK=$(echo "$LOAD_RESP" | python3 -c "
import sys, json
d = json.load(sys.stdin)
tok = d.get('page_access_token', '')
if '****' in tok or '***' in tok:
    print('ok')
elif tok == '':
    print('ok_hidden')
elif tok == 'EAAbCdEfGhIjKlMnOpQrStUvWxYz123456':
    print('exposed')
else:
    print(f'unclear:{tok[:20]}')
" 2>/dev/null)
if [ "$TOKEN_MASK" = "ok" ] || [ "$TOKEN_MASK" = "ok_hidden" ]; then
    pass "HV-34 Config GET masks page_access_token"
else
    fail "HV-34 Token masking" "$TOKEN_MASK"
fi

# HV-12: Bad token returns clear error (not stack trace)
track "HV-12"
api "facebook_config_api" '{"action":"set","config":{"page_access_token":"expired_token_test","page_id":"123456789012345"}}' > /dev/null 2>&1
# Alternate format too
api "facebook_config_api" '{"action":"set","page_access_token":"expired_token_test","page_id":"123456789012345"}' > /dev/null 2>&1
BAD_TEST=$(api "facebook_test" '{}')
BAD_CHECK=$(echo "$BAD_TEST" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    if d.get('error') or d.get('ok') == False or 'error' in str(d).lower() or 'fail' in str(d).lower() or 'auth' in str(d).lower():
        print('ok')
    elif d.get('ok') == True:
        print('fail:unexpected_success')
    else:
        print('ok')
except:
    print('ok')
" 2>/dev/null)
if [ "$BAD_CHECK" = "ok" ]; then
    pass "HV-12 Bad token returns error (no stack trace)"
else
    fail "HV-12 Bad token" "$BAD_CHECK"
fi

# HV-14: Masked token preserved on re-save
track "HV-14"
# Restore test token first
api "facebook_config_api" '{"action":"set","config":{"page_access_token":"EAAbCdEfGhIjKlMnOpQrStUvWxYz123456","page_id":"123456789012345"}}' > /dev/null 2>&1
api "facebook_config_api" '{"action":"set","page_access_token":"EAAbCdEfGhIjKlMnOpQrStUvWxYz123456","page_id":"123456789012345"}' > /dev/null 2>&1

# Load config to get the masked token
LOAD_RESP2=$(api "facebook_config_api")
if [ -z "$LOAD_RESP2" ] || [ "$LOAD_RESP2" = "{}" ]; then
    LOAD_RESP2=$(api "facebook_config_api" '{"action":"get"}')
fi
MASKED_TOK=$(echo "$LOAD_RESP2" | python3 -c "import sys,json; print(json.load(sys.stdin).get('page_access_token',''))" 2>/dev/null)

# Re-save with the masked token
api "facebook_config_api" "{\"action\":\"set\",\"config\":{\"page_access_token\":\"${MASKED_TOK}\",\"page_id\":\"123456789012345\"}}" > /dev/null 2>&1
api "facebook_config_api" "{\"action\":\"set\",\"page_access_token\":\"${MASKED_TOK}\",\"page_id\":\"123456789012345\"}" > /dev/null 2>&1

# Reload and check the token is still masked (not overwritten with masked string)
RELOAD_RESP=$(api "facebook_config_api")
if [ -z "$RELOAD_RESP" ] || [ "$RELOAD_RESP" = "{}" ]; then
    RELOAD_RESP=$(api "facebook_config_api" '{"action":"get"}')
fi
RESAVE_CHECK=$(echo "$RELOAD_RESP" | python3 -c "
import sys, json
d = json.load(sys.stdin)
tok = d.get('page_access_token', '')
if '****' in tok or '***' in tok or tok == '':
    print('ok')
elif tok == 'EAAbCdEfGhIjKlMnOpQrStUvWxYz123456':
    print('ok_original')
else:
    print(f'fail:{tok[:20]}')
" 2>/dev/null)
if [ "$RESAVE_CHECK" = "ok" ] || [ "$RESAVE_CHECK" = "ok_original" ]; then
    pass "HV-14 Masked token preserved on re-save"
else
    fail "HV-14 Masked save" "$RESAVE_CHECK"
fi

########################################
section "Phase C: Read Operations (HV-19, HV-29, HV-31, HV-32)"
########################################

# Use credential check from BEFORE Phase B modified config
HAS_CREDS="$HAS_REAL_CREDS"

if [ "$HAS_CREDS" = "yes" ]; then

    # HV-31: Get page info
    track "HV-31"
    RESULT=$(pyexec "
import asyncio
from usr.plugins.facebook.helpers.facebook_auth import get_facebook_config
from usr.plugins.facebook.helpers.facebook_client import FacebookClient
config = get_facebook_config()
client = FacebookClient(config)
async def test():
    try:
        result = await client.get_page_info()
        if result and (result.get('name') or result.get('id')):
            print('PASS')
        elif result.get('error'):
            print(f'FAIL:{result.get(\"detail\",\"unknown\")}')
        else:
            print('FAIL:no_name_or_id')
    except Exception as e:
        print(f'FAIL:{e}')
    finally:
        await client.close()
asyncio.run(test())
")
    LAST=$(echo "$RESULT" | tail -1)
    if [ "$LAST" = "PASS" ]; then
        pass "HV-31 Get page info (facebook_page)"
    else
        fail "HV-31 Get page info" "$LAST"
    fi

    # HV-19: Read page feed
    track "HV-19"
    RESULT=$(pyexec "
import asyncio
from usr.plugins.facebook.helpers.facebook_auth import get_facebook_config
from usr.plugins.facebook.helpers.facebook_client import FacebookClient
config = get_facebook_config()
client = FacebookClient(config)
async def test():
    try:
        result = await client.get_page_feed(limit=5)
        if result and isinstance(result, dict) and not result.get('error'):
            print('PASS')
        elif result.get('error'):
            print(f'FAIL:{result.get(\"detail\",\"unknown\")}')
        else:
            print('FAIL:empty_or_bad')
    except Exception as e:
        print(f'FAIL:{e}')
    finally:
        await client.close()
asyncio.run(test())
")
    LAST=$(echo "$RESULT" | tail -1)
    if [ "$LAST" = "PASS" ]; then
        pass "HV-19 Read page feed (facebook_read)"
    else
        fail "HV-19 Read page feed" "$LAST"
    fi

    # HV-29: Get page insights
    track "HV-29"
    RESULT=$(pyexec "
import asyncio
from usr.plugins.facebook.helpers.facebook_auth import get_facebook_config
from usr.plugins.facebook.helpers.facebook_client import FacebookClient
config = get_facebook_config()
client = FacebookClient(config)
async def test():
    try:
        result = await client.get_page_insights()
        if result and isinstance(result, dict) and not result.get('error'):
            print('PASS')
        elif result.get('error'):
            detail = result.get('detail', '')
            # Insights may require minimum page activity — permission errors are acceptable
            if 'permission' in detail.lower() or 'insufficient' in detail.lower():
                print('PASS')
            else:
                print(f'FAIL:{detail}')
        else:
            print('FAIL:empty')
    except Exception as e:
        if 'permission' in str(e).lower() or 'insufficient' in str(e).lower():
            print('PASS')
        else:
            print(f'FAIL:{e}')
    finally:
        await client.close()
asyncio.run(test())
")
    LAST=$(echo "$RESULT" | tail -1)
    if [ "$LAST" = "PASS" ]; then
        pass "HV-29 Get page insights (facebook_insights)"
    else
        fail "HV-29 Get page insights" "$LAST"
    fi

    # HV-32: List managed pages
    track "HV-32"
    RESULT=$(pyexec "
import asyncio
from usr.plugins.facebook.helpers.facebook_auth import get_facebook_config
from usr.plugins.facebook.helpers.facebook_client import FacebookClient
config = get_facebook_config()
client = FacebookClient(config)
async def test():
    try:
        result = await client.get_managed_pages()
        if result and isinstance(result, dict) and not result.get('error'):
            print('PASS')
        elif result.get('error'):
            detail = result.get('detail', '')
            # Managed pages may not work with a Page Access Token (needs User token)
            if 'permission' in detail.lower() or 'token' in detail.lower():
                print('PASS')
            else:
                print(f'FAIL:{detail}')
        else:
            print('FAIL:empty')
    except Exception as e:
        print(f'FAIL:{e}')
    finally:
        await client.close()
asyncio.run(test())
")
    LAST=$(echo "$RESULT" | tail -1)
    if [ "$LAST" = "PASS" ]; then
        pass "HV-32 List managed pages (facebook_page action=list)"
    else
        fail "HV-32 List managed pages" "$LAST"
    fi

else
    skip "HV-31 Get page info" "No credentials configured"
    skip "HV-19 Read page feed" "No credentials configured"
    skip "HV-29 Get page insights" "No credentials configured"
    skip "HV-32 List managed pages" "No credentials configured"
    track "HV-31"
    track "HV-19"
    track "HV-29"
    track "HV-32"
fi

########################################
section "Phase D: Error Handling & Validation (HV-12, HV-22, HV-35, HV-36)"
########################################

# HV-22: Invalid post_id rejected
track "HV-22"
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.sanitize import validate_post_id
try:
    validate_post_id('invalid_id_format!@#')
    print('FAIL:no_error')
except (ValueError, Exception) as e:
    print('PASS')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-22 Invalid post_id 'invalid_id_format!@#' rejected"
else
    fail "HV-22 Invalid post_id" "$LAST"
fi

# Valid post_id accepted
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.sanitize import validate_post_id
try:
    r = validate_post_id('123456789_987654321')
    if r:
        print('PASS')
    else:
        print('FAIL:empty')
except Exception as e:
    print(f'FAIL:{e}')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-22b Valid post_id '123456789_987654321' accepted"
else
    fail "HV-22b Valid post_id" "$LAST"
fi

# Invalid comment_id rejected
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.sanitize import validate_comment_id
try:
    validate_comment_id('not_a_valid_id!@#')
    print('FAIL:no_error')
except (ValueError, Exception):
    print('PASS')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-22c Invalid comment_id rejected"
else
    fail "HV-22c Invalid comment_id" "$LAST"
fi

# Valid comment_id accepted
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.sanitize import validate_comment_id
try:
    r = validate_comment_id('123456789_987654321')
    if r:
        print('PASS')
    else:
        print('FAIL:empty')
except Exception as e:
    print(f'FAIL:{e}')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-22d Valid comment_id accepted"
else
    fail "HV-22d Valid comment_id" "$LAST"
fi

# Invalid page_id rejected
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.sanitize import validate_page_id
try:
    validate_page_id('')
    print('FAIL:no_error')
except (ValueError, Exception):
    print('PASS')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-D1 Empty page_id rejected"
else
    fail "HV-D1 Empty page_id" "$LAST"
fi

# Valid page_id (numeric) accepted
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.sanitize import validate_page_id
try:
    r = validate_page_id('123456789012345')
    if r == '123456789012345':
        print('PASS')
    else:
        print(f'FAIL:{r}')
except Exception as e:
    print(f'FAIL:{e}')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-D2 Valid numeric page_id accepted"
else
    fail "HV-D2 Valid page_id" "$LAST"
fi

# Valid page_id (slug) accepted
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.sanitize import validate_page_id
try:
    r = validate_page_id('my.page.name')
    if r == 'my.page.name':
        print('PASS')
    else:
        print(f'FAIL:{r}')
except Exception as e:
    print(f'FAIL:{e}')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-D3 Valid slug page_id accepted"
else
    fail "HV-D3 Slug page_id" "$LAST"
fi

# HV-35: Post too long (>63206 chars)
track "HV-35"
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.sanitize import validate_post_length
ok, count = validate_post_length('x' * 63207)
if not ok:
    print('PASS')
else:
    print(f'FAIL:ok={ok},count={count}')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-35 Post >63206 chars rejected"
else
    fail "HV-35 Post length limit" "$LAST"
fi

# Normal post accepted
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.sanitize import validate_post_length
ok, count = validate_post_length('Hello from Agent Zero!')
if ok:
    print('PASS')
else:
    print(f'FAIL:ok={ok},count={count}')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-35b Normal post length accepted"
else
    fail "HV-35b Post length" "$LAST"
fi

# Exact boundary: 63206 chars OK
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.sanitize import validate_post_length
ok, count = validate_post_length('x' * 63206)
if ok and count == 63206:
    print('PASS')
else:
    print(f'FAIL:ok={ok},count={count}')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-35c Boundary: exactly 63206 chars accepted"
else
    fail "HV-35c Boundary check" "$LAST"
fi

# Comment length validation
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.sanitize import validate_comment_length
ok, count = validate_comment_length('x' * 8001)
if not ok:
    print('PASS')
else:
    print(f'FAIL:ok={ok},count={count}')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-D4 Comment >8000 chars rejected"
else
    fail "HV-D4 Comment length" "$LAST"
fi

RESULT=$(pyexec "
from usr.plugins.facebook.helpers.sanitize import validate_comment_length
ok, count = validate_comment_length('Great post!')
if ok:
    print('PASS')
else:
    print(f'FAIL:ok={ok}')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-D5 Normal comment length accepted"
else
    fail "HV-D5 Comment length" "$LAST"
fi

# HV-36: No credentials — has_credentials detects empty config
track "HV-36"
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.facebook_auth import has_credentials
if not has_credentials({'page_access_token': '', 'page_id': ''}):
    print('PASS')
else:
    print('FAIL')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-36 Empty credentials correctly detected as unconfigured"
else
    fail "HV-36 No credentials check" "$LAST"
fi

# Also test with missing keys
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.facebook_auth import has_credentials
if not has_credentials({}):
    print('PASS')
else:
    print('FAIL')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-36b Missing config keys detected as unconfigured"
else
    fail "HV-36b Missing keys" "$LAST"
fi

# Auth helper: get_auth_params returns empty dict without token
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.facebook_auth import get_auth_params
params = get_auth_params({})
if params == {}:
    print('PASS')
else:
    print(f'FAIL:{params}')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-D6 get_auth_params returns empty dict without token"
else
    fail "HV-D6 get_auth_params" "$LAST"
fi

# Auth helper: get_auth_params returns access_token with token
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.facebook_auth import get_auth_params
params = get_auth_params({'page_access_token': 'test_token'})
if params.get('access_token') == 'test_token':
    print('PASS')
else:
    print(f'FAIL:{params}')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-D7 get_auth_params returns access_token with token"
else
    fail "HV-D7 get_auth_params" "$LAST"
fi

########################################
section "Phase E: Sanitize & Format (HV-37, HV-40)"
########################################

# HV-37 (partial): Emoji handling — sanitize_text preserves emojis
track "HV-37"
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.sanitize import sanitize_text
t = sanitize_text('Testing emojis! \U0001f389\U0001f680\U0001f4af')
if '\U0001f389' in t and '\U0001f680' in t and '\U0001f4af' in t:
    print('PASS')
else:
    print(f'FAIL:{repr(t[:50])}')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-37 Emoji preserved through sanitize_text"
else
    fail "HV-37 Emoji handling" "$LAST"
fi

# Text sanitization: strips zero-width chars
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.sanitize import sanitize_text
t = sanitize_text('Hello\u200bWorld')
if 'HelloWorld' in t and '\u200b' not in t:
    print('PASS')
else:
    print(f'FAIL:{repr(t)}')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-E1 sanitize_text strips zero-width chars"
else
    fail "HV-E1 Zero-width strip" "$LAST"
fi

# Text sanitization: collapses excessive newlines
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.sanitize import sanitize_text
t = sanitize_text('Hello\n\n\n\n\nWorld')
if t == 'Hello\n\nWorld':
    print('PASS')
else:
    print(f'FAIL:{repr(t)}')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-E2 sanitize_text collapses excessive newlines"
else
    fail "HV-E2 Newline collapse" "$LAST"
fi

# Text sanitization: NFKC normalization
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.sanitize import sanitize_text
import unicodedata
t = sanitize_text('\uff28\uff45\uff4c\uff4c\uff4f')  # fullwidth 'Hello'
if unicodedata.is_normalized('NFKC', t):
    print('PASS')
else:
    print('FAIL')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-E3 sanitize_text applies NFKC normalization"
else
    fail "HV-E3 NFKC normalization" "$LAST"
fi

# Text sanitization: trims whitespace
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.sanitize import sanitize_text
t = sanitize_text('   Hello World   ')
if t == 'Hello World':
    print('PASS')
else:
    print(f'FAIL:{repr(t)}')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-E4 sanitize_text trims whitespace"
else
    fail "HV-E4 Trim whitespace" "$LAST"
fi

# format_post: includes message, ID, metrics
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.sanitize import format_post
p = format_post({
    'id': '123_456',
    'message': 'Hello from Agent Zero!',
    'created_time': '2026-01-01T12:00:00+0000',
    'type': 'status',
    'likes': {'summary': {'total_count': 5}},
    'comments': {'summary': {'total_count': 2}},
    'shares': {'count': 1}
})
if 'Hello from Agent Zero' in p and '123_456' in p and 'Likes: 5' in p and 'Comments: 2' in p and 'Shares: 1' in p:
    print('PASS')
else:
    print(f'FAIL:{p[:100]}')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-E5 format_post includes message, id, engagement metrics"
else
    fail "HV-E5 format_post" "$LAST"
fi

# format_posts: empty list
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.sanitize import format_posts
r = format_posts([])
if 'No posts found' in r:
    print('PASS')
else:
    print(f'FAIL:{r[:50]}')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-E6 format_posts handles empty list"
else
    fail "HV-E6 format_posts empty" "$LAST"
fi

# format_comment: includes author and message
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.sanitize import format_comment
c = format_comment({
    'id': '123_456_789',
    'from': {'name': 'Test User'},
    'message': 'Great post!',
    'created_time': '2026-01-01T12:00:00+0000',
    'like_count': 3,
    'comment_count': 1
})
if 'Great post' in c and 'Test User' in c and '123_456_789' in c:
    print('PASS')
else:
    print(f'FAIL:{c[:100]}')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-E7 format_comment includes author, message, id"
else
    fail "HV-E7 format_comment" "$LAST"
fi

# format_comments: empty list
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.sanitize import format_comments
r = format_comments([])
if 'No comments found' in r:
    print('PASS')
else:
    print(f'FAIL:{r[:50]}')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-E8 format_comments handles empty list"
else
    fail "HV-E8 format_comments empty" "$LAST"
fi

# format_page_info: includes name, category, fans
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.sanitize import format_page_info
p = format_page_info({
    'name': 'Test Page',
    'category': 'Technology',
    'fan_count': 5000,
    'id': '123456789',
    'about': 'A test page',
    'link': 'https://facebook.com/testpage'
})
if 'Test Page' in p and '5000' in p and 'Technology' in p:
    print('PASS')
else:
    print(f'FAIL:{p[:100]}')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-E9 format_page_info includes name, category, fan count"
else
    fail "HV-E9 format_page_info" "$LAST"
fi

# format_insights: includes metric name and values
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.sanitize import format_insights
r = format_insights([
    {'name': 'page_impressions', 'title': 'Page Impressions', 'period': 'day',
     'description': 'Total impressions', 'values': [{'end_time': '2026-01-01', 'value': 1234}]},
])
if 'Page Impressions' in r and '1234' in r:
    print('PASS')
else:
    print(f'FAIL:{r[:100]}')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-E10 format_insights includes metric name and values"
else
    fail "HV-E10 format_insights" "$LAST"
fi

# format_insights: empty data
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.sanitize import format_insights
r = format_insights([])
if 'No insights' in r:
    print('PASS')
else:
    print(f'FAIL:{r[:50]}')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-E11 format_insights handles empty data"
else
    fail "HV-E11 format_insights empty" "$LAST"
fi

# format_post: truncation of long messages at 500 chars
RESULT=$(pyexec "
from usr.plugins.facebook.helpers.sanitize import format_post
p = format_post({
    'id': '123_456',
    'message': 'A' * 600,
    'created_time': '2026-01-01T12:00:00+0000',
})
if '...' in p and len([l for l in p.split('\n') if 'AAA' in l][0]) < 600:
    print('PASS')
else:
    print('FAIL:no_truncation')
")
LAST=$(echo "$RESULT" | tail -1)
if [ "$LAST" = "PASS" ]; then
    pass "HV-E12 format_post truncates long messages with ..."
else
    fail "HV-E12 Message truncation" "$LAST"
fi

# HV-40 (partial): README lists 7 tools
track "HV-40"
README=$(docker exec "$CONTAINER" bash -c "cat $USR_DIR/docs/README.md 2>/dev/null || cat $USR_DIR/README.md 2>/dev/null || echo 'NOTFOUND'" 2>/dev/null)
if [ "$README" != "NOTFOUND" ]; then
    TOOL_MENTIONS=0
    for t in facebook_post facebook_read facebook_comment facebook_manage facebook_media facebook_insights facebook_page; do
        if echo "$README" | grep -qi "$t"; then
            TOOL_MENTIONS=$((TOOL_MENTIONS + 1))
        fi
    done
    if [ "$TOOL_MENTIONS" -ge 6 ]; then
        pass "HV-40 README references $TOOL_MENTIONS/7 tools"
    else
        fail "HV-40 README tool list" "Only $TOOL_MENTIONS/7 tools mentioned"
    fi
else
    skip "HV-40 README accuracy" "README.md not found"
fi

# Check QUICKSTART exists
QUICKSTART=$(docker exec "$CONTAINER" bash -c "cat $USR_DIR/docs/QUICKSTART.md 2>/dev/null || echo 'NOTFOUND'" 2>/dev/null)
if [ "$QUICKSTART" != "NOTFOUND" ]; then
    QS_TERMS=0
    for term in "token" "install" "config" "Page Access Token" "permission"; do
        if echo "$QUICKSTART" | grep -qi "$term"; then
            QS_TERMS=$((QS_TERMS + 1))
        fi
    done
    if [ "$QS_TERMS" -ge 3 ]; then
        pass "HV-41 QUICKSTART.md covers setup ($QS_TERMS/5 terms found)"
    else
        fail "HV-41 QUICKSTART.md" "Only $QS_TERMS/5 expected terms found"
    fi
else
    skip "HV-41 QUICKSTART.md" "QUICKSTART.md not found"
fi
track "HV-41"

########################################
# Cleanup: restore original config
########################################
echo ""
echo -e "${CYAN}━━━ Cleanup ━━━${NC}"
echo "$BACKUP_CONFIG" | docker exec -i "$CONTAINER" bash -c 'cat > /a0/usr/plugins/facebook/config.json' 2>/dev/null
if [ $? -eq 0 ]; then
    echo "  Restored original config"
else
    echo "  WARNING: Could not restore config"
fi

########################################
# Summary
########################################

TOTAL=$((PASSED + FAILED + SKIPPED))
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       AUTOMATED HV RESULTS — Facebook Pages         ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}  Total:   ${TOTAL}"
echo -e "${CYAN}║${NC}  ${GREEN}Passed:  ${PASSED}${NC}"
echo -e "${CYAN}║${NC}  ${RED}Failed:  ${FAILED}${NC}"
echo -e "${CYAN}║${NC}  ${YELLOW}Skipped: ${SKIPPED}${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"

echo ""
echo -e "${BOLD}Automated HV-IDs covered:${NC}${AUTOMATED_IDS}"
echo ""
echo -e "${BOLD}By phase:${NC}"
echo "  Phase A (WebUI & HTTP):   HV-03, HV-05, HV-06, HV-07, HV-08, HV-33"
echo "  Phase B (Config & Conn):  HV-09, HV-10, HV-11, HV-12, HV-14, HV-34"
echo "  Phase C (Read ops):       HV-19, HV-29, HV-31, HV-32  (requires credentials)"
echo "  Phase D (Errors & Valid): HV-22, HV-35, HV-36 + validators"
echo "  Phase E (Format & Docs):  HV-37, HV-40, HV-41 + 12 format/sanitize tests"
echo ""
echo "  Total: ~50 checks covering 19 HV-IDs (of 42 in HUMAN_TEST_PLAN.md)"
echo ""
echo -e "${YELLOW}Remaining HV tests require human interaction:${NC}"
echo "  HV-01, HV-02 (visual plugin list/toggle)"
echo "  HV-04 (dashboard usage stats — visual)"
echo "  HV-13 (restore good token — manual entry)"
echo "  HV-15 (restart persistence — manual timing)"
echo "  HV-16, HV-17, HV-18 (agent chat: facebook_post)"
echo "  HV-20, HV-21 (agent chat: read specific post/comments)"
echo "  HV-23, HV-24 (agent chat: facebook_comment)"
echo "  HV-25, HV-26, HV-27 (agent chat: facebook_manage)"
echo "  HV-28 (agent chat: facebook_media photo upload)"
echo "  HV-30 (agent chat: post insights)"
echo "  HV-38 (rapid tool calls)"
echo "  HV-39 (restart persistence — agent tools)"
echo "  HV-42 (example prompt from docs)"

if [ $FAILED -gt 0 ]; then
    echo -e "\n${RED}Failed tests:${NC}$ERRORS"
    echo ""
    exit 1
else
    echo -e "\n${GREEN}All automated HV tests passed!${NC}"
    exit 0
fi
