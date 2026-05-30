# AGENTS.md

이 저장소에서 Codex (GitHub cloud reviewer + CLI), Cursor, Windsurf, Gemini CLI 등 비-Claude 에이전트가 따라야 할 루트 지침이다. 상세 규칙의 authoritative source 는 `CLAUDE.md` 이며, 이 파일은 빠른 참조와 리뷰 기준을 정리한다.

## Project context

{{PROJECT_NAME}} — {{ONE_LINER}}

Owner: {{OWNER}}
Domain: ML / data — 모델 학습, 평가, 추론, 데이터 처리 파이프라인 중심.

> 코드 일정 수준 쌓이면 `rules-forge:write-rules` 로 tech-stack 기반 CLAUDE.md + `.claude/rules/*.md` 를 재생성하고, 이 파일도 그 결과에 맞춰 업데이트한다.

## Build / Test / Lint

<!-- TODO: 코드 추가되면 채운다. ML 프로젝트 기본 패턴: -->
<!-- ```bash -->
<!-- # 환경 -->
<!-- # uv sync                             # Python deps -->
<!-- # uv pip install --index-strategy unsafe-best-match -r requirements.lock  # PyTorch cu124 등 multi-index 시 -->
<!-- -->
<!-- # 학습 / 평가 -->
<!-- # uv run python scripts/train.py --config configs/base.yaml -->
<!-- # uv run python scripts/eval.py --checkpoint <path> -->
<!-- -->
<!-- # 테스트 / 린트 -->
<!-- # uv run pytest -q -->
<!-- # uv run ruff check . -->
<!-- # uv run python -m py_compile <file.py>  # 빠른 syntax 체크 -->
<!-- ``` -->

## Review guidelines

> 이 섹션은 Codex GitHub cloud reviewer 가 자동으로 읽는 영역이다 ([공식 문서](https://developers.openai.com/codex/integrations/github)). 한국어로 리뷰한다. 발견사항은 영향 + 근거 (파일/라인) + 수정 방향 순서로 제시한다. 근거가 부족하면 `unverified` 로 표시한다.

### Do not flag (린터/포매터 영역)

- 들여쓰기, 줄바꿈, 따옴표 스타일 — `ruff format`, `black` 등 포매터가 처리.
- import 순서 — `ruff --select I` 가 처리.
- 단순 typo / 영문 문법, 변수명 취향 — 결함이 아니면 skip.
- numpy/torch 차원 표현식 (`x[None, ...]` vs `x.unsqueeze(0)`) 같은 스타일 — 정확성 문제 아니면 skip.

### P0 — Correctness / Security

- Secret / API key (HF_TOKEN, WANDB_API_KEY, OPENAI_API_KEY, CLOUD creds) 노출.
- 원본 데이터셋 (raw video, gt 라벨, manifest) 파괴 가능성. 사람 검수 결과 (`*_human_reviewed*.json`) 덮어쓰기.
- 학습 결과 (checkpoint, 평가 JSON) 의 unsafe deserialization (`torch.load` `weights_only=False`, pickle).
- Destructive command (`rm -rf`, `git push --force`, RunPod pod 삭제) 가 사용자 확인 없이 실행되는 흐름.

### P1 — Performance / Maintainability

- **재현성 회귀** — random seed, 데이터 split, 프롬프트/하이퍼파라미터 변경에 frozen hash 가 깨졌는데 의도적 변경 표시 없음.
- **데이터 origin 혼선** — 학습/평가/테스트 split 누수, train data 가 eval set 으로 흘러가는 경로.
- **메모리 / GPU 점유** — `torch.no_grad()` 누락, batch 누적, dataloader `num_workers` 가 hot path 에 거대한 값.
- **Atomic write 회귀** — JSON / 모델 저장에 `path.write_text(json.dumps(...))` 직접 사용. tempfile + fsync + os.replace 패턴 깨짐.
- **Tokenizer / preprocessing drift** — 학습 시 사용한 normalization 과 추론 시 normalization 이 silently 다른 경우.
- 새 dependency (특히 CUDA wheel, PyTorch index), GitHub Actions 권한 변경 — 최소 권한, lockfile 동기화.
- 명시된 invariant (데이터 보존 정책, 학습 reproducibility hash) 위반.

### Domain-specific (ML)

- **decord / cv2 / PIL 혼용 금지** — 동일 파이프라인 내에서 frame 추출 라이브러리 일관성. 비디오는 `decord.VideoReader` 기본.
- **dataloader worker 수와 memory_format** — 학습 스크립트 변경 시 OOM 이나 throughput 회귀를 야기할 수 있는 매개변수는 명시적 근거 필요.
- **LoRA / adapter 학습** — base model freeze 가 실제로 적용됐는지, optimizer 가 trainable 만 보고 있는지 확인.
- **Mixed precision (fp16 / bf16)** — gradient overflow, NaN 처리 누락 시 학습이 silently 망가짐. `GradScaler` 사용 시 step 순서 확인.
- **Evaluation metric** — top-1 / top-5, mAP, F1 등 계산식 변경은 기존 baseline 과 비교 가능성 깨뜨림. metric 변경은 별도 PR 로 분리 권장.
- **vLLM / OpenRouter / 직접 API 백엔드 분기** — 동일 결과를 보장하는 backend 가 아니므로 backend 가 바뀌면 결과도 재측정해야 한다.

<!-- 코드 일정 수준 쌓이면 `.claude/rules/ml.md` 또는 `.claude/rules/training.md` 에 분리하고 여기서는 `@.claude/rules/<file>.md` 로 참조. -->

## CodeRabbit / Codex 조율

이 저장소는 PR 머지 전 자동 리뷰로 **CodeRabbit + ChatGPT-Codex** 를 사용한다. `github-dev:cr-fix` 명령이 양쪽을 동시에 처리한다.

| Source | Tier 정책 |
|--------|-----------|
| CodeRabbit `🚨 Bug` / `⚠️ Potential issue` / `🔒 Security` / `🔴 Critical-High` / `🟠 Major` | `gated` — 사용자 per-issue 확인 |
| CodeRabbit `🛠️ Refactor` (`🟡 Minor` / `🟢 Trivial` / `🟢 Info`) | `auto` — 자동 적용 |
| CodeRabbit `📝 Nitpick` | `skip` |
| Codex P1 (red), P2 (yellow) | `gated` |
| Codex P3 (green) | `skip` |

## 완료 보고

- 변경한 핵심 파일, 동작 변화, 영향받은 metric / checkpoint 를 짧게 말한다.
- 실행한 검증 (테스트, py_compile, 1-batch smoke run) 과 결과를 말한다.
- 실행하지 못한 검증 (예: 전체 학습) 이 있으면 이유 + 추정 비용을 밝힌다.
- 발견했지만 범위 밖인 문제는 임의로 고치지 말고 별도 메모로만 언급한다.

## Anti-patterns

- AI / Claude attribution 을 커밋, PR, 이슈, 문서에 추가하지 않는다.
- 이모지를 코드와 문서에 넣지 않는다.
- Drive-by refactor — 요청 범위 밖 코드를 임의로 리팩터링하지 않는다.
- 출력 파일, 체크포인트, 분석 노트북을 프로젝트 루트에 만들지 않는다 (`outputs/` 등 dedicated 디렉토리).
- `python` / `python3` 직접 호출 금지. `uv run python` 사용.
