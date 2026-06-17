# anti-slop-design 스킬 설계 (v0.1.0 MVP)

- 작성일: 2026-06-16
- 상태: draft (사용자 검토 대기)
- 근거 substance: `docs/references/anti-slop-design-oss-synthesis.md` (6개 OSS repo source-grounded 합성)
- 참고 원문: `docs/references/chatgpt-share-6a31408f-anti-slop-design.md` (리서치 대화 복원본)

## 1. 목적과 포지션

`anti-slop-design`은 Claude Code / Codex 공용 **가이던스 스킬**이다. 웹/SaaS 랜딩, 발표 덱(PPT), 대시보드/admin UI, 마케팅·UI 카피를 만들거나 감사·개선할 때 "AI가 만든 티(slop)"를 **생성 전에 차단**하고 **생성 후에 감사**한다.

예쁜 디자인 생성기가 아니라 **enterprise anti-slop guard**다. 핵심 명제(6개 repo 수렴): **slop = 브리프와 무관하게 나오는 기본값(default-not-choice)**. 모든 규칙은 "이 브리프를 위한 선택인가, 아무 브리프에나 나올 선택인가"로 환원된다.

역할 분담:
- 구조·실질 → 리서치 OSS(impeccable 44 detector / hallmark 58 gate / frontend-design 원칙 / huashu brand·density / stop-slop 카피 / frontend-slides 덱).
- 기본 제안값 → 사용자 house-style (mem0로 다수 프로젝트 재발 확인된 일관 취향).
- 한국어 카피 재작성 → `humanize-korean` 스킬에 위임(중복 구현 금지).

작성 언어 규약 (SKILL.md + 3 reference 전체 적용): **설명 산문은 한국어**, 단 **AI/도구가 정확히 인식해야 하는 키워드·식별자는 영어 유지** — 예: `gradient text`, `hero`, `side-stripe card`, `card-in-card`, `eyebrow chip`, `em-dash`, `audit gate`, `detector`, `WCAG`, `oklch()`, `prefers-reduced-motion`, CSS 속성·HTML 태그·repo/스킬 이름. description frontmatter 트리거도 한/영 병기. 이모지 금지(코드·문서 공통).

## 2. 비목표 (YAGNI / 롤백 용이)

v0.1에서 만들지 않는다. (근거: 합성 §7 DEFER)

- 실행형 JS 탐지 엔진(impeccable `cli/engine/*` 수천 줄, 4 백엔드) — 44-rule을 **체크리스트 데이터**로만 흡수.
- pre-edit 차단 hook(permission deny) — v0.1은 리포트·권고만, 편집 차단 안 함.
- 58 gate 전수 — §6의 ~12항목 게이트로 distill.
- 매크로구조/테마/아키타입 카탈로그(hallmark N1-N13, 21 매크로, 20 테마 / huashu 40-style / frontend-slides 12 preset) — anti-pattern 원칙만, 카탈로그는 비흡수.
- cross-session anti-sameness 로그, critique 스냅샷, PRODUCT.md/DESIGN.md drift 탐지, Nielsen/persona UX 평가, brand-asset sourcing 프로토콜, 번들 미디어/export 파이프라인.
- **sub-agent 파일(.claude/agents)** — 6단계 흐름을 SKILL.md 본문 inline으로. v0.2 승격 후보.
- **PPT 빌드 파이프라인(md→SVG→pptx)** — ppt 섹션은 원칙 + 기존 도구(ppt-master/codex-image) 포인터만. 덱 제작 자체는 비범위.

## 3. 파일 레이아웃

```
plugins/anti-slop-design/
  .claude-plugin/plugin.json          # name, version 0.1.0, description(<=1024자), skills[]
  skills/anti-slop-design/
    SKILL.md                          # 오케스트레이팅 본문(<500줄): 6단계 흐름 + 2단계 audit gate
    references/
      slop-taxonomy.md                # 범용 지문(VISUAL/STRUCTURAL) + 레인 quick-rules(web/ppt/dashboard)
      copy-rules.md                   # 카피 anti-slop(영문 banned list + 덱 8원칙) + humanize-korean 핸드오프
      house-style.md                  # 영재님 기본 제안값 + OSS 교차점검(blue/indigo·SVG 충돌 해소 포함)
```

단일 SKILL.md + 3 reference (progressive disclosure). 4레인 중 web/ppt/dashboard는 `slop-taxonomy.md` 안 섹션, copy는 `copy-rules.md`. 레인이 커지면 v0.2에서 파일 분리. 스킬만 있어 Codex 완전 호환.

## 4. SKILL.md 6단계 흐름 (inline, agent 없음)

1. **Clarify** — artifact 종류(web/ppt/dashboard/copy)·청중·브랜드·결정맥락 식별. 모호하면 AskUserQuestion.
2. **Context** — 해당 레인 규칙 + `house-style.md` + `slop-taxonomy.md` 로드. **브랜드 색·폰트는 기억으로 추측 금지**(huashu brand-protocol): 자료 있으면 읽고, 없으면 house-style 기본값. 자료 없는데 지어내기 금지.
3. **Plan** — "clean/modern/professional" 같은 모호한 방향 금지, **구체 방향 1개** 선택 + 정보 위계 정의. 시각 산출물은 **2~3개 방향을 제안하고 사용자가 택1**(show-don't-tell, mem0 확정 취향).
4. **Run** — 택1 방향 + 레인 규칙 + house-style 기본값으로 산출. 모든 ban은 "브리프의 명시 요구가 이기는" escape hatch 보유(브랜드가 보라색이면 허용 등).
5. **Audit gate** — §5의 2단계 게이트 실행. 카피 포함 시 영문은 자체 탐지·스코어링, **한국어 재작성은 `humanize-korean:humanize-korean`(fast) 핸드오프** 후 `final.md` 본문 회수.
6. **Revise** — 걸린 항목 수정 후 최종. 출력 형식: 사용한 디자인 방향 / 정보 위계 / 적용한 anti-slop 결정 / 산출물 / 남은 리스크·trade-off.

## 5. Audit Gate 설계 (lean 2단계)

근거: 합성 §6 (hallmark 6축 pre-emit + stop-slop/huashu 5-dim + impeccable 결정/주관 분리 + frontend-design self-similarity).

**Phase A — 생성 전 self-critique** (도구 불필요, 최고 레버리지)
- self-similarity probe: "비슷한 브리프를 머릿속으로 처리했을 때 나올 선택과 같은가? 같으면 이 브리프를 위한 선택으로 교체하고, 무엇을 왜 바꿨는지 적는다."
- 6축 1~5점, **한 축이라도 <3이면 1회 수정 후 emit**: Philosophy / Hierarchy / Specificity / Restraint / Variety / Honesty.
- 루프 종료 휴리스틱(hallmark): "2회 수정은 정상, 3회면 디자인이 아니라 브리프가 틀린 것."

**Phase B — 납품 전 binary 체크리스트** (~12항목, 모든 답이 "no"여야 함; 하나라도 "yes" = 수정 후 납품)
1. 보라/레인보우/mesh 그라데이션 또는 gradient text? 2. 단일 과용폰트(Inter/Roboto/Geist/Space-Grotesk)/한폰트 페이지? 3. side-stripe 카드/카드인카드/아이콘타일-위-제목 3열? 4. cream-default / `#0D1117`-네온 / 순수 `#000`·`#fff` 베이스? 5. 풀뷰포트 중앙정렬 hero/전부 중앙정렬? 6. 장식용 01/02/03 번호·모든 섹션 eyebrow chip? 7. 제네릭 Hero→3features→testimonials→CTA→footer 골격? 8. 지어낸 수치/가짜 후기/플레이스홀더명(Acme/Jane Doe)? 9. 이모지 아이콘/아이콘 라이브러리 혼용? 10. 손그림 figurative SVG/재그린 브라우저·폰·터미널 chrome? 11. 과애니/`transition-all`/균일 hover-scale/reduced-motion 없음? 12. 카피: buzzword/"Not X, it's Y" 대비/throat-clearing/지어낸 specifics?
- **수치 floor sweep**(자동검증 가능): 대비 본문 4.5:1·큰글자 3:1, 본문 ≥14px(슬라이드 ≥24px), 타입스케일 ≥1.25, 행길이 ≤80ch, line-height ≥1.3, 색 ≤3-4, 터치 44×44px, 모든 장식 이미지에 honesty test.

게이트 mechanics: Phase A 주관 판단을 Phase B 체크리스트보다 **먼저** 형성(앵커링 방지). 선택적으로 self-describing 스탬프(`<!-- anti-slop: A-pass · contrast ok · 1-12 no -->`)로 후속 drift 탐지.

## 6. 레인별 핵심 (slop-taxonomy.md 섹션)

- **Web/SaaS**: 가장 깊게 커버됨. 색·폰트·컴포넌트·구조 ban 전부 + 수치 floor. (합성 §3 Web)
- **PPT/덱**: web ban 전부 적용 + 고정 1920×1080 스테이지(reflow 금지, `.active` 토글), density 모드(speaker-led vs reading-first, "split don't shrink"), 슬라이드 본문 ≥24px, **scaffolding 노출 절대 금지**("preview"/"Option A" 등 화면 표기 금지), 페이지번호는 덱 셸이 소유. (합성 §3 PPT)
- **Dashboard/admin**: **증거 GAP — 6개 repo 어디도 대시보드 전용 아님. 정직하게 표기.** web의 컴포넌트/대비/density 규칙 + hallmark form-state 게이트(39번) 상속 + **huashu density 역전 원칙**(정보 밀도는 slop 아님 — 장식만 제거, "여백 늘리기" 반사 금지). 가장 얇은 레인, 전용 소스 확보 시 보강. (합성 §3 Dashboard)

## 7. 카피 연동 (copy-rules.md)

- 영문 banned list(stop-slop) + buzzword(impeccable) + 구조 패턴("Not X, it's Y" 대비, negative listing, false agency, em-dash ≥5 임계) 흡수.
- 핸드오프 전 체크리스트 = 사용자 **덱 8원칙**(표지 금액·수치 금지 / 일반론 문제제기 배제 / 번호나열→도식 / 비개발자 일상어 / 제목 담백·설득은 박스 / 내부표기 노출 금지 / 번역투 재점검 / 과대주장 완화).
- **경계**: anti-slop-design = 시각/구조 + 영문 카피 탐지 + 스코어링 게이트 소유. `humanize-korean` = 한국어 산문 재작성 소유. stop-slop의 무딘 절대금지(부사 전면금지, em-dash 전면금지, 3항목 리스트 금지)를 **한국어로 복제 금지** — 전역 CLAUDE.md·humanize-korean의 한국어 친화적 완화 스탠스 우선. (합성 §4)

## 8. House-Style (house-style.md)

사용자 기본 제안값: enterprise / monochrome + 단일 accent / Pretendard(한글) / no emoji / inline SVG 다이어그램 / 무외부의존 static HTML+CSS+vanilla JS / print-CSS / 콜아웃(Note/Tip/Important/Caution/Warning).

OSS 교차점검 결과 충돌 2건 해소 (합성 §5):
- **blue/indigo accent ↔ AI 팔레트**: 사용자 기본 accent(blue/indigo)는 repo들이 지목하는 바로 그 색대역. 해소 — **그라데이션이 slop이지 평면 단일 indigo는 OK**. house-style은 특정 committed indigo 토큰(`oklch()`)을 핀하고 **절대 그라데이션화 금지**. house-style이 banned 패턴에 가장 근접한 유일 지점으로 명시.
- **inline SVG 다이어그램 ↔ 손그림 SVG 금지**: huashu의 최우선 ban은 figurative/representational SVG(사람·장면·제품). **다이어그램·아이콘·data-viz는 허용 집합**. 따라서 SVG ban은 figurative에만 적용하도록 스코프 — 아키텍처/플로우 다이어그램 false-positive 방지.
- Pretendard·콜아웃: banned list에 없음, 충돌 없음. 범용 기본은 generic, 사용자 취향은 worked example/기본 제안값으로(브랜드 반영 "기본 범용+예시만").

## 9. dual-integration (Codex) + 버전·카운트

생성 후 필수 (근거: `.claude/rules/dual-integration.md`, `plugin-versioning.md`):
- `node scripts/sync-codex-manifests.mjs` → `.codex-plugin/plugin.json` 생성, `--check` 통과.
- `.claude-plugin/marketplace.json`: 플러그인 엔트리 추가 + `metadata.version` bump(merge 직전 origin/main 대비 재확인).
- plugin 개수 **21→22**: 루트 `CLAUDE.md`(`## Plugins (N)` + 트리) + `README.md`(설명문 + 배지 + 상세).
- skill `description` **≤1024자**(Codex 한도), pushy 트리거(한/영 — "AI 티 안 나게", "slop 제거", "anti-slop", "디자인 감사", "랜딩/덱/대시보드/카피" 등).

## 10. 검증

- skill-creator eval: should-trigger + should-NOT-trigger near-miss.
- dry-run 1건: 샘플 랜딩 hero에 심은 slop(보라 그라데이션 + 아이콘타일 3열 + 지어낸 "10x faster")을 Phase B 게이트가 잡는지.
- `sync-codex-manifests.mjs --check` 통과, description 길이 검증, `.githooks/pre-commit` 통과.

## 11. Sourcing / 신뢰도 caveat

(합성 §8 요약) 6개 분석 전부 gh api 원본 기반 HIGH. README는 stale — count는 source SSOT(impeccable 44, hallmark 58). `anthropic-fd`는 폰트 ban을 갖지 않음(형제 스킬의 환각 교정됨) — frontend-design 자체는 font-agnostic. cream=#F4F1EA Opus 기본설 / frontend-slides `#6366f1`·glassmorphism은 medium. 라이선스: impeccable Apache-2.0 / hallmark MIT / stop-slop MIT(저자 Hardik Pandya 표기) / frontend-slides MIT류 / huashu LICENSE 확인要(서드파티 미디어) / anthropic-fd 커스텀 10KB 약관. 코드 직접 재사용 시 라이선스·attribution 확인.

## 12. Open questions

- skill `description` 최종 문구 트리거 세트(한/영) — 구현 시 skill-creator description 최적화 루프로 확정.
- dashboard 레인 전용 소스 확보 여부(v0.2): 현재는 web 상속 + density 역전으로 충분한가.
