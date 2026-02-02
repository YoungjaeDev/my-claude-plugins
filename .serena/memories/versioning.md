# Versioning Rules (youngjaedev fork)

## 버전 형식

```
MAJOR.MINOR.PATCH-youngjaedev.BUILD
```

**예시:** `3.5.7-youngjaedev.1`

| 부분 | 설명 |
|------|------|
| `MAJOR.MINOR.PATCH` | upstream 버전 기준 |
| `-youngjaedev` | fork 식별자 |
| `.BUILD` | fork 내 빌드 번호 |

## 버전 업데이트 규칙

### Fork 내 변경 시
- 새 기능 추가: BUILD +1 (예: `.1` → `.2`)
- 버그 수정: BUILD +1
- 문서만 변경: 선택적

### Upstream 머지 시
- PATCH+1, BUILD 리셋 (예: `3.5.7-youngjaedev.3` → `3.5.8-youngjaedev.1`)

## 버전 파일 위치

```
.claude-plugin/plugin.json → "version" 필드
```

## 현재 버전

`3.5.7-youngjaedev.1` (2026-01-27)
- humanizer skill/agent 추가

## 참조 문서

`docs/VERSIONING.md` - 전체 버전 규칙
