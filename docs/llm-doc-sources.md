# LLM 문서 소스 레지스트리

플러그인 개발 중 라이브러리·런타임·플랫폼 사실을 확인할 때 참조하는 LLM 문서 소스 목록이다. 대부분은 `mcpdocs` MCP 서버(`mcpdoc`)에 `llms.txt` 인덱스로 등록되어 있고, `llms.txt` 가 없는 대상은 `deepwiki` MCP 로 조회한다. 이 문서는 실측 등록 상태를 그대로 반영한다 — 새 소스를 추가하면 이 표와 실제 `mcpdocs` 등록을 함께 갱신한다.

## 설정이 사는 곳

`mcpdocs` 는 **프로젝트 `.mcp.json` 이 아니라 사용자 스코프**(`~/.claude.json`, `claude mcp add` 로 등록)에 있다. 저장소 루트에는 `mcpdocs` 용 `.mcp.json` 이 없다 (루트에 존재하는 유일한 `.mcp.json` 은 `plugins/paper-search-tools/.mcp.json` 으로 무관한 paper-search 서버다). `mcpdoc` 는 모든 URL 을 단일 서버의 `--urls` 인자로 받으므로, 소스를 추가하려면 전체 목록을 다시 등록한다.

`mcpdoc` 는 재등록 시 `--urls` 에 준 목록으로 **통째로 교체**하므로, 하나라도 빠뜨리면 그 소스가 사라진다. 아래는 현재 16종 전체 + 신규 `github-docs` 를 명시한 실행 가능한 형태다 (이름에 공백이 있는 항목은 따옴표로 감쌌다). 실행 전 `claude mcp get mcpdocs` 로 현재 등록을 백업해 두면 실패 시 복구할 수 있다.

```bash
# (백업) 현재 --urls 목록 확인 — 아래 목록과 일치하는지 대조
claude mcp get mcpdocs

# 전체 목록 + github-docs 를 --scope user 로 재등록 (사용자 스코프 = ~/.claude.json)
claude mcp remove mcpdocs
claude mcp add mcpdocs --scope user -- npx @hapus/mcp-cache uvx --from mcpdoc mcpdoc \
  --urls \
  coderabbit:https://docs.coderabbit.ai/llms.txt \
  LangGraph:https://langchain-ai.github.io/langgraph/llms.txt \
  LangChain:https://python.langchain.com/llms.txt \
  'LangChain Python Wiki:https://raw.githubusercontent.com/teddynote-lab/mcp-langchain-docs/refs/heads/main/resources/langchain-wiki.md' \
  'LangGraph Python Wiki:https://raw.githubusercontent.com/teddynote-lab/mcp-langchain-docs/refs/heads/main/resources/langgraph-wiki.md' \
  cc-agents:https://gist.githubusercontent.com/YoungjaeDev/48821801580a8032b63e4961f127cbff/raw/llms-agents.txt \
  cc-commands:https://gist.githubusercontent.com/YoungjaeDev/48821801580a8032b63e4961f127cbff/raw/llms-commands.txt \
  cc-skills:https://gist.githubusercontent.com/YoungjaeDev/48821801580a8032b63e4961f127cbff/raw/llms-skills.txt \
  cc-mcps:https://gist.githubusercontent.com/YoungjaeDev/48821801580a8032b63e4961f127cbff/raw/llms-mcps.txt \
  cc-settings:https://gist.githubusercontent.com/YoungjaeDev/48821801580a8032b63e4961f127cbff/raw/llms-settings.txt \
  cc-hooks:https://gist.githubusercontent.com/YoungjaeDev/48821801580a8032b63e4961f127cbff/raw/llms-hooks.txt \
  cc-sandbox:https://gist.githubusercontent.com/YoungjaeDev/48821801580a8032b63e4961f127cbff/raw/llms-sandbox.txt \
  openrouter:https://openrouter.ai/docs/llms.txt \
  codex:https://developers.openai.com/codex/llms.txt \
  openai-api:https://developers.openai.com/api/docs/llms.txt \
  mem0:https://docs.mem0.ai/llms.txt \
  github-docs:https://docs.github.com/llms.txt \
  --allowed-domains '*' -

# 재시작 후 mcpdocs 의 list_doc_sources 가 17종(신규 github-docs 포함)을 보여주면 성공
```

> 보안 주의 — `--allowed-domains '*'` 는 mcpdoc 가 **모든 도메인**에서 문서를 가져오도록 허용한다. mcpdoc 기본값은 각 원격 `llms.txt` 의 호스팅 도메인만 자동 허용하므로, 인덱스가 교차 도메인 문서를 링크하지 않는다면 `*` 없이도 동작한다. 위 소스들은 gist·raw.githubusercontent·각 벤더 도메인에 흩어져 있어 실용상 `*` 를 쓰지만, 더 엄격히 하려면 실제 참조 도메인만 공백으로 나열한다 (`--allowed-domains docs.coderabbit.ai raw.githubusercontent.com gist.githubusercontent.com developers.openai.com ...`).

프로젝트 루트에 별도 `.mcp.json` 을 새로 만들지 않는다 — 사용자 스코프에 이미 같은 서버가 있으면 이중 등록으로 한쪽이 조용히 버려진다.

## 등록된 소스 (mcpdocs, 16종)

| 이름 | URL | 용도 (한 줄) |
|---|---|---|
| `coderabbit` | `https://docs.coderabbit.ai/llms.txt` | CodeRabbit 코드리뷰 봇 설정·동작 문서 (cr-fix 스킬의 tier/severity 근거) |
| `LangGraph` | `https://langchain-ai.github.io/langgraph/llms.txt` | LangGraph 그래프 오케스트레이션 API |
| `LangChain` | `https://python.langchain.com/llms.txt` | LangChain 파이썬 API |
| `LangChain Python Wiki` | `https://raw.githubusercontent.com/teddynote-lab/mcp-langchain-docs/refs/heads/main/resources/langchain-wiki.md` | teddynote-lab 의 LangChain 한국어 실전 위키 |
| `LangGraph Python Wiki` | `https://raw.githubusercontent.com/teddynote-lab/mcp-langchain-docs/refs/heads/main/resources/langgraph-wiki.md` | teddynote-lab 의 LangGraph 한국어 실전 위키 |
| `cc-agents` | `https://gist.githubusercontent.com/YoungjaeDev/48821801580a8032b63e4961f127cbff/raw/llms-agents.txt` | Claude Code 서브에이전트 정의 스펙 |
| `cc-commands` | `https://gist.githubusercontent.com/YoungjaeDev/48821801580a8032b63e4961f127cbff/raw/llms-commands.txt` | Claude Code 슬래시 커맨드 스펙 |
| `cc-skills` | `https://gist.githubusercontent.com/YoungjaeDev/48821801580a8032b63e4961f127cbff/raw/llms-skills.txt` | Claude Code 스킬(SKILL.md) 스펙 — 이 저장소의 주력 산출물 |
| `cc-mcps` | `https://gist.githubusercontent.com/YoungjaeDev/48821801580a8032b63e4961f127cbff/raw/llms-mcps.txt` | Claude Code MCP 서버 설정 스펙 |
| `cc-settings` | `https://gist.githubusercontent.com/YoungjaeDev/48821801580a8032b63e4961f127cbff/raw/llms-settings.txt` | Claude Code `settings.json` 스펙 |
| `cc-hooks` | `https://gist.githubusercontent.com/YoungjaeDev/48821801580a8032b63e4961f127cbff/raw/llms-hooks.txt` | Claude Code 훅 스펙 |
| `cc-sandbox` | `https://gist.githubusercontent.com/YoungjaeDev/48821801580a8032b63e4961f127cbff/raw/llms-sandbox.txt` | Claude Code 샌드박스·권한 스펙 |
| `openrouter` | `https://openrouter.ai/docs/llms.txt` | OpenRouter 통합 LLM 게이트웨이 API |
| `codex` | `https://developers.openai.com/codex/llms.txt` | OpenAI Codex CLI 문서 (멀티런타임 통합의 Codex 표면) |
| `openai-api` | `https://developers.openai.com/api/docs/llms.txt` | OpenAI 플랫폼 API |
| `mem0` | `https://docs.mem0.ai/llms.txt` | mem0 장기 메모리 API (mem0-ops 플러그인) |

## 추가 대상 (mcpdocs 에 신규 등록)

| 이름 | URL | 용도 (한 줄) | 검증 |
|---|---|---|---|
| `github-docs` | `https://docs.github.com/llms.txt` | GitHub 공식 문서 큐레이션 인덱스 + Article Body/Search API(마크다운 반환). github-dev 플러그인의 `gh` 워크플로 검증에 사용 | live, HTTP 200 (2026-07-14) |

위 재등록 스니펫의 `github-docs:...` 항목이 이 추가분이다. 등록 후 `mcpdocs` 재시작하면 `list_doc_sources` 에 나타난다.

## deepwiki 전용 타깃 (llms.txt 없음)

아래 대상은 공식 `llms.txt` 인덱스가 없어 `mcpdocs` 에 등록하지 않는다. 대신 `deepwiki` MCP(`ask_question` / `read_wiki_contents`)로 저장소 내부를 조회한다.

| 저장소 | 조회 경로 | 용도 (한 줄) | 검증 |
|---|---|---|---|
| `NousResearch/hermes-agent` | deepwiki MCP | Hermes Agent 런타임 (멀티런타임 통합의 Hermes 표면) | repo live, `llms.txt` 없음 — `main` 에서 HTTP 404 (2026-07-14) |
| `vercel-labs/skills` | deepwiki MCP | `npx skills` 스킬 설치 도구 (`scripts/install-skills.mjs` 가 래핑) | repo live, `llms.txt` 없음 — `main` 에서 HTTP 404 (2026-07-14) |
