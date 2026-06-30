"""Hermes Agent adapter for the ml-toolkit plugin.

The upstream plugin already ships skills for Claude Code and Codex. Hermes loads
plugin-provided skills through a small Python entrypoint, so this module simply
registers the existing SKILL.md files under the ``ml-toolkit:<skill>`` namespace.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import yaml


def _frontmatter_from_skill(skill_md: Path) -> dict[str, Any]:
    """Decode the YAML frontmatter from a SKILL.md file."""
    text = skill_md.read_text(encoding="utf-8", errors="replace")
    if not text.startswith("---"):
        return {}
    try:
        _, frontmatter, _ = text.split("---", 2)
    except ValueError:
        return {}
    data = yaml.safe_load(frontmatter) or {}
    return data if isinstance(data, dict) else {}


def _description_from_skill(skill_md: Path) -> str:
    """Extract the decoded frontmatter description from a SKILL.md file."""
    description = _frontmatter_from_skill(skill_md).get("description", "")
    if description is None:
        return ""
    if isinstance(description, str):
        return description.strip()
    return str(description).strip()


def register(ctx) -> None:
    """Register ml-toolkit skills with Hermes.

    Hermes automatically qualifies these as ``ml-toolkit:<name>`` based on the
    plugin manifest name, matching the existing Claude/Codex command namespace.
    """
    skills_root = Path(__file__).resolve().parent / "skills"
    for skill_md in sorted(skills_root.glob("*/SKILL.md")):
        ctx.register_skill(
            skill_md.parent.name,
            skill_md,
            _description_from_skill(skill_md),
        )
