"""Pure-logic tests for cleanup target selection. No network."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "scripts"))
from cleanup import select_targets

MEMS = [
    {"id": "a", "metadata": {"type": "session_summary"}},
    {"id": "b", "metadata": {"type": "decision"}},
    {"id": "c", "metadata": None},
    {"id": "d"},
]


def test_type_filter_selects_only_matching():
    assert select_targets(MEMS, mem_type="session_summary") == ["a"]


def test_all_selects_everything():
    assert select_targets(MEMS, all_types=True) == ["a", "b", "c", "d"]


def test_no_selector_selects_nothing():
    assert select_targets(MEMS) == []


def test_missing_metadata_never_matches_type():
    assert select_targets(MEMS, mem_type="decision") == ["b"]
