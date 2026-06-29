"""Hermes Agent adapter for the github-dev plugin.

The upstream plugin already ships skills for Claude Code and Codex. Hermes loads
plugin-provided skills through a small Python entrypoint, so this module simply
registers the existing SKILL.md files under the ``github-dev:<skill>`` namespace.
"""

from __future__ import annotations

from pathlib import Path


def _description_from_skill(skill_md: Path) -> str:
    """Extract the frontmatter description from a SKILL.md file."""
    text = skill_md.read_text(encoding="utf-8", errors="replace")
    if not text.startswith("---"):
        return ""
    try:
        _, frontmatter, _ = text.split("---", 2)
    except ValueError:
        return ""
    for line in frontmatter.splitlines():
        stripped = line.strip()
        if stripped.startswith("description:"):
            return stripped.split(":", 1)[1].strip().strip('"').strip("'")
    return ""


def register(ctx) -> None:
    """Register github-dev skills with Hermes.

    Hermes automatically qualifies these as ``github-dev:<name>`` based on the
    plugin manifest name, matching the existing Claude/Codex command namespace.
    """
    skills_root = Path(__file__).resolve().parent / "skills"
    for skill_md in sorted(skills_root.glob("*/SKILL.md")):
        ctx.register_skill(
            skill_md.parent.name,
            skill_md,
            _description_from_skill(skill_md),
        )
