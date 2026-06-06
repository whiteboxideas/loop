#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

project_dir="$tmp_dir/project"
fake_pi="$tmp_dir/fake-pi.sh"
mkdir -p "$project_dir/.nightshift"

cat >"$project_dir/.nightshift/TODO.md" <<'TODO'
# Test TODO

## Ready tasks

- [ ] NS-TEST-001 Follow-up chain smoke task.
TODO

cat >"$project_dir/.nightshift/DEFINITION_OF_DONE.md" <<'DOD'
# Test Definition of Done

Run the relevant test command.
DOD

cat >"$project_dir/.nightshift/FOLLOW_UP_CHAIN.md" <<'CHAIN'
# Follow-up Chain Guidance

Architect reviews should focus on module boundaries.
CHAIN

cat >"$fake_pi" <<'PI'
#!/usr/bin/env bash
prompt="${2:-${1:-}}"
if [[ "$prompt" != *"Follow-up chain: ai:architect,ai:reviewer"* ]]; then
  echo "Expected runtime prompt to include configured follow-up chain" >&2
  exit 7
fi
if [[ "$prompt" != *"Follow-up config file:"*".nightshift/FOLLOW_UP_CHAIN.md"* ]]; then
  echo "Expected runtime prompt to include follow-up config file" >&2
  exit 8
fi
if [[ "$prompt" != *"take that perspective"* ]]; then
  echo "Expected base prompt to tell persona follow-up agents to take the configured perspective" >&2
  exit 9
fi
cat <<'OUTPUT'
NIGHTSHIFT_TASK_PICKED_UP: NS-TEST-001 Follow-up chain smoke task
NIGHTSHIFT_TASK_STATUS: done
NIGHTSHIFT_READINESS_DECISION: ready - follow-up chain smoke test
NIGHTSHIFT_TDD: not practical; follow-up chain smoke test
NIGHTSHIFT_VALIDATION_COMMAND: not run
NIGHTSHIFT_VALIDATION_RESULT: not-run follow-up chain smoke test
NIGHTSHIFT_FIX: NONE
NIGHTSHIFT_DOCS: NONE
NIGHTSHIFT_FILES_TOUCHED:
- NONE
<promise>COMPLETE</promise>
OUTPUT
PI
chmod +x "$fake_pi"

PI_BIN="$fake_pi" PI_FLAGS="-p" \
  "$repo_root/night-shift.sh" --duration 0 --project "$project_dir" --iterations 1 \
  --follow-up-chain ai:architect,ai:reviewer \
  --follow-up-config .nightshift/FOLLOW_UP_CHAIN.md >/dev/null

run_log="$(find "$project_dir/.nightshift/logs/runs" -maxdepth 1 -type f -name '*.log' -print -quit)"
if [[ -z "$run_log" ]]; then
  echo "Expected a run log under project .nightshift/logs/runs" >&2
  exit 1
fi

if ! grep -Fq "follow_up_chain=ai:architect,ai:reviewer" "$run_log"; then
  echo "Expected follow-up chain config to be logged in $run_log" >&2
  exit 1
fi

echo "follow-up chain passed"
