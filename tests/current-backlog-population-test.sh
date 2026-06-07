#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

project_dir="$tmp_dir/project"
fake_pi="$tmp_dir/fake-pi.sh"
fake_state="$tmp_dir/fake-pi-state"
mkdir -p "$project_dir/.nightshift"

cat >"$project_dir/.nightshift/BACKLOG.md" <<'BACKLOG'
# Test Backlog

## Ready tasks

- [ ] NS-TEST-001 First ready task.
  - Goal: Prove the runner moves one task into current work.
  - Validation notes: Smoke test only.

- [ ] NS-TEST-002 Second ready task.
  - Goal: Remain in the backlog until current work is complete.

## Draft tasks

- [ ] draft-NS-TEST-003 Draft task should not move.
BACKLOG

cat >"$project_dir/.nightshift/DEFINITION_OF_DONE.md" <<'DOD'
# Test Definition of Done

Run the relevant test command.
DOD

cat >"$fake_pi" <<PI
#!/usr/bin/env bash
state_file="$fake_state"
if [[ ! -f "\$state_file" ]]; then
  if ! grep -Fq "NS-TEST-001 First ready task" .nightshift/CURRENT.md; then
    echo "Expected first ready task to be moved into CURRENT.md" >&2
    exit 11
  fi
  if grep -Fq "NS-TEST-001 First ready task" .nightshift/BACKLOG.md; then
    echo "Expected moved task to be removed from BACKLOG.md Ready tasks" >&2
    exit 12
  fi
  if ! grep -Fq "NS-TEST-002 Second ready task" .nightshift/BACKLOG.md; then
    echo "Expected second ready task to remain in BACKLOG.md" >&2
    exit 13
  fi
  if grep -Fq "draft-NS-TEST-003" .nightshift/CURRENT.md; then
    echo "Expected draft task to stay out of CURRENT.md" >&2
    exit 14
  fi
  perl -0pi -e 's/- \\[ \\] NS-TEST-001/- [x] NS-TEST-001/' .nightshift/CURRENT.md
  touch "\$state_file"
  cat <<'OUTPUT'
NIGHTSHIFT_TASK_PICKED_UP: NS-TEST-001 First ready task
NIGHTSHIFT_TASK_STATUS: done
NIGHTSHIFT_READINESS_DECISION: ready - first current/backlog population smoke test
NIGHTSHIFT_TDD: shell regression test drove current/backlog population
NIGHTSHIFT_VALIDATION_COMMAND: not run
NIGHTSHIFT_VALIDATION_RESULT: not-run current/backlog population smoke test
NIGHTSHIFT_FIX: NONE
NIGHTSHIFT_DOCS: NONE
NIGHTSHIFT_FILES_TOUCHED:
- .nightshift/CURRENT.md
- .nightshift/BACKLOG.md
OUTPUT
  exit 0
fi

if ! grep -Fq "NS-TEST-002 Second ready task" .nightshift/CURRENT.md; then
  echo "Expected second ready task to be moved into CURRENT.md after first completed" >&2
  exit 21
fi
if ! grep -Fq "NS-TEST-001 First ready task" .nightshift/BACKLOG.md; then
  echo "Expected completed first task to be archived back into BACKLOG.md" >&2
  exit 22
fi
if grep -Fq "draft-NS-TEST-003" .nightshift/CURRENT.md; then
  echo "Expected draft task to stay out of CURRENT.md on second iteration" >&2
  exit 23
fi
cat <<'OUTPUT'
NIGHTSHIFT_TASK_PICKED_UP: NS-TEST-002 Second ready task
NIGHTSHIFT_TASK_STATUS: in-progress
NIGHTSHIFT_READINESS_DECISION: ready - second current/backlog population smoke test
NIGHTSHIFT_TDD: shell regression test drove current/backlog population
NIGHTSHIFT_VALIDATION_COMMAND: not run
NIGHTSHIFT_VALIDATION_RESULT: not-run current/backlog population smoke test
NIGHTSHIFT_FIX: NONE
NIGHTSHIFT_DOCS: NONE
NIGHTSHIFT_FILES_TOUCHED:
- .nightshift/CURRENT.md
- .nightshift/BACKLOG.md
<promise>COMPLETE</promise>
OUTPUT
PI
chmod +x "$fake_pi"

PI_BIN="$fake_pi" PI_FLAGS="-p" \
  "$repo_root/night-shift.sh" --duration 0 --project "$project_dir" --iterations 2 >/dev/null

run_log="$(find "$project_dir/.nightshift/logs/runs" -maxdepth 1 -type f -name '*.log' -print -quit)"
if [[ -z "$run_log" ]]; then
  echo "Expected a run log under project .nightshift/logs/runs" >&2
  exit 1
fi

if [[ "$(grep -Fc "CURRENT_TASK status=populated" "$run_log")" -ne 2 ]]; then
  echo "Expected two current task population log entries in $run_log" >&2
  exit 1
fi

if ! grep -Fq "CURRENT_TASK status=archived_completed" "$run_log"; then
  echo "Expected completed current task archival to be logged in $run_log" >&2
  exit 1
fi

echo "current backlog population passed"
