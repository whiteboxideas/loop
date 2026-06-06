#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
prompt_file="$repo_root/AGENT_LOOP.md"
readme_file="$repo_root/README.md"

grep_fixed() {
  local needle="$1"
  local file="$2"
  if ! grep -Fq -- "$needle" "$file"; then
    echo "Expected to find '$needle' in $file" >&2
    exit 1
  fi
}

grep_fixed "## Task readiness analysis" "$prompt_file"
grep_fixed "READINESS DECISION" "$prompt_file"
grep_fixed "split it into smaller independently-checkable TODOs" "$prompt_file"
grep_fixed "origin reference" "$prompt_file"
grep_fixed "ask for human input" "$prompt_file"
grep_fixed "Do not leave the original broad or blocked task unchecked in Ready tasks" "$prompt_file"
grep_fixed "does not block later loop iterations" "$prompt_file"
grep_fixed "Do not create post-completion review" "$prompt_file"
grep_fixed 'Follow-up chain is `none`' "$prompt_file"
grep_fixed "ai:architect" "$prompt_file"
grep_fixed "## Task readiness analysis" "$readme_file"
grep_fixed "too complex" "$readme_file"
grep_fixed "Do not leave the original task unchecked in Ready tasks" "$readme_file"
grep_fixed "## Configurable follow-up chains" "$readme_file"
grep_fixed "Post-completion follow-up TODOs are opt-in" "$readme_file"
grep_fixed "--follow-up-chain ai:architect,ai:reviewer" "$readme_file"

echo "readiness analysis prompt coverage passed"
