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

- [ ] NS-TEST-001 Broad test task.
TODO

cat >"$project_dir/.nightshift/DEFINITION_OF_DONE.md" <<'DOD'
# Test Definition of Done

Run the relevant test command.
DOD

cat >"$fake_pi" <<'PI'
#!/usr/bin/env bash
cat <<'OUTPUT'
NIGHTSHIFT_TASK_PICKED_UP: NS-TEST-001 Broad test task
NIGHTSHIFT_TASK_STATUS: blocked
NIGHTSHIFT_READINESS_DECISION: split - broad task split into child TODOs
NIGHTSHIFT_TDD: not practical; readiness split only
NIGHTSHIFT_VALIDATION_COMMAND: not run
NIGHTSHIFT_VALIDATION_RESULT: not-run readiness split only
NIGHTSHIFT_FIX: NONE
NIGHTSHIFT_DOCS: NONE
NIGHTSHIFT_FILES_TOUCHED:
- .nightshift/TODO.md
<promise>COMPLETE</promise>
OUTPUT
PI
chmod +x "$fake_pi"

NIGHTSHIFT_LOG_DIR="$log_dir" PI_BIN="$fake_pi" PI_FLAGS="-p" \
  "$repo_root/night-shift.sh" --duration 0 --project "$project_dir" --iterations 1 >/dev/null

run_log="$(find "$log_dir/runs" -maxdepth 1 -type f -name '*.log' -print -quit)"
if [[ -z "$run_log" ]]; then
  echo "Expected a run log under $log_dir/runs" >&2
  exit 1
fi

if ! grep -Fq "READINESS iteration=1 decision=split - broad task split into child TODOs" "$run_log"; then
  echo "Expected readiness decision to be logged in $run_log" >&2
  exit 1
fi

echo "readiness logging passed"
