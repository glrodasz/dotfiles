#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Search System Settings
# @raycast.mode silent
# @raycast.packageName System

# Optional parameters:
# @raycast.icon ⚙️
# @raycast.argument1 { "type": "text", "placeholder": "Setting" }

# Documentation:
# @raycast.author Guillermo Rodas
# @raycast.authorURL https://raycast.com/germorodas

QUERY="${1:-}"

# The query is pasted instead of typed because `keystroke` mangles accented letters.
osascript - "$QUERY" <<'EOF'
on run argv
  set q to item 1 of argv
  tell application "System Settings" to activate
  if q is "" then return

  tell application "System Events"
    tell process "System Settings"
      repeat until exists window 1
        delay 0.1
      end repeat
      delay 0.3

      set previousClipboard to ""
      try
        set previousClipboard to the clipboard
      end try
      set the clipboard to q
      keystroke "f" using command down
      delay 0.2
      keystroke "a" using command down
      keystroke "v" using command down
      delay 0.2
      set the clipboard to previousClipboard
    end tell
  end tell
end run
EOF
