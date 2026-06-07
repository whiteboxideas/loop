#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

project_dir="$tmp_dir/project"
log_dir="$tmp_dir/logs"
fake_pi="$tmp_dir/fake-pi.sh"
mkdir -p "$project_dir/.nightshift" "$log_dir"
printf 'timestamp_utc\trun_id\titeration\tstatus\n' >"$log_dir/iterations.tsv"

cat >"$project_dir/.nightshift/TODO.md" <<'TODO'
# Test TODO

## Ready tasks

- [ ] NS-TEST-LOCAL-TIME Log timestamps in local time.
TODO

cat >"$project_dir/.nightshift/DEFINITION_OF_DONE.md" <<'DOD'
# Test Definition of Done

Run the relevant test command.
DOD

cat >"$fake_pi" <<'PI'
#!/usr/bin/env bash
cat <<'OUTPUT'
NIGHTSHIFT_TASK_PICKED_UP: NS-TEST-LOCAL-TIME Log timestamps in local time
NIGHTSHIFT_TASK_STATUS: done
NIGHTSHIFT_TASK_TYPE: implementation
NIGHTSHIFT_TASK_PERSONA: ai:implementer
NIGHTSHIFT_TASK_SOURCE: human-or-unmarked
NIGHTSHIFT_TOKEN_USAGE: unavailable
NIGHTSHIFT_READINESS_DECISION: ready - local timestamp smoke test
NIGHTSHIFT_TDD: not practical; local timestamp smoke test
NIGHTSHIFT_VALIDATION_COMMAND: not run
NIGHTSHIFT_VALIDATION_RESULT: not-run local timestamp smoke test
NIGHTSHIFT_FIX: NONE
NIGHTSHIFT_DOCS: no docs needed for smoke test
NIGHTSHIFT_FILES_TOUCHED:
- NONE
<promise>COMPLETE</promise>
OUTPUT
PI
chmod +x "$fake_pi"

TZ=America/New_York NIGHTSHIFT_LOG_DIR="$log_dir" PI_BIN="$fake_pi" PI_FLAGS="-p" \
  "$repo_root/night-shift.sh" --duration 0 --project "$project_dir" --iterations 1 >/dev/null

run_log="$(find "$log_dir/runs" -maxdepth 1 -type f -name '*.log' -print -quit)"
if [[ -z "$run_log" ]]; then
  echo "Expected a run log under $log_dir/runs" >&2
  exit 1
fi

if grep -Fq "start_utc=" "$run_log"; then
  echo "Expected run log to stop using start_utc" >&2
  exit 1
fi

if ! grep -Eq '^\[[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}-0[45]00\] RUN START .* start_local=' "$run_log"; then
  echo "Expected run log timestamps to use local time with timezone offset" >&2
  cat "$run_log" >&2
  exit 1
fi

overview="$log_dir/iterations.tsv"
if [[ ! -f "$overview" ]]; then
  echo "Expected iteration overview at $overview" >&2
  exit 1
fi

header="$(head -n 1 "$overview")"
if [[ "$header" != timestamp_local$'\t'* ]]; then
  echo "Expected iteration overview header to start with timestamp_local" >&2
  echo "$header" >&2
  exit 1
fi

first_timestamp="$(awk -F '\t' 'NR == 2 { print $1 }' "$overview")"
if ! grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}-0[45]00$' <<<"$first_timestamp"; then
  echo "Expected overview timestamp to use local New York time with offset, got: $first_timestamp" >&2
  exit 1
fi

echo "local time logging passed"
