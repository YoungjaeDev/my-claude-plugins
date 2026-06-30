---
name: ml-dev-principles
description: General working discipline for ML / multimodal / CV development (how to work, not which library). Load at the START of an ML task — model/dataset candidate selection, license or eligibility filtering, EDA, training/fine-tuning (SFT/DPO/LoRA), evaluation-harness and train/val/test isolation design, error analysis on FP/FN cases, or GPU throughput tuning. Triggers on "EDA", "explore dataset", "error analysis", "FP/FN", "train", "fine-tune", "SFT", "DPO", "LoRA", "eval harness", "validation split", "test leakage", "dataset selection", "model selection", "license filtering", "GPU utilization", "multimodal", "VLM", "image review".
---

# ML / 멀티모달 개발 원칙

## Hermes Agent Compatibility

When this skill is loaded through Hermes as `ml-toolkit:ml-dev-principles`, map Claude/Codex tool names to Hermes tools:

| Claude/Codex term | Hermes tool |
|---|---|
| Bash | terminal |
| Read | read_file |
| Write | write_file |

Treat `$ARGUMENTS` as the natural-language arguments supplied when the user asks Hermes to load the skill. Plugin-provided skills are explicit opt-in loads in Hermes; use `skill_view("ml-toolkit:ml-dev-principles")` (or ask Hermes to load that qualified skill) rather than relying on bare text.

ML·멀티모달·CV 작업을 *어떻게* 진행할지에 대한 범용 규율(어떤 라이브러리를 쓰느냐가 아니라). 작업 시작 시 한 번 훑고 적용한다. 한 문장 요약: **집계/규칙 텍스트만 보지 말고 실제(이미지·원문·util)를 직접 봐라.**

## 메타 — 규칙에는 타입이 있다

hard-block(컴플라이언스·안전·산출물 누설)과 process-caution(보수성·스타일·관행)을 구분한다. 모든 규칙을 반사적으로 최강 해석으로 적용하면 정당한 빠른 경로까지 막힌다. 분류부터 하고 hard-block만 게이트로 삼는다 — 나머지는 trade-off로 판단한다.

## 1. 후보 선정 — 라이선스/자격은 규칙 원문부터 읽고 거른다

- 모델·데이터를 "비상업/연구 라이선스라 제외" 식으로 선제 과필터링 금지. 과제가 연구/대회이고 규칙 원문이 실제로 금지하지 않으면 후보에 남긴다. permissive(Apache/MIT)는 동급일 때 tiebreaker지 gate가 아니다.
- 왜: 선정 단계의 잘못된 배제는 파이프라인 전체로 전파되고 방향 자체를 틀어버린다 — 되돌리는 비용이 가장 크다.
- 적용: 자격 제약을 문자 그대로 나열 → 각각 hard-block / preference로 분류 → hard-block만 배제.

## 2. 평가 격리 — 하드룰과 프로세스 주의를 분리한다

- 하드룰(절대 금지): 제출·배포되는 산출 모델을 held-out/test 라벨로 학습·early-stop·모델선택·튜닝하지 않는다. 누설이다.
- 허용·권장: test-GT(또는 임의 held-out proxy)를 flag-gated dev 진단으로 써서 파이프라인이 end-to-end로 도는지·숫자가 말이 되는지 sanity-check 하는 건 정당하다. 순수성을 이유로 무해한 파이프라인 점검을 거부하지 마라. 진단 경로는 flag 뒤로 격리해 산출물에 절대 흘러들지 않게 한다.
- 왜: "산출물에 누설 금지"와 "배관 점검용으로도 라벨을 보지 마라"를 혼동하면, 시간 촉박할 때 빠른 피드백을 스스로 차단한다.
- 적용: 제출 모델의 학습/선택 신호는 train-disjoint independent val에서만. test-GT는 산출물로 흐르는 어떤 것도 건드리지 않는 격리 경로에만.

## 3. EDA는 필수 — 멀티모달이면 사람이 raw/overlay 이미지를 직접 본다

- 모델링 전 EDA는 비협상. 라벨 있는 멀티모달/CV는 분포 통계로 끝내지 말고 사람(또는 Claude vision)이 raw 이미지(detection/seg면 overlay)를 실제로 본다.
- 왜: 집계 통계는 "다 봤다"는 거짓 인상을 준다. 멀티모달은 이미지가 판별 근거를 들고 있어 라벨-이미지 정합은 통계로 알 수 없다.
- 적용: interactive viewer(예: `ml-toolkit:cv-explorer`)로 strata별 샘플을 눈으로 — 숫자 신뢰 전에.

## 4. 오류 분석 — 지표가 아니라 실제 FP/FN 이미지를 본다

- 틀린 케이스(FP/FN)는 실제 이미지를 열어 (질문·선택지·정답)과 대조해 *왜* 틀렸는지 추론한다(overlay 포함). 그 인사이트를 다음 데이터/모델 변경의 입력으로 삼는다.
- 왜: 지표는 "얼마나 틀렸나"만 주고 "왜"는 못 준다. 왜(라벨 오류 / 이미지 모호 / 모델이 이미지 무시하고 text-prior 의존)는 픽셀에만 보이고, 그게 다음 iteration을 끈다.
- 적용: eval 후 FP/FN을 이미지와 함께 덤프하는 코드를 *실행* → 샘플 육안 리뷰 → 구체적 데이터/aug/prompt 변경으로 환원.

## 5. GPU 처리량 — 모델 크기에 맞는 병렬 전략 + eff-batch 불변식

- 병렬을 모델 크기에 맞춘다: 소형(약 3B 이하)은 순수 DDP, ZeRO/deepspeed는 끈다(파티셔닝 오버헤드 > 이득). ZeRO 카고컬트 금지.
- eff-batch 불변식(per_device x accum x n_gpu = 상수)을 유지한 채 per-device batch만 올려 수렴 동역학은 안 바꾸고 속도만 얻는다.
- LoRA rank·flash-attn·grad-checkpointing·bf16이 표준 레버. rank는 메모리 천장에 맞춰 튜닝.
- 모델 여러 개를 병렬 추론할 땐 손수 짠 멀티GPU 런처보다 CUDA_VISIBLE_DEVICES 격리 + per-process가 단순·충분 — 배칭은 엔진(예: vLLM)에 맡긴다.
- 왜: "GPU 기계장치 더 동원" != 빠름. 핵심은 모델에 맞는 전략 + eff-batch 고정으로 정확도 회귀 없는 공짜 속도.
- 적용: util 프로파일 → 90% 미만이면 exotic 병렬 꺼내기 전에 deepspeed/ZeRO 오버헤드나 과소 batch부터 의심.

## 6. 이중 판단 도구는 정액 구독 — 아끼지 말고 적극 쓴다

- VLM 인사이트·2차 의견이 도움 되는 모든 지점(데이터 페어 검증, GT/라벨 생성, 오류 리뷰, 설계·가설 대조)에서 Codex read + Claude vision을 기본 병행한다. OAuth 정액 구독이라 호출당 비용이 사실상 0 → API 토큰 아끼듯 판단 횟수를 rationing 하지 마라.
- 단일 모델 단독 판단 금지. 불일치는 정밀 재패스 + rationale 대조로 에스컬레이션.
- 왜: 이미지가 판별 근거인 멀티모달에서 이중 독립 판단은 오라벨·환각을 잡는 가장 싼 보험인데, 정액제면 그 보험이 공짜다. 비용 걱정에 단일 패스로 끝내면 잡을 오류를 놓친다.
- 적용: 위 3(EDA)·4(오류 리뷰)에서 디폴트로 Claude read + Codex read 동시 호출 후 합의/대조.
