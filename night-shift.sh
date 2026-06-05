#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Usage: loop/night-shift.sh <iterations> [workdir]

Runs a basic autonomous Night Shift loop using Claude CLI.

Environment:
  NIGHTSHIFT_PROMPT   Prompt file to use. Defaults to loop/AGENT_LOOP.md.
  CLAUDE_BIN          Claude executable. Defaults to claude.
  CLAUDE_FLAGS        Extra Claude flags. Defaults to --dangerously-skip-permissions.

Completion:
  The loop stops early when the agent output contains <promise>COMPLETE</promise>.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ -z "${1:-}" ]]; then
  usage >&2
  exit 1
fi

iterations="$1"
if ! [[ "$iterations" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: <iterations> must be a positive integer." >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
prompt_file="${NIGHTSHIFT_PROMPT:-$script_dir/AGENT_LOOP.md}"
workdir="${2:-$(pwd)}"
claude_bin="${CLAUDE_BIN:-claude}"

if [[ ! -f "$prompt_file" ]]; then
  echo "Error: prompt file not found: $prompt_file" >&2
  exit 1
fi

if [[ ! -d "$workdir" ]]; then
  echo "Error: workdir not found: $workdir" >&2
  exit 1
fi

# Intentional word splitting so callers can pass simple flag strings, e.g.
# CLAUDE_FLAGS='--model sonnet --dangerously-skip-permissions'
# shellcheck disable=SC2206
claude_flags=(${CLAUDE_FLAGS:---dangerously-skip-permissions})
prompt="$(<"$prompt_file")"

cd "$workdir"

for ((i = 1; i <= iterations; i++)); do
  echo "== Night Shift iteration $i/$iterations =="

  result="$($claude_bin "${claude_flags[@]}" -p "$prompt")"
  echo "$result"

  if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
    echo "Night Shift complete after $i iteration(s)."
    exit 0
  fi

done

echo "Night Shift stopped after $iterations iteration(s) without completion promise."
