---
status: published
repo: https://github.com/spinnakergit/a0-facebook
index_pr: https://github.com/agent0ai/a0-plugins/pull/88
published_date: 2026-03-18
version: 1.1.0
---

# Release Status

## Publication
- **GitHub**: https://github.com/spinnakergit/a0-facebook
- **Plugin Index PR**: [#88](https://github.com/agent0ai/a0-plugins/pull/88) (passed CI)
- **Published**: 2026-03-18

## v1.1.0 (2026-03-28)

### Changes
- Migrated config.html to Alpine.js framework pattern (outer Save button for settings)
- Added hooks.py for plugin lifecycle management
- Improved install.sh with in-place detection for plugin manager installs
- Fixed main.html fetchApi CSRF pattern (resolve at call time)

### Notes
- All tabs (Credentials, Defaults, Security) use Alpine.js x-model bindings saved by framework outer Save
- Setup Guide link points to GitHub docs
- Insights period uses select dropdown (day/week/28 days/lifetime)

## v1.0.0 (2026-03-18)

### Verification
- **Automated Tests**: 70/70 PASS
- **Human Verification**: 53/53 PASS
- **Manual Testing**: 20/20 PASS
- **Security Assessment**: Completed
