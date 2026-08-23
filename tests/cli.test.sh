#!/usr/bin/env bash

set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

cat >"$temp_dir/kdeconnect-cli" <<'EOF'
#!/usr/bin/env bash
if [[ ${1:-} == --list-available ]]; then
  printf '%s\n' 'abc123 Pixel 9' 'def456 Galaxy S25'
  exit 0
fi
if [[ ${1:-} == --device && ${3:-} == --ring ]]; then
  [[ ${2:-} == abc123 ]]
  exit
fi
exit 1
EOF
chmod +x "$temp_dir/kdeconnect-cli"

status="$(PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" status)"
jq -e '.installed == true and (.devices | length) == 2 and .devices[0].name == "Pixel 9"' <<<"$status" >/dev/null
PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" ring abc123 >/dev/null

echo "cli tests passed"
