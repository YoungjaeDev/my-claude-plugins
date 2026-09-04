# GitHub CLI Reference

## Installation

```bash
# macOS
brew install gh

# Ubuntu/Debian
sudo apt install gh

# Windows
winget install GitHub.cli
```

## Authentication

```bash
# Login interactively
gh auth login

# Check status
gh auth status
```

## Repository Search

### Basic Search

```bash
# Search repositories
gh search repos "keyword"

# With options
gh search repos "keyword" --limit 20 --sort stars

# Filter by language
gh search repos "keyword" --language python

# Filter by owner
gh search repos "keyword" --owner username
```

### Sort Options

- `stars` - Sort by star count (default)
- `forks` - Sort by fork count
- `updated` - Sort by last update
- `help-wanted-issues` - Sort by help-wanted issues
- `best-match` - Sort by relevance

### JSON Output

```bash
# Get specific fields as JSON
gh search repos "keyword" --json fullName,description,stargazersCount,url

# Available JSON fields
# fullName, name, owner, description, url, createdAt, updatedAt
# stargazersCount, forksCount, watchersCount, language, isArchived
# isFork, isPrivate, visibility, license, topics
```

## Repository Operations

### View Repository

```bash
# View in terminal
gh repo view owner/repo

# View specific fields as JSON
gh repo view owner/repo --json name,description,stargazersCount,readme
```

### Clone Repository

```bash
# Clone
gh repo clone owner/repo

# Clone to specific directory
gh repo clone owner/repo ./my-directory
```

### List Repository Contents

```bash
# List files (requires being in repo or using gh api)
gh api repos/owner/repo/contents/path

# Get file content
gh api repos/owner/repo/contents/README.md --jq '.content' | base64 -d
```

## Code Search

```bash
# Search code
gh search code "function_name"

# Filter by file extension
gh search code "import torch" --extension py

# Filter by repository
gh search code "keyword" --repo owner/repo
```

## API Usage

### Direct API Calls

```bash
# GET request
gh api repos/owner/repo

# With pagination
gh api repos/owner/repo/commits --paginate

# With query parameters
gh api search/repositories -f q="keyword" -f sort=stars
```

### Common Endpoints

```bash
# Repository info
gh api repos/owner/repo

# Repository contents
gh api repos/owner/repo/contents/path

# Releases
gh api repos/owner/repo/releases

# Contributors
gh api repos/owner/repo/contributors
```

## Useful Examples

### Find Popular Python ML Repositories

```bash
gh search repos "machine learning" --language python --sort stars --limit 20
```

### Get Repository Structure

```bash
gh api repos/owner/repo/git/trees/main?recursive=1 --jq '.tree[].path'
```

### Download Specific File

```bash
curl -sL "https://raw.githubusercontent.com/owner/repo/main/path/to/file"
```

### Check Repository Activity

```bash
gh api repos/owner/repo/commits --jq '.[0:5] | .[] | "\(.commit.author.date) - \(.commit.message | split("\n")[0])"'
```

## Rate Limits

- Authenticated: 5,000 requests/hour
- Search API: 30 requests/minute

Check rate limit:
```bash
gh api rate_limit
```
