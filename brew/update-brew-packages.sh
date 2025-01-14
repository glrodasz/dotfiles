#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Generate the current list of installed brew packages
current_packages=$(mktemp)
brew leaves > "$current_packages"

# Define the path to the existing list of brew packages
existing_packages="$SCRIPT_DIR/packages"

# Check if the existing_packages file exists, if not create an empty one
if [ ! -f "$existing_packages" ]; then
    touch "$existing_packages"
fi

# Combine both lists and remove duplicates
combined_packages=$(sort -u "$current_packages" "$existing_packages")

# Prepare the options for whiptail
options=()
while IFS= read -r package; do
    # Skip empty lines
    [ -z "$package" ] && continue
    
    if grep -Fxq "$package" "$existing_packages" 2>/dev/null; then
        options+=("$package" "" ON)
    else
        options+=("$package" "" OFF)
    fi
done <<< "$combined_packages"

# Use whiptail to present the options
selected_packages=$(whiptail --title "Select Brew Packages" --checklist \
"Choose which packages to keep in the list:" 20 78 15 \
"${options[@]}" 3>&1 1>&2 2>&3)

# Check if the user canceled the operation
if [ $? -eq 0 ]; then
    # Update the packages file with the selected packages
    echo "$selected_packages" | tr -d '"' | tr ' ' '\n' > "$existing_packages"
    echo "The packages file has been updated."
else
    echo "Operation canceled."
fi

# Clean up
rm "$current_packages" 