# HEAD 판정 대기의 예외: Minor 이하 수정은 머지 뒤 리뷰 없이 base 로 간다

ADR 0002 의 HEAD 판정 대기는 PR 머지에 그대로 적용된다. 켜진 리뷰어 전원이 판정을 낸 HEAD 만 머지한다. 예외는 하나다. 한 사이클에서 반영한 수정이 전부 Minor 이하 지적(CodeRabbit Minor·Trivial·Info, Codex P2)에서 왔으면 그 수정은 PR 에 push 해서 재리뷰를 받지 않는다. 판정을 받은 HEAD 를 먼저 머지하고, 수정은 PR 의 base 에 바로 push 한다. 기본 브랜치를 base 로 둔 PR 이면 main 이다. 수정 하나라도 Critical·High·Major, `🔒 Security & Privacy`, Codex P0·P1 에서 왔거나 판정에서 high 로 다시 매겨졌으면 예외가 아니다. 그때는 PR 에 push 하고 재리뷰를 기다린다. 결정 당시 review-loop 는 Minor 수정 하나에도 push 와 CodeRabbit 재리뷰 한 라운드를 돌렸다. CodeRabbit 은 비용과 횟수 한도가 있고, 그 라운드가 찾는 것은 다시 Minor 였다.

판정은 `plugins/dev/skills/review-loop/scripts/auto-merge-gate.sh` 의 `next_action` (`rereview_push` | `merge_then_main_push`) 이 내린다. base 로 가기 전에 머지된 base 위에서 build/test 와 pre-commit 가드가 통과해야 하고, 실패하면 base 로 가지 않는다. base 가 보호돼 있으면 직접 push 할 수 없으므로 재리뷰로 돌아간다. 머지하지 않기로 했을 때(자격 없음, 사용자가 거절, 물어볼 도구 없음)도 수정은 PR 로 간다.

## Considered Options

- 반복 상한을 낮춰 CodeRabbit 소비를 줄인다: 버렸다. 상한은 Major 수정의 재리뷰까지 같이 자르고, Minor 수정 하나가 라운드를 쓰는 것은 그대로다.
- 두 번째 라운드부터의 Codex P2 를 판정 없이 후속 이슈로 미룬다 (이전 규칙): 버렸다. `tbd` 이슈가 쌓였고 지적 0건짜리 빈 이슈(#316)도 생겼다. 이제 P2 는 다른 지적처럼 판정하고, 반영한 P2 가 다음 라운드의 재료가 되는 것은 이 예외가 막는다.

## Consequences

- base 에는 리뷰어가 보지 않은 커밋이 들어간다. 그 커밋은 build/test 와 pre-commit 가드만 거친다.
- 머지는 `--auto-merge` 가 있거나 사용자가 "auto-merge 할까요?" 에 예라고 답할 때만 일어난다. 리뷰가 끝났는데 조용히 멈추지 않는다.

출처: GitHub issue #322 (spec), #327
