#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
package_file="$repo_root/package.json"
cli_file="$repo_root/night-shift.sh"

node - "$package_file" <<'NODE'
const fs = require('fs');
const packagePath = process.argv[2];
const pkg = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
const requiredBins = {
  'night-shift': './night-shift.sh',
  nightshift: './night-shift.sh',
};
for (const [name, target] of Object.entries(requiredBins)) {
  if (pkg.bin?.[name] !== target) {
    throw new Error(`Expected bin ${name} to point at ${target}`);
  }
}
for (const file of ['AGENT_LOOP.md', 'REACTNATIVE_DEFAULT_STYLE_GUIDE.md', 'README.md', 'night-shift.sh']) {
  if (!pkg.files?.includes(file)) {
    throw new Error(`Expected package files to include ${file}`);
  }
}
NODE

if [[ ! -x "$cli_file" ]]; then
  echo "Expected CLI file to be executable: $cli_file" >&2
  exit 1
fi

help_output="$($cli_file --help)"
if ! grep -Fq "Usage:" <<<"$help_output"; then
  echo "Expected CLI help output" >&2
  exit 1
fi

if ! grep -Fq "night-shift.sh --agent cursor" <<<"$help_output"; then
  echo "Expected help output to include cursor agent example" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
project_dir="$tmp_dir/project"
bin_dir="$tmp_dir/bin"
fake_pi="$tmp_dir/fake-pi.sh"
mkdir -p "$project_dir/.nightshift" "$bin_dir"
ln -s "$cli_file" "$bin_dir/night-shift"

cat >"$project_dir/.nightshift/TODO.md" <<'TODO'
# Test TODO

## Ready tasks

- [ ] NS-TEST-001 Symlinked CLI smoke task.
TODO

cat >"$project_dir/.nightshift/DEFINITION_OF_DONE.md" <<'DOD'
# Test Definition of Done

Run the relevant test command.
DOD

cat >"$fake_pi" <<'PI'
#!/usr/bin/env bash
cat <<'OUTPUT'
NIGHTSHIFT_TASK_PICKED_UP: NS-TEST-001 Symlinked CLI smoke task
NIGHTSHIFT_TASK_STATUS: done
NIGHTSHIFT_READINESS_DECISION: ready - symlinked cli smoke test
NIGHTSHIFT_TDD: not practical; symlinked cli smoke test
NIGHTSHIFT_VALIDATION_COMMAND: not run
NIGHTSHIFT_VALIDATION_RESULT: not-run symlinked cli smoke test
NIGHTSHIFT_FIX: NONE
NIGHTSHIFT_DOCS: NONE
NIGHTSHIFT_FILES_TOUCHED:
- NONE
<promise>COMPLETE</promise>
OUTPUT
PI
chmod +x "$fake_pi"

PI_BIN="$fake_pi" PI_FLAGS="-p" \
  "$bin_dir/night-shift" --duration 0 --project "$project_dir" --iterations 1 >/dev/null

echo "package cli passed"
