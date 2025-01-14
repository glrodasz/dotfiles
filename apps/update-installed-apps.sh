#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Generate the current list of installed applications
current_apps=$(mktemp)
find /Applications -maxdepth 1 -name "*.app" -print0 | while IFS= read -r -d '' file; do
    basename "$file"
done > "$current_apps"

# Define the path to the existing list of installed applications
existing_apps="$SCRIPT_DIR/installed-apps"

# Check if the existing_apps file exists, if not create an empty one
if [ ! -f "$existing_apps" ]; then
    touch "$existing_apps"
fi

# Combine both lists and remove duplicates
combined_apps=$(sort -u "$current_apps" "$existing_apps")

# Prepare the options for whiptail
options=()
while IFS= read -r app; do
    # Skip empty lines
    [ -z "$app" ] && continue
    
    if grep -Fxq "$app" "$existing_apps" 2>/dev/null; then
        options+=("$app" "" ON)
    else
        options+=("$app" "" OFF)
    fi
done <<< "$combined_apps"

# Use whiptail to present the options
selected_apps=$(whiptail --title "Select Installed Apps" --checklist \
"Choose which applications to keep in the list:" 20 78 15 \
"${options[@]}" 3>&1 1>&2 2>&3)

# Check if the user canceled the operation
if [ $? -eq 0 ]; then
    # Update the installed-apps file with the selected applications
    # Put each app on its own line while preserving spaces within app names
    echo "$selected_apps" | tr -d '"' | sed 's/\.app /.app\n/g' > "$existing_apps"
    echo "The installed-apps file has been updated."
else
    echo "Operation canceled."
fi

# Clean up
rm "$current_apps"