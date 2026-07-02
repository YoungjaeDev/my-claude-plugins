# ppt-yeong-style 완료 게이트 + 문서 구조 리팩토링 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ppt-yeong-style 스킬 패키지에 (a) mode 선택·목차 작성 시점의 원인 단계 개선, (b) 품질 게이트 3종(anti-slop 감사·윤문·스토리 흐름)을 스킵 못 하게 강제하는 완료 게이트 리포트, (c) 이미지 기본값 이탈 사유 명시, (d) 문서 자체의 목차·번호·언어 일관성을 반영한다.

**Architecture:** `SKILL.md` + 5개 reference 파일(`ppt-master-craft.md`, `ppt-master-and-qa.md`, `images-and-pop.md`, `color-typography.md`, `design-language.md`)에 대한 순수 텍스트(마크다운) 편집. 새 파일 생성 없음, 코드 없음. 각 task는 논리적으로 응집된 변경 단위(파일 1~2개)를 편집하고, grep/yaml-parse 기반으로 검증한 뒤 커밋한다. 자동 테스트 스위트가 없는 문서 전용 프로젝트라 "테스트"는 매 task 정확히 재현 가능한 shell 검증 명령으로 대체한다.

**Tech Stack:** Markdown, Python3(YAML 파싱 확인), Node.js(기존 manifest sync-check 스크립트).

## Global Constraints

- 문서(md) 전용 변경 — 새 파일 생성 없음, 코드 없음.
- 이미 정확히 참조되고 있는 §4·§3b 번호는 변경 금지 — 참조 없는 §3c만 §3d로 재배치(근거: `grep -rn '§3c\|§3b\|§4' plugins/ppt-yeong-style/`로 확인됨, 스펙 §2.4 참고).
- `SKILL.md` 편집 후 매번 YAML frontmatter 파싱 확인(과거 콜론-스페이스 이슈 재발 방지).
- `design-language.md` 번역은 의미·6축·anti-slop↔high-end 표 7행·레버 락 7개 항목을 전부 보존.
- 각 task는 별도 커밋 — 성격이 다른 변경을 한 커밋에 섞지 않는다(surgical diff).
- 마지막 task에서 `node scripts/sync-codex-manifests.mjs --check` / `node scripts/sync-hermes-manifests.mjs --check` 통과 확인.
- 실행 환경: `superpowers:using-git-worktrees`로 격리된 워크스페이스에서 진행(사용자 지정). 이슈는 1개로 관리(sub-issue 분해 없음) — `github-dev:decompose-issue` 실행 시 이 계획 전체를 단일 이슈로 생성.

---

### Task 1: `SKILL.md` 구조 리팩토링 — 목차·참조 파일 지도·무번호 섹션 라벨링 + `color-typography.md` 번호 정정

**Files:**
- Modify: `plugins/ppt-yeong-style/skills/ppt-yeong-style/SKILL.md` (frontmatter 이후 전체 헤딩 구조)
- Modify: `plugins/ppt-yeong-style/skills/ppt-yeong-style/references/color-typography.md:1,3`

**Interfaces:**
- Consumes: 현재 `SKILL.md`의 헤딩 순서(§0 → 엔진·의존(무번호) → 언제쓰나(무번호) → §1 → §2 → §3 → §3b → 색·이미지·로고(무번호) → §3c → §4 → 다른세션주입(무번호)).
- Produces: 이후 모든 task가 참조할 최종 라벨 — §0b(엔진·의존), §0c(언제쓰나), §3c(색·이미지·로고), §3d(구 §3c 스크린샷), 부록 A(다른세션주입). Task 4는 이 섹션들의 라벨을 바꾸지 않으므로 순서 의존 없음(단, 먼저 실행해 혼선 방지).

- [ ] **Step 1: `SKILL.md`에 목차 + 참조 파일 지도 삽입**

`SKILL.md`에서 아래 old_string(“Hermes Agent Compatibility” 섹션의 마지막 줄과 본문 시작 사이)을 찾아 교체한다:

old_string:
```
Treat `$ARGUMENTS` as the natural-language arguments supplied when the user asks Hermes to load the skill. Plugin-provided skills are explicit opt-in loads in Hermes; use `skill_view("ppt-yeong-style:ppt-yeong-style")` (or ask Hermes to load that qualified skill) rather than relying on bare text.

**Hermes 전제**: 이 스킬은 외부 `ppt-master` 플러그인의 빌드 엔진(`uv run` 스크립트)에 의존한다. Hermes 세션에서는 (1) `ppt-master` 플러그인이 enable 되어 있고 (2) `uv`가 설치되어 있어야 한다. 둘 중 하나라도 없으면 빌드 단계 진입 전에 중단하고 사용자에게 설치를 요청한다 (`skill_view("ppt-master:ppt-master")`로 엔진 스킬 로드 가능).

yeong이 **강의/실습/제안/학술 덱**을 만들 때 적용하는 작성 규약.
```

new_string:
```
Treat `$ARGUMENTS` as the natural-language arguments supplied when the user asks Hermes to load the skill. Plugin-provided skills are explicit opt-in loads in Hermes; use `skill_view("ppt-yeong-style:ppt-yeong-style")` (or ask Hermes to load that qualified skill) rather than relying on bare text.

**Hermes 전제**: 이 스킬은 외부 `ppt-master` 플러그인의 빌드 엔진(`uv run` 스크립트)에 의존한다. Hermes 세션에서는 (1) `ppt-master` 플러그인이 enable 되어 있고 (2) `uv`가 설치되어 있어야 한다. 둘 중 하나라도 없으면 빌드 단계 진입 전에 중단하고 사용자에게 설치를 요청한다 (`skill_view("ppt-master:ppt-master")`로 엔진 스킬 로드 가능).

## 목차

- §0. 미감 토대 (Aesthetic foundation)
- §0b. 엔진·의존 (cross-skill 관용구)
- §0c. 언제 쓰나 / 안 쓰나
- §1. 덱 유형과 파이프라인
- §2. md 소스 작성 규약
- §3. 발표 덱 작성 원칙 15종
- §3b. 밀도·리듬 (정량 프리셋 + 기본값)
- §3c. 색·이미지·로고 (핵심 1줄 + 포인터)
- §3d. 스크린샷 — 옆에 둘까, 위에 짚을까 (앱 UI 실물 전제)
- §4. ppt-master 깊이 활용 — 조합으로 차별화
- 부록 A. 다른 세션에 규칙 주입

## 참조 파일 지도

| 파일 | 담당 SKILL.md 섹션 | 자기 내부 §라벨 |
|---|---|---|
| `references/design-language.md` | §0 상세 | (무번호, 전체가 §0 상세) |
| `references/color-typography.md` | §3c 상세(색·타이포) | §3c 상세 |
| `references/images-and-pop.md` | §3c 상세(이미지) | §5·§5b |
| `references/icons-logos.md` | §3c 상세(로고) | §5c |
| `references/ppt-master-craft.md` | §4 상세 | §4 상세 |
| `references/ppt-master-and-qa.md` | §1 파이프라인 상세(7-step·윤문·완료 QA·스토리 흐름) | §6~§8c |

> 참조 파일들 자체의 §5·§5b·§5c·§6~§8c 번호는 이번 라운드에서 재편하지 않는다(리스크 대비 이득 작음, 스펙 §2.4/§4 참고) — 위 표가 SKILL.md 쪽과의 대응만 명시한다.

yeong이 **강의/실습/제안/학술 덱**을 만들 때 적용하는 작성 규약.
```

- [ ] **Step 2: 무번호 섹션에 라벨 부여 — "엔진·의존" → §0b**

old_string:
```
## 엔진·의존 (cross-skill 관용구)
```

new_string:
```
## §0b. 엔진·의존 (cross-skill 관용구)
```

- [ ] **Step 3: "언제 쓰나 / 안 쓰나" → §0c**

old_string:
```
## 언제 쓰나 / 안 쓰나
```

new_string:
```
## §0c. 언제 쓰나 / 안 쓰나
```

- [ ] **Step 4: "색·이미지·로고" → §3c, 기존 §3c(스크린샷) → §3d**

old_string:
```
## 색·이미지·로고 (핵심 1줄 + 포인터)
```

new_string:
```
## §3c. 색·이미지·로고 (핵심 1줄 + 포인터)
```

그다음 old_string:
```
## §3c. 스크린샷 — 옆에 둘까, 위에 짚을까 (앱 UI 실물 전제)
```

new_string:
```
## §3d. 스크린샷 — 옆에 둘까, 위에 짚을까 (앱 UI 실물 전제)
```

- [ ] **Step 5: "다른 세션에 규칙 주입" → 부록 A**

old_string:
```
## 다른 세션에 규칙 주입
```

new_string:
```
## 부록 A. 다른 세션에 규칙 주입
```

- [ ] **Step 6: `color-typography.md`의 잘못된 §번호 자칭 정정**

old_string:
```
# 색·타이포 (§4)

SKILL.md §3b·"색·이미지·로고" 1줄 요약의 상세본. 색 결정은 **deck-wide 1회 락**이 원칙 — 슬라이드별 색 날조는 slop의 1순위 신호다.
```

new_string:
```
# 색·타이포 (§3c 상세)

SKILL.md §3c "색·이미지·로고" 1줄 요약의 상세본. 색 결정은 **deck-wide 1회 락**이 원칙 — 슬라이드별 색 날조는 slop의 1순위 신호다.
```

(주의: 같은 파일 line 40의 "본문 바닥 20pt 유지(§3b 고정선)"은 §3b=밀도·리듬을 가리키는 **정확한** 크로스레퍼런스이므로 건드리지 않는다.)

- [ ] **Step 7: 검증 — 헤딩 시퀀스 확인**

Run:
```bash
grep -n "^## " plugins/ppt-yeong-style/skills/ppt-yeong-style/SKILL.md
```
Expected: `§0b`, `§0c`, `§3c`(색·이미지·로고), `§3d`(스크린샷), `부록 A` 순서로 새 라벨이 보이고, 기존 `§0`/`§1`/`§2`/`§3`/`§3b`/`§4`는 그대로.

- [ ] **Step 8: 검증 — YAML frontmatter 파싱**

Run:
```bash
python3 -c "
import re, yaml
content = open('plugins/ppt-yeong-style/skills/ppt-yeong-style/SKILL.md', encoding='utf-8').read()
m = re.match(r'^---\n(.*?)\n---\n', content, re.DOTALL)
yaml.safe_load(m.group(1))
print('frontmatter OK')
"
```
Expected: `frontmatter OK` (에러 없이).

- [ ] **Step 9: 검증 — 재배치된 §3c/§3d가 다른 곳에서 안 깨졌는지**

Run:
```bash
grep -rn '§3c\|§3d' plugins/ppt-yeong-style/
```
Expected: `SKILL.md`의 새 헤딩 2개(`§3c. 색·이미지·로고`, `§3d. 스크린샷`) + `color-typography.md`의 새 자기참조 2건(제목·본문)만 나오고, 다른 파일에 옛 의미의 "§3c=스크린샷"을 가리키는 참조가 없어야 한다(사전 조사에서 없음을 확인했으므로 회귀 확인 성격).

- [ ] **Step 10: Commit**

```bash
git add plugins/ppt-yeong-style/skills/ppt-yeong-style/SKILL.md \
        plugins/ppt-yeong-style/skills/ppt-yeong-style/references/color-typography.md
git commit -m "docs(ppt-yeong-style): add TOC + reference map, label unnumbered sections"
```

---

### Task 2: `SKILL.md` §2 — 목차(TOC) 슬라이드 작성 시점 규칙

**Files:**
- Modify: `plugins/ppt-yeong-style/skills/ppt-yeong-style/SKILL.md` (§2 섹션 말미)

**Interfaces:**
- Consumes: Task 1에서 확정된 §2 위치(라벨 자체는 안 바뀜).
- Produces: "TOC는 페이지 순서 확정 후 마지막에 작성" 규칙 — Task 4의 §8c/§8b(목차-실순서 일치 체크)가 이 규칙의 존재를 전제로 한다.

- [ ] **Step 1: TOC 작성 시점 규칙 추가**

old_string:
```
- 전역 규약(컨텍스트·톤·디자인 락·흐름 표·출처)은 단일 md면 **앞머리 블록**에, 섹션 분리면 별도 `deck_spec.md`에.

## §3. 발표 덱 작성 원칙 15종
```

new_string:
```
- 전역 규약(컨텍스트·톤·디자인 락·흐름 표·출처)은 단일 md면 **앞머리 블록**에, 섹션 분리면 별도 `deck_spec.md`에.
- **목차(TOC) 슬라이드는 마지막에 작성한다.** 다른 슬라이드와 같이 초안 단계에서 쓰지 않는다 — 전체 페이지 순서가 `spec_lock.md`에 확정된 뒤, 그 순서를 그대로 옮겨 적는다. 순서가 나중에 바뀌면 목차도 같이 갱신한다(재확인 없이 방치 금지 — `ppt-master-and-qa.md` §8b의 "목차-실제 순서 일치" 체크와 짝).

## §3. 발표 덱 작성 원칙 15종
```

- [ ] **Step 2: 검증 — 새 규칙이 §2 안에 들어갔는지, §3 헤딩 앞인지**

Run:
```bash
grep -n "목차(TOC) 슬라이드는 마지막" plugins/ppt-yeong-style/skills/ppt-yeong-style/SKILL.md
sed -n '90,96p' plugins/ppt-yeong-style/skills/ppt-yeong-style/SKILL.md
```
Expected: 새 불릿이 §2 블록 끝, §3 헤딩 바로 위에 위치.

- [ ] **Step 3: 검증 — YAML frontmatter 파싱 (재확인)**

Run: 동일한 Task 1 Step 8 명령.
Expected: `frontmatter OK`.

- [ ] **Step 4: Commit**

```bash
git add plugins/ppt-yeong-style/skills/ppt-yeong-style/SKILL.md
git commit -m "docs(ppt-yeong-style): require TOC authored after page order is locked"
```

---

### Task 3: `references/ppt-master-craft.md` — mode 레버에 pyramid/SCQA 트리거 추가

**Files:**
- Modify: `plugins/ppt-yeong-style/skills/ppt-yeong-style/references/ppt-master-craft.md:19`

**Interfaces:**
- Consumes: 없음(독립적인 테이블 셀 편집).
- Produces: 없음(다른 task가 이 트리거 문구를 참조하지 않음).

- [ ] **Step 1: mode 레버 행에 트리거 추가**

old_string:
```
| **mode(구조)** | Strategist 확인 d.Layer 1 — `pyramid`/`narrative`/`instructional`/`showcase`/`briefing` 중 자체 추천표로 선택, `spec_lock`에 `mode:` 기입 | 모든 덱 | 강의/실습 덱 → `instructional` 고정(ppt-master 자체 추천표와 일치, 판단 불필요). 제안 덱 → `narrative`/`pyramid` 중 인터뷰에서 판단(색 락과 동일 원칙 — 프로젝트마다 판단, 강제 고정 안 함) |
```

new_string:
```
| **mode(구조)** | Strategist 확인 d.Layer 1 — `pyramid`/`narrative`/`instructional`/`showcase`/`briefing` 중 자체 추천표로 선택, `spec_lock`에 `mode:` 기입 | 모든 덱 | 강의/실습 덱 → `instructional` 고정(ppt-master 자체 추천표와 일치, 판단 불필요). 제안 덱 → `narrative`/`pyramid` 중 인터뷰에서 판단(색 락과 동일 원칙 — 프로젝트마다 판단, 강제 고정 안 함). **콘텐츠가 여러 옵션을 비교해 1개로 확정하는 구조면 `pyramid` 우선**(SCQA 오프닝[Situation→Complication→Question→Answer]과 MECE 비교가 내장돼 있어 페이지 순서·비교 논리가 저절로 안정된다. ppt-master 자체 auto-selection표의 "Strategic decision/analysis/board/investor → pyramid"와 일치. 스토리가 서사 아치[기승전결]로 가는 제안이면 여전히 `narrative`) |
```

- [ ] **Step 2: 검증 — 마크다운 표 무결성**

Run:
```bash
awk -F'|' 'NR==19 {print NF}' plugins/ppt-yeong-style/skills/ppt-yeong-style/references/ppt-master-craft.md
```
Expected: 편집 전후 필드 개수(`|`로 구분된 열 수)가 동일해야 한다(표가 안 깨졌는지 — 편집 전 실제 값을 먼저 기록해두고 대조).

- [ ] **Step 3: Commit**

```bash
git add plugins/ppt-yeong-style/skills/ppt-yeong-style/references/ppt-master-craft.md
git commit -m "docs(ppt-yeong-style): add pyramid/SCQA trigger to the mode lever row"
```

---

### Task 4: `references/ppt-master-and-qa.md` §8b/§8c + `SKILL.md` §1 파이프라인 줄

**Files:**
- Modify: `plugins/ppt-yeong-style/skills/ppt-yeong-style/references/ppt-master-and-qa.md:32-43`
- Modify: `plugins/ppt-yeong-style/skills/ppt-yeong-style/SKILL.md` (§1 파이프라인 코드블록)

**Interfaces:**
- Consumes: Task 2가 만든 "TOC는 순서 확정 후 마지막 작성" 규칙(§8b의 "목차-실제 순서 일치" 체크가 이를 전제).
- Produces: `§8c. 완료 게이트 리포트` — 이후 이 스킬을 실제로 쓸 때 빌드 완료 선언의 필수 게이트가 됨(다른 task가 참조하지 않음, 사용 시점 검증만).

- [ ] **Step 1: §8b에 이름 붙은 체크 2개 추가**

old_string:
```
- **through-line**: 표지의 한 문장 약속이 끝까지 일관되게 증명되는가. 끊기거나 갑자기 튀는 장 없는가.
- **surface 일관성**(원칙 14): 명령·스크린샷이 한 주 surface(CLI/Desktop/웹)로 일관되는가. "데스크톱으로 시작"인데 CLI 명령이 섞이지 않는가.
- **용어 일관성**: 같은 개념을 다른 말로 부르지 않는가(예: 채팅 AI vs 에이전틱 AI 표현 통일).
- **개념 등장 순서·의존**: 뒤에서 쓰는 개념을 앞에서 정의했는가. 선후 역전 없는가.
- **고아·탈선 슬라이드**(원칙 15): 본 흐름과 무관한 곁가지·경쟁 도구가 본류에 끼지 않았는가.
- **사실 정확성**(원칙 4): 명령·UI·기능 주장이 공식 docs(Claude 런타임이면 `claude-code-guide` 에이전트도)와 맞는가. 미확인은 `unverified` 표기·재확인.

발견 시 → deck.md 소스 수정 후 해당 장만 재빌드. 이 review는 **렌더 QA 통과만으로 완료로 보지 않는다**(정렬은 맞아도 스토리가 끊기면 미완).
```

new_string:
```
- **through-line**: 표지의 한 문장 약속이 끝까지 일관되게 증명되는가. 끊기거나 갑자기 튀는 장 없는가.
- **표지 약속 범위-실제 빌드 범위 일치**: 표지가 약속한 범위(예: "A·B·C까지")가 실제 빌드된 페이지에 전부 있는가. 일부만 빌드했으면 표지 문구를 그 범위로 축소했는가.
- **surface 일관성**(원칙 14): 명령·스크린샷이 한 주 surface(CLI/Desktop/웹)로 일관되는가. "데스크톱으로 시작"인데 CLI 명령이 섞이지 않는가.
- **용어 일관성**: 같은 개념을 다른 말로 부르지 않는가(예: 채팅 AI vs 에이전틱 AI 표현 통일).
- **개념 등장 순서·의존**: 뒤에서 쓰는 개념을 앞에서 정의했는가. 선후 역전 없는가.
- **목차-실제 순서 일치**: 목차(TOC) 슬라이드가 나열한 순서가 실제 빌드된 페이지 순서와 정확히 같은가(§2의 "TOC는 마지막에 작성" 규칙이 지켜졌는지 확인).
- **고아·탈선 슬라이드**(원칙 15): 본 흐름과 무관한 곁가지·경쟁 도구가 본류에 끼지 않았는가.
- **사실 정확성**(원칙 4): 명령·UI·기능 주장이 공식 docs(Claude 런타임이면 `claude-code-guide` 에이전트도)와 맞는가. 미확인은 `unverified` 표기·재확인.

발견 시 → deck.md 소스 수정 후 해당 장만 재빌드. 이 review는 **렌더 QA 통과만으로 완료로 보지 않는다**(정렬은 맞아도 스토리가 끊기면 미완).

## §8c. 완료 게이트 리포트 (통합, MANDATORY)

빌드 완료를 사용자에게 보고하기 전, 아래 3개를 **실제로 실행하고 그 결과를 하나의 리포트로 출력**해야 완료 선언이 가능하다(내부적으로 판단만 하고 넘어가는 것 금지 — 규칙이 문서에 있어도 완료를 서두르면 스킵되는 게 반복된 실패 패턴이었다):

1. **anti-slop-design audit** — 설치돼 있으면 그 스킬의 감사를 실행한 결과(적발 항목 수·수정 여부)를 보고. 미설치 시 §3 원칙 15종 체크리스트로 수동 대체한 결과를 보고.
2. **humanize-korean 윤문** — 적용 여부와 적용 범위(fast/strict)를 보고. 미설치 시 §7 차단 목록 수동 체크 결과를 보고.
3. **§8b 스토리 흐름 체크리스트** — 위 8개 항목별 ✓/✗를 실제로 출력.

셋 중 하나라도 "미실행"이거나 ✗가 있으면 완료 보고 대신 해당 장 수정 또는 감사/윤문 재실행부터 한다.
```

- [ ] **Step 2: `SKILL.md` §1 파이프라인 줄 갱신**

old_string:
```text
(1) 인터뷰: interview 스킬 → (2) 색 락: design-shotgun + AskUserQuestion → (3) md 소스 작성
→ (4) 사용자 검토 → (5) ppt-master 빌드 → (6) anti-slop-design audit → humanize-korean 윤문
→ 렌더 Visual QA + 스토리 흐름 review → (7) finalize_svg → svg_to_pptx → cairosvg PDF
이미지 = codex-image · 산출물 = 항상 pptx + PDF
```

new_string:
```text
(1) 인터뷰: interview 스킬 → (2) 색 락: design-shotgun + AskUserQuestion → (3) md 소스 작성
→ (4) 사용자 검토 → (5) ppt-master 빌드 → (6) 렌더 Visual QA
→ 완료 게이트 리포트(anti-slop 감사 · 윤문 · 스토리 흐름 통합 출력) → (7) finalize_svg → svg_to_pptx → cairosvg PDF
이미지 = codex-image · 산출물 = 항상 pptx + PDF
```

- [ ] **Step 3: 검증 — 새 §8c가 §8b 뒤·§9(없음, 파일 끝 "주의" 섹션) 앞에 있는지**

Run:
```bash
grep -n "^## " plugins/ppt-yeong-style/skills/ppt-yeong-style/references/ppt-master-and-qa.md
```
Expected: `§8b. 스토리 흐름 review` 다음에 `§8c. 완료 게이트 리포트`가 오고, 그다음 `주의 / 미해결` 섹션.

- [ ] **Step 4: 검증 — SKILL.md YAML frontmatter 파싱 (재확인)**

Run: Task 1 Step 8과 동일한 명령.
Expected: `frontmatter OK`.

- [ ] **Step 5: Commit**

```bash
git add plugins/ppt-yeong-style/skills/ppt-yeong-style/references/ppt-master-and-qa.md \
        plugins/ppt-yeong-style/skills/ppt-yeong-style/SKILL.md
git commit -m "docs(ppt-yeong-style): merge anti-slop/humanize/story-flow into one completion gate report"
```

---

### Task 5: `references/images-and-pop.md` §5 — codex-image 기본값 이탈 사유 명시

**Files:**
- Modify: `plugins/ppt-yeong-style/skills/ppt-yeong-style/references/images-and-pop.md:5-9`

**Interfaces:**
- Consumes: 없음.
- Produces: 없음(사용 시점 검증만).

- [ ] **Step 1: §5에 이탈 사유 규칙 추가**

old_string:
```
- **codex-image**(기본 이미지 경로, ppt-master 밖 별도 도구): 사진·무드컷·배경(흐림/바램)·전략적 hero·표보다 이미지가 나은 도식. 한/영 레터링 품질 양호 — **생성 성능을 매번 반문하지 말 것**(saturation). 톤 통일을 명시(디자인 토큰 hex + 캐릭터 참조 이미지 첨부)하고, 생성 후 라벨 오타를 검증. ppt-master의 AI 이미지 생성 경로(Step 5 ai)는 **기본 사용 안 함** — 이미지는 codex-image로 채운다.
- **ppt-master SVG**: 정확한 한국어 라벨·구조·표·숫자·타임라인. 텍스트 정확·수정 가능.
- **하이브리드**: 무드 배경(codex) + 라벨 오버레이(SVG). 도식 2안(풀 codex vs 하이브리드)을 렌더 후 사용자 선택.
```

new_string:
```
- **codex-image**(기본 이미지 경로, ppt-master 밖 별도 도구): 사진·무드컷·배경(흐림/바램)·전략적 hero·표보다 이미지가 나은 도식. 한/영 레터링 품질 양호 — **생성 성능을 매번 반문하지 말 것**(saturation). 톤 통일을 명시(디자인 토큰 hex + 캐릭터 참조 이미지 첨부)하고, 생성 후 라벨 오타를 검증. ppt-master의 AI 이미지 생성 경로(Step 5 ai)는 **기본 사용 안 함** — 이미지는 codex-image로 채운다.
- **ppt-master SVG**: 정확한 한국어 라벨·구조·표·숫자·타임라인. 텍스트 정확·수정 가능.
- **하이브리드**: 무드 배경(codex) + 라벨 오버레이(SVG). 도식 2안(풀 codex vs 하이브리드)을 렌더 후 사용자 선택.
- **기본값(codex-image) 이탈 시 사유 명시**: 이미지 없음(SVG 전용)이나 기존 자산 재사용으로 갈 경우, `design_spec.md` 8대 확인 항목 h에 **왜 기본 codex-image 경로를 타지 않는지 한 줄 사유**를 남긴다(예: "이 장은 표·숫자 정확도가 핵심이라 이미지 불필요", "이전 세션에서 이미 승인된 텍스처 재사용"). 사유 없이 그냥 생략하는 것은 금지.
```

- [ ] **Step 2: 검증 — 새 불릿이 §5 안에 들어갔는지**

Run:
```bash
grep -n "기본값(codex-image) 이탈 시 사유 명시" plugins/ppt-yeong-style/skills/ppt-yeong-style/references/images-and-pop.md
```
Expected: 1건 매치, `## §5.` 헤딩과 `## codex 배경 fade 범위` 헤딩 사이.

- [ ] **Step 3: Commit**

```bash
git add plugins/ppt-yeong-style/skills/ppt-yeong-style/references/images-and-pop.md
git commit -m "docs(ppt-yeong-style): require a stated reason when deviating from codex-image default"
```

---

### Task 6: `references/design-language.md` — 한글화

**Files:**
- Modify: `plugins/ppt-yeong-style/skills/ppt-yeong-style/references/design-language.md` (전체, 79줄)

**Interfaces:**
- Consumes: 없음(번역, 의미 불변).
- Produces: 없음.

- [ ] **Step 1: 전체 파일을 한글로 교체**

기존 파일 전체(영문)를 아래 한글 번역으로 교체한다 — Write 도구로 전체 덮어쓰기(구조·6축 5개 항목·anti-slop↔high-end 표 7행·레버 락 7개 항목·마지막 포인터 문단까지 전부 보존):

```markdown
# 디자인 언어 — yeong 시그니처 (§0 상세)

이 스킬의 미감 근간. anti-slop이 "하지 말 것"을 정한다면, 이 문서는 무엇을 **해야** 하는지를 정해서
덱이 무난하지만 흔한 AI 하우스 스타일이 아니라 의도적으로 만든 하이엔드 산출물로 읽히게 한다.

> 레퍼런스 코퍼스(기업/제품 덱, 성수·홍대 팝, 한남 하이엔드, 애플급, 한국 카드뉴스)에서
> Claude + Codex가 거의 완전히 일치하는 결론으로 교차 추출했다. 이 문서는 그 결과를 하나의
> 시그니처로 증류한 것이다.

## 하나의 시그니처

**"에디토리얼 절제, 단 하나의 커밋된 액센트."**
절제된 웜 뉴트럴 에디토리얼 캔버스를, 페이지당 정확히 하나의 커밋된 라우드 모먼트로 깬다.
살아있는 절제이지 안전한 절제가 아니다. 침묵을 장식적 소음으로 만들지 않으면서도 긴장감
있게 만드는 게 이 크래프트의 핵심이다.

핵심 명제: **신뢰 안의 시그니처(signature within trust).** anti-slop의 신뢰 바닥은 전부
그대로 유지된다(아래 모든 금지 사항 유지). 하이엔드 차별화는 그 위에 의도적인 *톤 의도*로
얹힌다 — 더 넣어서가 아니라 톤으로 통제한다. 이건 anti-slop 자체의 "브랜드 자산" 탈출구를
의도적으로 쓰는 것이다: 확고한 비주얼 언어가 있을 땐, 그게 무난한 기본값을 이긴다.

## 6축 (매 덱에 적용)

1. **레이아웃** — 스위스/에디토리얼 그리드를 깔고, 의도적으로 깬다. 페이지당 지배적 앵커
   하나(오버사이즈 타이포/숫자 또는 크롭된 이미지 하나). 하드 좌측 정렬, 베이스라인 규율,
   작은 메타데이터 레일. 긴장은 가장자리·오버랩·크롭에서 나오지, 센터 히어로에서 나오지 않는다.
2. **여백** — 중간~극단, 절대 균등하게 채우지 않는다. 비어 있음이 *압력*을 만든다(앵커를
   프레이밍한다) — 그냥 "깨끗한 공간"이 아니다.
3. **색** — 뉴트럴이 **먼저**, 웜 틴트 베이스 + 커밋된 고채도 액센트 **하나**. 낮은 베이스
   채도, 날카로운 액센트. 액센트는 뿌려놓는 게 아니라 하나의 *시스템*이다. yeong 하우스
   액센트 = 웜 오프화이트(웜 크림톤) `#FAF8F3` 위 Claude 오렌지 `#D97757`. 정확한 토큰은
   프로젝트마다 락하되(`color-typography.md`), *철학*(웜 뉴트럴 + 커밋된 단일 액센트)은
   고정이다. 무지개 금지, 그라데이션 금지, 그라데이션 텍스트 금지.
4. **타이포그래피** — 헤더→본문 스케일이 **극단적으로** 벌어진다(**디스플레이 ≥ 본문 1.5배,
   표지 ≥ 3배**). 무게 대비도 매우 크게(무거운 디스플레이 vs 아주 가벼운 작은 메타데이터).
   산세리프 위주, 세리프는 에디토리얼 양념으로만. 타이트하고 자신감 있는, 포스터 같은
   자간 — 여유롭지 않다. **타이포 자체가 그래픽 요소**다(오버사이즈, 스택, 숫자가 구조가
   되는).
5. **사진** — 장식이 아니라 에디토리얼 소재(로파이 아카이브 무드에 가까운 바랜 톤). 흑백/저채도 = 권위, 통제된 컬러 = 즉시성.
   단색(액센트) 오버레이, 은은한 그레인, 절대 glossy하게 매끈하지 않다. 과감하고 의도적인
   크롭, 타이포가 사진을 겹치거나 프레이밍한다.
6. **팝(pop)** — 크게 튀는 지점은 위계의 정점에만 고립된다(표지, 섹션 구분선, 큰 숫자 하나,
   액센트 패널/버스트 하나). **정직성 테스트(톤 버전): 팝은 감정적이거나 서사적인 신호를
   담아야 한다. 아무 톤 정보도 전달하지 않으면 삭제한다.** 스프레드당 팝 하나, 요소마다가
   아니다.

## anti-slop ↔ 하이엔드: 둘 다 유지 (금지는 그대로, 톤이 차이를 만든다)

| anti-slop 금지(유지) | 하이엔드 무브(금지를 깨지 않고 톤으로 차별화하는 법) |
|---|---|
| 보라/파랑 그라데이션 금지, 그라데이션 텍스트 금지 | 커밋된 플랫 액센트 하나 — 깊이는 그라데이션이 아니라 스케일+여백으로 |
| 센터 히어로 금지 | 오프센터 앵커, 하드 좌측 정렬, 비대칭 긴장 |
| icon-tile 3열 그리드 금지 | 지배적 앵커 하나 — 보조 정보는 작은 레일이나 표로 |
| 슬라이드 간 균등한 리듬 금지 | 의도적인 조용함/시끄러움/밀도/여백의 페이싱(page_rhythm) |
| 이모지 아이콘 금지 | 하나의 라인/에디토리얼 아이콘 패밀리, fill 전용 |
| 조작된 수치/가짜 대칭 금지 | 긴장에서 오는 균형, 진짜 숫자만 |
| 본문 wall-of-text 금지 | 극단적 타입 스케일: 거대한 앵커 + 작은 메타데이터 |

## ppt-master 레버 락 (시그니처 → 엔진 값)

`spec_lock.md`에 아래를 박아 executor가 매 페이지 적용하게 한다(레버 상세는
`ppt-master-craft.md` 참조):

- **visual_style** — `custom`으로 락(기성 프리셋 아님 — ppt-master의 18개 프리셋 중 이
  시그니처와 맞는 게 없다), `visual_style_behavior:` 문단에 이 문서의 시그니처 + 6축을
  요약해 넣는다. 이건 ppt-master 자체가 문서화해둔 커스텀 미감 탈출구다(`visual-styles/_index.md`
  §3) — 이게 없으면 ppt-master의 Strategist가 무관한 기성 스타일을 임의로 고를 수 있다.
- **이미지 rendering × palette** — 웜 뉴트럴 베이스 + 단일 액센트, deck-wide 1조합.
- **page_rhythm** — 의도적으로 불균등: anchor(극단적 여백) / breathing / dense.
- **type-scale** — 디스플레이 ≥1.5배 본문, 표지 ≥3배; 무게 대비도 크게.
- **아이콘** — 한 패밀리, 라인/에디토리얼, fill 전용, 이모지 금지.
- **사진** — 흑백 또는 단일 액센트 오버레이 + 그레인; 과감한 크롭; 타이포가 겹침.
- **팝** — 위계 정점에만 고립; 정직성 테스트로 게이트.

> 나머지가 이어지는 곳: 색/면적 규율 → `color-typography.md`; 팝/사진 정직성 →
> `images-and-pop.md`; 레버 인코딩 → `ppt-master-craft.md`. 이 문서는 *왜*를 담고,
> 저 문서들은 *어떻게*를 담는다.
```

- [ ] **Step 2: 검증 — 항목 수 대조(번역 전후 누락 확인)**

`git diff`로 편집 전(HEAD, 영문 원본) vs 편집 후(워킹트리, 한글본)의 항목 수를 직접 대조한다 — 파일을 덮어썼으므로 원본은 git 이력에서 가져온다:

```bash
F=plugins/ppt-yeong-style/skills/ppt-yeong-style/references/design-language.md
echo "번호 목록(원본 vs 번역):"
git show HEAD:"$F" | grep -c "^[0-9]\."
grep -c "^[0-9]\." "$F"
echo "표 라인(원본 vs 번역):"
git show HEAD:"$F" | grep -c "^| "
grep -c "^| " "$F"
echo "레버 락 불릿(원본 vs 번역):"
git show HEAD:"$F" | grep -c "^- \*\*"
grep -c "^- \*\*" "$F"
```
Expected: 세 쌍(번호 목록/표 라인/레버 락 불릿) 모두 원본과 번역본의 숫자가 **정확히 같아야** 한다(번호 목록 6, 레버 락 불릿 7 — 실제 원본 기준값. 표 라인은 헤더+구분선+데이터행을 합친 수라 원본·번역 둘 다 같은 방식으로 세어지므로 두 값이 같은지만 확인).

- [ ] **Step 3: Commit**

```bash
git add plugins/ppt-yeong-style/skills/ppt-yeong-style/references/design-language.md
git commit -m "docs(ppt-yeong-style): translate design-language.md to Korean for consistency"
```

---

### Task 7: 최종 회귀 확인

**Files:** 없음(읽기 전용 검증)

**Interfaces:**
- Consumes: Task 1~6의 모든 산출물.
- Produces: 이 스펙/계획의 완료 신호.

- [ ] **Step 1: Codex/Hermes manifest 회귀 확인**

Run:
```bash
node scripts/sync-codex-manifests.mjs --check
node scripts/sync-hermes-manifests.mjs --check
```
Expected: 둘 다 drift 없음으로 통과(이번 변경은 `description`/`version`을 안 건드리므로 영향 없을 것으로 예상 — 실패 시 원인 조사).

- [ ] **Step 2: 전체 §번호 최종 스윕**

Run:
```bash
grep -n "^## " plugins/ppt-yeong-style/skills/ppt-yeong-style/SKILL.md
grep -rn '^# ' plugins/ppt-yeong-style/skills/ppt-yeong-style/references/
```
Expected: SKILL.md는 §0/§0b/§0c/§1/§2/§3/§3b/§3c/§3d/§4/부록A 순서, references는 각자 제목이 참조 파일 지도 표와 일치.

- [ ] **Step 3: plugin.json 버전 — 이번 변경이 콘텐츠 추가/정정 성격이라 버전 불변 확인**

Run:
```bash
git diff main --stat -- plugins/ppt-yeong-style/.claude-plugin/plugin.json
```
Expected: 빈 출력(이번 PR은 순수 콘텐츠 보완이라 버전 미변경 — `plugin-versioning.md`의 "pure content additions need no version bump" 컨벤션과 일치, PR #87 선례와 동일).

- [ ] **Step 4: 최종 상태 확인**

```bash
git log --oneline main..HEAD
git status --porcelain
```
Expected: Task 1~6의 6개 커밋이 순서대로 있고, working tree clean.

---

## 실행 방식

이 계획은 사용자가 지정한 대로 `superpowers:using-git-worktrees`로 격리된 워크스페이스에서 실행하고, `github-dev:decompose-issue`로 이슈 1개를 만든 뒤 `github-dev:resolve-issue`(cr-fix loop on)로 마무리, 병합 후 `github-dev:post-merge`로 이어간다. 6개 task 전부가 문서 편집이라 이슈를 sub-issue로 쪼갤 필요는 없다(사용자 지정: 단일 이슈).
