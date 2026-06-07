#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

project_dir="$tmp_dir/project"
fake_pi="$tmp_dir/fake-pi.sh"
mkdir -p "$project_dir/.nightshift"

cd "$project_dir"
git init -q
git config user.email "nightshift-test@example.invalid"
git config user.name "Night Shift Test"

cat >".nightshift/TODO.md" <<'TODO'
# Test TODO

## Ready tasks

- [ ] NS-TEST-LOG Commit run logs.
TODO

cat >".nightshift/DEFINITION_OF_DONE.md" <<'DOD'
# Test Definition of Done

Run the relevant test command.
DOD

cat >".nightshift/.gitignore" <<'GITIGNORE'
logs/
GITIGNORE

git add .nightshift/TODO.md .nightshift/DEFINITION_OF_DONE.md .nightshift/.gitignore
git commit -qm "initial project"

printf 'pre-existing staged change\n' > user-change.txt
git add user-change.txt

cat >"$fake_pi" <<'PI'
#!/usr/bin/env bash
cat <<'OUTPUT'
NIGHTSHIFT_TASK_PICKED_UP: NS-TEST-LOG Commit run logs
NIGHTSHIFT_TASK_STATUS: done
NIGHTSHIFT_TASK_TYPE: implementation
NIGHTSHIFT_TASK_PERSONA: ai:implementer
NIGHTSHIFT_TASK_SOURCE: human-or-unmarked
NIGHTSHIFT_TOKEN_USAGE: unavailable
NIGHTSHIFT_READINESS_DECISION: ready - log commit smoke test
NIGHTSHIFT_TDD: not practical; log commit smoke test
NIGHTSHIFT_VALIDATION_COMMAND: not run
NIGHTSHIFT_VALIDATION_RESULT: not-run log commit smoke test
NIGHTSHIFT_FIX: NONE
NIGHTSHIFT_DOCS: no docs needed for smoke test
NIGHTSHIFT_FILES_TOUCHED:
- NONE
<promise>COMPLETE</promise>
OUTPUT
PI
chmod +x "$fake_pi"

PI_BIN="$fake_pi" PI_FLAGS="-p" \
  "$repo_root/night-shift.sh" --duration 0 --project "$project_dir" --iterations 1 >/dev/null

latest_subject="$(git log -1 --pretty=%s)"
if [[ "$latest_subject" != chore:\ add\ Night\ Shift\ run\ logs* ]]; then
  echo "Expected latest commit to be the Night Shift run log commit, got: $latest_subject" >&2
  exit 1
fi

changed_files="$(git diff-tree --no-commit-id --name-only -r HEAD)"
if grep -Fq "user-change.txt" <<<"$changed_files"; then
  echo "Expected log commit not to include pre-existing staged user changes" >&2
  exit 1
fi

if ! grep -Eq '^\.nightshift/logs/runs/[^/]+\.log$' <<<"$changed_files"; then
  echo "Expected per-run detail log to be committed" >&2
  echo "$changed_files" >&2
  exit 1
fi

if ! grep -Eq '^\.nightshift/logs/runs/[^/]+\.raw/iteration-1\.log$' <<<"$changed_files"; then
  echo "Expected raw iteration log to be committed" >&2
  echo "$changed_files" >&2
  exit 1
fi

if git ls-files --error-unmatch .nightshift/logs/night-shift.log >/dev/null 2>&1; then
  echo "Expected append-only general log to remain untracked to avoid dirtying later runs" >&2
  exit 1
fi

if [[ "$(git status --short user-change.txt)" != "A  user-change.txt" ]]; then
  echo "Expected pre-existing staged user change to remain staged" >&2
  git status --short >&2
  exit 1
fi

echo "log commit passed"
