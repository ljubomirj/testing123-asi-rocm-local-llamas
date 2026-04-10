#!/bin/bash
# Extract git history from ~/.githome for sglang-rocm-glm-4.7-flash files

set -e

PROJECT_DIR="/home/ljubomir/sglang-rocm-glm-4.7-flash"
GITHOME_DIR="/home/ljubomir/.githome"
TEMP_DIR="/tmp/sglang-git-extract-$$"

echo "=== Extracting Git History ==="
echo "From: $GITHOME_DIR"
echo "To: $PROJECT_DIR/.git"
echo "Temp: $TEMP_DIR"
echo ""

# Step 1: Create temporary clone of githome
echo "Step 1: Creating temporary clone..."
git clone --no-hardlinks "file://$GITHOME_DIR" "$TEMP_DIR"
cd "$TEMP_DIR"

# Step 2: Use filter-branch to keep only sglang-rocm-glm-4.7-flash files
echo "Step 2: Filtering to keep only sglang-rocm-glm-4.7-flash files..."
git filter-branch --force --prune-empty \
  --subdirectory-filter sglang-rocm-glm-4.7-flash \
  --tag-name-filter cat \
  -- --all

# Step 3: Clean up
echo "Step 3: Cleaning up..."
git for-each-ref --format="%(refname)" refs/original/ | xargs -n 1 git update-ref -d
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Step 4: Move .git directory to project
echo "Step 4: Moving .git to project directory..."
cd "$PROJECT_DIR"

# Backup existing .git if it exists
if [ -d .git ]; then
  echo "  Backing up existing .git to .git.backup..."
  mv .git .git.backup
fi

# Move the filtered .git
mv "$TEMP_DIR/.git" "$PROJECT_DIR/.git"

# Step 5: Reset working tree
echo "Step 5: Resetting working tree..."
git reset --hard HEAD

# Step 6: Cleanup temp directory
echo "Step 6: Cleaning up temporary directory..."
rm -rf "$TEMP_DIR"

echo ""
echo "=== Success! ==="
echo "Git repository initialized with history from ~/.githome"
echo ""
echo "Summary:"
git log --oneline --all | head -20
echo ""
echo "Total commits: $(git rev-list --all --count)"
