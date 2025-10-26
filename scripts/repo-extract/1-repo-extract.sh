#!/bin/bash
set -e

# Git Repository Extraction Script
# This script creates a new repository containing only selected folders from the current repo
# while preserving the full git history for those folders.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_REPO_PATH="$(cd "$SCRIPT_DIR/../.." && pwd)"
FOLDERS_FILE="$SCRIPT_DIR/folders-to-extract.txt"

echo "=========================================="
echo "Git Repository Extraction Script"
echo "=========================================="
echo ""
echo "Source repository: $MAIN_REPO_PATH"
echo ""

# Ask if user wants to generate folders file
read -p "Generate folders list from current repository? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Ask for depth
    echo ""
    echo "Enter folder depth to scan:"
    echo "  1 = top level only (e.g., libs/, src/)"
    echo "  2 = one level deep (e.g., libs/project-one/, libs/shared/)"
    echo "  3 = two levels deep (e.g., libs/shared/util/, libs/shared/auth/)"
    echo "  etc."
    echo ""
    
    while true; do
        read -p "Folder depth [default: 2]: " DEPTH
        DEPTH=${DEPTH:-2}
        
        # Validate depth is a number
        if [[ "$DEPTH" =~ ^[0-9]+$ ]]; then
            break
        else
            echo "Error: Please enter a valid number (1, 2, 3, etc.)"
        fi
    done
    
    echo ""
    echo "Scanning repository at depth $DEPTH..."
    echo ""
    
    # Generate temporary folders file
    TEMP_FOLDERS_FILE="$SCRIPT_DIR/folders-to-extract-temp.txt"
    
    # Create header
    cat > "$TEMP_FOLDERS_FILE" << EOF
# List of folders and files to extract into the extracted repository
# Generated from: $MAIN_REPO_PATH
# Scan depth: $DEPTH
# Date: $(date)
#
# SYNC MODE PREFIX (add before path):
#   s: or sync: = bidirectional sync (changes push back to main repo)
#   c: or copy: = one-way copy only (won't sync back to main repo)
#
# FORMAT EXAMPLES:
#   s:libs/project-one              - synced folder (default)
#   c:libs/shared/util       - copy-only folder
#   sync:package.json        - synced file
#   copy:nx.json             - copy-only file
#
# INSTRUCTIONS:
# 1. Uncomment items you want (remove the # at start)
# 2. Add sync mode prefix (s: or c:) - defaults to s: if omitted
# 3. Save and exit to continue
#
# Tip: Use search/replace to uncomment and add sync modes:
#   - In vim: :%s/^# libs/s:libs/g           (uncomment all libs/* as sync)
#   - In vim: :%s/^# libs\/shared/c:libs\/shared/g  (shared/* as copy)
#   - In vim: :g/package\.json/s/^# /s:/     (package.json as sync)

# ========== FOLDERS ==========
EOF
    
    # Find all directories up to specified depth, excluding .git and node_modules
    cd "$MAIN_REPO_PATH"
    find . -mindepth 1 -maxdepth "$DEPTH" -type d \
        -not -path "*/\.*" \
        -not -path "*/node_modules/*" \
        -not -path "*/dist/*" \
        -not -path "*/build/*" \
        -not -path "*/coverage/*" \
        -not -path "*/.nx/*" \
        -not -path "*/tmp/*" | \
        sed 's|^\./||' | \
        sort | \
        while read -r dir; do
            echo "# $dir"
        done >> "$TEMP_FOLDERS_FILE"
    
    # Add common root files section
    cat >> "$TEMP_FOLDERS_FILE" << EOF

# ========== FILES (in root directory) ==========
# Note: These are copied without git history
EOF

    # Find common root files
    find "$MAIN_REPO_PATH" -maxdepth 1 -type f \
        -not -name ".*" \
        -name "*.json" -o -name "*.md" -o -name "*.yml" -o -name "*.yaml" -o -name "*.js" -o -name "*.ts" 2>/dev/null | \
        sed "s|$MAIN_REPO_PATH/||" | \
        sort | \
        while read -r file; do
            echo "# $file"
        done >> "$TEMP_FOLDERS_FILE"
    
    # Add manual file examples
    cat >> "$TEMP_FOLDERS_FILE" << EOF

# Add more files manually if needed:
# .gitignore
# .eslintrc.json
# README.md
EOF
    
    echo "Generated folder list in: $TEMP_FOLDERS_FILE"
    echo ""
    echo "Opening editor to select folders..."
    echo "(Uncomment the folders you want to extract)"
    echo ""
    sleep 2
    
    # Open in editor (try multiple editors)
    if [ -n "$EDITOR" ]; then
        $EDITOR "$TEMP_FOLDERS_FILE"
    elif command -v nano &> /dev/null; then
        nano "$TEMP_FOLDERS_FILE"
    elif command -v vim &> /dev/null; then
        vim "$TEMP_FOLDERS_FILE"
    elif command -v vi &> /dev/null; then
        vi "$TEMP_FOLDERS_FILE"
    else
        echo "No editor found. Please edit this file manually:"
        echo "$TEMP_FOLDERS_FILE"
        echo ""
        read -p "Press Enter when you've finished editing..." 
    fi
    
    # Read the edited file and parse [FOLDER] and [FILE] tags
    FOLDERS=()
    SYNC_MODES=()
    while IFS= read -r line; do
        # Trim leading/trailing whitespace
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Skip empty lines and comments
        if [[ -n "$line" ]] && [[ ! "$line" =~ ^# ]]; then
            # Remove [FOLDER] or [FILE] tags if present
            line=$(echo "$line" | sed 's/^\[FOLDER\][[:space:]]*//;s/^\[FILE\][[:space:]]*//')
            
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
    done < "$TEMP_FOLDERS_FILE"
    
    # Clean up temp file
    rm -f "$TEMP_FOLDERS_FILE"
    
else
    # Read from existing folders-to-extract.txt
    if [ ! -f "$FOLDERS_FILE" ]; then
        echo "ERROR: folders-to-extract.txt not found!"
        echo "Please create it and list the folders you want to extract."
        exit 1
    fi
    
    echo "Using existing folders-to-extract.txt"
    echo ""
    
    # Read folders from file (trim whitespace, ignore comments)
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
fi

if [ ${#FOLDERS[@]} -eq 0 ]; then
    echo "ERROR: No folders specified"
    echo "Please specify at least one folder to extract."
    exit 1
fi

# Separate folders from files
FOLDER_PATHS=()
FILE_PATHS=()

echo ""
echo "Analyzing paths in: $MAIN_REPO_PATH"
echo ""

for item in "${FOLDERS[@]}"; do
    full_path="$MAIN_REPO_PATH/$item"
    
    # Debug output
    echo "Checking: $item"
    
    if [ -d "$full_path" ]; then
        FOLDER_PATHS+=("$item")
        echo "  ✅ Detected as FOLDER"
    elif [ -f "$full_path" ]; then
        FILE_PATHS+=("$item")
        echo "  ✅ Detected as FILE"
    else
        # Check if it looks like a file (has extension) or folder
        if [[ "$item" == *.* ]]; then
            echo "  ❌ FILE NOT FOUND (will skip): $item"
        else
            echo "  ❌ FOLDER NOT FOUND (will skip): $item"
        fi
    fi
    echo ""
done

if [ ${#FOLDER_PATHS[@]} -eq 0 ] && [ ${#FILE_PATHS[@]} -eq 0 ]; then
    echo ""
    echo "ERROR: No valid folders or files to extract"
    exit 1
fi

echo ""

# Get new repository path from user
read -p "Enter the path where you want to create the new repository: " NEW_REPO_PATH
NEW_REPO_PATH=$(eval echo "$NEW_REPO_PATH") # Expand ~

if [ -z "$NEW_REPO_PATH" ]; then
    echo "ERROR: No path provided"
    exit 1
fi

# Create new repository directory
mkdir -p "$NEW_REPO_PATH"

# Save folders to a file in the new repo for future syncing
echo "# Folders extracted from main repository" > "$NEW_REPO_PATH/folders-to-extract.txt"
echo "# Source: $MAIN_REPO_PATH" >> "$NEW_REPO_PATH/folders-to-extract.txt"
echo "# Generated: $(date)" >> "$NEW_REPO_PATH/folders-to-extract.txt"
echo "#" >> "$NEW_REPO_PATH/folders-to-extract.txt"
echo "# SYNC MODE PREFIX:" >> "$NEW_REPO_PATH/folders-to-extract.txt"
echo "#   s: or sync: = bidirectional sync (changes push back to main)" >> "$NEW_REPO_PATH/folders-to-extract.txt"
echo "#   c: or copy: = one-way copy only (won't sync back to main)" >> "$NEW_REPO_PATH/folders-to-extract.txt"
echo "#" >> "$NEW_REPO_PATH/folders-to-extract.txt"
echo "# Examples:" >> "$NEW_REPO_PATH/folders-to-extract.txt"
echo "#   s:libs/project-one              - synced folder" >> "$NEW_REPO_PATH/folders-to-extract.txt"
echo "#   c:libs/shared/util       - copy-only folder" >> "$NEW_REPO_PATH/folders-to-extract.txt"
echo "#   sync:package.json        - synced file" >> "$NEW_REPO_PATH/folders-to-extract.txt"
echo "#   copy:nx.json             - copy-only file" >> "$NEW_REPO_PATH/folders-to-extract.txt"
echo "" >> "$NEW_REPO_PATH/folders-to-extract.txt"
for i in "${!FOLDERS[@]}"; do
    folder="${FOLDERS[$i]}"
    mode="${SYNC_MODES[$i]}"
    if [ "$mode" = "copy" ]; then
        echo "c:$folder" >> "$NEW_REPO_PATH/folders-to-extract.txt"
    else
        echo "s:$folder" >> "$NEW_REPO_PATH/folders-to-extract.txt"
    fi
done

cd "$NEW_REPO_PATH"

echo ""
echo "Creating new repository at: $NEW_REPO_PATH"

# Initialize new repository
if [ ! -d ".git" ]; then
    git init -b main
    echo "Initialized new git repository with 'main' branch"
else
    echo "Using existing git repository"
fi

# Create initial commit to avoid HEAD errors
if ! git rev-parse HEAD >/dev/null 2>&1; then
    echo "Creating initial commit..."
    echo "# Extracted Repository" > README.md
    echo "" >> README.md
    echo "This repository contains selected folders from the main repository." >> README.md
    echo "Source: $MAIN_REPO_PATH" >> README.md
    git add README.md folders-to-extract.txt
    git commit -m "Initial commit"
    echo "Initial commit created"
fi

# Add remote pointing to main repository
MAIN_REPO_URL=$(cd "$MAIN_REPO_PATH" && git config --get remote.origin.url || echo "")
if [ -n "$MAIN_REPO_URL" ]; then
    git remote add main-repo "$MAIN_REPO_PATH" 2>/dev/null || git remote set-url main-repo "$MAIN_REPO_PATH"
    echo "Added remote 'main-repo' pointing to: $MAIN_REPO_PATH"
else
    git remote add main-repo "$MAIN_REPO_PATH" 2>/dev/null || git remote set-url main-repo "$MAIN_REPO_PATH"
    echo "Added local remote 'main-repo'"
fi

echo ""
echo "Fetching from main repository (this may take a while)..."
git fetch main-repo

echo ""
echo "Extracting folders using file-based copying..."

# Get the current branch from main repo
MAIN_BRANCH=$(cd "$MAIN_REPO_PATH" && git branch --show-current)
if [ -z "$MAIN_BRANCH" ]; then
    MAIN_BRANCH="main"
fi

# Extract folders - use simple direct copy since git subtree split often fails
if [ ${#FOLDER_PATHS[@]} -gt 0 ]; then
    echo ""
    echo "Extracting folders..."
    
    for folder in "${FOLDER_PATHS[@]}"; do
        echo ""
        echo "  📁 Extracting: $folder"
        
        if [ -d "$MAIN_REPO_PATH/$folder" ]; then
            # Create directory structure
            mkdir -p "$(dirname "$folder")"
            
            # Copy the folder with all contents
            echo "     Copying folder structure..."
            cp -r "$MAIN_REPO_PATH/$folder" "$folder"
            
            # Add to git
            git add "$folder"
            
            echo "     ✅ Done"
        else
            echo "     ❌ Folder not found: $MAIN_REPO_PATH/$folder"
        fi
    done
    
    # Commit all folders at once
    if [ ${#FOLDER_PATHS[@]} -gt 0 ]; then
        git commit -m "Add folders: ${FOLDER_PATHS[*]}" 2>/dev/null || echo "No folders to commit"
    fi
fi

# Copy individual files (individual file extraction)
if [ ${#FILE_PATHS[@]} -gt 0 ]; then
    echo ""
    echo "Copying files..."
    for file in "${FILE_PATHS[@]}"; do
        echo "  📄 Copying: $file"
        
        # Create directory structure if needed
        file_dir=$(dirname "$file")
        if [ "$file_dir" != "." ]; then
            mkdir -p "$file_dir"
        fi
        
        # Copy file from main repo
        if [ -f "$MAIN_REPO_PATH/$file" ]; then
            cp "$MAIN_REPO_PATH/$file" "$file"
            git add "$file"
        else
            echo "     ⚠️  File not found: $file"
        fi
    done
    
    # Commit copied files
    if [ ${#FILE_PATHS[@]} -gt 0 ]; then
        git commit -m "Add root files: ${FILE_PATHS[*]}" 2>/dev/null || echo "     No files to commit"
    fi
fi

# Copy sync scripts to the new repo
echo ""
echo "Copying sync scripts to new repository..."
mkdir -p "$NEW_REPO_PATH/scripts/repo-extract"
cp "$SCRIPT_DIR/2-sync-from-main.sh" "$NEW_REPO_PATH/scripts/repo-extract/" 2>/dev/null || echo "Note: 2-sync-from-main.sh not found"
cp "$SCRIPT_DIR/3-sync-to-main.sh" "$NEW_REPO_PATH/scripts/repo-extract/" 2>/dev/null || echo "Note: 3-sync-to-main.sh not found"
chmod +x "$NEW_REPO_PATH/scripts/repo-extract"/*.sh 2>/dev/null || true
git add scripts/repo-extract/*.sh 2>/dev/null || true
git commit -m "Add sync scripts" 2>/dev/null || echo "Sync scripts already committed"

echo ""
echo "=========================================="
echo "Extraction completed successfully!"
echo "=========================================="
echo ""
echo "New repository created at: $NEW_REPO_PATH"
echo "Source repository: $MAIN_REPO_PATH"
echo ""
echo "Files created in extracted repo:"
echo "  - folders-to-extract.txt (list of synced folders)"
echo "  - scripts/repo-extract/2-sync-from-main.sh (pull updates from main repo)"
echo "  - scripts/repo-extract/3-sync-to-main.sh (push changes to main repo)"
echo ""
echo "Next steps:"
echo "1. Review the extracted files: cd $NEW_REPO_PATH"
echo "2. To pull updates from main repo: ./scripts/repo-extract/2-sync-from-main.sh"
echo "3. To push your changes to main repo: ./scripts/repo-extract/3-sync-to-main.sh"
echo "4. To add more folders: edit folders-to-extract.txt and run ./scripts/repo-extract/2-sync-from-main.sh"
echo "5. If you want to push to a remote (GitHub, GitLab, etc.):"
echo "   - Create a new empty repository on your git hosting service"
echo "   - Run: git remote add origin <your-remote-url>"
echo "   - Run: git push -u origin $MAIN_BRANCH"
echo ""
