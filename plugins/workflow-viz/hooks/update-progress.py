#!/usr/bin/env python3
"""
Workflow Progress Tracker Hook

Triggered on Stop event to update workflow progress state.
Updates .claude/state/workflow-progress.json and diagram metadata.
"""

import json
import os
import sys
from datetime import datetime
from pathlib import Path

# 경로 설정
PROJECT_ROOT = Path(os.environ.get("CLAUDE_PROJECT_ROOT", os.getcwd()))
STATE_DIR = PROJECT_ROOT / ".claude" / "state"
STATE_FILE = STATE_DIR / "workflow-progress.json"
DOCS_DIR = PROJECT_ROOT / "docs" / "architecture"


def load_state() -> dict:
    """Load current workflow progress state."""
    if STATE_FILE.exists():
        with open(STATE_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return {
        "version": "1.0.0",
        "lastUpdated": None,
        "activeWorkflow": None,
        "completedTasks": [],
        "history": [],
    }


def save_state(state: dict) -> None:
    """Save workflow progress state."""
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    state["lastUpdated"] = datetime.now().isoformat()
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2, ensure_ascii=False)


def detect_active_workflow() -> dict | None:
    """Detect currently active workflow from state files."""
    # github-dev state files
    for state_file in STATE_DIR.glob("github-dev-*.json"):
        if "archive" not in str(state_file):
            with open(state_file, "r", encoding="utf-8") as f:
                data = json.load(f)
                return {
                    "plugin": "github-dev",
                    "command": data.get("command", "unknown"),
                    "phase": data.get("phase", "unknown"),
                    "issueNumber": data.get("issueNumber"),
                }

    return None


def update_diagram_metadata() -> None:
    """Update last-updated timestamp in diagram files."""
    if not DOCS_DIR.exists():
        return

    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    for md_file in DOCS_DIR.rglob("*.md"):
        try:
            content = md_file.read_text(encoding="utf-8")
            if "<!-- last-updated:" in content:
                # 타임스탬프 업데이트
                import re

                updated = re.sub(
                    r"<!-- last-updated:.*?-->",
                    f"<!-- last-updated: {timestamp} -->",
                    content,
                )
                if updated != content:
                    md_file.write_text(updated, encoding="utf-8")
        except Exception:
            pass  # 파일 접근 오류 무시


def main():
    """Main entry point for Stop hook."""
    try:
        state = load_state()

        # 활성 워크플로우 감지
        active = detect_active_workflow()

        if active:
            # 활성 워크플로우가 있으면 상태 업데이트
            state["activeWorkflow"] = active

            # 히스토리에 기록
            state["history"].append(
                {
                    "timestamp": datetime.now().isoformat(),
                    "event": "stop",
                    "workflow": active,
                }
            )

            # 히스토리 최대 100개 유지
            if len(state["history"]) > 100:
                state["history"] = state["history"][-100:]
        else:
            # 워크플로우 완료
            if state.get("activeWorkflow"):
                state["completedTasks"].append(
                    {
                        "workflow": state["activeWorkflow"],
                        "completedAt": datetime.now().isoformat(),
                    }
                )
                state["activeWorkflow"] = None

        save_state(state)
        update_diagram_metadata()

        # 시스템 리마인더 출력 (선택적)
        if active:
            print(
                f"<system-reminder>Workflow progress updated: {active['plugin']}:{active.get('command', 'unknown')}</system-reminder>"
            )

    except Exception as e:
        # 훅 실패가 전체 워크플로우를 방해하지 않도록
        print(
            f"<system-reminder>workflow-viz hook warning: {e}</system-reminder>",
            file=sys.stderr,
        )


if __name__ == "__main__":
    main()
