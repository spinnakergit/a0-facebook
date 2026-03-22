# Human Test Plan: Facebook Pages Integration

> **Plugin:** `facebook`
> **Version:** 1.0.0
> **Type:** Social Media (Page management via Graph API v21.0)
> **Prerequisite:** `regression_test.sh` passed 100%
> **Estimated Time:** 45-60 minutes

---

## How to Use This Plan

1. Work through each phase in order — phases are gated (Phase 2 requires Phase 1 pass, etc.)
2. For each test, perform the **Action**, check against **Expected**, tell Claude "Pass" or "Fail"
3. Claude will record results in `HUMAN_TEST_RESULTS.md` as you go
4. If any test fails: stop, troubleshoot with Claude, fix, then continue

**Start by telling Claude:** "Start human verification for facebook"

---

## Phase 0: Prerequisites & Environment

Before starting, confirm each item:

- [ ] **Container running:** `docker ps | grep <container-name>`
- [ ] **WebUI accessible:** Open `http://localhost:<port>` in browser
- [ ] **Plugin deployed:** `docker exec <container> ls /a0/usr/plugins/facebook/plugin.yaml`
- [ ] **Plugin enabled:** `docker exec <container> ls /a0/usr/plugins/facebook/.toggle-1`
- [ ] **Symlink exists:** `docker exec <container> ls -la /a0/plugins/facebook`
- [ ] **Page Access Token obtained:** Token with required permissions from Graph API Explorer
- [ ] **Required permissions granted:** `pages_manage_posts`, `pages_read_engagement`, `pages_read_user_content`, `pages_manage_metadata`, `pages_manage_engagement`
- [ ] **Facebook Page available:** You have admin access to a test Facebook Page
- [ ] **Regression passed:** `bash regression_test.sh <container> <port>` shows 100% pass

**Record your environment:**
```
Container:       _______________
Port:            _______________
Page Access Token: _______________  (first 5 chars)
Page ID:         _______________
Page Name:       _______________
```

---

## Phase 1: WebUI Verification (8 tests)

Open the Agent Zero WebUI in your browser.

| ID | Test | Action | Expected | Result |
|----|------|--------|----------|--------|
| HV-01 | Plugin in list | Navigate to Settings > Plugins | "Facebook Pages" appears in the plugin list | |
| HV-02 | Toggle | Toggle the Facebook plugin off, then back on | Plugin disables/enables without error or page crash | |
| HV-03 | Dashboard loads | Click the Facebook plugin dashboard tab | `main.html` renders with status badge showing "Checking..." then resolving | |
| HV-04 | Dashboard usage stats | After successful connection, check usage section | Shows "This month: X posts, X comments, X photos" (or 0 for fresh install) | |
| HV-05 | Config loads | Click the Facebook plugin settings tab | `config.html` renders with Page Access Token field (password type) and Page ID field (text type) | |
| HV-06 | No console errors | Open browser DevTools (F12) > Console tab, reload the config page | Zero JavaScript errors in console | |
| HV-07 | Token field type | Inspect the Page Access Token input field | Input type is `password` (dots, not plaintext) | |
| HV-08 | Setup instructions | Check config page for setup help | "How to get a Page Access Token" instructions visible, links to developers.facebook.com and Graph API Explorer, lists required permissions | |

---

## Phase 2: Configuration & Connection (7 tests)

| ID | Test | Action | Expected | Result |
|----|------|--------|----------|--------|
| HV-09 | Enter credentials | Paste Page Access Token and Page ID into the config fields, click Save | Status shows "Saved!" in green | |
| HV-10 | Credentials persist | Reload the config page (F5) | Values persist; Page Access Token is masked (e.g., "EA****Zx"), Page ID shows in full | |
| HV-11 | Test connection | Go to Dashboard tab, click "Test Connection" | Shows "Connected as [Page Name] (ID: xxxxx)" with green status badge | |
| HV-12 | Bad token error | Go to Config, change token to "expired_token_test", Save, go to Dashboard, Test Connection | Shows clear error message about authentication failure (not a stack trace or crash) | |
| HV-13 | Restore good token | Go to Config, re-enter correct Page Access Token, Save | Save succeeds | |
| HV-14 | Masked token preserved | Reload config page — token shows masked. Click Save WITHOUT changing it | Test Connection still works (masked token preserved, not overwritten with masked string) | |
| HV-15 | Restart persistence | Run `docker exec <container> supervisorctl restart run_ui`, wait 10s, reload WebUI | Plugin still configured, Test Connection still works | |

---

## Phase 3: Core Tools — facebook_post (3 tests)

Test via the Agent Zero chat interface. Type each prompt into the agent chat.

| ID | Test | Agent Prompt | Expected | Result |
|----|------|-------------|----------|--------|
| HV-16 | Create text post | "Post to my Facebook Page: Hello from Agent Zero!" | Agent uses `facebook_post` tool, post appears on the Page, agent reports success with post ID | |
| HV-17 | Create link post | "Post a link to https://github.com on my Facebook Page with message 'Check this out'" | Post appears with link preview on the Page, agent reports success with post ID | |
| HV-18 | Create scheduled post | "Schedule a post on my Facebook Page for tomorrow at 3pm: 'Scheduled post test'" | Agent calculates correct Unix timestamp, scheduled post appears in Page's Publishing Tools (not yet published) | |

---

## Phase 4: Core Tools — facebook_read (4 tests)

| ID | Test | Agent Prompt | Expected | Result |
|----|------|-------------|----------|--------|
| HV-19 | Read page feed | "Show me my Facebook Page's recent posts" | Agent uses `facebook_read`, returns formatted posts with message, timestamp, engagement metrics, and post IDs | |
| HV-20 | Read specific post | "Show me this Facebook post: `<post_id>`" (use ID from HV-19) | Returns full post details with likes, comments, shares counts | |
| HV-21 | Read comments | "Show me the comments on this Facebook post: `<post_id>`" (use a post with comments) | Returns formatted comments with author, text, timestamps | |
| HV-22 | Invalid post ID | "Show me this Facebook post: invalid_id_format!@#" | Agent reports validation error for the ID format, does not make API call with malformed input | |

---

## Phase 5: Core Tools — facebook_comment (2 tests)

| ID | Test | Agent Prompt | Expected | Result |
|----|------|-------------|----------|--------|
| HV-23 | Reply to comment | "Reply to this comment `<comment_id>` with 'Thanks for your feedback!'" (use ID from HV-21) | Agent uses `facebook_comment`, reply appears threaded under the original comment on Facebook | |
| HV-24 | Delete comment | "Delete this Facebook comment: `<comment_id>`" (use reply from HV-23 or a test comment) | Agent uses `facebook_comment` with delete action, comment is removed from Facebook | |

---

## Phase 6: Core Tools — facebook_manage (3 tests)

| ID | Test | Agent Prompt | Expected | Result |
|----|------|-------------|----------|--------|
| HV-25 | Edit a post | "Edit my Facebook post `<post_id>` to say 'Updated: Hello from Agent Zero!'" (use post from HV-16) | Agent uses `facebook_manage` with edit action, post text is updated on Facebook | |
| HV-26 | Delete a post | "Delete this Facebook post: `<post_id>`" (create a test post first) | Agent uses `facebook_manage` with delete action, post is removed from the Page | |
| HV-27 | Hide a comment | "Hide this comment on my Facebook Page: `<comment_id>`" | Agent uses `facebook_manage` with hide action, comment is hidden (visible only to author and page admins) | |

---

## Phase 7: Core Tools — facebook_media (1 test)

| ID | Test | Agent Prompt | Expected | Result |
|----|------|-------------|----------|--------|
| HV-28 | Upload a photo | "Upload this photo to my Facebook Page with caption 'Test photo upload': https://picsum.photos/200" | Agent uses `facebook_media`, photo appears on the Page with caption | |

---

## Phase 8: Core Tools — facebook_insights (2 tests)

| ID | Test | Agent Prompt | Expected | Result |
|----|------|-------------|----------|--------|
| HV-29 | Page insights | "Show me my Facebook Page analytics for this week" | Agent uses `facebook_insights`, returns page-level metrics (impressions, engaged users, fan adds) formatted with dates and values | |
| HV-30 | Post insights | "Show me the analytics for this Facebook post: `<post_id>`" | Agent uses `facebook_insights` with post-level metrics, returns post impressions, engaged users, clicks | |

---

## Phase 9: Core Tools — facebook_page (2 tests)

| ID | Test | Agent Prompt | Expected | Result |
|----|------|-------------|----------|--------|
| HV-31 | Get page info | "Show me my Facebook Page details" | Agent uses `facebook_page`, returns page name, category, about, fan count, website, ID | |
| HV-32 | List managed pages | "What Facebook Pages do I manage?" | Agent uses `facebook_page` with list action, returns list of pages with names, categories, fan counts | |

---

## Phase 10: Security — Access Control (2 tests)

| ID | Test | Action | Expected | Result |
|----|------|--------|----------|--------|
| HV-33 | CSRF enforcement | Run: `curl -X POST http://localhost:<port>/api/plugins/facebook/facebook_test -H "Content-Type: application/json" -d '{}'` | 403 Forbidden (no CSRF token) | |
| HV-34 | Config masking | Fetch config via API with valid CSRF token and check token field | Page Access Token is masked (shows `EA****Zx` not full token) | |

**Note for HV-33/34:** You'll need a valid CSRF token. Get one from:
```bash
curl -s http://localhost:<port>/api/csrf_token -c cookies.txt
# Then use the token from the response in subsequent requests
```

---

## Phase 11: Edge Cases & Error Handling (5 tests)

| ID | Test | Action | Expected | Result |
|----|------|--------|----------|--------|
| HV-35 | Post too long | Ask agent to post text longer than 63,206 characters | Agent reports error about length limit, does not attempt the API call | |
| HV-36 | No credentials | Remove Page Access Token from config, then ask: "Post to my Facebook Page" | Agent reports "No Page Access Token configured", suggests configuring in plugin settings | |
| HV-37 | Emoji in post | Ask: "Post to my Facebook Page: Testing emojis! 🎉🚀💯" | Post appears on Facebook with emojis rendered correctly, no encoding errors | |
| HV-38 | Rapid tool calls | Ask agent to perform 3 actions quickly (read feed, get page info, get insights) | All complete without crash or rate-limit failure | |
| HV-39 | Restart persistence | `docker exec <container> supervisorctl restart run_ui`, wait 15s, then ask agent to read page feed | Plugin recovers, tools work after restart | |

---

## Phase 12: Documentation Spot-Check (3 tests)

| ID | Test | Action | Expected | Result |
|----|------|--------|----------|--------|
| HV-40 | README accuracy | Read README.md. Does it list 7 tools? | Tools listed match: facebook_post, facebook_read, facebook_comment, facebook_manage, facebook_media, facebook_insights, facebook_page | |
| HV-41 | QUICKSTART works | Follow QUICKSTART.md steps. Are they accurate? | Steps match actual process (token setup, install, config, test) | |
| HV-42 | Example prompt | Try an example prompt from the docs | It works as described | |

---

## Phase 13: Sign-Off

```
Plugin:           Facebook Pages
Version:          1.0.0
Container:        _______________
Port:             _______________
Date:             _______________
Tester:           _______________

Regression Tests: ___/___ PASS
Human Tests:      ___/42  PASS  ___/42 FAIL  ___/42 SKIP
Security Assessment: Pending / Complete (see SECURITY_ASSESSMENT_RESULTS.md)

Overall:          [ ] APPROVED  [ ] NEEDS WORK  [ ] BLOCKED

Notes:
_______________________________________________________________
_______________________________________________________________
_______________________________________________________________
```

---

## Quick Troubleshooting

| Problem | Check |
|---------|-------|
| "Test Connection" fails | Is Page Access Token correct and not expired? Is container network accessible? |
| Agent doesn't use Facebook tools | Is plugin enabled (.toggle-1)? Restart run_ui after deploy |
| Permission errors from API | Check token has all 5 required permissions in Graph API Explorer |
| Scheduled post not visible | Check Page's Publishing Tools (not the main feed) |
| Insights return empty | Page may need minimum activity/followers for metrics to populate |
| Rate limited | Facebook Graph API rate limits vary; wait and retry |
| Token expired | Page Access Tokens can expire; regenerate in Graph API Explorer |
