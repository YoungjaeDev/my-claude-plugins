# Paper Search MCP Setup

Configures the Paper Search MCP server for academic paper discovery.

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

Windows users must update the `.mcp.json` volume mount path. The path format depends on your Docker Desktop backend:

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

Run `/mcp` to verify 'paper-search' server is connected.

## Troubleshooting

- **Docker not found** - Install Docker (see step 1)
- **Docker not running** - Start Docker Desktop
- **Connection failed** - Restart Claude Code after Docker starts
- **Semantic Scholar rate limited** - Add API key (see step 5)
