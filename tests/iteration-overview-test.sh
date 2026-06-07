#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

project_dir="$tmp_dir/project"
log_dir="$tmp_dir/logs"
fake_pi="$tmp_dir/fake-pi.sh"
mkdir -p "$project_dir/.nightshift" "$log_dir"

cat >"$project_dir/.nightshift/TODO.md" <<'TODO'
# Test TODO

## Ready tasks

- [ ] NS-TEST-REVIEW AI generated reviewer task.
  - Type: review
  - Persona: ai:reviewer
  - Chain origin: NS-TEST-001 Implementation task
TODO

cat >"$project_dir/.nightshift/DEFINITION_OF_DONE.md" <<'DOD'
# Test Definition of Done

Run the relevant test command.
DOD

cat >"$fake_pi" <<'PI'
#!/usr/bin/env bash
cat <<'OUTPUT'
NIGHTSHIFT_TASK_PICKED_UP: NS-TEST-REVIEW AI generated reviewer task
NIGHTSHIFT_TASK_STATUS: done
NIGHTSHIFT_TASK_TYPE: review
NIGHTSHIFT_TASK_PERSONA: ai:reviewer
NIGHTSHIFT_TASK_SOURCE: ai-generated-follow-up
NIGHTSHIFT_TOKEN_USAGE: prompt=123 completion=45 total=168
NIGHTSHIFT_READINESS_DECISION: ready - reviewer task metadata smoke test
NIGHTSHIFT_TDD: not practical; metadata logging smoke test
NIGHTSHIFT_VALIDATION_COMMAND: not run
NIGHTSHIFT_VALIDATION_RESULT: not-run metadata logging smoke test
NIGHTSHIFT_FIX: NONE
NIGHTSHIFT_DOCS: NONE
NIGHTSHIFT_FILES_TOUCHED:
- NONE
<promise>COMPLETE</promise>
OUTPUT
PI
chmod +x "$fake_pi"

NIGHTSHIFT_LOG_DIR="$log_dir" PI_BIN="$fake_pi" PI_FLAGS="-p" \
  "$repo_root/night-shift.sh" --duration 0 --project "$project_dir" --iterations 1 >/dev/null

overview="$log_dir/iterations.tsv"
if [[ ! -f "$overview" ]]; then
  echo "Expected iteration overview at $overview" >&2
  exit 1
fi

awk -F '\t' '
  NR == 1 {
    for (i = 1; i <= NF; i++) {
      col[$i] = i
    }
    next
  }
  NR == 2 {
    if ($col["iteration"] != "1") fail="expected iteration 1"
    else if ($col["status"] != "complete") fail="expected complete status"
    else if ($col["duration_seconds"] !~ /^[0-9]+$/) fail="expected numeric duration"
    else if ($col["prompt_tokens_est"] !~ /^[1-9][0-9]*$/) fail="expected positive prompt token estimate"
    else if ($col["output_tokens_est"] !~ /^[1-9][0-9]*$/) fail="expected positive output token estimate"
    else if ($col["reported_token_usage"] != "prompt=123 completion=45 total=168") fail="expected reported token usage"
    else if ($col["task_source"] != "ai-generated-follow-up") fail="expected task source"
    else if ($col["task_type"] != "review") fail="expected task type"
    else if ($col["task_persona"] != "ai:reviewer") fail="expected task persona"
    else if ($col["ai_persona_task"] != "yes") fail="expected ai persona marker"
    else if ($col["task_status"] != "done") fail="expected task status"
    else if ($col["readiness_decision"] != "ready - reviewer task metadata smoke test") fail="expected readiness decision"
    if (fail) {
      print fail > "/dev/stderr"
      exit 1
    }
    seen=1
  }
  END {
    if (!seen) {
      print "expected one overview data row" > "/dev/stderr"
      exit 1
    }
  }
' "$overview"

run_log="$(find "$log_dir/runs" -maxdepth 1 -type f -name '*.log' -print -quit)"
if [[ -z "$run_log" ]]; then
  echo "Expected a run log under $log_dir/runs" >&2
  exit 1
fi

if ! grep -Fq "TASK_META iteration=1 type=review persona=ai:reviewer source=ai-generated-follow-up ai_persona_task=yes" "$run_log"; then
  echo "Expected task metadata to be logged in $run_log" >&2
  exit 1
fi

if ! grep -Fq "USAGE iteration=1 duration_seconds=" "$run_log"; then
  echo "Expected usage summary to be logged in $run_log" >&2
  exit 1
fi

echo "iteration overview passed"
