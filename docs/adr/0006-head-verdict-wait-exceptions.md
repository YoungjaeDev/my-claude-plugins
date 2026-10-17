# HEAD 판정 대기의 예외: Minor 이하 수정은 머지 뒤 리뷰 없이 base 로 가고, 막힌 리뷰어는 빠진다

ADR 0002 의 HEAD 판정 대기는 PR 머지에 그대로 적용된다. 켜진 리뷰어 전원이 판정을 낸 HEAD 만 머지한다. 예외는 둘이다.

## Minor 이하 수정은 머지 뒤 base 로 간다

한 사이클에서 반영한 수정이 전부 Minor 이하 지적(CodeRabbit Minor·Trivial·Info, Codex P2)에서 왔으면 그 수정은 PR 에 push 해서 재리뷰를 받지 않는다. 판정을 받은 HEAD 를 먼저 머지하고, 수정은 PR 의 base 에 바로 push 한다. 기본 브랜치를 base 로 둔 PR 이면 main 이다. 수정 하나라도 Critical·High·Major, `🔒 Security & Privacy`, Codex P0·P1 에서 왔거나 판정에서 high 로 다시 매겨졌으면 예외가 아니다. 그때는 PR 에 push 하고 재리뷰를 기다린다. 결정 당시 review-loop 는 Minor 수정 하나에도 push 와 CodeRabbit 재리뷰 한 라운드를 돌렸다. CodeRabbit 은 비용과 횟수 한도가 있고, 그 라운드가 찾는 것은 다시 Minor 였다.

판정은 `plugins/dev/skills/review-loop/scripts/auto-merge-gate.sh` 의 `next_action` (`rereview_push` | `merge_then_main_push`) 이 내린다. base 로 가기 전에 머지된 base 위에서 build/test 와 pre-commit 가드가 통과해야 하고, 실패하면 base 로 가지 않는다. base 가 보호돼 있으면 직접 push 할 수 없으므로 재리뷰로 돌아간다. 머지하지 않기로 했을 때(자격 없음, 사용자가 거절, 물어볼 도구 없음)도 수정은 PR 로 간다.

## 막힌 리뷰어는 빼고 끝낸다

리뷰어가 자기 대기 상한(CodeRabbit 은 `TIMEOUT`, Codex 는 Codex 대기 예산)이 지나도 HEAD 에 판정을 내지 않으면 막힌 것으로 본다. CodeRabbit 의 상한은 push(또는 그보다 늦은 첫 요청) 기준 `TIMEOUT` 하나다. 그 절반이 지나도 판정이 없고 그 HEAD 에 요청이 아직 없으면 `@coderabbitai review` 를 한 번 올리고, 남은 절반만 기다린다. 재촉이 상한을 다시 세지 않으므로 최악 대기는 `TIMEOUT` 이다. 상한까지 판정이 없으면 뺀다. Codex 는 재촉하지 않고 상한에서 뺀다. Codex 대기 예산 기본값은 ADR 0002 가 잰 가장 늦은 Codex 리뷰(726초)보다 큰 900초다 (`scripts/codex-turnaround.sh`): 늦지만 정상인 리뷰가 빠지지 않게 한다. 읽을 수 없는 리뷰어(재촉 여부를 확인하는 댓글 조회 실패, 👍 만이 판정일 수 있는데 반응 조회 실패 포함)는 빼지 않는다. `@codex review` 금지는 그대로이고, Codex 는 push 마다 알아서 돈다. 뺀 리뷰어는 그 실행의 나머지 동안 꺼지고, 남은 리뷰어의 판정으로 HEAD 를 판정한다. 이름은 종료 판정 출력과 최종 JSON 의 `dropped_reviewers`, 최종 보고에 남는다. 리뷰어를 뺀 실행은 `--auto-merge` 가 있어도 사용자에게 머지를 묻는다. 남은 리뷰어가 없거나 읽을 수 없는 리뷰어만 남으면 예전처럼 `timeout` 이다. 결정 당시 PR #315 에서 CodeRabbit 이 push 뒤 6시간 동안 아무것도 내지 않았고, 일시정지·rate limit 표시도 없어 재요청 조건에 걸리지 않았다. 루프는 timeout 으로 끝났고 사용자가 손으로 머지했다.

판정은 `plugins/dev/skills/review-loop/scripts/head-verdicts.sh` 가 내린다 (`stuck` 상태와 `dropped`). Codex 가 지적 없이 PR 에 남기는 👍 반응은 push 뒤에 생긴 것이면 clean 판정으로 읽으므로, 그 경우는 막힌 것으로 치지 않는다.

## Considered Options

- 막힌 Codex 에 `@codex review` 로 재촉한다: 버렸다. PR 댓글 정책이 금지하고, Codex 는 push 마다 스스로 리뷰한다.
- 막힌 리뷰어가 있으면 지금처럼 `timeout` 으로 끝낸다: 버렸다. 남은 리뷰어가 판정을 냈는데도 머지 판단까지 가지 않아, 사용자가 손으로 머지하면서 처리하지 않은 지적이 들어갔다.
- 반복 상한을 낮춰 CodeRabbit 소비를 줄인다: 버렸다. 상한은 Major 수정의 재리뷰까지 같이 자르고, Minor 수정 하나가 라운드를 쓰는 것은 그대로다.
- 두 번째 라운드부터의 Codex P2 를 판정 없이 후속 이슈로 미룬다 (이전 규칙): 버렸다. `tbd` 이슈가 쌓였고 지적 0건짜리 빈 이슈(#316)도 생겼다. 이제 P2 는 다른 지적처럼 판정하고, 반영한 P2 가 다음 라운드의 재료가 되는 것은 이 예외가 막는다.

## Consequences

- base 에는 리뷰어가 보지 않은 커밋이 들어간다. 그 커밋은 build/test 와 pre-commit 가드만 거친다.
- 머지는 `--auto-merge` 가 있거나 사용자가 "auto-merge 할까요?" 에 예라고 답할 때만 일어난다. 리뷰가 끝났는데 조용히 멈추지 않는다.
- 뺀 리뷰어가 늦게 낸 지적은 그 실행에서 다루지 않는다. 사용자는 최종 보고에서 이름을 보고 머지 질문에 답한다.

출처: GitHub issue #322 (spec), #327, #328
