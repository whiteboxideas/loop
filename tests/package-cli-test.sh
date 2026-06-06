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

echo "package cli passed"
