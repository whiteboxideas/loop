#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

project_dir="$tmp_dir/project"
fake_pi="$tmp_dir/fake-pi.sh"
mkdir -p "$project_dir"

cat >"$fake_pi" <<'PI'
#!/usr/bin/env bash
cat <<'OUTPUT'
NIGHTSHIFT_TASK_PICKED_UP: NONE
NIGHTSHIFT_TASK_STATUS: none
NIGHTSHIFT_READINESS_DECISION: none - scaffold smoke test
NIGHTSHIFT_TDD: not practical; scaffold smoke test
NIGHTSHIFT_VALIDATION_COMMAND: not run
NIGHTSHIFT_VALIDATION_RESULT: not-run scaffold smoke test
NIGHTSHIFT_FIX: NONE
NIGHTSHIFT_DOCS: NONE
NIGHTSHIFT_FILES_TOUCHED:
- NONE
<promise>COMPLETE</promise>
OUTPUT
PI
chmod +x "$fake_pi"

PI_BIN="$fake_pi" PI_FLAGS="-p" \
  "$repo_root/night-shift.sh" --duration 0 --project "$project_dir" --iterations 1 >/dev/null

if [[ ! -d "$project_dir/.nightshift" ]]; then
  echo "Expected .nightshift directory to be created" >&2
  exit 1
fi

if [[ ! -f "$project_dir/.nightshift/BACKLOG.md" ]]; then
  echo "Expected .nightshift/BACKLOG.md to be created" >&2
  exit 1
fi

if [[ ! -f "$project_dir/.nightshift/CURRENT.md" ]]; then
  echo "Expected .nightshift/CURRENT.md to be created" >&2
  exit 1
fi

if [[ ! -f "$project_dir/.nightshift/DEFINITION_OF_DONE.md" ]]; then
  echo "Expected .nightshift/DEFINITION_OF_DONE.md to be created" >&2
  exit 1
fi

if [[ ! -f "$project_dir/.nightshift/.gitignore" ]]; then
  echo "Expected .nightshift/.gitignore to be created" >&2
  exit 1
fi

if ! grep -Fq "Recommended content:" "$project_dir/.nightshift/BACKLOG.md"; then
  echo "Expected BACKLOG.md scaffold to include recommended content guidance" >&2
  exit 1
fi

if ! grep -Fq 'The runner populates this file from `.nightshift/BACKLOG.md`' "$project_dir/.nightshift/CURRENT.md"; then
  echo "Expected CURRENT.md scaffold to explain backlog population" >&2
  exit 1
fi

if ! grep -Fq "Required validation commands" "$project_dir/.nightshift/DEFINITION_OF_DONE.md"; then
  echo "Expected DEFINITION_OF_DONE.md scaffold to include validation guidance" >&2
  exit 1
fi

if ! grep -Fxq "logs/" "$project_dir/.nightshift/.gitignore"; then
  echo "Expected .gitignore scaffold to ignore logs/" >&2
  exit 1
fi

run_log="$(find "$project_dir/.nightshift/logs/runs" -maxdepth 1 -type f -name '*.log' -print -quit)"
if [[ -z "$run_log" ]]; then
  echo "Expected a run log under project .nightshift/logs/runs" >&2
  exit 1
fi

if ! grep -Fq "CONFIG scaffolded_project_files=true" "$run_log"; then
  echo "Expected scaffold action to be logged in $run_log" >&2
  exit 1
fi

echo "nightshift scaffold passed"
