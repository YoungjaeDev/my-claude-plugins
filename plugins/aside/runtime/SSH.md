# Orin → Mac → Aside 직접 호출

이 경로에는 Mac의 Claude Code 또는 Hermes 모델 호출이 필요하지 않다. Orin의 기존 에이전트가 SSH로 Mac의 공용 게이트와 Aside CLI를 실행한다. Aside의 자체 에이전트·인증·브라우저 호스트는 정상이어야 한다. Mac 전문 봇/Claude 플러그인에 작업 전체를 맡기는 경로는 별도의 선택 사항이다.

## 전제
- Orin의 SSH 별칭 `macbook`이 올바른 Mac 계정에 연결돼야 한다. 키와 known_hosts는 사용자가 안전하게 설정한다. host-key 검증을 끄거나 개인키/비밀번호를 기록하지 않는다.
- 이 Mac 기본 기록·런타임 루트는 `~/aside-ops`. 사용자 지정이면 모든 명령의 OPS_ROOT와 모든 기록 경로를 동일한 절대 경로로 바꾼다. 로컬 Orin의 ASIDE_OPS_ROOT가 SSH에 자동 전달된다고 가정하지 않는다.
- 비대화형 SSH는 `.zshrc`의 PATH를 기대하지 않는다. 아래처럼 Mac에서 PATH를 명시한다.

## 1. 준비 상태
Orin에서 실행한다:
```bash
ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=8 macbook 'export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"; OPS_ROOT="$HOME/aside-ops"; command -v aside; python3 "$OPS_ROOT/bin/aside_gate.py" --root "$OPS_ROOT" status'
```
예약이 있으면 기존 작업을 조정한다. 다른 요청의 예약을 지우거나 강탈하지 않는다. `aside --version`이 된다는 것만으로 브라우저까지 실행 가능한 것은 아니다.

## 2. 직접 작업 실행
먼저 공유 README의 범위·기록 계약에 따라 고유 request ID와 request.json을 준비한다. 아래 `ssh-readonly-UNIQUE-ID`는 **작업마다 새 값으로 교체**한다. 이것은 공개 페이지 조회 예시이지 임의 사이트 쓰기 권한이 아니다.
```bash
ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=8 macbook 'export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"; OPS_ROOT="$HOME/aside-ops"; python3 "$OPS_ROOT/bin/aside_gate.py" --root "$OPS_ROOT" run --request-id ssh-readonly-UNIQUE-ID --owner hermes -- exec --permission guard "Read-only task: inspect https://example.com/ only. Use an exact matching tab, or open that URL if absent. Return the actual Aside session ID and direct browser tool output for page.url() and page.title(). Do not inspect unrelated tabs, send, purchase, delete, log in, change settings, or close tabs. Stop after observation."'
```
- `--owner hermes`는 Orin의 호출자가 Hermes인 예다. Claude 호출자는 `claude-code`로 통일한다. 같은 작업의 후속 명령은 원래 owner/request ID를 유지한다.
- 요청 문장은 하나의 안전하게 인용된 인자다. 동적 요청을 SSH 명령 문자열에 그대로 연결하지 않는다. 프로그래밍 호출자는 argv 배열을 만들고 SSH의 원격 쉘 경계도 올바르게 인용한다. 페이지/요청 파일의 shell 문자열을 실행하지 않는다.
- 실제 도구의 URL/title 등 완료 근거와 Aside session ID를 확인한다. CLI exit 0이나 요약문만으로 성공이라고 하지 않는다.
- 이 명령은 request/result 파일을 자동 작성하는 큐가 아니다. 호출 에이전트가 SSH/scp로 Mac의 같은 `runs/<id>/` 기록을 관리하고 실제 결과를 기록한다. 파일을 Orin에 내려받는 것은 원격 마운트 없이도 가능하다. 인증 파일은 전송하지 않는다.

## 3. 종료 확인 → 기록 → 해제
현재 설치 CLI에서 `session list`로 정확한 session ID의 idle/종료 상태를 확인할 수 있다. 실행 중이거나 결과가 불명확하면 예약을 유지한다. 조회도 같은 게이트를 사용한다:
```bash
ssh -o BatchMode=yes -o StrictHostKeyChecking=yes macbook 'export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"; OPS_ROOT="$HOME/aside-ops"; python3 "$OPS_ROOT/bin/aside_gate.py" --root "$OPS_ROOT" run --request-id ssh-readonly-UNIQUE-ID --owner hermes -- session list'
```
무관한 세션은 기록하지 않는다. 실제 완료·안전한 종료를 확인하고 result.json을 쓴 후에만:
```bash
ssh -o BatchMode=yes -o StrictHostKeyChecking=yes macbook 'OPS_ROOT="$HOME/aside-ops"; python3 "$OPS_ROOT/bin/aside_gate.py" --root "$OPS_ROOT" release --request-id ssh-readonly-UNIQUE-ID --owner hermes && python3 "$OPS_ROOT/bin/aside_gate.py" --root "$OPS_ROOT" status'
```
해제 상태를 다시 읽고 결과 파일에 반영한다. 명령 종료와 브라우저 작업 종료를 혼동하지 않는다.

## 실패·인증 재개
- 실행파일을 시작하지 못한 확실한 실패는 새 예약만 제거한다. 이미 있던 예약은 유지한다. 시작된 CLI가 126/127을 반환해도 자동 해제되지 않는다. 항상 status와 실제 세션을 확인한다.
- 로그인·2FA·권한 승인 필요 시 `waiting_for_user`와 실제 session ID, 필요한 사용자 행동을 기록하고 돌아간다. 승인/로그인을 우회하거나 원격 키체인 토큰을 복사하지 않는다.
- 명시적 계속 요청 후 같은 요청/owner/루트로 `session resume <actual-session-id> <follow-up>`을 게이트를 거쳐 실행한다. 실제 ID가 null이면 없는 세션을 만들지 말고 미실행 여부부터 조정한다.
- SSH 단절·timeout만으로 실패라고 단정하거나 같은 쓰기를 다시 실행하지 않는다. Aside 세션·사이트 결과를 확인한다. SSH 프로세스를 죽였다고 Aside 세션이 멈췄다고 주장하지 않는다.
- 비대화형 명령 승인에 막히면 승인을 요청한다. TTY가 필요하면 사용자와 대화형 경로를 선택한다. 전역 allow/bypass 또는 다른 실행 계층으로 승인을 우회하지 않는다.

## 선택적 전문 에이전트 경로
Mac의 Hermes `aside-operator`나 Claude 플러그인을 SSH로 시작할 수도 있지만, 그때는 해당 모델 인증과 명령 승인도 별도로 필요하다. 이 선택적 경로의 Claude `Not logged in`은 위 직접 Aside 경로의 필수 장애가 아니다. 새 서버/MCP/peer/watcher는 필요하지 않다.
