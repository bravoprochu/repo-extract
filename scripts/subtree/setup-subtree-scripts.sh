#!/bin/bash
set -e

# Helper script to copy sync scripts to your subtree repository

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Setup Subtree Sync Scripts"
echo "=========================================="
echo ""

read -p "Enter the path to your subtree repository: " SUBTREE_REPO_PATH
SUBTREE_REPO_PATH=$(eval echo "$SUBTREE_REPO_PATH") # Expand ~

if [ -z "$SUBTREE_REPO_PATH" ]; then
    echo "ERROR: No path provided"
    exit 1
fi

if [ ! -d "$SUBTREE_REPO_PATH/.git" ]; then
    echo "ERROR: $SUBTREE_REPO_PATH is not a git repository"
    exit 1
fi

echo ""
echo "Copying sync scripts to: $SUBTREE_REPO_PATH"

# Copy the sync scripts
cp "$SCRIPT_DIR/2-sync-from-main.sh" "$SUBTREE_REPO_PATH/scripts/subtree"
cp "$SCRIPT_DIR/3-sync-to-main.sh" "$SUBTREE_REPO_PATH/scripts/subtree"
cp "$SCRIPT_DIR/folders-to-extract.txt" "$SUBTREE_REPO_PATH/scripts/subtree"

# Make them executable
chmod +x "$SUBTREE_REPO_PATH/2-sync-from-main.sh"
chmod +x "$SUBTREE_REPO_PATH/3-sync-to-main.sh"

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Sync scripts have been copied to your subtree repository."
echo ""
echo "Usage:"
echo "  cd $SUBTREE_REPO_PATH/scripts/subtree"
echo ""
echo "  # Pull changes FROM main repo:"
echo "  ./2-sync-from-main.sh"
echo ""
echo "  # Push changes TO main repo:"
echo "  ./3-sync-to-main.sh"
echo ""
