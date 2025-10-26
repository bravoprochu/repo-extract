#!/bin/bash
set -e

#!/bin/bash
set -e

# Sync changes FROM main repository TO extracted repository
# This pulls changes from the main repo into your extracted repo
# This pulls the latest changes from the main repo for the selected folders

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FOLDERS_FILE="$SCRIPT_DIR/folders-to-extract.txt"

# If folders file doesn't exist in script dir, look in current dir
if [ ! -f "$FOLDERS_FILE" ]; then
    FOLDERS_FILE="./folders-to-extract.txt"
fi

echo "=========================================="
echo "Sync FROM Main Repository"
echo "=========================================="
echo ""

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "ERROR: Not in a git repository!"
    echo "Please run this script from your extracted repository."
    exit 1
fi

# Check if folders file exists
if [ ! -f "$FOLDERS_FILE" ]; then
    echo "ERROR: folders-to-extract.txt not found"
    echo "Please run this script from your extracted repository."
    echo "This file should have been created by 1-extract-repo.sh"
    exit 1
fi

# Read folders from file (trim whitespace)
FOLDERS=()
SYNC_MODES=()
while IFS= read -r line; do
    # Trim leading/trailing whitespace
    line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    # Skip empty lines and comments
    if [[ -n "$line" ]] && [[ ! "$line" =~ ^# ]]; then
        # Parse sync mode prefix (s:, c:, sync:, copy:)
        sync_mode="sync"  # default
        if [[ "$line" =~ ^(s|sync):(.+)$ ]]; then
            sync_mode="sync"
            line="${BASH_REMATCH[2]}"
        elif [[ "$line" =~ ^(c|copy):(.+)$ ]]; then
            sync_mode="copy"
            line="${BASH_REMATCH[2]}"
        fi
        
        FOLDERS+=("$line")
        SYNC_MODES+=("$sync_mode")
    fi
done < "$FOLDERS_FILE"

if [ ${#FOLDERS[@]} -eq 0 ]; then
    echo "ERROR: No folders specified in folders-to-extract.txt"
    exit 1
fi

echo "Items to sync from main:"
SYNC_COUNT=0
for i in "${!FOLDERS[@]}"; do
    folder="${FOLDERS[$i]}"
    mode="${SYNC_MODES[$i]}"
    if [ "$mode" = "sync" ]; then
        echo "  - $folder"
        SYNC_COUNT=$((SYNC_COUNT + 1))
    fi
done
echo ""

if [ $SYNC_COUNT -eq 0 ]; then
    echo "No items marked for sync! All items are copy-only."
    echo "Nothing to sync from main repository."
    exit 0
fi

# Check if main-repo remote exists
if ! git remote | grep -q "main-repo"; then
    echo "ERROR: Remote 'main-repo' not found!"
    echo "Please add it manually:"
    echo "  git remote add main-repo /home/bravoprochu/bp-nx"
    exit 1
fi

# Get the main branch name from the remote
MAIN_BRANCH=$(git remote show main-repo | grep "HEAD branch" | cut -d' ' -f5)
if [ -z "$MAIN_BRANCH" ]; then
    echo "Could not detect main branch, using 'marketing-campaign-manager'"
    MAIN_BRANCH="marketing-campaign-manager"
fi

echo "Fetching latest changes from main repository..."
git fetch main-repo

# Get main repo path
MAIN_REPO_PATH=$(git remote get-url main-repo)

# Separate folders from files, and filter by sync mode
FOLDER_PATHS=()
FILE_PATHS=()
FOLDER_SYNC_MODES=()
FILE_SYNC_MODES=()

for i in "${!FOLDERS[@]}"; do
    item="${FOLDERS[$i]}"
    mode="${SYNC_MODES[$i]}"
    
    if [ -d "$MAIN_REPO_PATH/$item" ]; then
        FOLDER_PATHS+=("$item")
        FOLDER_SYNC_MODES+=("$mode")
    elif [ -f "$MAIN_REPO_PATH/$item" ]; then
        FILE_PATHS+=("$item")
        FILE_SYNC_MODES+=("$mode")
    else
        # If it exists locally as a directory, treat as folder
        if [ -d "$item" ]; then
            FOLDER_PATHS+=("$item")
            FOLDER_SYNC_MODES+=("$mode")
        else
            FILE_PATHS+=("$item")
            FILE_SYNC_MODES+=("$mode")
        fi
    fi
done

# Sync folders - use simple copy/update approach (only sync mode items)
if [ ${#FOLDER_PATHS[@]} -gt 0 ]; then
    echo ""
    echo "Syncing folders..."
    
    for i in "${!FOLDER_PATHS[@]}"; do
        folder="${FOLDER_PATHS[$i]}"
        mode="${FOLDER_SYNC_MODES[$i]}"
        
        # Skip copy-only folders
        if [ "$mode" = "copy" ]; then
            continue
        fi
        
        echo ""
        echo "  📁 Syncing: $folder"
        
        if [ -d "$MAIN_REPO_PATH/$folder" ]; then
            # Create directory structure if needed
            mkdir -p "$(dirname "$folder")"
            
            # Remove old version and copy new version
            echo "     Updating folder..."
            rm -rf "$folder"
            cp -r "$MAIN_REPO_PATH/$folder" "$folder"
            
            # Add changes
            git add "$folder"
            
            echo "     ✅ Done"
        else
            echo "     ❌ Folder not found in main repo: $MAIN_REPO_PATH/$folder"
        fi
    done
    
    # Commit changes
    if git diff --staged --quiet; then
        echo ""
        echo "No changes to commit"
    else
        git commit -m "Sync folders from main repo: ${FOLDER_PATHS[*]}"
        echo ""
        echo "✅ Changes committed"
    fi
fi

# Sync files by copying
if [ ${#FILE_PATHS[@]} -gt 0 ]; then
    echo ""
    echo "Syncing files..."
    
    FILES_CHANGED=false
    for i in "${!FILE_PATHS[@]}"; do
        file="${FILE_PATHS[$i]}"
        mode="${FILE_SYNC_MODES[$i]}"
        
        # Skip copy-only files (they were copied once during extraction)
        if [ "$mode" = "copy" ]; then
            continue
        fi
        
        echo "  📄 Syncing: $file"
        
        # Create directory structure if needed
        file_dir=$(dirname "$file")
        if [ "$file_dir" != "." ]; then
            mkdir -p "$file_dir"
        fi
        
        # Copy file from main repo
        if [ -f "$MAIN_REPO_PATH/$file" ]; then
            cp "$MAIN_REPO_PATH/$file" "$file"
            git add "$file"
            FILES_CHANGED=true
        else
            echo "     ⚠️  File not found in main repo: $file"
        fi
    done
    
    # Commit changes if any
    if [ "$FILES_CHANGED" = true ]; then
        git commit -m "Sync files from main repo: ${FILE_PATHS[*]}" 2>/dev/null || echo "     No file changes to commit"
    fi
fi

echo ""
echo "=========================================="
echo "Sync completed successfully!"
echo "=========================================="
echo ""
echo "All folders are now up to date with the main repository."
echo ""
