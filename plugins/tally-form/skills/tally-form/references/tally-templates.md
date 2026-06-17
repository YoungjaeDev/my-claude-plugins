# Tally 템플릿 레퍼런스 인덱스

새 폼을 만들 때 구조·디자인을 참고할 Tally 공식 템플릿 모음. 이 스킬은 md → 블록을 결정적으로 빌드하므로 템플릿을 임포트하지는 않는다. 패턴(섹션 구성·문항 흐름)만 참고해 체크리스트 md 를 쓴다. 프리셋 보이스의 distill 출처이기도 하다.

| 템플릿 | URL | 용도 | 구조 / 디자인 메모 |
|--------|-----|------|--------------------|
| Web Project Intake Questionnaire | `tally.so/templates/web-project-intake-questionnaire/w44adw` | 웹 프로젝트 인테이크 | 기능 우선순위 + 자유 입력 혼합. dev-survey 프리셋 출처. |
| Project Intake Form | `tally.so/templates/project-intake-form/mBB15m` | 일반 프로젝트 인테이크 | 개요→범위→일정 흐름. dev-survey 프리셋 출처. |
| Project Intake Form (Template) | `tally.so/templates/project-intake-form-template/wQ0aX3` | 프로젝트 인테이크 변형 | 짧은 필수 필드 위주. 경량 인테이크 참고. |
| Course Registration Form | `tally.so/templates/course-registration-form-template/3N09On` | 강의 수강 신청 | 신청자 정보 + 분야 선택. lecture 프리셋 출처. |
| Pre-assessment for Coaching | `tally.so/templates/pre-assessment-for-coaching/mD4Abm` | 코칭 사전 평가 | 현재 수준·목표 진단 문항. lecture 프리셋 출처. |
| User Onboarding Survey | `tally.so/templates/user-onboarding-survey-template/PmObkn` | 사용자 온보딩 설문 | 짧은 객관식 중심. 가벼운 만족도/온보딩 참고. |

- 일정 조율은 외부 스케줄러(Cal.com/Calendly) 대신 네이티브 `%%matrix`(요일×시간대) / `%%date` / `%%time` 로 처리(외부 스케줄러는 oEmbed 비대상 → Tally 임베드 불가, 링크아웃만 가능).
- 대화형 편집이 필요하면 공식 Tally MCP(`api.tally.so/mcp`, beta)도 있으나 이 스킬은 채택하지 않는다(결정성·idempotent·무의존성 보존).
