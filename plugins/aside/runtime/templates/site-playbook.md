# <domain> Playbook

- status: candidate
- scope: <지원하는 작업과 제외 범위>
- account_alias: <별칭>
- browser_profile_alias: <별칭>
- last_verified_at: null
- cli_version: <실제 조회한 버전>

## 전제조건 및 진입 경로
사용자 제공 또는 실제 관찰한 URL, 로그인 전제조건. 자격증명 금지.

## 페이지 구조와 UI 단서
실제 관찰한 역할/라벨/메뉴. snapshot ref를 영구 저장하지 않는다.

## 성공 절차
현재 화면을 다시 관찰하며 따라갈 의미 기반 단계.

## 실패 징후와 복구
증상 / 실제 원인 또는 미검증 가설 / 시도 결과 / 안전한 다음 행동.

## 완료 검증
사이트 상태, 레코드, 다운로드 내용 등 관찰 가능한 기준.

## 검증 이력
- request_id / 날짜 / 관찰 근거 / candidate 또는 verified.
독립 재실행 전에는 verified로 쓰지 않는다.
