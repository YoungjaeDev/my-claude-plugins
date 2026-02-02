# Oh-My-ClaudeCode Project Overview

## Purpose
Oh-My-ClaudeCode (OMC)는 Claude Code를 위한 멀티 에이전트 오케스트레이션 시스템입니다. oh-my-zsh에서 영감을 받아, Claude Code 사용을 위한 설정 없이 바로 사용할 수 있는 플러그인을 제공합니다.

## Key Features
- **28+ 전문 에이전트**: architect, researcher, explore, designer, writer, vision, critic, analyst, executor, planner, qa-tester, scientist 등
- **31+ 스킬**: orchestrate, ultrawork, ralph, planner, deepsearch, git-master 등
- **Magic Keywords**: ralph, ralplan, ulw, plan, autopilot 등 자연어 키워드로 모드 활성화
- **MCP Server 지원**: Context7, Exa, GitHub, Filesystem 등
- **HUD Statusline**: 실시간 오케스트레이션 상태 표시
- **Research Workflow**: 병렬 scientist 에이전트 오케스트레이션

## Tech Stack
- **Language**: TypeScript (ES2022, NodeNext modules)
- **Runtime**: Node.js 20+
- **Package Manager**: npm
- **Build Tool**: TypeScript Compiler (tsc)
- **Test Framework**: Vitest
- **Linting**: ESLint with TypeScript support
- **Formatting**: Prettier
- **Dependencies**:
  - @anthropic-ai/claude-agent-sdk
  - @ast-grep/napi (AST 분석)
  - zod (스키마 검증)
  - commander (CLI)
  - chalk (터미널 색상)

## Version
- Current: 3.3.9
- npm package: oh-my-claude-sisyphus

## Repository
- GitHub: https://github.com/Yeachan-Heo/oh-my-claudecode
