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
| 폼 제목 | `FORM_TITLE` | `TEXT` | 자기 `groupUuid` (입력 블록과 분리) |
| 인트로/설명 | `TEXT` | `TEXT` | `payload.html`, 문단당 1블록 |
| 구분선 | `DIVIDER` | `DIVIDER` | `payload {}`, 섹션 사이 시각 분리 |
| 섹션 제목 | `HEADING_2` | `HEADING_2` | `payload.html` |
| 문항 제목 | `TITLE` | `QUESTION` | 모든 문항 공통, 자기 `groupUuid` |
| 객관식 옵션 | `MULTIPLE_CHOICE_OPTION` | `MULTIPLE_CHOICE` | 옵션들이 한 `groupUuid` 공유 |
| 서술 입력 | `TEXTAREA` | `TEXTAREA` | 자기 `groupUuid` |
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

Tally OpenAPI 스키마는 입력 계열 블록(`TEXTAREA`/`INPUT_*`)의 `groupType` 을 일괄 `QUESTION` 으로 적지만, **실측·공식 예제는 `groupType == type`(예: `INPUT_EMAIL`→`INPUT_EMAIL`) 로 동작**한다. 이 빌더는 검증된 `groupType == type` 규약을 따른다(`TEXTAREA`/`INPUT_DATE`/`INPUT_TIME`). `MATRIX` 컨테이너만 예외로 `groupType == QUESTION`(`MatrixPayload` 에 라벨 필드가 없어 컨테이너로 분류됨).

## 매트릭스 (일정 조율 그리드)

행×열 그리드 한 문항 = `TITLE` 1 + `MATRIX` 1 + `MATRIX_ROW` ×N + `MATRIX_COLUMN` ×M.

- `MATRIX` 블록: `uuid == groupUuid`(= `mg`), `groupType QUESTION`, `payload {isRequired}`.
- `MATRIX_ROW`/`MATRIX_COLUMN`: `groupUuid = mg`(부모 MATRIX uuid), `groupType MATRIX`.
- 행/열 payload = `{index, isFirst, isLast, isRequired, text, html}`.
- **단일 선택**(행마다 열 1개): 행 payload 에 `hasMaxChoices:true, maxChoices:1`. **복수 선택**: 미설정.
- TITLE 은 자기 group 으로 매트릭스 앞에 둔다(검증된 객관식 `TITLE`+입력그룹 패턴 미러). 라이브 렌더로 최종 확인 권장.

## 날짜 / 시간 입력

- `INPUT_DATE` payload = `{isRequired, placeholder?, format?}`. `format` enum = `MM/dd/yyyy | dd/MM/yyyy | yyyy/MM/dd`.
  - 현재 OpenAPI `InputDatePayload` 에 min-date 류(afterDate/dateRange) 단일 필드는 없다. 세밀한 날짜 제약은 v1 범위 밖.
- `INPUT_TIME` payload = `{isRequired, placeholder?}`.

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
      + Σ 매트릭스 (2 + 행 수 + 열 수)
```

예(번들 `assets/example-matrix-schedule.md` 류): 제목 1 + 인트로 1 + 섹션 1 + 구분선 0 + 매트릭스(2+5+3) + 날짜 1×2 + 시간 1×2 = **17 블록**. `--dry-run` 출력의 `built payload: N blocks` 와 분해 항목 합이 일치해야 한다(회귀 게이트).
