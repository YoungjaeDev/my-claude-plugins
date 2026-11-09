#!/usr/bin/env bash
# Smoke test: dev:new Step 0 preflight guard (issue #391). The guard refuses any
# non-empty cwd, except a recovery run: an in_progress record shaped as Phase 0.5
# writes it, with nothing in cwd beyond what dev:new itself seeds.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
SKILL="$HERE/../skills/new/SKILL.md"
PROC="$HERE/../references/new-procedure.md"
fail=0; pass(){ echo "  PASS: $1"; }; die(){ echo "  FAIL: $1"; fail=1; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# The first bash block under "## Step 0" is the guard, run as written.
GUARD="$TMP/guard.sh"
awk '/^## Step 0/{s=1} s&&/^```bash/{f=1;next} f&&/^```/{exit} f{print}' "$SKILL" > "$GUARD"
[ -s "$GUARD" ] || { echo "  FAIL: no Step 0 bash block in $SKILL"; exit 1; }

# fixture <name>: a fresh cwd named my-app, so the record slug is my-app.
fixture() { D="$TMP/$1/my-app"; mkdir -p "$D"; }
# The record comes from the real Phase 0.5 block, so a writer change that the
# guard no longer accepts fails here. record [jq-mutation] : write it, then mutate.
P05="$TMP/phase05.sh"
awk '/^## Phase 0.5/{s=1} s&&/^```bash/{f=1;next} f&&/^```/{exit} f{print}' "$PROC" > "$P05"
[ -s "$P05" ] || { echo "  FAIL: no Phase 0.5 bash block in $PROC"; exit 1; }
record() {
  (cd "$D" && bash "$P05" >/dev/null) || die "Phase 0.5 block failed in $D"
  R="$D/.claude/state/project-init-my-app.json"
  [ -z "${1:-}" ] || { jq "$1" "$R" > "$R.tmp" && mv "$R.tmp" "$R"; }
}
seeded() {  # what Phases 2-6 leave behind when a later phase fails
  mkdir -p "$D/.claude/spec" "$D/.claude/rules" "$D/.llmwiki/raw" "$D/.llmwiki/wiki" "$D/.git"
  : > "$D/.claude/spec/.gitkeep"; : > "$D/.claude/rules/.gitkeep"
  : > "$D/.llmwiki/raw/.gitkeep"; : > "$D/.llmwiki/wiki/.gitkeep"
  for f in CLAUDE.md AGENTS.md README.md CHANGELOG.md .gitignore; do : > "$D/$f"; done
}
expect() {  # expect <pass|abort> <label>
  if (cd "$D" && bash "$GUARD" >/dev/null 2>&1); then got=pass; else got=abort; fi
  [ "$got" = "$1" ] && pass "$2 -> $got" || die "$2: expected $1, got $got"
}

fixture empty;        expect pass  "empty dir"
fixture project;      mkdir -p "$D/src"; : > "$D/src/main.py"; expect abort "unrelated project"
fixture gitonly;      mkdir -p "$D/.git"; expect abort ".git without a record"
fixture rec;          record; expect pass "in_progress record after Phase 0.5"
fixture recseed;      record; seeded; expect pass "in_progress record + seeded files"
fixture recextra;     record; seeded; mkdir -p "$D/src"; : > "$D/src/main.py"
                      expect abort "record + unrelated source file"
fixture recdir;       record; mkdir -p "$D/.claude/agents"; : > "$D/.claude/agents/x.md"
                      expect abort "record + unseeded .claude entry"
fixture done;         record '.status = "completed" | .conclusion = "success"'; expect abort "completed record"
fixture schema;       record '.schema = "other/v1"'; expect abort "foreign schema"
fixture runid;        record '.run_id = "project-init-other"'; expect abort "foreign run_id"
fixture broken;       mkdir -p "$D/.claude/state"; echo '{' > "$D/.claude/state/project-init-my-app.json"
                      expect abort "unparsable record"

[ "$fail" = 0 ] && echo "dev new guard smoke: ALL PASS" || { echo "dev new guard smoke: FAILURES"; exit 1; }
