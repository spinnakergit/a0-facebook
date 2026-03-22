## facebook_manage
Manage Facebook Page content: delete posts, edit posts, hide or unhide comments.

**Arguments:**
- **action** (string): `delete_post`, `edit_post`, `hide_comment`, or `unhide_comment`
- **post_id** (string): Post ID (for `delete_post`, `edit_post`)
- **comment_id** (string): Comment ID (for `hide_comment`, `unhide_comment`)
- **message** (string): New message text (for `edit_post`)

~~~json
{"action": "delete_post", "post_id": "123456789_987654321"}
~~~
~~~json
{"action": "edit_post", "post_id": "123456789_987654321", "message": "Updated post text"}
~~~
~~~json
{"action": "hide_comment", "comment_id": "123456789_987654321"}
~~~
~~~json
{"action": "unhide_comment", "comment_id": "123456789_987654321"}
~~~

**Notes:**
- Hidden comments are only visible to the commenter and their friends
- Editing a post replaces the entire message text
- Deleting a post is permanent and cannot be undone
