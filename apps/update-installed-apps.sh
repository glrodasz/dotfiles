#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
JSON_FILE="$SCRIPT_DIR/installed-apps.json"

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install it with: brew install jq"
  exit 1
fi

if [ ! -f "$JSON_FILE" ] || ! jq empty "$JSON_FILE" 2>/dev/null; then
  echo "[]" > "$JSON_FILE"
fi

existing_json=$(cat "$JSON_FILE")

get_existing_url() {
  local name="$1"
  echo "$existing_json" | jq -r --arg n "$name" '(.[] | select(.name == $n) | .url) // empty'
}

lookup_appstore_url() {
  local bundle_id="$1"
  [ -z "$bundle_id" ] && return
  local response
  response=$(curl -sf "https://itunes.apple.com/lookup?bundleId=$bundle_id&country=us" 2>/dev/null)
  [ -z "$response" ] && return
  echo "$response" | jq -r '.results[0].trackViewUrl // empty' 2>/dev/null
}

echo "Scanning /Applications..."

bundle_ids_dir=$(mktemp -d)
all_apps_json="[]"

while IFS= read -r -d '' app_path; do
  app_file=$(basename "$app_path")
  app_name="${app_file%.app}"

  existing_url=$(get_existing_url "$app_name")
  existing_source=$(echo "$existing_json" | jq -r --arg n "$app_name" '(.[] | select(.name == $n) | .source) // empty')

  source_type="${existing_source:-}"
  url="${existing_url:-}"

  if [ -z "$url" ]; then
    bundle_id=$(defaults read "$app_path/Contents/Info" CFBundleIdentifier 2>/dev/null)
    if [ -n "$bundle_id" ]; then
      echo "$bundle_id" > "$bundle_ids_dir/$app_name"
    fi
  fi

  all_apps_json=$(echo "$all_apps_json" | jq \
    --arg name "$app_name" \
    --arg source "$source_type" \
    --arg url "$url" \
    '. + [{"name": $name, "source": $source, "url": $url}]')
done < <(find /Applications -maxdepth 1 -name "*.app" -print0 2>/dev/null)

existing_names=$(echo "$all_apps_json" | jq -r '.[].name')
while IFS= read -r entry; do
  [ -z "$entry" ] && continue
  name=$(echo "$entry" | jq -r '.name')
  if ! echo "$existing_names" | grep -Fxq "$name"; then
    all_apps_json=$(echo "$all_apps_json" | jq --argjson entry "$entry" '. + [$entry]')
  fi
done < <(echo "$existing_json" | jq -c '.[]')

all_apps_json=$(echo "$all_apps_json" | jq 'sort_by(.name | ascii_downcase)')

options=()
existing_app_names=$(echo "$existing_json" | jq -r '.[].name')
while IFS= read -r app_name; do
  [ -z "$app_name" ] && continue
  if echo "$existing_app_names" | grep -Fxq "$app_name"; then
    options+=("$app_name" "" ON)
  else
    options+=("$app_name" "" OFF)
  fi
done < <(echo "$all_apps_json" | jq -r '.[].name')

selected=$(whiptail --title "Select Installed Apps" --checklist \
  "Choose which applications to keep in the list:" 30 78 20 \
  "${options[@]}" 3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
  echo "Operation canceled."
  exit 0
fi

result="[]"
while IFS= read -r name; do
  [ -z "$name" ] && continue
  entry=$(echo "$all_apps_json" | jq -c --arg n "$name" '[.[] | select(.name == $n)][0]')
  [ "$entry" = "null" ] && continue
  result=$(echo "$result" | jq --argjson e "$entry" '. + [$e]')
done < <(echo "$selected" | sed 's/" "/"\n"/g' | tr -d '"')

result=$(echo "$result" | jq 'sort_by(.name | ascii_downcase)')

url_results_dir=$(mktemp -d)
pending=0
while IFS= read -r entry; do
  [ -z "$entry" ] && continue
  name=$(echo "$entry" | jq -r '.name')
  url=$(echo "$entry" | jq -r '.url')
  if [ -z "$url" ] && [ -f "$bundle_ids_dir/$name" ]; then
    bundle_id=$(cat "$bundle_ids_dir/$name")
    if [ -n "$bundle_id" ]; then
      echo "  Looking up $name..."
      (
        store_url=$(lookup_appstore_url "$bundle_id")
        if [ -n "$store_url" ]; then
          printf '%s\n%s' "appstore" "$store_url" > "$url_results_dir/$name"
        else
          printf '%s\n' "web" > "$url_results_dir/$name"
        fi
      ) &
      pending=$((pending + 1))
    fi
  fi
done < <(echo "$result" | jq -c '.[]')

if [ "$pending" -gt 0 ]; then
  echo "  Waiting for $pending lookups..."
  wait
  for f in "$url_results_dir"/*; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    src=$(head -1 "$f")
    url=$(tail -1 "$f")
    [ "$src" = "web" ] && url=""
    result=$(echo "$result" | jq --arg n "$name" --arg s "$src" --arg u "$url" \
      'map(if .name == $n then .source = $s | .url = $u else . end)')
  done
fi
rm -rf "$bundle_ids_dir" "$url_results_dir"

echo "$result" | jq '.' > "$JSON_FILE"
echo "Updated $JSON_FILE with $(echo "$result" | jq length) apps."
