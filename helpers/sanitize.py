"""
Facebook content sanitization, validation, and formatting utilities.

Post limits:
- Text: 63,206 characters (Facebook's max post length)
- Photos: Multiple per post, max 10MB each via Graph API
"""

import re
import unicodedata


MAX_POST_LENGTH = 63206
MAX_COMMENT_LENGTH = 8000


def sanitize_text(text: str) -> str:
    """
    Sanitize text content: normalize unicode, strip zero-width chars,
    collapse whitespace, trim.
    """
    text = unicodedata.normalize("NFKC", text)
    text = re.sub(r"[\u200b\u200c\u200d\u2060\ufeff]", "", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    text = text.strip()
    return text


def validate_post_length(text: str) -> tuple:
    """
    Validate post text length.
    Returns (ok: bool, char_count: int).
    """
    count = len(text)
    return (count <= MAX_POST_LENGTH, count)


def validate_comment_length(text: str) -> tuple:
    """
    Validate comment text length.
    Returns (ok: bool, char_count: int).
    """
    count = len(text)
    return (count <= MAX_COMMENT_LENGTH, count)


def validate_page_id(page_id: str) -> str:
    """
    Validate a Facebook Page ID.
    Can be numeric or a slug (alphanumeric with dots/hyphens).
    Returns cleaned ID or raises ValueError.
    """
    page_id = page_id.strip()
    if not page_id:
        raise ValueError("Page ID cannot be empty")
    if len(page_id) > 256:
        raise ValueError("Page ID too long")
    # Numeric ID
    if re.match(r"^\d+$", page_id):
        return page_id
    # Slug format (e.g., "my.page.name" or "mypage-123")
    if re.match(r"^[a-zA-Z0-9][a-zA-Z0-9.\-_]*$", page_id):
        return page_id
    raise ValueError(f"Invalid Page ID format: {page_id}")


def validate_post_id(post_id: str) -> str:
    """
    Validate a Facebook post ID.
    Format: typically {page_id}_{post_id} (e.g., "123456789_987654321")
    or just a numeric ID.
    Returns cleaned ID or raises ValueError.
    """
    post_id = post_id.strip()
    if not post_id:
        raise ValueError("Post ID cannot be empty")
    if len(post_id) > 256:
        raise ValueError("Post ID too long")
    # Standard format: digits_digits
    if re.match(r"^\d+_\d+$", post_id):
        return post_id
    # Pure numeric
    if re.match(r"^\d+$", post_id):
        return post_id
    raise ValueError(f"Invalid post ID format: {post_id}")


def validate_comment_id(comment_id: str) -> str:
    """
    Validate a Facebook comment ID.
    Format: typically {post_id}_{comment_id} or just numeric.
    Returns cleaned ID or raises ValueError.
    """
    comment_id = comment_id.strip()
    if not comment_id:
        raise ValueError("Comment ID cannot be empty")
    if len(comment_id) > 256:
        raise ValueError("Comment ID too long")
    if re.match(r"^\d+(_\d+)*$", comment_id):
        return comment_id
    raise ValueError(f"Invalid comment ID format: {comment_id}")


def format_post(post: dict) -> str:
    """Format a single post for display."""
    message = post.get("message", "(no text)")
    created = post.get("created_time", "")[:19].replace("T", " ")
    post_id = post.get("id", "")
    permalink = post.get("permalink_url", "")
    post_type = post.get("type", "")

    # Engagement metrics (reactions replaces likes in Graph API v3.3+)
    reactions_data = post.get("reactions", post.get("likes", {}))
    reactions_summary = reactions_data.get("summary", {}) if isinstance(reactions_data, dict) else {}
    like_count = reactions_summary.get("total_count", 0)

    comments_data = post.get("comments", {})
    comments_summary = comments_data.get("summary", {}) if isinstance(comments_data, dict) else {}
    comment_count = comments_summary.get("total_count", 0)

    shares_data = post.get("shares", {})
    share_count = shares_data.get("count", 0) if isinstance(shares_data, dict) else 0

    lines = [
        f"--- Post [{post_type}] ---",
        message[:500] + ("..." if len(message) > 500 else ""),
        f"  [{created}] Likes: {like_count} | Comments: {comment_count} | Shares: {share_count}",
    ]
    if post_id:
        lines.append(f"  ID: {post_id}")
    if permalink:
        lines.append(f"  URL: {permalink}")
    return "\n".join(lines)


def format_posts(posts: list) -> str:
    """Format a list of posts for display."""
    if not posts:
        return "No posts found."
    return "\n\n".join(format_post(p) for p in posts)


def format_comment(comment: dict) -> str:
    """Format a single comment for display."""
    message = comment.get("message", "(no text)")
    created = comment.get("created_time", "")[:19].replace("T", " ")
    comment_id = comment.get("id", "")
    from_user = comment.get("from", {})
    author = from_user.get("name", "Unknown") if isinstance(from_user, dict) else "Unknown"
    like_count = comment.get("like_count", 0)
    reply_count = comment.get("comment_count", 0)

    lines = [
        f"  {author}: {message}",
        f"    [{created}] Likes: {like_count} | Replies: {reply_count} | ID: {comment_id}",
    ]
    return "\n".join(lines)


def format_comments(comments: list) -> str:
    """Format a list of comments for display."""
    if not comments:
        return "No comments found."
    return "\n".join(format_comment(c) for c in comments)


def format_insights(data: list) -> str:
    """Format insights metrics for display."""
    if not data:
        return "No insights data available."
    lines = []
    for metric in data:
        name = metric.get("name", "unknown")
        title = metric.get("title", name)
        description = metric.get("description", "")
        period = metric.get("period", "")
        values = metric.get("values", [])
        lines.append(f"--- {title} ({period}) ---")
        if description:
            lines.append(f"  {description}")
        for val in values[-3:]:  # Show last 3 data points
            end_time = val.get("end_time", "")[:10]
            value = val.get("value", 0)
            lines.append(f"  {end_time}: {value}")
    return "\n".join(lines)


def format_page_info(page: dict) -> str:
    """Format page information for display."""
    name = page.get("name", "Unknown")
    page_id = page.get("id", "")
    category = page.get("category", "")
    about = page.get("about", "")
    description = page.get("description", "")
    fan_count = page.get("fan_count", 0)
    link = page.get("link", "")
    website = page.get("website", "")

    lines = [f"Page: {name}"]
    if category:
        lines.append(f"Category: {category}")
    if about:
        lines.append(f"About: {about}")
    if description:
        lines.append(f"Description: {description[:200]}")
    lines.append(f"Fans: {fan_count}")
    if link:
        lines.append(f"Facebook URL: {link}")
    if website:
        lines.append(f"Website: {website}")
    if page_id:
        lines.append(f"ID: {page_id}")
    return "\n".join(lines)
