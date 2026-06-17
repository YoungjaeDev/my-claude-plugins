# Tally API — 블록 · 테마 · 게시 (실측 검증)

`build_tally_form.py` 실측 + Tally 공식 OpenAPI(`developers.tally.so`)로 확인한 규칙. 추측 아님.

## 생성 vs 게시 (가장 중요)

| 작업 | 메서드 · 엔드포인트 | 바디 |
|------|----------------------|------|
| 생성 | `POST /forms` | `{status, blocks, settings}` |
| 갱신·게시 | `PATCH /forms/{id}` | `{status:"PUBLISHED", blocks, settings}` |

- 게시·갱신은 반드시 **`PATCH /forms/{id}`** 에 `status:"PUBLISHED"` 를 포함해야 한다. 공유 URL(`/r/{id}`)은 유지된다.
- **함정**: `PATCH /forms/{id}/blocks` 만 호출하면 draft 상태로 남아 **공유 URL 에 반영되지 않는다**.
- 확인: `GET /forms/{id}` → `status == "PUBLISHED"`, `hasDraftBlocks == false`.

## 블록 구조

블록 배열은 평면 리스트. 각 블록 = `{uuid, type, groupUuid, groupType, payload}`.

| 논리 요소 | block `type` | `groupType` | 비고 |
|-----------|--------------|-------------|------|
| 폼 제목 | `FORM_TITLE` | `TEXT` | 자기 `groupUuid`; payload 에 `logo`/`cover` URL 옵션 |
| 인트로/설명 | `TEXT` | `TEXT` | `payload.html`, 문단당 1블록 |
| 이미지(본문) | `IMAGE` | `IMAGE` | `payload.images:[{name,url}]` 1장 + caption/link |
| 구분선 | `DIVIDER` | `DIVIDER` | `payload {}`, 섹션 사이 시각 분리 |
| 섹션 제목 | `HEADING_2` | `HEADING_2` | `payload.html` |
| 문항 제목 | `TITLE` | `QUESTION` | 모든 문항 공통, 자기 `groupUuid` |
| 문항 보조줄(desc) | `TEXT` | `TEXT` | 제목 직후 배치, `payload.html` (문항 개행/도움말) |
| 객관식 옵션(단일) | `MULTIPLE_CHOICE_OPTION` | `MULTIPLE_CHOICE` | 옵션들이 한 `groupUuid` 공유 |
| 복수선택 옵션 | `CHECKBOX` | `CHECKBOXES` | 체크박스(여러 개 선택), 한 `groupUuid` 공유 (실측) |
| 서술 입력 | `TEXTAREA` | `TEXTAREA` | 자기 `groupUuid` |
| 단답 입력 | `INPUT_TEXT`·`INPUT_NUMBER`·`INPUT_EMAIL`·`INPUT_PHONE_NUMBER`·`INPUT_LINK` | =`type` | 자기 `groupUuid`, `payload {isRequired, placeholder?}` |
| 날짜 입력 | `INPUT_DATE` | `INPUT_DATE` | 자기 `groupUuid` |
| 시간 입력 | `INPUT_TIME` | `INPUT_TIME` | 자기 `groupUuid` |
| 매트릭스(그리드) | `MATRIX` | `QUESTION` | 행·열의 부모 컨테이너 |
| 매트릭스 행 | `MATRIX_ROW` | `MATRIX` | `groupUuid` = MATRIX 블록 uuid |
| 매트릭스 열 | `MATRIX_COLUMN` | `MATRIX` | `groupUuid` = MATRIX 블록 uuid |

- **TITLE 은 자기 `groupUuid`** 를 갖는다 (옵션/입력 블록과 다른 group).
- 객관식 한 문항 = `TITLE` 1개 + `MULTIPLE_CHOICE_OPTION` N개. 옵션들은 같은 `groupUuid`(`og`)를 공유.
- 옵션 payload = `{text, index, isFirst, isLast, isRequired}`. `isFirst = (index==0)`, `isLast = (index==N-1)`.
- 서술/날짜/시간 한 문항 = `TITLE` 1개 + 입력 블록 1개 (각각 자기 group).

### groupType 규약 주의 (실측 vs OpenAPI)

Tally OpenAPI 스키마는 입력 계열 블록(`TEXTAREA`/`INPUT_*`)의 `groupType` 을 일괄 `QUESTION` 으로 적지만, **실측·공식 예제는 `groupType == type`(예: `INPUT_EMAIL`→`INPUT_EMAIL`) 로 동작**한다. 이 빌더는 검증된 `groupType == type` 규약을 따른다(`TEXTAREA`/`INPUT_DATE`/`INPUT_TIME`). `MATRIX` 컨테이너만 예외로 `groupType == QUESTION`(`MatrixPayload` 에 라벨 필드가 없어 컨테이너로 분류됨). 라이브 생성으로 `FORM_TITLE`→`TEXT`, `INPUT_DATE`/`INPUT_TIME`→자기 type, `MATRIX`→`QUESTION` 모두 `status:PUBLISHED, hasDraftBlocks:false` 로 확인됨.

## 문항별 보기 · 필수 · 복수선택 · 단답 (%%choice / 단답 directive)

전역 `options` 1세트를 공유하는 `## `+`- [ ]` 객관식과 별개로, 문항마다 다른 보기·필수·복수선택·단답을 directive 로 둔다(전역 경로는 비파괴 유지).

### `%%choice … %%` — 문항별 객관식/복수선택

```markdown
%%choice
title: 관심 분야 (복수 선택)
options: 브랜딩, 웹사이트, 마케팅, 기타   # CSV, 이 문항 전용 보기 (전역 options override)
select: multi             # single → MULTIPLE_CHOICE(기본) | multi → CHECKBOX
required: true            # 기본 false
desc: 해당 항목 모두 선택   # (선택) 제목 아래 보조 줄(TEXT) = 문항 개행
%%
```

- 블록: `TITLE`(QUESTION) + (`desc` 있으면 `TEXT` 1) + 보기 N개. `select:single` → `MULTIPLE_CHOICE_OPTION`/`MULTIPLE_CHOICE`, `select:multi` → `CHECKBOX`/`CHECKBOXES`.
- directive 문항은 matrix/date/time 처럼 **자동 번호 미부여**(제목 그대로). 전역 `## `+`- [ ]` 만 `{n}.` 번호 유지.

### 단답 directive — `%%text`/`%%number`/`%%email`/`%%phone`/`%%link`

```markdown
%%text  label: 이름 (required) (placeholder: 홍길동)
%%email label: 이메일 (required)
%%phone label: 연락처 (desc: 010-0000-0000 형식)
%%number label: 인원수
%%link  label: 포트폴리오 URL
```

- 키워드→block_type: `text→INPUT_TEXT, number→INPUT_NUMBER, email→INPUT_EMAIL, phone→INPUT_PHONE_NUMBER, link→INPUT_LINK`.
- 블록: `TITLE`(QUESTION) + (`desc` 있으면 `TEXT` 1) + 입력 1. tail 문법은 `%%date`/`%%time` 와 동형 — `label:` + bare `(required)` + `(placeholder: …)` + `(desc: …)`.

### required / desc 위치 (실측 확정)

- **required** 는 **답변 블록 payload** 에 실린다 — `%%choice` 는 각 옵션(`MULTIPLE_CHOICE_OPTION`/`CHECKBOX`) `payload.isRequired`, 단답은 입력 블록 `payload.isRequired`. 기존 MC/matrix 패턴과 동일 위치(라이브에서 `isRequired:true` persist 확인).
- **desc** 는 `TEXT`(groupType TEXT) 블록으로 **제목 직후·답변 직전** 에 둔다. `payload.html` 로 보내면 Tally 가 `safeHTMLSchema` 로 저장(round-trip) — `<br>` 비의존.

> 실측 2026-06-17: `%%choice`(single+multi/CHECKBOX, required, desc) + 단답 5종(text/number/email/phone/link, required/placeholder/desc) + 전역 `- [ ]` 1섹션을 한 폼에 POST → 32블록 `status:PUBLISHED, hasDraftBlocks:false`; GET 으로 CHECKBOX/CHECKBOXES·option/input `isRequired:true`·desc TEXT(safeHTMLSchema) round-trip 확인 후 폼 DELETE.

## 매트릭스 (일정 조율 그리드)

행×열 그리드 한 문항 = `TITLE` 1 + `MATRIX` 1 + `MATRIX_ROW` ×N + `MATRIX_COLUMN` ×M.

- `MATRIX` 블록: `uuid == groupUuid`(= `mg`), `groupType QUESTION`, `payload {isRequired}` (+ 단일 선택이면 `hasMaxChoices/maxChoices`, 아래).
- `MATRIX_ROW`/`MATRIX_COLUMN`: `groupUuid = mg`(부모 MATRIX uuid), `groupType MATRIX`.
- 행/열 payload = `{index, isFirst, isLast, isRequired, text, html}`.
- **단일 선택**(행마다 열 1개): **`MATRIX` 블록 payload** 에 `hasMaxChoices:true, maxChoices:1`. **복수 선택**: 미설정.
  - **함정(실측)**: 같은 키를 `MATRIX_ROW` payload 에 넣으면 live API 가 `400 "payload.hasMaxChoices is not allowed"` 로 거부한다 — OpenAPI `MatrixRowPayload` 가 해당 키를 *나열*하지만 실제로는 행에서 허용 안 됨. 컨테이너(MATRIX) 레벨에 둔다.
- TITLE 은 자기 group 으로 매트릭스 앞에 둔다(검증된 객관식 `TITLE`+입력그룹 패턴 미러). 라이브 생성 검증 완료 — `/questions` 가 MATRIX 를 1문항으로 반환.

## 날짜 / 시간 입력

- `INPUT_DATE` payload = `{isRequired, placeholder?, format?}`. `format` enum = `MM/dd/yyyy | dd/MM/yyyy | yyyy/MM/dd`.
  - 현재 OpenAPI `InputDatePayload` 에 min-date 류(afterDate/dateRange) 단일 필드는 없다. 세밀한 날짜 제약은 v1 범위 밖.
- `INPUT_TIME` payload = `{isRequired, placeholder?}`.

## 이미지 & 리다이렉트 (라이브 검증)

Tally 는 미디어 업로드 엔드포인트가 없다(경로는 `/forms` 하나) — 이미지는 전부 **호스팅된 공개 URL 참조**. public GitHub repo 의 `assets/` + `raw.githubusercontent.com` 링크가 무인프라 호스트로 동작한다(실측). 빌더는 `owner/repo[@ref]:path` 숏핸드를 raw URL 로 변환하고, 전체 `https://` URL 은 그대로 쓴다.

- **로고 / 커버**: `FORM_TITLE.payload` 에 `logo`(원형, 200x200 권장) / `cover`(전폭, 1500px+) URL. 둘 다 `format: uri`.
- **본문 이미지**: `IMAGE` 블록 = `{type:IMAGE, groupType:IMAGE, payload:{images:[{name,url}], hasCaption?, caption?, hasLink?, link?}}`. `images` 는 정확히 1장.
- **GIF**: `.gif` URL 도 그대로 들어간다(라이브 POST 통과 확인). 애니메이션 렌더 여부는 Tally 프론트 동작이라 폼 열어 육안 확인.
- **제출 후 리다이렉트**: `settings.redirectOnCompletion = {html:<url>, mentions:[]}` (무료). 화면에 뜨는 thank-you 문구 커스터마이즈는 create API 에 필드가 없다(에디터 전용).

> 실측 2026-06-17: logo(png)+cover(animated gif)+IMAGE(png)+redirect 한 폼이 `status:PUBLISHED, hasDraftBlocks:false` 로 생성됨.

## 테마

`settings.styles` 로 지정:

```json
{
  "theme": "CUSTOM",
  "color": {
    "background": "#FFFFFF",
    "text": "#18181B",
    "accent": "#52525B",
    "buttonBackground": "#18181B",
    "buttonText": "#FFFFFF"
  },
  "direction": "ltr"
}
```

- **`--theme neutral`(기본)** = 클린 모노크롬 잉크-온-화이트(슬롭 팔레트 회피). **`--theme hermes`** = 웜 오프화이트 / 잉크 / 틸 액센트 / 골드 CTA 프리셋.
- `--theme none` → `settings.styles` 생략(Tally 기본 테마). `--theme <path.json>` → 해당 JSON 을 `styles` 로 사용. frontmatter `theme:` 의 파일 경로는 워크스페이스 밖을 못 읽게 confine 됨.
- 커스텀 CSS·폰트는 Tally 유료 — 범위 밖.

## 인증 · 환경

- urllib 호출에 **브라우저 User-Agent 헤더 필수**. 없으면 Cloudflare 가 403 (코드 1010) 반환.
  - 사용 UA: `Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36`
- API 키 = env `TALLY_API_KEY` → 없으면 repo `.env`(`TALLY_API_KEY=...`) 자동 탐색(CWD 부터 상위로). `.env` 는 gitignore — **키 노출·출력 금지**.
- 표준 라이브러리만 사용(urllib) — 추가 의존성 없음. `uv run` 으로 그대로 실행.

## 블록 카운트 (파싱 검증용)

```text
total = 1(제목)
      + 인트로 문단 수
      + ## 섹션 수
      + max(0, heading 있는 섹션 수 - 1)  # dividers on 일 때 섹션 사이 구분선
      + 객관식 항목 수 × (1 + 옵션 수)
      + 서술 항목 수 × 2
      + 날짜 항목 수 × 2
      + 시간 항목 수 × 2
      + 이미지(%%image) 항목 수
      + Σ 매트릭스 (2 + 행 수 + 열 수)
      + Σ %%choice (1 + (desc?1:0) + 옵션 수)
      + Σ 단답 directive (1 + 1 + (desc?1:0))
```

`logo`/`cover`(FORM_TITLE payload)와 `redirect`(settings)는 블록을 추가하지 않는다.

예(번들 `assets/example-matrix-schedule.md` 류): 제목 1 + 인트로 1 + 섹션 1 + 구분선 0 + 매트릭스(2+5+3) + 날짜 1×2 + 시간 1×2 = **17 블록**. `--dry-run` 출력의 `built payload: N blocks` 와 분해 항목 합이 일치해야 한다(회귀 게이트).
