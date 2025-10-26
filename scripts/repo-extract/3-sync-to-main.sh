#!/bin/bash

# Sync changes FROM extracted repository TO main repository
# This pushes your changes in the extracted repo back to the main repo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FOLDERS_FILE="$SCRIPT_DIR/folders-to-extract.txt"

# If folders file doesn't exist in script dir, look in current dir
if [ ! -f "$FOLDERS_FILE" ]; then
    FOLDERS_FILE="./folders-to-extract.txt"
fi

echo "=========================================="
echo "Sync TO Main Repository"
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

# Check for uncommitted changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "WARNING: You have uncommitted changes!"
    echo "Please commit your changes before syncing to main repository."
    echo ""
    read -p "Do you want to see the changes? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git status
    fi
    exit 1
fi

echo "Folders to sync back to main:"
SYNC_COUNT=0
COPY_ONLY_COUNT=0
for i in "${!FOLDERS[@]}"; do
    folder="${FOLDERS[$i]}"
    mode="${SYNC_MODES[$i]}"
    if [ "$mode" = "copy" ]; then
        COPY_ONLY_COUNT=$((COPY_ONLY_COUNT + 1))
    else
        echo "  - $folder"
        SYNC_COUNT=$((SYNC_COUNT + 1))
    fi
done
echo ""

if [ $SYNC_COUNT -eq 0 ]; then
    echo "No folders marked for sync! All folders are copy-only."
    echo "Nothing to push to main repository."
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

# Get main repo path
MAIN_REPO_PATH=$(git remote get-url main-repo)

echo "WARNING: This will push changes to the main repository!"
echo "Target: $MAIN_REPO_PATH"
echo "Branch: $MAIN_BRANCH"
echo ""
read -p "Are you sure you want to continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Separate folders from files
FOLDER_PATHS=()
FILE_PATHS=()

# Separate folders from files, and filter by sync mode
FOLDER_PATHS=()
FILE_PATHS=()
FOLDER_SYNC_MODES=()
FILE_SYNC_MODES=()

for i in "${!FOLDERS[@]}"; do
    item="${FOLDERS[$i]}"
    mode="${SYNC_MODES[$i]}"
    
    if [ -d "$item" ]; then
        FOLDER_PATHS+=("$item")
        FOLDER_SYNC_MODES+=("$mode")
    elif [ -f "$item" ]; then
        FILE_PATHS+=("$item")
        FILE_SYNC_MODES+=("$mode")
    fi
done

# Copy folders to main repo (only sync mode)
if [ ${#FOLDER_PATHS[@]} -gt 0 ]; then
    echo ""
    echo "Copying folders to main repository..."
    
    # Need to work in main repo for copying back
    CURRENT_DIR=$(pwd)
    cd "$MAIN_REPO_PATH" || exit 1
    
    # Ensure we're on the main branch
    git checkout "$MAIN_BRANCH" 2>/dev/null || git checkout -b "$MAIN_BRANCH"
    
    HAS_FOLDER_CHANGES=false
    for i in "${!FOLDER_PATHS[@]}"; do
        folder="${FOLDER_PATHS[$i]}"
        mode="${FOLDER_SYNC_MODES[$i]}"
        
        # Skip copy-only folders
        if [ "$mode" = "copy" ]; then
            continue
        fi
        
        echo "  📁 Copying: $folder"
        HAS_FOLDER_CHANGES=true
        
        # Remove old folder in main repo and copy new version from extracted repo
        rm -rf "$folder"
        cp -r "$CURRENT_DIR/$folder" "$folder"
        git add "$folder"
    done
    
    # Commit changes in main repo
    if [ "$HAS_FOLDER_CHANGES" = false ]; then
        echo "  ℹ️  No folders to sync (all were copy-only)"
    elif git diff --cached --quiet; then
        echo "  ✓ No changes to commit for folders"
    else
        # Build commit message with only synced folders
        SYNCED_FOLDERS=()
        for i in "${!FOLDER_PATHS[@]}"; do
            if [ "${FOLDER_SYNC_MODES[$i]}" = "sync" ]; then
                SYNCED_FOLDERS+=("${FOLDER_PATHS[$i]}")
            fi
        done
        git commit -m "Sync folders from extracted repo: ${SYNCED_FOLDERS[*]}"
        echo "  ✓ Committed folder changes to main repo"
    fi
    
    # Return to extracted repo
    cd "$CURRENT_DIR" || exit 1
fi

# Copy files directly to main repo (only sync mode)
if [ ${#FILE_PATHS[@]} -gt 0 ]; then
    echo ""
    echo "Copying files to main repository..."
    echo "⚠️  WARNING: Files will be copied directly (no history preservation)"
    echo ""
    
    HAS_FILE_CHANGES=false
    SYNCED_FILES=()
    for i in "${!FILE_PATHS[@]}"; do
        file="${FILE_PATHS[$i]}"
        mode="${FILE_SYNC_MODES[$i]}"
        
        # Skip copy-only files
        if [ "$mode" = "copy" ]; then
            continue
        fi
        
        if [ -f "$file" ]; then
            echo "  📄 Copying: $file"
            cp "$file" "$MAIN_REPO_PATH/$file"
            SYNCED_FILES+=("$file")
            HAS_FILE_CHANGES=true
        else
            echo "  ⚠️  File not found in extracted repo: $file"
        fi
    done
    
    if [ "$HAS_FILE_CHANGES" = false ]; then
        echo "  ℹ️  No files to sync (all were copy-only)"
    else
        echo ""
        echo "⚠️  Remember to commit and push the file changes in the main repository:"
        echo "  cd $MAIN_REPO_PATH"
        echo "  git add ${SYNCED_FILES[*]}"
        echo "  git commit -m 'Update files from extracted repo'"
        echo "  git push"
    fi
fi

echo ""
echo "=========================================="
echo "Sync completed successfully!"
echo "=========================================="
echo ""
echo "Your changes have been pushed to the main repository."
echo "Don't forget to pull changes in the main repository:"
echo "  cd $MAIN_REPO_PATH && git pull"
echo ""
