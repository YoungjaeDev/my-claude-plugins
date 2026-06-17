---
name: tally-form
description: "Build a Tally questionnaire/survey form from a checklist markdown — parse the md, run a copy-voice + humanize pass, build blocks with theme presets, section dividers and paragraph-split intros, plus native scheduling (matrix grid, date, time), then create or idempotently publish via the Tally API and return the share URL. Reusable per project or client. Use when the user wants to '설문 폼 만들어', 'Tally 폼 만들어', 'questionnaire', '체크리스트를 폼으로', '상담 신청 폼', '일정 조율 설문', 'dev survey form', or 'lecture consultation form'."
argument-hint: "--md <checklist.md> [--update <formId>] [--theme neutral|hermes|none|<styles.json>] [--no-dividers] [--no-humanize]"
allowed-tools: Bash(uv run *) Bash(curl *) Read AskUserQuestion
---

# Tally Form

체크리스트 markdown 을 Tally 설문 폼으로 빌드해 생성/게시하고 공유 URL 을 돌려준다. 개발 인테이크·강의 상담 등 매 프로젝트/클라이언트마다 재사용. 결정적·무의존성(stdlib-only urllib)·idempotent 빌더다.

- 검증된 블록·테마·게시 규칙 + Matrix/DIVIDER/INPUT_DATE/INPUT_TIME 스키마: `references/tally-blocks.md`
- 제네릭 카피 톤: `references/form-copy-style.md`
- 도메인 보이스 프리셋: `references/preset-dev-survey.md`, `references/preset-lecture-consultation.md`
- 템플릿 레퍼런스 인덱스: `references/tally-templates.md`
- 바로 빌드 가능한 예시 md: `assets/example-{dev-survey,lecture-consultation,matrix-schedule}.md`

## 워크플로우

1. **입력 확인** — `--md <checklist.md>`(기본) 또는 `--json <spec.json>`. 기존 폼 갱신이면 `--update <formId>` 또는 frontmatter `form_id`. 새 폼이면 도메인에 맞는 프리셋(`preset-*.md`)으로 보이스·옵션·섹션 골격을 잡고, 필요하면 `assets/example-*.md` 를 복사·편집해 시작한다.
2. **카피 보이스 + humanize 패스** (md 작성·수정 시) — `references/form-copy-style.md` 적용 후, 기본적으로 한글 카피를 `/humanize-korean:humanize-korean`(fast)에 윤문 위임. 상세 라우팅은 아래 "humanize 기본 라우팅".
3. **빌드 + 미리보기** — `--dry-run` 으로 블록 수 먼저 확인(파싱 검증). 출력 `built payload: N blocks (...)` 의 분해 항목 합 = N 이어야 한다(`references/tally-blocks.md` 카운트 공식과 일치).
4. **생성/게시** — 키가 있으면 `--update` 없을 때 POST 생성, 있으면 PATCH 게시(공유 URL 유지).
5. **결과 반환** — EDIT/SHARE URL 출력. 게시 후 `GET /forms/{id}` 로 `status=PUBLISHED`·`hasDraftBlocks=false` 확인 권장.

## 실행

`uv run <abs>/scripts/build_tally_form.py` — `<abs>` 는 Claude Code 에서 `plugins/tally-form/skills/tally-form`(repo 루트 기준), Codex 에서 `~/.agents/skills/tally-form`(sync 후). 절대 경로로 cwd 의존 회피. stdlib-only 라 `uv run` 이 에페메랄 환경으로 그대로 실행(별도 `python` 호출 불필요).

```bash
# 미리보기 (API 호출 없음 — 블록 수 검증)
uv run plugins/tally-form/skills/tally-form/scripts/build_tally_form.py --md <checklist.md> --dry-run

# 신규 생성
uv run plugins/tally-form/skills/tally-form/scripts/build_tally_form.py --md <checklist.md>

# 기존 폼 갱신·게시 (공유 URL 유지, idempotent)
uv run plugins/tally-form/skills/tally-form/scripts/build_tally_form.py --md <checklist.md> --update <formId>

# Codex (sync 후)
uv run ~/.agents/skills/tally-form/scripts/build_tally_form.py --md <checklist.md> --dry-run
```

- `--theme neutral`(기본) | `hermes` | `none`(Tally 기본 테마) | `<styles.json>`(커스텀 `settings.styles`).
- `--dividers`/`--no-dividers` — 섹션 사이 구분선(기본 on). `--no-humanize` — humanize 패스 skip(아래 참조).
- `--out <path>` — payload 사이드카 위치(기본: 입력 옆 `<name>_tally_payload.json`).

## 프리셋 / 테마

- **테마 프리셋** — `neutral`(기본, 클린 모노크롬) / `hermes`(웜 오프화이트 브랜드). 커스텀은 `<styles.json>`.
- **도메인 프리셋** — 새 폼의 보이스·기본 옵션·섹션 골격: `preset-dev-survey.md`(개발/프로젝트 인테이크), `preset-lecture-consultation.md`(강의/코칭 상담). 프리셋만으론 빌드 불가(이 스킬은 입력 md 기반) — `assets/example-*.md` 를 시작점으로 편집한다.
- 모든 `## ` 객관식 문항은 frontmatter `options` 하나를 공유한다. 다른 척도가 필요한 문항은 서술(`### ` + `- 라벨: ___`)이나 매트릭스로 둔다.

## 가독성

- **문단 분리** — 인트로(제목 직후 첫 blockquote run)는 빈 `>` 줄로 문단을 나누면 문단당 별도 TEXT 블록으로 렌더. `<br>` 비의존.
- **섹션 구분선** — `## 섹션` 사이에 DIVIDER 블록 자동 삽입(기본 on, 첫 섹션 앞에는 없음). frontmatter `dividers: false` 또는 `--no-dividers` 로 끔.

## 일정 조율 (matrix / date / time)

외부 스케줄러 임베드 대신 네이티브 블록으로 처리(외부 스케줄러는 oEmbed 비대상 → 링크아웃만). 1:1 상담 수준(Lv1).

```markdown
## 가능한 상담 시간
%%matrix
rows: 월요일, 화요일, 수요일, 목요일, 금요일
cols: 오전, 오후, 저녁
select: single        # single(행마다 1개) | multi(여러 개)
%%
%%date label: 희망 상담일 (format: yyyy/MM/dd)
%%time label: 희망 시간
```

- `%%matrix … %%` → MATRIX 그리드 한 문항. `%%date`/`%%time` → INPUT_DATE/INPUT_TIME 한 문항.
- `select: single` 은 행마다 열 1개로 제한. `format` enum = `MM/dd/yyyy | dd/MM/yyyy | yyyy/MM/dd`. 세밀한 날짜 제약(min-date)은 현재 Tally 스키마에 단일 필드가 없어 v1 범위 밖.

## humanize 기본 라우팅

- **카피를 새로 쓰거나 수정할 때**: 기본적으로 한글 카피를 `/humanize-korean:humanize-korean`(fast)에 윤문 위임 후 빌드.
- **`--update` 재빌드**(문구 변화 없이 게시만): humanize skip.
- **`--no-humanize`**: 명시적 escape(스크립트 패스스루 플래그 — 윤문 호출 자체를 main 세션에서 생략). 스크립트는 윤문을 호출하지 않는다.
- **`humanize-korean` 미설치**: graceful degrade — `form-copy-style.md` 규칙만 수동 적용하고 계속 진행.

## 키 처리

- API 키 = env `TALLY_API_KEY` → 없으면 repo `.env`(`TALLY_API_KEY=...`) 자동 탐색(CWD 부터 상위로).
- `.env` 는 gitignore. **키를 출력·로그·커밋하지 않는다.**
- 키가 없으면 스크립트는 payload 만 만들고 `NO_KEY` 출력(안전).

## 게시 & idempotent 갱신 (중요)

- 게시 = `PATCH /forms/{id}` 에 `status:"PUBLISHED"` 포함. `/forms/{id}/blocks` 만 PATCH 하면 draft 잔류 → 공유 URL 미반영. (`references/tally-blocks.md`.)
- `--update <formId>` 는 같은 md 로 여러 번 돌려도 같은 폼을 덮어쓰므로 안전(idempotent). 공유 URL 불변.

## 체크리스트 md 규약

```markdown
---
options:                 # (선택) 기본 = 네, 해주세요 / 나중에 / 설명 듣고 정할게요
  - 네, 해주세요
  - 나중에
  - 설명 듣고 정할게요
theme: neutral           # (선택) neutral(기본) | hermes | none | <styles.json>
dividers: true           # (선택) 섹션 구분선, 기본 on
form_id: vGWGr0          # (선택) 기존 폼 갱신 대상 (= --update)
---
# 폼 제목                  → FORM_TITLE
> 인트로 문단 1            → 인트로 TEXT (제목 직후 첫 blockquote run)
>
> 인트로 문단 2            → 빈 `>` 줄로 분리 시 별도 TEXT 블록

## 섹션 제목              → HEADING_2 (이하 - [ ] 항목은 객관식)
- [ ] 항목 (예: …)        → 객관식 문항 (전역 번호 자동, 공유 options)

### 자유 의견             → HEADING_2 (이하 - 라벨: ___ 은 서술)
- 라벨: ___               → 서술(TEXTAREA) 문항 (번호 없음)

%%matrix / %%date / %%time → 위 "일정 조율" 참조
```

- frontmatter 가 본문보다 우선(`title`/`intro` 도 override 가능). CLI `--theme`/`--update`/`--dividers` 는 frontmatter 보다 우선.
- 제목 직후 첫 blockquote run 만 인트로. 이후 빈 줄로 끊긴 별도 blockquote(옵션 안내·공유 URL·내부 메모)는 무시.

## 템플릿 레퍼런스

새 폼 구조를 잡을 때 `references/tally-templates.md` 의 6종 공식 Tally 템플릿(인테이크·수강신청·코칭·온보딩) URL·구조 메모 참고. 임포트는 안 하고 패턴만 참고한다.

## 대안: 공식 Tally MCP (채택 X)

대화형 편집이 필요하면 공식 Tally MCP(`claude mcp add tally --transport http https://api.tally.so/mcp`, beta)도 있으나 이 스킬은 채택하지 않는다 — 결정성·idempotent·무의존성 보존을 위해 urllib 빌더를 유지.

## 범위 밖

- 폼 이미지/cover/logo/IMAGE(URL 참조 + 호스팅 갭) — 후속.
- 제출(submission) 수신·집계, 전원-겹침 히트맵(when2meet Lv2+) — 1:1 상담 범위 밖.
- 커스텀 CSS·폰트(Tally 유료).
