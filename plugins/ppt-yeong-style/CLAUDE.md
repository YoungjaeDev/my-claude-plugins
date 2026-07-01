# ppt-yeong-style Plugin

yeong 스타일 강의·제안 덱 작성 규약. **ppt-master**(빌드 엔진) 위에 얹는 작성 레이어 — 엔진은 손대지 않고, 그 위에서 무엇을·어떻게 쓸지를 일관 적용한다.

## Skill

| Skill | Description |
|-------|-------------|
| `ppt-yeong-style` | 미감 시그니처(§0)·덱 유형·md 소스 규약·작성 원칙 15종·밀도 리듬(중간 강화 기본)·역할 기반 색·codex-image vs SVG 경계·앱 UI 실물 강제·ppt-master 레버 조합 차별화·빌드 후 스토리 흐름 review·공식 로고 fetch·윤문·렌더 QA. 진입점 = `SKILL.md`, 세부는 `references/` 6종 + `assets/injection-prompt.md` |

## 엔진·의존 관계

- **ppt-master** = 빌드 엔진(spec_lock·finalize_svg·svg_to_pptx·anti-slop 7-step). 구현 owner이며 **bare name으로 참조**(vendor 금지). 이 스킬은 그 위 "작성 규약" 레이어.
- 의존 스킬은 **있으면 사용, 없으면 graceful degrade**: `codex-image`(이미지)·`interview`(인터뷰)·`anti-slop-design`(영문 slop·디자인 감사)·`humanize-korean`(한국어 윤문)·`design-shotgun`(색 후보 생성).

## 구조

```text
ppt-yeong-style/
├── .claude-plugin/plugin.json
├── CLAUDE.md                       # 이 파일
└── skills/ppt-yeong-style/
    ├── SKILL.md                    # 진입점: §0 미감 시그니처 + 파이프라인 + md 규약 + 원칙 15 + 밀도 리듬 + §4 레버 조합
    ├── references/
    │   ├── design-language.md      # §0 상세: 시그니처 6축 + anti-slop↔하이엔드 양립표 + ppt-master 레버 락 (색·이미지·craft의 상위 미감 계약)
    │   ├── color-typography.md     # 색·타이포 (역할 기반 팔레트 + 폰트 폴백 + 타입 스케일·톤 + 토큰 예)
    │   ├── images-and-pop.md       # codex vs SVG 경계 + fade 범위 + 마스코트/pop + 스크린샷 배치(앱 UI 실물 강제)
    │   ├── icons-logos.md          # 공식 SVG fetch → 인라인 → 근접성 → 상표권
    │   ├── ppt-master-craft.md     # ppt-master 레버 6종·조합 레시피·정확도 충실도·함정 (§4 상세)
    │   └── ppt-master-and-qa.md    # ppt-master 7-step(참조) + 윤문 + 완료 QA + 스토리 흐름 review + 실사용 주의
    └── assets/
        └── injection-prompt.md     # 다른 세션 주입용 압축 프롬프트(복붙 페이로드)
```

## Hermes Agent

monorepo 서브디렉토리에서 플러그인을 설치:

```bash
hermes plugins install YoungjaeDev/my-claude-plugins/plugins/ppt-yeong-style --enable
hermes gateway restart  # 메시징 게이트웨이로 Hermes를 쓰는 경우
```

스킬을 명시적으로 로드 (Hermes plugin skill은 opt-in, `--enable` 후 새 Hermes 세션 시작):

```text
skill_view("ppt-yeong-style:ppt-yeong-style")
```

- 스킬 본문은 Claude/Codex 도구 용어(`Bash`, `Read`, `AskUserQuestion`, 이미지 생성, `Skill`)를 Hermes 도구(`terminal`, `read_file`, `clarify`, `image_generate`, `skill_view`)로 매핑하는 호환 표를 포함한다.
- 전제: 빌드 엔진인 외부 `ppt-master` 플러그인 enable + `uv` 설치가 필요하다. 미설치 시 빌드 진입 전 중단.
