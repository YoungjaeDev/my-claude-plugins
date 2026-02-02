# Notion Integration Setup Guide

This guide walks through setting up a Notion integration for the Markdown uploader.

## Step 1: Create a Notion Integration

1. Go to https://www.notion.so/my-integrations
2. Click "+ New integration"
3. Fill in the form:
   - **Name**: Choose a descriptive name (e.g., "MD Uploader")
   - **Logo**: Optional
   - **Associated workspace**: Select your target workspace
4. Click "Submit"

## Step 2: Configure Capabilities

After creation, configure the integration's capabilities:

### Content Capabilities

Enable all of these for full functionality:

- **Read content**: Required for verifying pages
- **Update content**: Required for appending blocks
- **Insert content**: Required for creating pages and uploading files

### User Capabilities

- **Read user information including email addresses**: Not required
- **No user information**: Sufficient for this tool

### Comment Capabilities

- Not required for the uploader

## Step 3: Copy the API Key

1. On the integration page, find the "Internal Integration Secret"
2. Click "Show" then "Copy"
3. Store this securely - it cannot be retrieved again

## Step 4: Set Environment Variable

### Option A: .env File (Recommended)

Create or edit `.env` in your project root:

```bash
NOTION_API_KEY=ntn_xxxxxxxxxxxxxxxxxxxxx
```

### Option B: Export in Shell

```bash
export NOTION_API_KEY=ntn_xxxxxxxxxxxxxxxxxxxxx
```

### Option C: Session-specific

```bash
NOTION_API_KEY=ntn_xxx uv run python upload_md.py ...
```

## Step 5: Share Pages with Integration

The integration can only access pages explicitly shared with it.

### Sharing a Single Page

1. Open the target page in Notion
2. Click the "..." menu (top right corner)
3. Select "Add connections"
4. Search for your integration name
5. Click to add

### Sharing a Database

Same process as above, but on the database page.

### Sharing Child Pages

When you share a parent page, all child pages are also accessible.

## Step 6: Find Page ID

### From Browser URL

1. Open the page in Notion
2. Copy the URL: `https://www.notion.so/Page-Title-abc123def456ghi789jkl012`
3. The ID is the 32-character string at the end: `abc123def456ghi789jkl012`

### From Share Link

1. Click "Share" > "Copy link"
2. Extract the ID from the URL

### Format Requirements

The script accepts:
- Raw 32-character ID: `abc123def456ghi789jkl012`
- UUID format: `abc123de-f456-ghi7-89jk-l012mnopqrst`
- Full URL: `https://www.notion.so/...`

## Verification

Test the setup:

```bash
uv run python .claude/skills/notion-md-uploader/scripts/upload_md.py \
    --help
```

Then try a dry run:

```bash
uv run python .claude/skills/notion-md-uploader/scripts/upload_md.py \
    README.md \
    --parent-page-id YOUR_PAGE_ID \
    --dry-run
```

## Troubleshooting

### "unauthorized" Error

1. Verify the API key is correct
2. Check there are no extra spaces or newlines
3. Regenerate the key if needed

### "Could not find page" Error

1. Confirm the page ID is correct
2. Ensure the page is shared with the integration
3. Check the integration has the required capabilities

### "validation_error" for File Upload

1. File may exceed size limit (20MB, or 5MB for free plans)
2. File type may not be supported
3. Check the file exists at the specified path

## Security Best Practices

1. **Never commit API keys**: Add `.env` to `.gitignore`
2. **Use environment variables**: Don't hardcode keys
3. **Limit access**: Only share necessary pages
4. **Rotate keys**: Regenerate periodically
5. **Monitor usage**: Check integration logs in Notion

## Workspace Limits

| Feature | Free | Plus/Business |
|---------|------|---------------|
| Max file size | 5 MB | 5 GB |
| API rate limit | 3 req/s | 3 req/s |
| Blocks per request | 100 | 100 |
