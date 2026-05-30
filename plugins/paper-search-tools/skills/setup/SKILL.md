---
name: setup
description: Configure or troubleshoot the Paper Search MCP server (Docker-based academic paper search). Use when the user wants to set up paper search, or hits "paper-search MCP error", "Docker not found", "Docker not running", "paper search not working", or "Semantic Scholar rate limit". Walks through Docker install/verify, image pull, downloads dir, volume mounts, and the optional Semantic Scholar API key.
---

# Paper Search MCP Setup

Configure the Paper Search MCP server for academic paper discovery, or fix a
broken setup. Self-contained — follow the steps below.

## Prerequisites

Docker must be installed and running.

## Steps

### 1. Check Docker Installation

```bash
docker --version
```

**If not installed:**
- macOS: `brew install --cask docker`
- Linux: `curl -fsSL https://get.docker.com | sh`
- Windows: `winget install Docker.DockerDesktop`

### 2. Verify Docker is Running

```bash
docker info
```

If not running, start Docker Desktop and wait for it to fully initialize.

### 3. Pull the Image

```bash
docker pull mcp/paper-search
```

### 4. Create Downloads Directory

Papers will be downloaded to a local directory.

**macOS/Linux:**
```bash
mkdir -p /tmp/paper-search-downloads
```

**Windows (PowerShell):**
```powershell
mkdir -Force $env:TEMP\paper-search-downloads
```

### Windows Volume Mount Configuration

Windows users must update the `.mcp.json` volume mount path. The path format
depends on your Docker Desktop backend:

**WSL2 Backend (Default):**
```json
"-v", "/mnt/c/Users/<username>/paper-search-downloads:/downloads"
```

**Hyper-V Backend:**
```json
"-v", "C:/Users/<username>/paper-search-downloads:/downloads"
```

Replace `<username>` with your actual Windows username.

**Full `.mcp.json` example (WSL2):**
```json
{
  "mcpServers": {
    "paper-search": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "-v", "/mnt/c/Users/<username>/paper-search-downloads:/downloads", "-e", "SEMANTIC_SCHOLAR_API_KEY", "mcp/paper-search"]
    }
  }
}
```

### 5. (Optional) Configure Semantic Scholar API Key

For enhanced Semantic Scholar functionality, set the API key:

```bash
export SEMANTIC_SCHOLAR_API_KEY="your-api-key"
```

Get a free API key at: https://www.semanticscholar.org/product/api

### 6. Done

Restart Claude Code (`exit` then `claude`).

Run `/mcp` to verify the 'paper-search' server is connected.

## Troubleshooting / Quick Fixes

- **Docker not found** — Install Docker (see Step 1)
- **Docker not running** — Start Docker Desktop
- **Connection failed** — Restart Claude Code after Docker starts
- **Semantic Scholar rate limited** — Add the API key (see Step 5)

## Don't Need Paper Search?

Disable it via the `/mcp` command to prevent errors.
