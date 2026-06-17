# copy-rules

카피(문구) anti-slop. 주 출처: stop-slop(영문 전용, 유일 카피 전담 repo) + impeccable/frontend-design/huashu/hallmark의 카피 detector. 출처 substance: `docs/references/anti-slop-design-oss-synthesis.md` §4.

**경계 (중요):** anti-slop-design은 **영문 카피 탐지·스코어링 + 핸드오프 전 체크리스트**를 소유한다. **한국어 산문 재작성은 `humanize-korean`에 위임**한다. stop-slop의 무딘 절대금지(부사 전면금지, em-dash 전면금지, 3항목 리스트 금지)를 **한국어로 복제하지 않는다** — 한국어는 humanize-korean의 한국어 친화 완화 스탠스를 따른다.

---

## 1. 핸드오프 전 체크리스트 (덱 8원칙 — 한국어 카피 공통)

> 출처 주의: 이 8원칙은 사용자 **경험 기반 authored 가이던스**이며 6-repo corpus(§2~§4 출처)에서 도출된 게 아니다. corpus와 직접 연결되는 건 #6(→ slop-taxonomy §3 PPT scaffolding)·#8(→ §2 honesty test)뿐. 나머지는 프로젝트 디자인 원칙으로 적용한다.

한국어 카피를 humanize-korean에 넘기기 전, 구조/내용 차원에서 먼저 거른다(이건 문체가 아니라 슬라이드·문서 설계 문제라 humanize 이전 단계):

1. **표지에 금액·수치·절차 금지** — 표지는 무엇/누구/언제만.
2. **AI-slop 일반론 문제제기 배제** — "쏟아지는데/결국 사람 손" 류 명사나열+당위, 청중이 이미 아는 일반론 문제제기 슬라이드는 통째 삭제가 정답인 경우 많음 -> 솔루션 도식으로 바로 진입.
3. **단순 번호 나열 대신 도식** — "(1)(2)(3)(4)(5)" 목록 대신 좌->우 흐름 박스.
4. **비개발자 청중 = 일상어** — "구축/산정/연동" -> "만들기/잡기/이어주기".
5. **제목은 담백하게, 설득은 박스에** — 제목에 영업·당위 꼬리표 금지.
6. **내부 표기·버전 라벨 노출 금지** — "v4", "intake", "Mid 1~2주" 빼기.
7. **번역투·보고서 말투 재점검** — "정밀화합니다/이렇게 일합니다" -> 발화 호흡 한국어.
8. **과대주장 완화** — "끝냈다" -> "제시·양산 가능" 류, 증거(숫자/사례/제약/trade-off) 없는 단정 회피.

이 8개를 통과한 한국어 산문의 문체 재작성은 humanize-korean로 넘긴다(§4).

---

## 2. 영문 banned phrases (greppable blocklist)

- **throat-clearing openers:** "Here's the thing:", "Here's what/why [X]", "The uncomfortable truth is", "It turns out", "The real [X] is", "Let me be clear", "The truth is,", "I'm going to be honest", "Can we talk about".
- **emphasis crutches:** "Full stop.", "Period.", "Let that sink in.", "This matters because", "Make no mistake", "Here's why that matters".
- **filler:** "At its core", "In today's [X]", "It's worth noting", "At the end of the day", "When it comes to", "In a world where", "The reality is".
- **marketing buzzwords:** "streamline/empower/supercharge your", "unleash the power", "leverage the power", "built for the modern", "trusted by leading/the world", "best-in-class", "industry-leading", "world-class", "enterprise-grade", "next-generation", "cutting-edge", "transform your business", "revolutionize", "game-changer", "mission-critical", "future-proof", "seamless(ly)", "drive engagement/growth/results", "harness the power".
- **jargon -> plain:** Navigate->Handle, Unpack->Explain, Lean into->Embrace, Landscape->Field, Game-changer->Significant, Double down->Commit, Deep dive->Analysis, Moving forward->Next, Circle back->Return to, On the same page->Aligned.
- **adverb crutches:** really, just, literally, genuinely, honestly, simply, actually, deeply, truly, fundamentally, inherently, inevitably, crucially.
- **meta-commentary:** "Hint:", "Plot twist:", "Spoiler:", "But that's another post", "Let me walk you through...", "In this section, we'll...", "As we'll see...".
- **lazy extremes:** every, always, never, everyone, nobody -> 구체로.

---

## 3. 영문 banned structures (pattern-match)

- **[CORE] manufactured contrast / telegraphed reversal** — "Not because X. Because Y.", "The answer isn't X. It's Y.", "not just X but also Y" / 아포리즘 cadence `Not a X. A Y.`, `X. No/Just y.`. count >=3에서 fire(한 번은 OK, 패턴이 tell). Instead: Y를 직접 진술, 부정 drop.
- **negative listing (rhetorical striptease)** — "Not a X... Not a Y... A Z." Instead: Z를 바로.
- **[CORE] em-dash 남용** — **임계 기반 advisory(>=5), 전면금지 아님**(전역·한국어 완화 스탠스). regex `/[—]|--(?=\S)/g`.
- **dramatic fragmentation** — "[Noun]. That's it. That's the [thing].", "X. And Y. And Z." Instead: 완결 문장.
- **false agency (무생물 주어 + 인간 동사)** — "a complaint becomes a fix", "the data tells us", "the market rewards". Instead: 인간 행위자 명시 또는 "you".
- **passive / 원거리 narrator** — 행위자를 앞으로, 독자를 현장에.
- **rule of three** — "두 개가 세 개를 이긴다"; 리듬 변주, staccato stacking 금지.
- **UX-copy detectors (wholesale 채택)** — 시스템 구현이 아니라 사용자가 제어하는 것으로 명명("manage notifications" not "webhook config"); flow 전체에서 일관 action verb(button "Publish" -> toast "Published"); error는 사과·모호 금지(무엇이 왜 + 어떻게 고치나); empty state는 행동 유도; "nothing quietly does double duty"(요소당 한 일).

---

## 4. 스코어링 + humanize-korean 핸드오프

### 스코어링 (영문)
stop-slop/huashu 수렴: **5차원 1-10, /50, 35 미만이면 수정.** 차원: Directness / Rhythm / Trust / Authenticity / Density. 각 banned 패턴은 "Instead:" 직접 재작성과 쌍으로(금지만 말고 대체를 처방).

### 핸드오프
- 영문 카피: 위 banned list/structure로 탐지·스코어링하고 직접 수정.
- **한국어 카피 재작성: `humanize-korean:humanize-korean` 호출**(기본 fast 모드; >=8000자 또는 정밀 필요 시 strict). 출력 `final.md` 본문만 회수(HTML 주석 메타 제외). humanize-korean이 10 category/40+ 한국어 AI-tell(번역투, 영어 인용 과다, 기계적 병렬, 피동태 남용, 리듬 균일성 등)을 담당.
- stop-slop 영문 리스트는 한국어 translationese에 매핑되지 않음(자체 caveat). 한국어 corpus 커버리지 0 -> humanize-korean 우선. 단 humanize-korean은 이 marketplace 미번들 외부 의존이므로 미설치 시 본 파일의 한국어 카피 원칙으로 직접 수동 재작성(lane 중단 금지, hard-require 아님).
- caveat: stop-slop의 `examples.md`조차 자기가 금지한 em-dash를 씀 — 예시를 ground truth로 그대로 복사 금지.
