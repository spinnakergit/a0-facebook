## facebook_media
Upload photos to a Facebook Page.

**Arguments:**
- **action** (string): `upload_photo`
- **image_path** (string): Local file path to the image (mutually exclusive with image_url)
- **image_url** (string): URL of the image to upload (mutually exclusive with image_path)
- **caption** (string): Photo caption / description text (optional)

~~~json
{"action": "upload_photo", "image_path": "/path/to/photo.jpg", "caption": "Beautiful sunset!"}
~~~
~~~json
{"action": "upload_photo", "image_url": "https://example.com/image.jpg", "caption": "Shared from the web"}
~~~

**Notes:**
- Supported formats: PNG, JPEG, GIF, BMP, TIFF, WebP
- Maximum file size: 10MB
- Photos are posted to the page's timeline with the caption
- Either image_path (local file) or image_url (remote URL) must be provided
