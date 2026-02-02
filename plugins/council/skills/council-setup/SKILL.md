---
name: council-setup
description: Setup Codex CLI and Gemini CLI for LLM Council multi-model deliberation. Run this to install additional AI models for richer council discussions.
---

# Council Setup

Setup additional AI models for LLM Council deliberation.

## Current Status Check

Run this first to see what's available:

```bash
echo "=== Council Models Status ==="
echo ""
echo "Built-in (always available):"
echo "  Claude Opus:   ✅ Ready"
echo "  Claude Sonnet: ✅ Ready"
echo ""
echo "Optional (enhances council diversity):"
command -v codex > /dev/null 2>&1 && echo "  Codex CLI:     ✅ Installed" || echo "  Codex CLI:     ❌ Not installed"
command -v gemini > /dev/null 2>&1 && echo "  Gemini CLI:    ✅ Installed" || echo "  Gemini CLI:    ❌ Not installed"
echo ""
echo "Council can run with 2+ models. More models = more diverse perspectives."
```

## Model Overview

| Model | Provider | Strengths |
|-------|----------|-----------|
| **Claude Opus** | Anthropic | Deep reasoning, nuanced analysis |
| **Claude Sonnet** | Anthropic | Balanced speed/quality |
| **Codex** | OpenAI | Code expertise, structured thinking |
| **Gemini** | Google | Broad knowledge, different perspective |

## Install Codex CLI

### Prerequisites
- Node.js 22+ (`node --version`)
- OpenAI API key

### Installation

```bash
# Install globally
npm install -g @openai/codex

# Verify installation
codex --version
```

### Configuration

```bash
# Set API key (interactive)
codex auth

# Or set environment variable
export OPENAI_API_KEY="sk-..."
```

### MCP Configuration (Optional)

Create/edit `~/.codex/config.toml`:

```toml
[mcp]
enabled = true

[mcp.servers.filesystem]
command = "npx"
args = ["-y", "@anthropic/mcp-server-filesystem", "/path/to/allowed/dir"]
```

### Verify

```bash
codex "Hello, what's 2+2?"
```

---

## Install Gemini CLI

### Prerequisites
- Node.js 18+ or Python 3.9+
- Google AI API key

### Installation (Node.js)

```bash
# Install globally
npm install -g @anthropic/gemini-cli

# Verify
gemini --version
```

### Installation (Python alternative)

```bash
# Using pipx (recommended)
pipx install gemini-cli

# Or pip
pip install gemini-cli
```

### Configuration

```bash
# Set API key
export GOOGLE_API_KEY="your-api-key"

# Or use gcloud auth (if using Vertex AI)
gcloud auth application-default login
```

### Create Guidelines File

Create `GEMINI.md` in your project root (similar to CLAUDE.md):

```markdown
# Gemini Guidelines

Project-specific instructions for Gemini model.

## Coding Standards
- Follow existing patterns
- Use TypeScript for new files

## Response Style
- Be concise
- Include code examples
```

### MCP Configuration (Optional)

Since 2025, Gemini CLI supports MCP. Create `~/.gemini/settings.json`:

```json
{
  "mcp": {
    "servers": {
      "filesystem": {
        "command": "npx",
        "args": ["-y", "@anthropic/mcp-server-filesystem", "/path/to/dir"]
      }
    }
  }
}
```

### Verify

```bash
gemini -p "Hello, what's 2+2?"
```

---

## Post-Setup Verification

After installing, run full verification:

```bash
echo "=== Full Council Verification ==="

# Check all CLIs
echo -n "Claude Code: " && command -v claude > /dev/null && echo "✅" || echo "❌"
echo -n "Codex CLI:   " && command -v codex > /dev/null && echo "✅" || echo "❌"
echo -n "Gemini CLI:  " && command -v gemini > /dev/null && echo "✅" || echo "❌"

# Check guidelines files
echo ""
echo "Guidelines files:"
[ -f ./CLAUDE.md ] && echo "  CLAUDE.md: ✅" || echo "  CLAUDE.md: ❌ (create for Claude)"
[ -f ./AGENTS.md ] && echo "  AGENTS.md: ✅" || echo "  AGENTS.md: ❌ (optional, for Codex)"
[ -f ./GEMINI.md ] && echo "  GEMINI.md: ✅" || echo "  GEMINI.md: ❌ (create for Gemini)"

# Count available models
echo ""
MODELS=2  # Claude Opus + Sonnet always available
command -v codex > /dev/null && MODELS=$((MODELS + 1))
command -v gemini > /dev/null && MODELS=$((MODELS + 1))
echo "Total council members: $MODELS/4"
echo ""
if [ $MODELS -ge 2 ]; then
  echo "✅ Council is ready! Run /council to start."
else
  echo "❌ Need at least 2 models for council."
fi
```

---

## Test Council

Run a quick test:

```bash
/council --quick "What's the best way to handle errors in async JavaScript?"
```

---

## Troubleshooting

### Codex: "command not found"

```bash
# Check npm global bin path
npm bin -g

# Add to PATH if needed
export PATH="$PATH:$(npm bin -g)"
```

### Gemini: "API key not set"

```bash
# Verify environment variable
echo $GOOGLE_API_KEY

# Set it if missing
export GOOGLE_API_KEY="your-key-here"

# Add to shell profile for persistence
echo 'export GOOGLE_API_KEY="your-key"' >> ~/.bashrc
```

### Timeout Issues

Council uses generous timeouts:
- Opus/Sonnet: 5 min
- Codex: 8 min (deep reasoning)
- Gemini: 10 min (CLI overhead)

If still timing out, try `--quick` mode for faster responses.

---

## Minimum vs Optimal Setup

| Setup | Models | Quality |
|-------|--------|---------|
| **Minimum** | Opus + Sonnet | Good (2 perspectives) |
| **Better** | + Codex | Better (3 perspectives, code expertise) |
| **Optimal** | + Codex + Gemini | Best (4 perspectives, maximum diversity) |

Council works with minimum 2 models. Additional models are optional but recommended for richer deliberation.
