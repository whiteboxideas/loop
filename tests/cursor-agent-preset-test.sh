#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

project_dir="$tmp_dir/project"
bin_dir="$tmp_dir/bin"
marker_file="$tmp_dir/cursor-agent-invoked"
mkdir -p "$project_dir/.nightshift" "$bin_dir"

cat >"$project_dir/.nightshift/TODO.md" <<'TODO'
# Test TODO

## Ready tasks

- [ ] NS-TEST-001 Cursor preset smoke task.
TODO

cat >"$project_dir/.nightshift/DEFINITION_OF_DONE.md" <<'DOD'
# Test Definition of Done

Run the relevant test command.
DOD

cat >"$bin_dir/agent" <<PI
#!/usr/bin/env bash
if [[ "\${1:-}" != "--yolo" ]]; then
  echo "Expected cursor preset to invoke: agent --yolo <prompt>; got first arg: \${1:-}" >&2
  exit 7
fi
if [[ -z "\${2:-}" ]]; then
  echo "Expected runtime prompt as second argument" >&2
  exit 8
fi
printf 'ok\n' >"$marker_file"
cat <<'OUTPUT'
NIGHTSHIFT_TASK_PICKED_UP: NS-TEST-001 Cursor preset smoke task
NIGHTSHIFT_TASK_STATUS: done
NIGHTSHIFT_READINESS_DECISION: ready - cursor preset smoke test
NIGHTSHIFT_TDD: not practical; cursor preset smoke test
NIGHTSHIFT_VALIDATION_COMMAND: not run
NIGHTSHIFT_VALIDATION_RESULT: not-run cursor preset smoke test
NIGHTSHIFT_FIX: NONE
NIGHTSHIFT_DOCS: NONE
NIGHTSHIFT_FILES_TOUCHED:
- NONE
<promise>COMPLETE</promise>
OUTPUT
PI
chmod +x "$bin_dir/agent"

PATH="$bin_dir:$PATH" \
  "$repo_root/night-shift.sh" --agent cursor --duration 0 --project "$project_dir" --iterations 1 >/dev/null

if [[ ! -f "$marker_file" ]]; then
  echo "Expected cursor agent preset command to be invoked" >&2
  exit 1
fi

run_log="$(find "$project_dir/.nightshift/logs/runs" -maxdepth 1 -type f -name '*.log' -print -quit)"
if [[ -z "$run_log" ]]; then
  echo "Expected a run log under project .nightshift/logs/runs" >&2
  exit 1
fi

if ! grep -Fq "agent=cursor command=agent flags=--yolo" "$run_log"; then
  echo "Expected cursor agent config to be logged in $run_log" >&2
  exit 1
fi

echo "cursor agent preset passed"
