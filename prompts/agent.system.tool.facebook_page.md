## facebook_page
Get Facebook Page details and list managed pages.

**Arguments:**
- **action** (string): `info` or `pages_list`

~~~json
{"action": "info"}
~~~
~~~json
{"action": "pages_list"}
~~~

**Notes:**
- `info` returns details about the currently configured page (name, category, fan count, description, etc.)
- `pages_list` returns all pages the token owner has admin access to — useful for finding page IDs
- Use `pages_list` to discover your Page ID if you don't know it
