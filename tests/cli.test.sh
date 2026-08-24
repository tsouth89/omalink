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
if [[ ${1:-} == --device && ${3:-} == --share-text ]]; then
  [[ ${2:-} == abc123 && ${4:-} == "hello phone" ]]
  exit
fi
if [[ ${1:-} == --device && ${3:-} == --share ]]; then
  [[ ${2:-} == abc123 && ${4:-} == "https://omalink.app" ]]
  exit
fi
if [[ ${1:-} == --device && ${3:-} == --send-sms ]]; then
  [[ ${2:-} == abc123 && ${4:-} == "New message" && ${5:-} == --destination && ${6:-} == +15550000001 ]]
  exit
fi
exit 1
EOF
chmod +x "$temp_dir/kdeconnect-cli"

cat >"$temp_dir/busctl" <<'EOF'
#!/usr/bin/env bash
if [[ " $* " == *" replyToConversation "* || " $* " == *" sendReply "* || " $* " == *" requestAttachmentFile "* ]]; then
  exit 0
fi
if [[ " $* " == *" monitor "* ]]; then
  printf '{"type":"signal","interface":"org.kde.kdeconnect.device.conversations","member":"attachmentReceived","payload":{"data":["%s","PART_1.jpeg"]}}\n' "$(dirname "$0")/attachment-full.jpg"
  sleep 3
  exit 0
fi
case "${*: -1}" in
  charge) printf '%s\n' 'i 71' ;;
  isCharging) printf '%s\n' 'b false' ;;
  cellularNetworkStrength) printf '%s\n' 'i 3' ;;
  cellularNetworkType) printf '%s\n' 's "5G"' ;;
  dismiss) echo "dismiss $*" >>"$0.log"; exit 0 ;;
  activeNotifications)
    printf '%s\n' '{"type":"as","data":[["notif.1","notif.2"]]}'
    ;;
  activeConversations)
    printf '%s\n' '{"type":"av","data":[[{"type":"(isa(s)xiixixa(xsss))","data":[1,"Newest",[["+15550000001"]],2000,1,0,7,10,-1,[[42,"image/jpeg","VGh1bWI=","PART_1.jpeg"]]]},{"type":"(isa(s)xiixixa(xsss))","data":[1,"Older",[["+15550000002"]],1000,2,1,8,11,-1,[]]}]]}'
    ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$temp_dir/busctl"

contact_dir="$temp_dir/data/kpeoplevcard/kdeconnect-abc123"
mkdir -p "$contact_dir"
cat >"$contact_dir/contact.vcf" <<'EOF'
BEGIN:VCARD
VERSION:2.1
FN:Alex Rivera
TEL;CELL:+15550000001
END:VCARD
EOF

status="$(PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" status)"
jq -e '.installed == true and (.devices | length) == 2 and .devices[0].name == "Pixel 9" and .devices[0].battery.charge == 71 and .devices[0].connectivity.type == "5G"' <<<"$status" >/dev/null
PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" ring abc123 >/dev/null
PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" clipboard abc123 >/dev/null
PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" share abc123 "hello phone" >/dev/null
PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" share abc123 "https://omalink.app" >/dev/null
PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" dismiss abc123 notification-1 >/dev/null
: >"$temp_dir/busctl.log"
PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" dismiss-all abc123 >/dev/null
[[ "$(grep -c '/notifications/notif\.' "$temp_dir/busctl.log")" == 2 ]]
PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" reply abc123 7 "Test reply" >/dev/null
PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" notify-reply abc123 reply-uuid.1 "Quick reply" >/dev/null
PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" sms abc123 +15550000001 "New message" >/dev/null
contacts="$(XDG_DATA_HOME="$temp_dir/data" PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" contacts abc123)"
jq -e 'length == 1 and .[0].name == "Alex Rivera" and .[0].number == "+15550000001"' <<<"$contacts" >/dev/null
conversations="$(XDG_DATA_HOME="$temp_dir/data" PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" conversations abc123)"
jq -e 'length == 2 and .[0].threadId == 7 and .[0].unread == true and .[0].names[0] == "Alex Rivera" and .[1].incoming == false' <<<"$conversations" >/dev/null
jq -e '.[0].attachments[0] == {partId: 42, mimeType: "image/jpeg", thumbnail: "VGh1bWI=", unique: "PART_1.jpeg"} and .[1].attachments == []' <<<"$conversations" >/dev/null
printf 'jpegbytes' >"$temp_dir/attachment-full.jpg"
attachment_path="$(PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" attachment abc123 42 PART_1.jpeg)"
[[ $attachment_path == "$temp_dir/attachment-full.jpg" ]]
saved_home="$temp_dir/home"
mkdir -p "$saved_home"
first_save="$(HOME="$saved_home" PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" attachment-save "$temp_dir/attachment-full.jpg")"
[[ $first_save == "$saved_home/Downloads/attachment-full.jpg" && -f $first_save ]]
second_save="$(HOME="$saved_home" PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" attachment-save "$temp_dir/attachment-full.jpg")"
[[ $second_save == "$saved_home/Downloads/attachment-full-1.jpg" && -f $second_save ]]
if PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" dismiss '../bad' notification-1 >/dev/null 2>&1; then
  echo "invalid device id was accepted" >&2
  exit 1
fi
if PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" reply abc123 bad "Test reply" >/dev/null 2>&1; then
  echo "invalid thread id was accepted" >&2
  exit 1
fi
if PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" notify-reply abc123 'bad reply;id' "Quick reply" >/dev/null 2>&1; then
  echo "invalid reply id was accepted" >&2
  exit 1
fi
if PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" attachment abc123 notanumber PART_1.jpeg >/dev/null 2>&1; then
  echo "invalid attachment part id was accepted" >&2
  exit 1
fi
if PATH="$temp_dir:/usr/bin" "$project_dir/bin/omalink" sms abc123 'bad;number' "Test" >/dev/null 2>&1; then
  echo "invalid SMS destination was accepted" >&2
  exit 1
fi

echo "cli tests passed"
