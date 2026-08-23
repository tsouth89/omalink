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
if [[ ${1:-} == --device && ${3:-} == --send-clipboard ]]; then
  [[ ${2:-} == abc123 ]]
  exit
fi
exit 1
EOF
chmod +x "$temp_dir/kdeconnect-cli"

cat >"$temp_dir/busctl" <<'EOF'
#!/usr/bin/env bash
case "${*: -1}" in
  charge) printf '%s\n' 'i 71' ;;
  isCharging) printf '%s\n' 'b false' ;;
  cellularNetworkStrength) printf '%s\n' 'i 3' ;;
  cellularNetworkType) printf '%s\n' 's "5G"' ;;
  dismiss) exit 0 ;;
  activeConversations)
    printf '%s\n' '{"type":"av","data":[[{"type":"(isa(s)xiixixa(xsss))","data":[1,"Newest",[["+15550000001"]],2000,1,0,7,10,-1,[]]},{"type":"(isa(s)xiixixa(xsss))","data":[1,"Older",[["+15550000002"]],1000,2,1,8,11,-1,[]]}]]}'
    ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$temp_dir/busctl"

status="$(PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" status)"
jq -e '.installed == true and (.devices | length) == 2 and .devices[0].name == "Pixel 9" and .devices[0].battery.charge == 71 and .devices[0].connectivity.type == "5G"' <<<"$status" >/dev/null
PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" ring abc123 >/dev/null
PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" clipboard abc123 >/dev/null
PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" dismiss abc123 notification-1 >/dev/null
conversations="$(PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" conversations abc123)"
jq -e 'length == 2 and .[0].threadId == 7 and .[0].unread == true and .[0].names[0] == "+15550000001" and .[1].incoming == false' <<<"$conversations" >/dev/null
if PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" dismiss '../bad' notification-1 >/dev/null 2>&1; then
  echo "invalid device id was accepted" >&2
  exit 1
fi

echo "cli tests passed"
