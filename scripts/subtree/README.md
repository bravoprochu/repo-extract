# Repository Folder Sync Setup

Generic solution to extract specific folders from any Git monorepo into a separate repository while maintaining full sync capabilities.

## Overview

This toolset allows you to:

- Extract specific folders into a new repository
- Sync changes bidirectionally between repos
- Easily add more folders anytime
- **Works with ANY Git repository**

**Important Note:**
These scripts use file-based synchronization rather than true git subtree operations. This approach:

- ✅ More reliable with complex repository histories
- ✅ Works with reorganized folder structures
- ✅ Simple and predictable behavior
- ⚠️ Git history is NOT preserved for extracted folders
- ⚠️ Each sync creates a new commit rather than merging history

## Sync Modes Feature

Control how each folder/file syncs with **sync mode prefixes**:

| Prefix          | Mode                   | Description                                                |
| --------------- | ---------------------- | ---------------------------------------------------------- |
| `s:` or `sync:` | **Bidirectional Sync** | Changes sync both ways between main and extracted repos    |
| `c:` or `copy:` | **One-Time Copy**      | Copied once during extraction, then completely independent |

### Example Configuration

```
# folders-to-extract.txt

# Synced folders - stay in sync with main repo
s:libs/project-one
s:libs/shared/ngrx
sync:package.json

# Copy-only folders - copied once, then independent
c:libs/shared/common-controls
c:libs/shared/util
copy:nx.json
copy:tsconfig.base.json
```

### Use Cases

**Sync Mode (`s:`)** - Use for folders you actively develop:

- Your project-specific code (`libs/project-one`)
- Shared utilities you maintain
- Config files you customize and want to keep in sync

**Copy-Only Mode (`c:`)** - Use for folders you want as starting point:

- Shared libraries you'll fork and customize independently
- Template files you want to modify without affecting main
- Dependencies you need a snapshot of but will diverge from

### Behavior

**During Extraction (`1-extract-subtree.sh`):**

- Both `sync` and `copy` items are copied to new repo
- Sync modes are saved in `folders-to-extract.txt`

**Pull updates (`2-sync-from-main.sh`):**

- `sync` mode: Updates are pulled from main repo
- `copy` mode: Skipped entirely (already independent)

**Push changes (`3-sync-to-main.sh`):**

- `sync` mode: Changes are pushed to main repo
- `copy` mode: Skipped entirely (already independent)

📖 **[See full sync modes documentation](./SYNC_MODES.md)**

## Quick Start (Interactive Mode)

```bash
cd /path/to/your/main/repo
./scripts/subtree/1-extract-subtree.sh
```

**Interactive prompts:**

1. Select folders interactively? **y**
2. Enter folder paths one by one:
   ```
   Folder path: libs/project-one
   Folder path: libs/shared/util
   Folder path: package.json
   Folder path: [Enter to finish]
   ```
3. Path for new repository: `~/my-subtree-project`

**Done!** The script will:

- ✅ Extract folders with full git history
- ✅ Create `folders-to-extract.txt` in new repo
- ✅ Copy sync scripts to new repo
- ✅ Set up remote connection

## Quick Start (File Mode)

If you have `folders-to-extract.txt` already:

```bash
cd /path/to/your/main/repo
./scripts/subtree/1-extract-subtree.sh
```

Select **n** for interactive mode, and it will use your existing file.

## Daily Workflow

### In Subtree Repository

**Pull changes from main repo:**

```bash
cd ~/my-subtree-project
./2-sync-from-main.sh
```

**Push your changes to main repo:**

```bash
cd ~/my-subtree-project
git add .
git commit -m "My changes"
./3-sync-to-main.sh
```

### In Main Repository

After someone syncs from subtree:

```bash
cd /path/to/your/main/repo
git pull
```

## Adding More Folders

Edit `folders-to-extract.txt` in your subtree repo:

```bash
cd ~/my-subtree-project
nano folders-to-extract.txt
```

Add new folders:

```
libs/project-one
libs/shared/util
libs/shared/new-folder    ← Add this
package.json
```

Sync:

```bash
./2-sync-from-main.sh
```

## Files

- **`1-extract-subtree.sh`** - Creates subtree repo (run once from main repo)
- **`2-sync-from-main.sh`** - Pull updates (run from subtree repo)
- **`3-sync-to-main.sh`** - Push changes (run from subtree repo)
- **`folders-to-extract.txt`** - List of synced folders (auto-generated)

## Team Workflow

### Option 1: Subtree Repo Only (Recommended)

Most developers work only in the subtree repository:

```bash
git clone <subtree-repo-url>
# Work normally, no need for main repo!
```

### Option 2: Main Repo Only

Full-stack developers work in the main repository:

```bash
git clone <main-repo-url>
# Work on any project
```

### The Maintainer (You)

You bridge the two repos by running sync scripts when needed, or automate with CI/CD.

## Example: Complete Setup

```bash
# 1. Extract from main repo
cd ~/my-main-repo
./scripts/subtree/1-extract-subtree.sh

# Choose interactive mode
# Enter folders: libs/myapp, libs/shared/util, package.json
# New repo path: ~/myapp-subtree

# 2. Check the result
cd ~/myapp-subtree
ls -la
# → libs/myapp/, libs/shared/util/, package.json
# → folders-to-extract.txt, 2-sync-from-main.sh, 3-sync-to-main.sh

# 3. Make changes
echo "// new code" >> libs/myapp/src/index.ts
git add .
git commit -m "Added new code"

# 4. Push to main repo
./3-sync-to-main.sh

# 5. Pull in main repo
cd ~/my-main-repo
git pull
# → Your changes are now in main repo!
```

## Workflow Diagram

```
Main Repo                        Subtree Repo
├── libs/myapp/            ←→    ├── libs/myapp/
├── libs/shared/util/      ←→    ├── libs/shared/util/
├── libs/shared/other/            ├── package.json
├── package.json           ←→    └── [sync scripts]
└── [many other folders]

./2-sync-from-main.sh: Pull updates from main → subtree
./3-sync-to-main.sh:   Push changes from subtree → main
```

## Advanced: CI/CD Automation

### Auto-sync on push (GitHub Actions example)

**In main repo** `.github/workflows/sync-to-subtree.yml`:

```yaml
name: Sync to Subtree
on:
  push:
    branches: [main]
    paths:
      - "libs/myapp/**"
      - "libs/shared/util/**"
jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Push to subtree repo
        run: |
          # Use git subtree push or custom script
```

**In subtree repo** `.github/workflows/sync-to-main.yml`:

```yaml
name: Sync to Main
on:
  push:
    branches: [main]
jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Create PR in main repo
        run: |
          # Push changes and create PR
```

## Tips & Tricks

1. **Whitespace matters!** No leading spaces in folder paths
2. **Commit before syncing** to avoid conflicts
3. **Regular syncs** reduce merge conflicts
4. **Root files** like `package.json`, `tsconfig.json` can be synced too
5. **Test locally first** before setting up CI/CD

## Troubleshooting

### "Not a git repository"

Run sync scripts FROM the subtree repository, not main repo.

### "Remote 'main-repo' not found"

The subtree repo wasn't created with `1-extract-subtree.sh`. Manually add:

```bash
git remote add main-repo /path/to/main/repo
```

### Merge conflicts

1. Resolve conflicts in subtree repo
2. `git add <files>`
3. `git commit`
4. Continue syncing

### Want to start over?

```bash
rm -rf ~/my-subtree-project
cd ~/my-main-repo
./scripts/subtree/1-extract-subtree.sh
```

## FAQ

**Q: Do all devs need both repos?**  
A: No! Most devs only need the subtree repo. Only you (maintainer) or CI/CD needs both.

**Q: Can I have multiple subtree repos?**  
A: Yes! Run `1-extract-subtree.sh` multiple times with different folder selections.

**Q: What about git history?**  
A: Full history is preserved for extracted folders.

**Q: Performance impact?**  
A: Subtree repos are faster to clone and smaller in size.

**Q: Better than submodules?**  
A: For this use case (selective extraction), yes! No submodule initialization needed.

**Q: Can this work with any monorepo?**  
A: Yes! It's completely generic - works with any Git repository.

## Summary

1. **Extract**: `./1-extract-subtree.sh` (once, from main repo)
2. **Pull updates**: `./2-sync-from-main.sh` (from subtree repo)
3. **Push changes**: `./3-sync-to-main.sh` (from subtree repo)
4. **Add folders**: Edit `folders-to-extract.txt` + run step 2

That's it! 🚀
