#!/bin/bash

# update-csproj-rtr.sh
# This script recursively searches for .csproj files and
# either modifies an existing <PublishReadyToRun> tag to 'false',
# or inserts <PublishReadyToRun>false</PublishReadyToRun> just before
# the first </PropertyGroup> tag if it doesn't already exist.

# --- Configuration ---
# By default, the script runs in DRY RUN mode (no actual file modifications).
# To make it modify files, run with the -e or --execute option.
DRY_RUN=true

# --- Usage ---
usage() {
    echo "Usage: $0 [OPTIONS] [START_DIRECTORY]"
    echo "  Recursively updates or inserts <PublishReadyToRun>false</PublishReadyToRun> in .csproj files."
    echo ""
    echo "Options:"
    echo "  -e, --execute   Execute modifications (default is dry run)."
    echo "  -h, --help      Display this help message."
    echo ""
    echo "Examples:"
    echo "  $0                  # Dry run in current directory."
    echo "  $0 -e               # Execute in current directory."
    echo "  $0 -e /path/to/repo # Execute in a specific directory (dry run)."
    echo "  $0 -e /path/to/repo # Execute in a specific directory (actual modification)."
    exit 1
}

# --- Parse Command-line Arguments ---
START_DIR="." # Default starting directory is current directory
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -e|--execute)
            DRY_RUN=false
            shift
            ;;
        -h|--help)
            usage
            ;;
        *) # Positional argument (assumed to be START_DIRECTORY)
            if [[ -d "$1" ]]; then
                START_DIR="$1"
                shift
            else
                echo "Error: Unknown option or directory not found: '$1'"
                usage
            fi
            ;;
    esac
done

# --- Function to Process a Single .csproj File ---
process_csproj_file() {
    local file="$1"
    local action_taken="No change"

    # Check if <PublishReadyToRun> tag exists in the file
    if grep -q "<PublishReadyToRun>" "$file"; then
        # Check if it's already set to false
        if grep -q "<PublishReadyToRun>false</PublishReadyToRun>" "$file"; then
            action_taken="Already false"
        else
            # If it exists and is not 'false', modify it
            if [ "$DRY_RUN" = "false" ]; then
                sed -i "s|<PublishReadyToRun>.*</PublishReadyToRun>|<PublishReadyToRun>false</PublishReadyToRun>|g" "$file"
                action_taken="Modified existing"
            else
                action_taken="Would modify existing"
            fi
        fi
    else
        # If <PublishReadyToRun> does not exist, check for </PropertyGroup> to insert
        if grep -q "</PropertyGroup>" "$file"; then
            if [ "$DRY_RUN" = "false" ]; then
                # Insert the tag with 4 spaces indentation before the first </PropertyGroup>
                # The '\n' ensures a newline, and '    ' adds indentation.
                sed -i "/<\/PropertyGroup>/i\\\n    <PublishReadyToRun>false<\/PublishReadyToRun>" "$file"
                action_taken="Inserted"
            else
                action_taken="Would insert"
            fi
        else
            action_taken="No </PropertyGroup> tag found"
        fi
    fi
    echo "  [$action_taken] $file"
}

# --- Main Script Execution ---
echo "--- .csproj PublishReadyToRun Update Script ---"
echo "This script will search for .csproj files in '$START_DIR' and set or insert <PublishReadyToRun>false</PublishReadyToRun>."
echo "------------------------------------------------"
echo "!!! IMPORTANT: ALWAYS BACKUP YOUR FILES BEFORE RUNNING SCRIPTS THAT MODIFY THEM !!!"
echo "------------------------------------------------"
echo ""

if [ "$DRY_RUN" = "true" ]; then
    echo "MODE: DRY RUN ACTIVE - No files will be modified."
    echo "      Run with '-e' or '--execute' to apply changes."
else
    echo "MODE: EXECUTION ACTIVE - Files WILL be modified."
fi
echo ""

# Validate the starting directory
if [ ! -d "$START_DIR" ]; then
    echo "Error: The specified start directory '$START_DIR' does not exist."
    exit 1
fi

echo "Searching for .csproj files in '$START_DIR'..."
echo "---"

# Find and process each .csproj file safely (handles spaces in filenames)
find "$START_DIR" -name "*.csproj" -print0 | while IFS= read -r -d $'\0' file; do
    process_csproj_file "$file"
done

echo "---"
echo "Script Finished."
echo "Total .csproj files found: $(find "$START_DIR" -name "*.csproj" | wc -l)"
echo "Remember to rebuild your project after making these changes."
