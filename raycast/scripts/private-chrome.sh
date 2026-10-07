#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Private Chrome
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🔒
# @raycast.argument1 { "type": "text", "placeholder": "Placeholder" }

# Documentation:
# @raycast.author Guillermo Rodas
# @raycast.authorURL https://raycast.com/germorodas

QUERY="${1:-}"
PROFILE="Profile 1"
CHROME_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

if [ -z "$QUERY" ]; then
  "$CHROME_PATH" \
    --profile-directory="$PROFILE" \
    --new-tab "about:blank"
else
  if [[ "$QUERY" =~ ^(https?://|www\.) || "$QUERY" =~ \.[a-zA-Z]{2,}$ ]]; then
    [[ ! "$QUERY" =~ ^https?:// ]] && QUERY="https://$QUERY"

    "$CHROME_PATH" \
      --profile-directory="$PROFILE" \
      --new-tab "$QUERY"
  else
    SEARCH_QUERY=$(printf '%s' "$QUERY" | jq -sRr @uri)

    "$CHROME_PATH" \
      --profile-directory="$PROFILE" \
      --new-tab "https://www.google.com/search?q=$SEARCH_QUERY"
  fi
fi
