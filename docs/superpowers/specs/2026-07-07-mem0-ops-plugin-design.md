---
status: merged
---

# mem0-ops 플러그인 설계 (플릿 레벨 mem0 진단·정리)

- 작성일: 2026-07-07
- 상태: approved (plan-mode 미러 승인, 세션 73e1c10b)
- 관련: `plugins/mem0-ops/` (신규), upstream `mem0@mem0-plugins` 0.2.x (경계 상대)
- 근거: 2026-07-07 세션의 mem0 store 전수 감사 — 45 app / 9,968건 실측, stdlib 스크립트 3종 라이브 검증(793건 삭제 실패 0)
- 대체: `.claude/spec/2026-07-07-mem0-ops-plugin-draft.md` (이 문서로 확정, 드래프트 삭제)

## 1. 배경과 목적

2026-07-07 세션에서 mem0 store를 전수 감사한 결과, 단일 프로젝트가 아니라 플릿 레벨의 운영 문제가 확인됐다:

- 45개 app entity, 활성 35개. 총 9,968건 중 **6,716건(67%)이 stop-hook session_summary 노이즈**. 이날 수동 정리한 것은 1개 앱(my-claude-plugins, 1007→230건)뿐.
- **app_id 파편화**: `cc-card-news-deck`(67) vs `YoungjaeDev-cc-card-news-deck`(124) 같은 이중 스코프 + `tmp`/`docs`/`dev` 등 cwd 쓰레기 app_id 약 10개. 쓰레기 app_id의 생성 경로는 upstream의 basename fallback(비-git·unmapped 디렉토리에서 세션 시작)으로 실측 확인.
- **user_id 파편화**: dacon 앱에 4개 정체성 혼재(총 user entity 9개).
- **재발 구조**: `auto_save=false`는 머신 단위(`~/.mem0/settings.json`) — Windows 머신은 계속 노이즈 생산 중.

upstream `mem0@mem0-plugins` 스킬(health/memory-reviewer/stats/dream)은 프로젝트 내부 품질 전용(200건 캡, 단일 app_id)이라 플릿 레벨 갭이 실재한다. 이 세션에서 검증된 stdlib 스크립트 3종(플릿 스캔·감사·정리, LLM 비용 0)이 구현 원형으로 존재한다(`~/.mem0/mem0_audit.py`, `~/.mem0/mem0_cleanup.py`).

## 2. 확정 결정 5건

AskUserQuestion 60s 무응답으로 Recommended 자동 수락 후 plan 승인으로 함께 확정:

1. **app_id 병합 v1 제외** — move API 부재(병합=삭제+재추가, created_at·decay access history 손실). fleet-scan이 파편화 쌍 리포트만.
2. **쓰레기 app_id는 백업→앱 단위 삭제 지원** — 휴리스틱 플래그(cwd형 이름 + 노이즈율 90%+ + 수동 타입 0)는 스캔이, 삭제는 앱별 AskUserQuestion 게이트 뒤에서만.
3. **Windows 동기화는 doctor 안내만** — 각 머신에서 doctor 실행 시 로컬 설정 점검·수정 안내. 원격 배포 스코프 밖.
4. **스킬 3개 분리** (fleet-scan / doctor / cleanup) — e2e-harness(setup/author/debug) 선례. `scripts/` 공유.
5. **Codex eligible 포함(자동), HERMES_ELIGIBLE v1 제외**.

## 3. 플러그인 구조

```
plugins/mem0-ops/
├── .claude-plugin/plugin.json     # name, version 0.1.0, description(<1024c), skills 3종
├── CLAUDE.md                      # 스킬 목록 + upstream 경계 명시
├── scripts/                       # stdlib-only, 단독 실행 가능
│   ├── fleet_scan.py              # entities 열거 → 앱별 노이즈율·타입 분포·파편화 리포트
│   ├── audit.py                   # 단일 앱 전수: 중복쌍(Jaccard)·Exclusions 위반·연령 (mem0_audit.py 이식, APP_ID → argv)
│   ├── cleanup.py                 # 백업(필수) → 타입/앱 단위 삭제. --dry-run 기본, --execute 명시 시만 삭제
│   └── doctor.py                  # 설정 자세 점검(§5)
└── skills/
    ├── fleet-scan/SKILL.md        # 스캔 실행 + 리포트 해석 + 쓰레기 후보 플래그
    ├── doctor/SKILL.md            # 점검 실행 + 수정 안내(제안만)
    └── cleanup/SKILL.md           # dry-run → AskUserQuestion 앱별 게이트 → execute → 재감사 검증
```

## 4. 스코프 규칙 (호출 위치 기반)

| 스킬 | 기본 스코프 | 근거 |
|---|---|---|
| fleet-scan | 항상 전역 (전체 app_id) | 플릿 조망이 존재 이유 |
| doctor | 항상 전역 | 점검 대상(env·settings.json·decay·정체성)이 머신/계정 레벨 |
| cleanup (+검증용 audit) | **cwd의 프로젝트 app_id** — upstream 해석 체인 미러: `MEM0_PROJECT_ID` env → `~/.mem0/project_map.json[$PWD]` → git remote slug(owner-repo) → basename fallback | 프로젝트에서 부르면 그 프로젝트, `--app <id>`로 임의 앱, `--fleet`으로 전 앱 순회 트리아지 |

basename fallback으로 해석된 경우(map에 없고 git remote도 없음) 경고 출력: "unmapped 디렉토리 — 이 스코프가 쓰레기 app_id의 생성 경로다. 프로젝트 루트에서 실행하거나 --app 지정".

## 5. doctor 점검 항목

- `MEM0_RERANK` env (미설정 = rerank on = mem0 공식 Best Practice 위반)
- `~/.mem0/settings.json` `auto_save` — **env가 아니라 이 파일이 지배**(upstream `_identity.sh`가 매 훅마다 덮어씀) 함정 경고 포함
- `project.get(fields=["decay"])` REST 호출로 decay 상태
- upstream 캐시 `hooks/hooks.json`의 UserPromptSubmit timeout 8s 예산 경고(존재 시)
- entities 기반 user_id/app_id 파편화 요약

## 6. cleanup 안전 계약

- 삭제 전 대상 앱 전문 JSON 백업 필수: `~/.mem0/backups/<app>-<YYYY-MM-DD>.json`
- `--dry-run` 기본값 — 대상 카운트·샘플만 출력, `--execute`에서만 DELETE
- 타입 스코프 삭제(`--type session_summary`) 또는 앱 전체(`--all`, 쓰레기 app_id용)
- 5xx retry/backoff(2^i, 3회), 부분 실패 리포트, idempotent(이미 삭제된 ID 무시)
- 복원 절차 문서화: 백업 JSON → `add_memory infer=False` 재주입
- 스킬 레이어: 실행 전 앱별 AskUserQuestion 게이트, 실행 후 audit.py 재실행으로 검증

## 7. 경계 (upstream과 역할 분리)

- upstream mem0 플러그인 = 프로젝트 내부 품질(health/reviewer/dream). mem0-ops = **플릿 레벨(app_id 간)** 전용. 기능 복제 금지.
- upstream 스크립트/venv 의존 금지. REST v1/v2 + stdlib만: `POST /v2/memories/`(list), `DELETE /v1/memories/{id}/`, `GET /v1/entities/` (전부 2026-07-07 세션에서 실검증).
- `MEM0_API_KEY` 부재 시 graceful stop(설치 안내만).
- 회색지대 판단(오태깅 개별 판정, 병합 canonical 선택)은 스크립트가 후보 플래그만 하고 스킬(LLM)이 게이트에서 처리.

## 8. 버전·매니페스트 fan-out (plugin-versioning.md 계약)

- `plugins/mem0-ops/.claude-plugin/plugin.json` 0.1.0 + `marketplace.json` 엔트리 + `metadata.version` 1.83.0 → 1.84.0 (머지 직전 origin/main 재확인)
- 카운트: 총 23 → 24 (`CLAUDE.md` `## Plugins (24)` + 구조 트리, README 문장·배지·상세), Codex eligible 21 → 22 (CLAUDE.md Codex 섹션 + README + **AGENTS.md 미러 2곳**: Hermes-allowlist 카운트는 불변, Codex 검증 코멘트 `# N entries`)
- `.claude/settings.json` `plugins.local`에 `./plugins/mem0-ops` 등록
- `node scripts/sync-codex-manifests.mjs` + `sync-hermes-manifests.mjs` 재생성 (Hermes는 allowlist 밖이라 adapter 미생성 확인)
- 스킬 description: 1024자 미만 + colon-space 시 쿼팅 (Codex silent-skip 가드)

## 9. 구현 순서

1. spec 확정(이 문서) → `spec-state:state-tracker` init
2. `superpowers:writing-plans` → 단일 GitHub issue → `github-dev:resolve-issue` (같은 모듈이므로 1 PR, cr-fix loop on)
3. 구현: scripts 4종 이식·일반화 → SKILL.md 3종 → 매니페스트 fan-out → 검증

## 10. 검증

- 각 스크립트 단독 실행: `fleet_scan.py`(read-only 라이브), `audit.py <app>`(live), `cleanup.py --dry-run`(no-op 확인), `doctor.py`(현 설정에서 rerank off·auto_save false·decay true 정확 보고)
- cleanup 실검증은 쓰레기 app_id 1개(`tmp`, 57건 100% 노이즈)로: dry-run → execute → audit 재실행 0건 확인(백업 생성 확인 포함)
- `--check` 두 생성기 + `python3 -m py_compile` 4종
- 이 세션의 793건 삭제 실적이 원형 검증이며, 이식 후 `tmp` 앱 실행이 회귀 확인
