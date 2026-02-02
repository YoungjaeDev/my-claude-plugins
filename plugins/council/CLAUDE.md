# Council Plugin

LLM Council - Query multiple AI models and synthesize collective wisdom.

Inspired by Andrej Karpathy's LLM Council concept.

## Commands

| Command | Description |
|---------|-------------|
| `/council` | Start multi-model deliberation |
| `/council --quick` | Quick mode (single round, faster) |
| `/council-setup` | Setup Codex/Gemini CLI |
| `/council:ask-codex` | Query Codex directly with Claude cross-check |
| `/council:ask-gemini` | Query Gemini directly with Claude cross-check |

## How It Works

1. **Query** all available models in parallel with the same question
2. **Anonymize** responses (Response A, B, C, D)
3. **Analyze** gaps and conflicts
4. **Re-query** if needed (up to 3 rounds)
5. **Synthesize** collective wisdom with model reveal

## Available Models

| Model | Status | Notes |
|-------|--------|-------|
| Claude Opus | Built-in | Always available |
| Claude Sonnet | Built-in | Always available |
| Codex | Optional | Run `/council-setup` to install |
| Gemini | Optional | Run `/council-setup` to install |

**Minimum**: 2 models required (Opus + Sonnet always available)

## Usage Examples

```bash
# Architecture question
/council What's the best way to structure this microservice?

# Quick opinion poll
/council --quick Should we use Redis or Memcached for caching?

# Code review
/council Review the authentication flow and suggest improvements
```

## Modes

| Mode | Rounds | Speed | Use Case |
|------|--------|-------|----------|
| **Default** | Up to 3 | 5-15 min | Complex decisions |
| **Quick** (`--quick`) | 1 | 1-3 min | Simple questions |

## Setup

Check current status:
```bash
command -v codex && echo "Codex: ✅" || echo "Codex: ❌"
command -v gemini && echo "Gemini: ✅" || echo "Gemini: ❌"
```

Install additional models:
```
/council-setup
```

## Output

Council produces a structured report:
- Individual responses (anonymized)
- Model reveal
- Consensus points
- Conflicts and resolutions
- Final synthesized verdict
