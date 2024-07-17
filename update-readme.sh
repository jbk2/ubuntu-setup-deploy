#!/bin/bash
set -euo pipefail

# Directory where README.md is located
REPO_DIR="/Users/jamesbkemp/Documents/Code/devops/toy-app1"

# Fetch the current date and time
CURRENT_DATE=$(date "+%Y-%m-%d %H:%M:%S")

# File path to README.md
README_FILE="$REPO_DIR/README.md"

# Check if README.md exists
if [[ -e "$README_FILE" ]]; then
    # Temporary file to hold the new version of README
    TEMP_FILE=$(mktemp)

    # Replace the placeholder with the current date and time
    sed "s/Last updated: \`.*\`/Last updated: \`$CURRENT_DATE\`/g" "$README_FILE" > "$TEMP_FILE"

    # Move the temporary file to the original file
    mv "$TEMP_FILE" "$README_FILE"

    # Add the changes to the git repository to be included in the current commit
    git add "$README_FILE"
else
    echo "README.md does not exist in the specified directory."
    exit 1  # Exit with an error status if README.md is not found
fi
