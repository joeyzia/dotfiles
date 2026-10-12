#!/usr/bin/env bash
# Ghostty-native desktop notification when Claude Code finishes a turn or needs input.
# Fired by the Stop and Notification hooks. Emits an OSC 777 escape to the Ghostty
# tab's pty so clicking the notification focuses that exact tab (Ghostty >= 1.3.0).
#
# Claude Code spawns hooks without a controlling terminal, so /dev/tty does not
# resolve to the tab. We walk up the process tree to Claude Code and use its tty.

payload="$(cat)"

event="$(printf '%s' "$payload" | jq -r '.hook_event_name // "Stop"')"
cwd="$(printf '%s' "$payload" | jq -r '.cwd // ""')"
msg="$(printf '%s' "$payload" | jq -r '.message // ""')"

dir="$(basename "${cwd:-$PWD}")"

case "$event" in
  Notification)
    title="Claude needs you — $dir"
    body="${msg:-Waiting for input}"
    ;;
  *)
    title="Claude done — $dir"
    body="Turn finished"
    ;;
esac

# Find the controlling tty by walking ancestors until one has a real ttys* device.
find_tty() {
  local pid="$1" t ppid
  while [ -n "$pid" ] && [ "$pid" -gt 1 ] 2>/dev/null; do
    t="$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')"
    case "$t" in
      ttys*) printf '/dev/%s' "$t"; return 0 ;;
    esac
    ppid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
    [ "$ppid" = "$pid" ] && break
    pid="$ppid"
  done
  return 1
}

emit() { printf '\033]777;notify;%s;%s\033\\' "$title" "$body" > "$1" 2>/dev/null; }

log="$HOME/.claude/hooks/notify-done.log"

# 1) Try our own controlling tty (works if the hook ever gets one).
if emit /dev/tty; then
  echo "$(date '+%H:%M:%S') event=$event ppid=$PPID via=/dev/tty" >> "$log"
  exit 0
fi

# 2) Walk up to Claude Code's tty and write the OSC there.
target="$(find_tty "$PPID")"
echo "$(date '+%H:%M:%S') event=$event ppid=$PPID target=${target:-NONE} writable=$([ -w "$target" ] && echo y || echo n)" >> "$log"
if [ -n "$target" ] && [ -w "$target" ] && emit "$target"; then exit 0; fi

exit 0
