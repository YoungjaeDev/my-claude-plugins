#!/usr/bin/env bash
# infer-github-context.sh
#
# gh CLI 로 personal account + 사용자가 멤버인 모든 org 를 수집해
# JSON 으로 stdout 출력. /project-init:new Phase 0 에서 owner 후보 시드용.
#
# 출력 예시:
#   {"personal":"youngjaedev","orgs":["hansungts","my-org-2"]}
#
# 실패 조건:
#   - gh CLI 미설치 또는 미인증 → exit 1, stderr 에 안내
#   - gh api 호출 실패 → exit 2

set -euo pipefail

# gh CLI 존재 확인
if ! command -v gh >/dev/null 2>&1; then
  echo "[infer-github-context] gh CLI not installed. Install: https://cli.github.com/" >&2
  exit 1
fi

# Auth 확인
if ! gh auth status >/dev/null 2>&1; then
  echo "[infer-github-context] gh CLI not authenticated. Run: gh auth login" >&2
  exit 1
fi

# Personal account
PERSONAL=$(gh api user --jq '.login' 2>/dev/null || true)
if [ -z "$PERSONAL" ]; then
  echo "[infer-github-context] failed to fetch personal account" >&2
  exit 2
fi

# Orgs (paginated)
# Note: gh CLI rejects --slurp + --jq together, so we pipe to local jq.
# --slurp wraps multi-page responses as array-of-arrays; [.[][].login] flattens.
ORGS_JSON=$(gh api --paginate --slurp /user/orgs 2>/dev/null | jq -c '[.[][].login]' 2>/dev/null || echo "[]")
if [ -z "$ORGS_JSON" ]; then
  ORGS_JSON="[]"
fi

# 최종 JSON 조립 — jq 가 -c 로 compact 출력
jq -nc --arg personal "$PERSONAL" --argjson orgs "$ORGS_JSON" \
  '{personal: $personal, orgs: $orgs}'
