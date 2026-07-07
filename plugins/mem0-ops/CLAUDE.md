# mem0-ops

플릿 레벨 mem0 진단·정리. upstream `mem0@mem0-plugins`(프로젝트 내부 품질:
health/memory-reviewer/stats/dream)와 역할 분리 — 이 플러그인은 app_id **간**
운영만 담당한다. 기능 복제 금지.

| Skill | 역할 |
|---|---|
| `fleet-scan` | 전 앱 노이즈율·쓰레기 후보·파편화 리포트 (read-only) |
| `doctor` | 설정 자세 점검 — rerank env, auto_save 파일 우선순위 함정, decay, 훅 timeout, 정체성 파편화 (제안만) |
| `cleanup` | 백업→타입/앱 단위 삭제. dry-run 기본, `--execute` + 사용자 확인 필수 |

스크립트는 stdlib + REST 직결(`scripts/_api.py`). upstream 스크립트/venv 의존
없음. `MEM0_API_KEY` 필수. 근거 스펙:
`docs/superpowers/specs/2026-07-07-mem0-ops-plugin-design.md`.
