# PRD Suite Plugin

PRD, Tech Spec, Use Case, IA 문서를 순차 질문 방식으로 작성하는 플러그인입니다.

## 커맨드

| 커맨드 | 설명 | 출력 경로 |
|--------|------|----------|
| `/prd-suite:prd` | PRD 작성 | `docs/prd/{project}-prd.md` |
| `/prd-suite:tech-spec` | Tech Spec 작성 | `docs/tech-spec/{project}-tech-spec.md` |
| `/prd-suite:usecase` | Use Case 작성 | `docs/usecase/{project}-usecase.md` |
| `/prd-suite:ia` | IA 작성 | `docs/ia/{project}-ia.md` |
| `/prd-suite:spec-all` | 전체 순차 실행 | 위 4개 문서 모두 |

## 워크플로우

각 문서는 순차 질문 방식으로 작성됩니다:
1. 필요한 정보를 하나씩 질문
2. 답변을 바탕으로 초안 작성
3. interactive-review로 검토
4. 수정 사항 반영 후 최종 저장

## 핵심 원칙

- **템플릿 엄수**: 문서 구조 변경 금지
- **순차 질문**: 한 번에 하나씩 질문
- **실무 중심**: 즉시 활용 가능한 구체성
- **단순성 우선**: 불필요한 복잡성 배제
