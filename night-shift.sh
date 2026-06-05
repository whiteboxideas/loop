#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Usage: loop/night-shift.sh [iterations] [workdir]

Runs a basic autonomous Night Shift loop using Claude CLI.

Defaults:
  iterations            Defaults to NIGHTSHIFT_ITERATIONS or 999999.
  max runtime           Defaults to NIGHTSHIFT_MAX_SECONDS or 18000 seconds (5h).

Environment:
  NIGHTSHIFT_ITERATIONS Max iterations when omitted. Defaults to 999999.
  NIGHTSHIFT_MAX_SECONDS
                         Max wall-clock runtime from script start. Defaults to 18000.
                         Set to 0 to disable the time cap.
  NIGHTSHIFT_PROMPT     Prompt file to use. Defaults to loop/AGENT_LOOP.md.
  CLAUDE_BIN            Claude executable. Defaults to claude.
  CLAUDE_FLAGS          Extra Claude flags. Defaults to --dangerously-skip-permissions.

Completion:
  The loop stops early when the agent output contains <promise>COMPLETE</promise>.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

iterations="${1:-${NIGHTSHIFT_ITERATIONS:-999999}}"
if ! [[ "$iterations" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: iterations must be a positive integer." >&2
  exit 1
fi

max_seconds="${NIGHTSHIFT_MAX_SECONDS:-18000}"
if ! [[ "$max_seconds" =~ ^[0-9]+$ ]]; then
  echo "Error: NIGHTSHIFT_MAX_SECONDS must be a non-negative integer." >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
prompt_file="${NIGHTSHIFT_PROMPT:-$script_dir/AGENT_LOOP.md}"
workdir="${2:-$(pwd)}"
claude_bin="${CLAUDE_BIN:-claude}"
start_time="$(date +%s)"
end_time=$((start_time + max_seconds))

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
  now="$(date +%s)"
  if ((max_seconds > 0 && now >= end_time)); then
    echo "Night Shift reached the ${max_seconds}s time cap before iteration $i."
    exit 0
  fi

  if ((max_seconds > 0)); then
    remaining=$((end_time - now))
    echo "== Night Shift iteration $i/$iterations (${remaining}s remaining) =="
  else
    remaining=0
    echo "== Night Shift iteration $i/$iterations =="
  fi

  output_file="$(mktemp -t nightshift-output.XXXXXX)"
  status_file="$(mktemp -t nightshift-status.XXXXXX)"
  rm -f "$status_file"

  (
    set +e
    "$claude_bin" "${claude_flags[@]}" -p "$prompt" >"$output_file" 2>&1
    echo "$?" >"$status_file"
  ) &
  claude_pid=$!

  watcher_pid=""
  if ((max_seconds > 0)); then
    (
      sleep "$remaining"
      if kill -0 "$claude_pid" 2>/dev/null; then
        kill "$claude_pid" 2>/dev/null || true
        sleep 2
        kill -9 "$claude_pid" 2>/dev/null || true
      fi
    ) &
    watcher_pid=$!
  fi

  set +e
  wait "$claude_pid" 2>/dev/null
  wait_status=$?
  set -e

  if [[ -n "$watcher_pid" ]]; then
    kill "$watcher_pid" 2>/dev/null || true
    wait "$watcher_pid" 2>/dev/null || true
  fi

  result="$(<"$output_file")"
  rm -f "$output_file"

  echo "$result"

  if [[ -f "$status_file" ]]; then
    command_status="$(<"$status_file")"
    rm -f "$status_file"
  else
    command_status=124
  fi

  if [[ "$command_status" == "124" || "$wait_status" == "143" || "$wait_status" == "137" ]]; then
    echo "Night Shift stopped because the ${max_seconds}s time cap was reached."
    exit 0
  fi

  if [[ "$command_status" != "0" ]]; then
    echo "Claude command failed with exit code $command_status." >&2
    exit "$command_status"
  fi

  if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
    echo "Night Shift complete after $i iteration(s)."
    exit 0
  fi

done

echo "Night Shift stopped after $iterations iteration(s) without completion promise."
