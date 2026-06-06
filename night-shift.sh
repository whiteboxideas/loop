#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  local command_name
  command_name="$(basename "${0:-night-shift}")"
  cat <<USAGE
Usage:
  $command_name [duration] [project]
  $command_name --duration 5h --project ../hello-world [--iterations 50]
  $command_name --agent cursor --duration 5h --project ../hello-world
  $command_name --follow-up-chain ai:architect,ai:reviewer --project ../hello-world

Runs a basic autonomous Night Shift loop using pi in headless print mode by default.

Project contract:
  Night Shift tooling stays in loop/.
  Project-specific task/config files stay in <project>/.nightshift/.
  Required project files (created with commented starter templates when missing):
    <project>/.nightshift/TODO.md
    <project>/.nightshift/DEFINITION_OF_DONE.md
  Style guide:
    Uses the first project style guide found, or loop/REACTNATIVE_DEFAULT_STYLE_GUIDE.md.

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
  NIGHTSHIFT_PROMPT     Prompt file to use. Defaults to bundled AGENT_LOOP.md.
  NIGHTSHIFT_LOG_DIR    Directory for logs. Defaults to <project>/.nightshift/logs.
  NIGHTSHIFT_LOG_VERBOSE
                         Set to 1 to include low-level step/pid/tmp-file debug logs.
  NIGHTSHIFT_FOLLOW_UP_CHAIN
                         Optional comma-separated follow-up chain. Defaults to none.
                         Examples: ai:architect, ai:ux, ai:architect,ai:reviewer.
  NIGHTSHIFT_FOLLOW_UP_CONFIG
                         Optional project-specific follow-up chain guidance file.
  NIGHTSHIFT_AGENT      Agent preset: pi, cursor, or custom. Defaults to pi.
  NIGHTSHIFT_AGENT_BIN  Override agent executable.
  NIGHTSHIFT_AGENT_FLAGS
                         Override agent flags. Cursor defaults to --yolo.
  PI_BIN                pi executable alias for the pi preset. Defaults to pi.
  PI_FLAGS              pi flags alias for the pi preset. Defaults to -p.
  CURSOR_AGENT_BIN      Cursor agent executable alias. Defaults to agent.
  CURSOR_AGENT_FLAGS    Cursor agent flags alias. Defaults to --yolo.

Logs:
  General run log:      <log-dir>/night-shift.log
  Per-run detail logs:  <log-dir>/runs/<run-id>.log
  Raw agent outputs:    <log-dir>/runs/<run-id>.raw/iteration-<n>.log

Completion:
  The loop stops early when the agent output contains <promise>COMPLETE</promise>.
USAGE
}

timestamp_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

sanitize_agent_output() {
  perl -pe 's/\e\[[0-?]*[ -\/]*[@-~]//g; s/\e\][^\a]*(?:\a|\e\\)//g; s/\e[=>][0-9;]*[A-Za-z]?//g; s/\e[()][A-Za-z0-9]//g; s/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]//g'
}

extract_field() {
  local field="$1"
  awk -v field="$field" 'index($0, field ":") == 1 { sub(field ":[[:space:]]*", ""); print; exit }'
}

resolve_script_dir() {
  local source
  local dir

  source="${BASH_SOURCE[0]}"
  while [[ -L "$source" ]]; do
    dir="$(cd -P "$(dirname "$source")" && pwd)"
    source="$(readlink "$source")"
    if [[ "$source" != /* ]]; then
      source="$dir/$source"
    fi
  done

  cd -P "$(dirname "$source")" && pwd
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
agent_kind="${NIGHTSHIFT_AGENT:-pi}"
follow_up_chain="${NIGHTSHIFT_FOLLOW_UP_CHAIN:-none}"
follow_up_config_file="${NIGHTSHIFT_FOLLOW_UP_CONFIG:-}"
agent_bin_override="${NIGHTSHIFT_AGENT_BIN:-}"
agent_flags_override=""
agent_flags_override_set=0
if [[ "${NIGHTSHIFT_AGENT_FLAGS+x}" == "x" ]]; then
  agent_flags_override="$NIGHTSHIFT_AGENT_FLAGS"
  agent_flags_override_set=1
fi
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
    --follow-up-chain)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --follow-up-chain requires a value." >&2
        exit 1
      fi
      follow_up_chain="$2"
      shift 2
      ;;
    --follow-up-config)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --follow-up-config requires a value." >&2
        exit 1
      fi
      follow_up_config_file="$2"
      shift 2
      ;;
    --agent)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --agent requires a value." >&2
        exit 1
      fi
      agent_kind="$2"
      shift 2
      ;;
    --agent-bin)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --agent-bin requires a value." >&2
        exit 1
      fi
      agent_bin_override="$2"
      shift 2
      ;;
    --agent-flags)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --agent-flags requires a value." >&2
        exit 1
      fi
      agent_flags_override="$2"
      agent_flags_override_set=1
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

script_dir="$(resolve_script_dir)"
prompt_file="${NIGHTSHIFT_PROMPT:-$script_dir/AGENT_LOOP.md}"
nightshift_definition_of_done_file="$script_dir/NIGHTSHIFT_DEFINITION_OF_DONE.md"
case "$agent_kind" in
  pi)
    agent_bin="${agent_bin_override:-${PI_BIN:-pi}}"
    if (( agent_flags_override_set )); then
      agent_flags_string="$agent_flags_override"
    else
      agent_flags_string="${PI_FLAGS:--p}"
    fi
    ;;
  cursor|cursor-agent)
    agent_kind="cursor"
    agent_bin="${agent_bin_override:-${CURSOR_AGENT_BIN:-agent}}"
    if (( agent_flags_override_set )); then
      agent_flags_string="$agent_flags_override"
    else
      agent_flags_string="${CURSOR_AGENT_FLAGS:---yolo}"
    fi
    ;;
  custom)
    agent_bin="$agent_bin_override"
    if [[ -z "$agent_bin" ]]; then
      echo "Error: --agent custom requires --agent-bin or NIGHTSHIFT_AGENT_BIN." >&2
      exit 1
    fi
    agent_flags_string="$agent_flags_override"
    ;;
  *)
    echo "Error: unknown agent preset: $agent_kind. Expected pi, cursor, or custom." >&2
    exit 1
    ;;
esac
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

if [[ ! -f "$nightshift_definition_of_done_file" ]]; then
  echo "Error: Night Shift Definition of Done file not found: $nightshift_definition_of_done_file" >&2
  exit 1
fi

if [[ ! -d "$workdir" ]]; then
  echo "Error: project directory not found: $workdir" >&2
  exit 1
fi

workdir="$(cd "$workdir" && pwd)"
if [[ -z "$follow_up_chain" ]]; then
  follow_up_chain="none"
fi
follow_up_config_display="none"
if [[ -n "$follow_up_config_file" ]]; then
  if [[ "$follow_up_config_file" != /* ]]; then
    follow_up_config_file="$workdir/$follow_up_config_file"
  fi
  if [[ ! -f "$follow_up_config_file" ]]; then
    echo "Error: follow-up config file not found: $follow_up_config_file" >&2
    exit 1
  fi
  follow_up_config_display="$follow_up_config_file"
fi
project_nightshift_dir="$workdir/.nightshift"
project_todo_file="$project_nightshift_dir/TODO.md"
project_definition_of_done_file="$project_nightshift_dir/DEFINITION_OF_DONE.md"
project_nightshift_scaffolded=()

if [[ ! -e "$project_nightshift_dir" ]]; then
  mkdir -p "$project_nightshift_dir"
  project_nightshift_scaffolded+=("$project_nightshift_dir/")
elif [[ ! -d "$project_nightshift_dir" ]]; then
  echo "Error: project Night Shift path exists but is not a directory: $project_nightshift_dir" >&2
  exit 2
fi

if [[ ! -e "$project_todo_file" ]]; then
  cat >"$project_todo_file" <<'TODO_TEMPLATE'
<!--
Night Shift TODO queue.

Recommended content:
- Add a "## Ready tasks" section.
- Write one small, independently-checkable task per bullet.
- Use checkboxes, for example: "- [ ] NS-001 Add a focused feature".
- Include validation notes and links to ready specs when useful.
-->
TODO_TEMPLATE
  project_nightshift_scaffolded+=("$project_todo_file")
elif [[ ! -f "$project_todo_file" ]]; then
  echo "Error: project Night Shift TODO path exists but is not a file: $project_todo_file" >&2
  exit 2
fi

if [[ ! -e "$project_definition_of_done_file" ]]; then
  cat >"$project_definition_of_done_file" <<'DOD_TEMPLATE'
<!--
Project Night Shift Definition of Done.

Recommended content:
- Required validation commands, such as npm run check, tests, lint, or typecheck.
- Project-specific TDD expectations and when exceptions are acceptable.
- Project-specific documentation update requirements.
- How to record project-specific fixes, blockers, and completion notes in .nightshift/TODO.md.

Do not duplicate universal Night Shift rules here; the runner provides those from its bundled NIGHTSHIFT_DEFINITION_OF_DONE.md.
-->
DOD_TEMPLATE
  project_nightshift_scaffolded+=("$project_definition_of_done_file")
elif [[ ! -f "$project_definition_of_done_file" ]]; then
  echo "Error: project Night Shift Definition of Done path exists but is not a file: $project_definition_of_done_file" >&2
  exit 2
fi

project_style_guide_candidates=(
  "$workdir/REACTNATIVE_DEFAULT_STYLE_GUIDE.md"
  "$workdir/STYLE_GUIDE.md"
  "$workdir/docs/REACTNATIVE_DEFAULT_STYLE_GUIDE.md"
  "$workdir/docs/STYLE_GUIDE.md"
  "$project_nightshift_dir/REACTNATIVE_DEFAULT_STYLE_GUIDE.md"
  "$project_nightshift_dir/STYLE_GUIDE.md"
)
style_guide_file=""
style_guide_source="project"
for candidate in "${project_style_guide_candidates[@]}"; do
  if [[ -f "$candidate" ]]; then
    style_guide_file="$candidate"
    break
  fi
done
if [[ -z "$style_guide_file" ]]; then
  style_guide_file="$script_dir/REACTNATIVE_DEFAULT_STYLE_GUIDE.md"
  style_guide_source="loop-default"
fi
if [[ ! -f "$style_guide_file" ]]; then
  echo "Error: default style guide not found: $style_guide_file" >&2
  exit 1
fi
if [[ -n "${NIGHTSHIFT_LOG_DIR:-}" ]]; then
  log_dir="$NIGHTSHIFT_LOG_DIR"
else
  log_dir="$project_nightshift_dir/logs"
fi
raw_output_dir="$log_dir/runs/$run_id.raw"
mkdir -p "$log_dir/runs" "$raw_output_dir"
general_log="$log_dir/night-shift.log"
run_log="$log_dir/runs/$run_id.log"

log_detail() {
  printf '[%s] %s\n' "$(timestamp_utc)" "$*" | tee -a "$run_log"
}

log_debug() {
  if [[ "${NIGHTSHIFT_LOG_VERBOSE:-0}" == "1" ]]; then
    log_detail "DEBUG $*"
  fi
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
log_detail "CONFIG project=$workdir duration_seconds=$max_seconds iterations=$iterations log_dir=$log_dir agent=$agent_kind command=$agent_bin flags=$agent_flags_string follow_up_chain=$follow_up_chain follow_up_config=$follow_up_config_display style_guide=$style_guide_file style_guide_source=$style_guide_source"
log_debug "config-details project_nightshift_dir=$project_nightshift_dir task_queue=$project_todo_file nightshift_definition_of_done=$nightshift_definition_of_done_file project_definition_of_done=$project_definition_of_done_file follow_up_chain=$follow_up_chain follow_up_config=$follow_up_config_display style_guide=$style_guide_file style_guide_source=$style_guide_source prompt=$prompt_file raw_output_dir=$raw_output_dir"
append_general "start" "0" "0"

if (( ${#project_nightshift_scaffolded[@]} > 0 )); then
  log_detail "CONFIG scaffolded_project_files=true"
  for scaffolded in "${project_nightshift_scaffolded[@]}"; do
    log_detail "SCAFFOLDED path=$scaffolded"
  done
else
  log_detail "CONFIG scaffolded_project_files=false"
fi
log_detail "CONFIG OK required_project_files_present=true"
log_debug "required-files task_queue=$project_todo_file nightshift_definition_of_done=$nightshift_definition_of_done_file project_definition_of_done=$project_definition_of_done_file"

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
Night Shift Definition of Done: $nightshift_definition_of_done_file
Project Definition of Done: $project_definition_of_done_file
Style guide: $style_guide_file
Style guide source: $style_guide_source
Follow-up chain: $follow_up_chain
Follow-up config file: $follow_up_config_display

Before selecting work, read the Night Shift Definition of Done, .nightshift/TODO.md, .nightshift/DEFINITION_OF_DONE.md, the follow-up config file when not 'none', and the style guide listed above. Follow both definitions of done and the style guide for every non-blocked task. If the project definition conflicts with the Night Shift Definition of Done, follow the stricter rule. If Follow-up chain is 'none' or empty, do not create extra review, architecture, UX, or human follow-up tasks after completion unless the selected task explicitly asks for them. If Follow-up chain is configured, use it exactly as the post-completion chain. If style_guide_source is loop-default, treat it as the default only because no project style guide was found. Only use project-specific Night Shift files from .nightshift/ unless the task explicitly says otherwise."

cd "$workdir"
log_debug "change-directory path=$workdir"

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
    echo "== Night Shift iteration $i/$iterations (${remaining}s remaining) =="
  else
    remaining=0
    log_detail "ITERATION START iteration=$i/$iterations remaining_seconds=unlimited"
    echo "== Night Shift iteration $i/$iterations =="
  fi

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_before_status="$(git status --short --untracked-files=all)"
    if [[ -z "$git_before_status" ]]; then
      log_detail "WORKTREE iteration=$i before=clean"
    else
      log_detail "WORKTREE iteration=$i before=dirty"
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        log_debug "git-before iteration=$i status_line=$line"
      done <<<"$git_before_status"
    fi
  else
    git_before_status=""
    log_detail "WORKTREE iteration=$i before=not-a-git-repo"
  fi

  output_file="$(mktemp -t nightshift-output.XXXXXX)"
  status_file="$(mktemp -t nightshift-status.XXXXXX)"
  rm -f "$status_file"
  log_debug "prepare-command iteration=$i output_file=$output_file status_file=$status_file"

  log_detail "AGENT iteration=$i status=started command=$agent_bin flags=$agent_flags_string"
  (
    set +e
    "$agent_bin" "${agent_flags[@]}" "$runtime_prompt" >"$output_file" 2>&1
    echo "$?" >"$status_file"
  ) &
  agent_pid=$!
  log_debug "agent-started iteration=$i pid=$agent_pid"

  watcher_pid=""
  if ((max_seconds > 0)); then
    log_debug "time-cap-watcher-start iteration=$i remaining_seconds=$remaining"
    (
      sleep "$remaining"
      if kill -0 "$agent_pid" 2>/dev/null; then
        kill "$agent_pid" 2>/dev/null || true
        sleep 2
        kill -9 "$agent_pid" 2>/dev/null || true
      fi
    ) &
    watcher_pid=$!
    log_debug "time-cap-watcher-started iteration=$i pid=$watcher_pid"
  fi

  set +e
  wait "$agent_pid" 2>/dev/null
  wait_status=$?
  set -e
  log_debug "agent-wait-finished iteration=$i wait_status=$wait_status"

  if [[ -n "$watcher_pid" ]]; then
    kill "$watcher_pid" 2>/dev/null || true
    wait "$watcher_pid" 2>/dev/null || true
    log_debug "time-cap-watcher-stopped iteration=$i pid=$watcher_pid"
  fi

  result="$(<"$output_file")"
  rm -f "$output_file"
  sanitized_result="$(printf '%s\n' "$result" | sanitize_agent_output)"
  raw_output_file="$raw_output_dir/iteration-$i.log"
  printf '%s\n' "$sanitized_result" >"$raw_output_file"
  log_detail "AGENT iteration=$i status=finished raw_output=$raw_output_file"

  if [[ -f "$status_file" ]]; then
    command_status="$(<"$status_file")"
    rm -f "$status_file"
  else
    command_status=124
  fi
  log_debug "agent-status iteration=$i command_status=$command_status wait_status=$wait_status"

  task_picked="$(printf '%s\n' "$sanitized_result" | extract_field "NIGHTSHIFT_TASK_PICKED_UP" || true)"
  task_status="$(printf '%s\n' "$sanitized_result" | extract_field "NIGHTSHIFT_TASK_STATUS" || true)"
  [[ -z "$task_picked" ]] && task_picked="UNREPORTED"
  [[ -z "$task_status" ]] && task_status="UNREPORTED"
  log_detail "TASK iteration=$i picked_up=$task_picked status=$task_status"

  readiness_decision="$(printf '%s\n' "$sanitized_result" | extract_field "NIGHTSHIFT_READINESS_DECISION" || true)"
  [[ -z "$readiness_decision" ]] && readiness_decision="UNREPORTED"
  log_detail "READINESS iteration=$i decision=$readiness_decision"

  tdd_summary="$(printf '%s\n' "$sanitized_result" | extract_field "NIGHTSHIFT_TDD" || true)"
  docs_summary="$(printf '%s\n' "$sanitized_result" | extract_field "NIGHTSHIFT_DOCS" || true)"
  [[ -z "$tdd_summary" ]] && tdd_summary="UNREPORTED"
  [[ -z "$docs_summary" ]] && docs_summary="UNREPORTED"
  log_detail "TDD iteration=$i summary=$tdd_summary"
  log_detail "DOCS iteration=$i summary=$docs_summary"

  printf '%s\n' "$sanitized_result" | awk '/^NIGHTSHIFT_VALIDATION_COMMAND:/ || /^NIGHTSHIFT_VALIDATION_RESULT:/ { print }' | while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    log_detail "VALIDATION iteration=$i ${line#NIGHTSHIFT_}"
  done

  printf '%s\n' "$sanitized_result" | awk '/^NIGHTSHIFT_FIX:/ { sub(/^NIGHTSHIFT_FIX:[[:space:]]*/, ""); print }' | while IFS= read -r fix; do
    [[ -z "$fix" ]] && continue
    log_detail "FIX iteration=$i summary=$fix"
  done

  reported_files="$(printf '%s\n' "$sanitized_result" | awk '
    /^NIGHTSHIFT_FILES_TOUCHED:/ { in_files=1; next }
    in_files && /^- / { sub(/^- /, ""); print; next }
    in_files && NF == 0 { next }
    in_files { exit }
  ' || true)"
  if [[ -z "$reported_files" ]]; then
    log_detail "FILES_REPORTED iteration=$i path=UNREPORTED"
  else
    while IFS= read -r file; do
      [[ -z "$file" ]] && continue
      log_detail "FILES_REPORTED iteration=$i path=$file"
    done <<<"$reported_files"
  fi

  commit_summary="$(printf '%s\n' "$sanitized_result" | awk '/^- Commit:/ { sub(/^- Commit:[[:space:]]*/, ""); gsub(/`/, ""); print; exit }' || true)"
  if [[ -n "$commit_summary" ]]; then
    log_detail "COMMIT iteration=$i value=$commit_summary"
  fi

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_after_status="$(git status --short --untracked-files=all)"
    if [[ -z "$git_after_status" ]]; then
      log_detail "WORKTREE iteration=$i after=clean"
    else
      log_detail "WORKTREE iteration=$i after=dirty"
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        git_status="${line:0:2}"
        file_path="${line:3}"
        log_detail "FILE_UNCOMMITTED iteration=$i git_status=$git_status path=$file_path"
      done <<<"$git_after_status"
    fi
  else
    log_detail "WORKTREE iteration=$i after=not-a-git-repo"
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
    final_reason="agent command failed during iteration $i with exit code $command_status"
    log_detail "ITERATION END iteration=$i status=failed command_status=$command_status"
    echo "Agent command failed with exit code $command_status." | tee -a "$run_log" >&2
    exit "$command_status"
  fi

  iterations_completed=$i

  if [[ "$sanitized_result" == *"<promise>COMPLETE</promise>"* ]]; then
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
log_detail "LIMIT iteration_cap_reached iterations=$iterations"
echo "Night Shift stopped after $iterations iteration(s) without completion promise." | tee -a "$run_log"
