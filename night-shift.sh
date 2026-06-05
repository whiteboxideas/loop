#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Usage:
  loop/night-shift.sh [duration] [project]
  loop/night-shift.sh --duration 5h --project ../hello-world [--iterations 50]

Runs a basic autonomous Night Shift loop using pi in headless print mode.

Project contract:
  Night Shift tooling stays in loop/.
  Project-specific task/config files stay in <project>/.nightshift/.
  Required project files:
    <project>/.nightshift/TODO.md
    <project>/.nightshift/DEFINITION_OF_DONE.md

Duration formats:
  0       Disable time cap.
  300     Seconds.
  30m     Minutes.
  5h      Hours.

Defaults:
  project               Defaults to NIGHTSHIFT_PROJECT or current directory.
  iterations            Defaults to NIGHTSHIFT_ITERATIONS or 999999.
  max runtime           Defaults to NIGHTSHIFT_MAX_SECONDS or 18000 seconds (5h).

Environment:
  NIGHTSHIFT_PROJECT    Project directory to run against.
  NIGHTSHIFT_ITERATIONS Max iterations. Defaults to 999999.
  NIGHTSHIFT_MAX_SECONDS
                         Max wall-clock runtime from script start. Defaults to 18000.
                         Accepts seconds, Nm, Nh. Set to 0 to disable.
  NIGHTSHIFT_PROMPT     Prompt file to use. Defaults to loop/AGENT_LOOP.md.
  NIGHTSHIFT_LOG_DIR    Directory for logs. Defaults to <project>/.nightshift/logs
                         when .nightshift exists; otherwise loop/logs for config errors.
  PI_BIN                pi executable. Defaults to pi.
  PI_FLAGS              Extra pi flags. Defaults to -p.

Logs:
  General run log:      <log-dir>/night-shift.log
  Per-run detail logs:  <log-dir>/runs/<run-id>.log

Completion:
  The loop stops early when the agent output contains <promise>COMPLETE</promise>.
USAGE
}

timestamp_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

parse_duration_seconds() {
  local value="$1"
  local number

  if [[ "$value" == "0" ]]; then
    echo 0
    return 0
  fi

  if [[ "$value" =~ ^[1-9][0-9]*$ ]]; then
    echo "$value"
    return 0
  fi

  if [[ "$value" =~ ^([1-9][0-9]*)([sSmMhH])$ ]]; then
    number="${BASH_REMATCH[1]}"
    case "${BASH_REMATCH[2]}" in
      s|S) echo "$number" ;;
      m|M) echo $((number * 60)) ;;
      h|H) echo $((number * 3600)) ;;
    esac
    return 0
  fi

  return 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

iterations="${NIGHTSHIFT_ITERATIONS:-999999}"
max_seconds_input="${NIGHTSHIFT_MAX_SECONDS:-18000}"
workdir="${NIGHTSHIFT_PROJECT:-$(pwd)}"
positional=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --duration|--max-seconds|--for)
      if [[ -z "${2:-}" ]]; then
        echo "Error: $1 requires a value." >&2
        exit 1
      fi
      max_seconds_input="$2"
      shift 2
      ;;
    --project|--workdir)
      if [[ -z "${2:-}" ]]; then
        echo "Error: $1 requires a value." >&2
        exit 1
      fi
      workdir="$2"
      shift 2
      ;;
    --iterations)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --iterations requires a value." >&2
        exit 1
      fi
      iterations="$2"
      shift 2
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        positional+=("$1")
        shift
      done
      ;;
    -*)
      echo "Error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      positional+=("$1")
      shift
      ;;
  esac
done

if (( ${#positional[@]} > 2 )); then
  echo "Error: too many positional arguments." >&2
  usage >&2
  exit 1
fi

if (( ${#positional[@]} >= 1 )); then
  first="${positional[0]}"
  if parse_duration_seconds "$first" >/dev/null; then
    max_seconds_input="$first"
  else
    echo "Error: first positional argument must be a duration like 5h, 30m, 300s, 300, or 0." >&2
    exit 1
  fi
fi

if (( ${#positional[@]} == 2 )); then
  workdir="${positional[1]}"
fi

if ! [[ "$iterations" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: iterations must be a positive integer." >&2
  exit 1
fi

if ! max_seconds="$(parse_duration_seconds "$max_seconds_input")"; then
  echo "Error: duration must be 0, seconds, Nm, or Nh. Got: $max_seconds_input" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
prompt_file="${NIGHTSHIFT_PROMPT:-$script_dir/AGENT_LOOP.md}"
agent_bin="${PI_BIN:-pi}"
agent_flags_string="${PI_FLAGS:--p}"
start_time="$(date +%s)"
start_utc="$(timestamp_utc)"
end_time=$((start_time + max_seconds))
run_id="$(date -u +"%Y%m%dT%H%M%SZ")-$$"
iterations_completed=0
final_status="running"
final_reason="not finished"

if [[ ! -f "$prompt_file" ]]; then
  echo "Error: prompt file not found: $prompt_file" >&2
  exit 1
fi

if [[ ! -d "$workdir" ]]; then
  echo "Error: project directory not found: $workdir" >&2
  exit 1
fi

workdir="$(cd "$workdir" && pwd)"
project_nightshift_dir="$workdir/.nightshift"
project_todo_file="$project_nightshift_dir/TODO.md"
project_definition_of_done_file="$project_nightshift_dir/DEFINITION_OF_DONE.md"
if [[ -n "${NIGHTSHIFT_LOG_DIR:-}" ]]; then
  log_dir="$NIGHTSHIFT_LOG_DIR"
elif [[ -d "$project_nightshift_dir" ]]; then
  log_dir="$project_nightshift_dir/logs"
else
  log_dir="$script_dir/logs"
fi
mkdir -p "$log_dir/runs"
general_log="$log_dir/night-shift.log"
run_log="$log_dir/runs/$run_id.log"

log_detail() {
  printf '[%s] %s\n' "$(timestamp_utc)" "$*" | tee -a "$run_log"
}

append_general() {
  printf '[%s] run_id=%s event=%s status=%s exit_code=%s iterations_completed=%s duration_seconds=%s workdir=%q prompt=%q max_seconds=%s run_log=%q reason=%q\n' \
    "$(timestamp_utc)" \
    "$run_id" \
    "$1" \
    "$final_status" \
    "$2" \
    "$iterations_completed" \
    "$3" \
    "$workdir" \
    "$prompt_file" \
    "$max_seconds" \
    "$run_log" \
    "$final_reason" >>"$general_log"
}

finish_logging() {
  exit_code=$?
  finish_time="$(date +%s)"
  duration=$((finish_time - start_time))

  if [[ "$final_status" == "running" ]]; then
    if [[ "$exit_code" == "0" ]]; then
      final_status="stopped"
      final_reason="script exited without explicit final reason"
    else
      final_status="failed"
      final_reason="script exited unexpectedly"
    fi
  fi

  log_detail "RUN END status=$final_status exit_code=$exit_code iterations_completed=$iterations_completed duration_seconds=$duration reason=$final_reason"
  append_general "end" "$exit_code" "$duration"
}
trap finish_logging EXIT

: >"$run_log"
log_detail "RUN START run_id=$run_id start_utc=$start_utc"
log_detail "CONFIG iterations=$iterations max_seconds=$max_seconds workdir=$workdir project_nightshift_dir=$project_nightshift_dir task_queue=$project_todo_file definition_of_done=$project_definition_of_done_file prompt=$prompt_file pi_bin=$agent_bin pi_flags=$agent_flags_string log_dir=$log_dir"
append_general "start" "0" "0"

missing_required=()
if [[ ! -d "$project_nightshift_dir" ]]; then
  missing_required+=("$project_nightshift_dir/")
fi
if [[ ! -f "$project_todo_file" ]]; then
  missing_required+=("$project_todo_file")
fi
if [[ ! -f "$project_definition_of_done_file" ]]; then
  missing_required+=("$project_definition_of_done_file")
fi

if (( ${#missing_required[@]} > 0 )); then
  final_status="config_error"
  final_reason="missing required project Night Shift files"
  log_detail "CONFIG ERROR missing required project Night Shift files"
  for missing in "${missing_required[@]}"; do
    log_detail "MISSING path=$missing"
    echo "Missing required Night Shift file: $missing" | tee -a "$run_log" >&2
  done
  echo "Create the missing files under <project>/.nightshift/ and rerun." | tee -a "$run_log" >&2
  echo "Required files:" | tee -a "$run_log" >&2
  echo "- <project>/.nightshift/TODO.md" | tee -a "$run_log" >&2
  echo "- <project>/.nightshift/DEFINITION_OF_DONE.md" | tee -a "$run_log" >&2
  exit 2
fi

log_detail "CONFIG OK required_project_files_present task_queue=$project_todo_file definition_of_done=$project_definition_of_done_file"

# Intentional word splitting so callers can pass simple flag strings, e.g.
# PI_FLAGS='-p --model sonnet:high'
# shellcheck disable=SC2206
agent_flags=($agent_flags_string)
base_prompt="$(<"$prompt_file")"
runtime_prompt="$base_prompt

## Runtime Project Configuration

Project root: $workdir
Project Night Shift folder: $project_nightshift_dir
Required task queue: $project_todo_file
Required definition of done: $project_definition_of_done_file

Before selecting work, read .nightshift/TODO.md and .nightshift/DEFINITION_OF_DONE.md in this project. Follow the definition of done for every non-blocked task. Only use project-specific Night Shift files from .nightshift/ unless the task explicitly says otherwise."

cd "$workdir"
log_detail "STEP change-directory path=$workdir"

for ((i = 1; i <= iterations; i++)); do
  now="$(date +%s)"
  if ((max_seconds > 0 && now >= end_time)); then
    final_status="time_cap"
    final_reason="time cap reached before iteration $i"
    log_detail "STEP time-cap-before-iteration iteration=$i max_seconds=$max_seconds"
    echo "Night Shift reached the ${max_seconds}s time cap before iteration $i." | tee -a "$run_log"
    exit 0
  fi

  if ((max_seconds > 0)); then
    remaining=$((end_time - now))
    log_detail "ITERATION START iteration=$i/$iterations remaining_seconds=$remaining"
    echo "== Night Shift iteration $i/$iterations (${remaining}s remaining) ==" | tee -a "$run_log"
  else
    remaining=0
    log_detail "ITERATION START iteration=$i/$iterations remaining_seconds=unlimited"
    echo "== Night Shift iteration $i/$iterations ==" | tee -a "$run_log"
  fi

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_before_status="$(git status --short --untracked-files=all)"
    log_detail "STEP git-status-before-begin iteration=$i"
    if [[ -z "$git_before_status" ]]; then
      log_detail "GIT_BEFORE iteration=$i status=clean"
    else
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        log_detail "GIT_BEFORE iteration=$i status_line=$line"
      done <<<"$git_before_status"
    fi
    log_detail "STEP git-status-before-end iteration=$i"
  else
    git_before_status=""
    log_detail "STEP git-status-before-skipped iteration=$i reason=not-a-git-repo"
  fi

  output_file="$(mktemp -t nightshift-output.XXXXXX)"
  status_file="$(mktemp -t nightshift-status.XXXXXX)"
  rm -f "$status_file"
  log_detail "STEP prepare-command iteration=$i output_file=$output_file status_file=$status_file"

  log_detail "TASK executing iteration=$i value=task-selection-and-single-task-execution-delegated-to-pi"
  log_detail "STEP pi-start iteration=$i command=$agent_bin flags=$agent_flags_string"
  (
    set +e
    "$agent_bin" "${agent_flags[@]}" "$runtime_prompt" >"$output_file" 2>&1
    echo "$?" >"$status_file"
  ) &
  agent_pid=$!
  log_detail "STEP pi-started iteration=$i pid=$agent_pid"

  watcher_pid=""
  if ((max_seconds > 0)); then
    log_detail "STEP time-cap-watcher-start iteration=$i remaining_seconds=$remaining"
    (
      sleep "$remaining"
      if kill -0 "$agent_pid" 2>/dev/null; then
        kill "$agent_pid" 2>/dev/null || true
        sleep 2
        kill -9 "$agent_pid" 2>/dev/null || true
      fi
    ) &
    watcher_pid=$!
    log_detail "STEP time-cap-watcher-started iteration=$i pid=$watcher_pid"
  fi

  set +e
  wait "$agent_pid" 2>/dev/null
  wait_status=$?
  set -e
  log_detail "STEP pi-wait-finished iteration=$i wait_status=$wait_status"

  if [[ -n "$watcher_pid" ]]; then
    kill "$watcher_pid" 2>/dev/null || true
    wait "$watcher_pid" 2>/dev/null || true
    log_detail "STEP time-cap-watcher-stopped iteration=$i pid=$watcher_pid"
  fi

  result="$(<"$output_file")"
  rm -f "$output_file"

  log_detail "STEP pi-output-begin iteration=$i"
  printf '%s\n' "$result" | tee -a "$run_log"
  log_detail "STEP pi-output-end iteration=$i"

  if [[ -f "$status_file" ]]; then
    command_status="$(<"$status_file")"
    rm -f "$status_file"
  else
    command_status=124
  fi
  log_detail "STEP pi-status iteration=$i command_status=$command_status wait_status=$wait_status"

  task_picked="$(printf '%s\n' "$result" | awk '/^NIGHTSHIFT_TASK_PICKED_UP:/ { sub(/^NIGHTSHIFT_TASK_PICKED_UP:[[:space:]]*/, ""); print; exit }' || true)"
  task_status="$(printf '%s\n' "$result" | awk '/^NIGHTSHIFT_TASK_STATUS:/ { sub(/^NIGHTSHIFT_TASK_STATUS:[[:space:]]*/, ""); print; exit }' || true)"
  [[ -z "$task_picked" ]] && task_picked="UNREPORTED"
  [[ -z "$task_status" ]] && task_status="UNREPORTED"
  log_detail "TASK picked_up iteration=$i value=$task_picked"
  log_detail "TASK status iteration=$i value=$task_status"

  printf '%s\n' "$result" | awk '/^NIGHTSHIFT_TDD:/ || /^NIGHTSHIFT_VALIDATION_COMMAND:/ || /^NIGHTSHIFT_VALIDATION_RESULT:/ || /^NIGHTSHIFT_FIX:/ { print }' | while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    log_detail "PROCESS iteration=$i $line"
  done

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_after_status="$(git status --short --untracked-files=all)"
    log_detail "STEP files-touched-begin iteration=$i source=git-status"
    if [[ -z "$git_after_status" ]]; then
      log_detail "FILE_TOUCHED iteration=$i path=NONE"
    else
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        git_status="${line:0:2}"
        file_path="${line:3}"
        log_detail "FILE_TOUCHED iteration=$i git_status=$git_status path=$file_path"
      done <<<"$git_after_status"
    fi
    log_detail "STEP files-touched-end iteration=$i source=git-status"
  else
    log_detail "STEP files-touched-skipped iteration=$i reason=not-a-git-repo"
  fi

  if [[ "$command_status" == "124" || "$wait_status" == "143" || "$wait_status" == "137" ]]; then
    final_status="time_cap"
    final_reason="time cap reached during iteration $i"
    log_detail "ITERATION END iteration=$i status=time_cap"
    echo "Night Shift stopped because the ${max_seconds}s time cap was reached." | tee -a "$run_log"
    exit 0
  fi

  if [[ "$command_status" != "0" ]]; then
    final_status="failed"
    final_reason="pi command failed during iteration $i with exit code $command_status"
    log_detail "ITERATION END iteration=$i status=failed command_status=$command_status"
    echo "pi command failed with exit code $command_status." | tee -a "$run_log" >&2
    exit "$command_status"
  fi

  iterations_completed=$i

  if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
    final_status="complete"
    final_reason="completion promise received during iteration $i"
    log_detail "ITERATION END iteration=$i status=complete promise=received"
    echo "Night Shift complete after $i iteration(s)." | tee -a "$run_log"
    exit 0
  fi

  log_detail "ITERATION END iteration=$i status=continue promise=not-received"
done

final_status="iteration_cap"
final_reason="iteration cap reached without completion promise"
log_detail "STEP iteration-cap-reached iterations=$iterations"
echo "Night Shift stopped after $iterations iteration(s) without completion promise." | tee -a "$run_log"
