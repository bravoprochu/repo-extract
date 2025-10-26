# Sync Modes Feature

## Overview

Sync modes give you fine-grained control over which folders/files sync bidirectionally and which are copy-only.

## Syntax

Add a prefix to each line in `folders-to-extract.txt`:

| Prefix | Aliases | Mode                   | Pull Updates | Push Changes |
| ------ | ------- | ---------------------- | ------------ | ------------ |
| `s:`   | `sync:` | **Bidirectional Sync** | ✅ Yes       | ✅ Yes       |
| `c:`   | `copy:` | **One-Time Copy**      | ❌ No        | ❌ No        |

**Note:** If no prefix is provided, defaults to `s:` (sync mode)

## Example Configuration

```
# folders-to-extract.txt

# Active development - stay in sync
s:libs/project-one
s:libs/shared/ngrx
sync:package.json

# One-time copy - then independent
c:libs/shared/common-controls
c:libs/shared/util
copy:nx.json
copy:tsconfig.base.json
```

## Use Cases

### Sync Mode (`s:` or `sync:`)

Use for folders/files you actively develop and want changes to sync back to main repo:

- **Your project code**: `s:libs/my-project`
- **Shared utilities you maintain**: `s:libs/shared/my-util`
- **Config files you customize**: `sync:package.json`
- **Documentation you update**: `sync:README.md`

### One-Time Copy Mode (`c:` or `copy:`)

Use for folders/files you want as a starting point but will customize independently:

- **Shared libraries you'll fork**: `c:libs/shared/team-x-util`
- **Template code you'll customize**: `c:libs/shared/common-controls`
- **Base config you'll modify**: `copy:tsconfig.base.json`
- **Documentation you'll diverge from**: `copy:CONTRIBUTING.md`

**Important:** After initial extraction, copy-only items are completely independent. They won't receive updates from main and won't push changes back. They're yours to customize freely.

## Workflow Examples

### Example 1: Feature Development

```
# You're building a project-one app that uses shared Angular components

s:libs/project-one                        # Your active work
c:libs/shared/common-controls      # Copy once, then customize independently
c:libs/shared/common-styles        # Copy once, then customize independently
s:package.json                     # Keep in sync
c:tsconfig.base.json               # Copy once, then customize
```

**Benefits:**

- ✅ Your project-one app stays in sync with main
- ✅ You can freely modify copied libraries without affecting main
- ✅ Simple mental model: synced items stay in sync, copied items are yours

### Example 2: Library Maintenance

```
# You're maintaining shared utilities that others consume

s:libs/shared/my-util              # Your library - stays in sync
c:libs/example-app                 # Copy as reference, customize freely
s:README.md                        # Keep docs in sync
copy:nx.json                       # Copy once, customize as needed
```

**Benefits:**

- ✅ Utility library stays in sync with main
- ✅ Example app is independent - modify without affecting main
- ✅ Clear separation between synced and independent code

## Script Behavior

### 2-sync-from-main.sh (Pull Updates)

**Output:**

```
Folders to sync:
  - libs/project-one
  - package.json
```

**Behavior:**

- ✅ Only `sync` mode items are pulled from main repo
- ⏭️ `copy` mode items are skipped (already independent)

### 3-sync-to-main.sh (Push Changes)

**Output:**

```
Folders to sync back to main:
  - libs/project-one
  - package.json
```

**Behavior:**

- ✅ Only `sync` mode items are pushed to main repo
- ⏭️ `copy` mode items are skipped (already independent)
- If all items are copy-only, script exits with message: "No folders marked for sync!"

## Migration Guide

### Existing Configurations

If you have an existing `folders-to-extract.txt` without sync mode prefixes:

**Old format (still works):**

```
libs/project-one
libs/shared/util
package.json
```

**Behavior:** All items default to sync mode (`s:`)

**New format (with explicit modes):**

```
s:libs/project-one
c:libs/shared/util
sync:package.json
```

### Converting Existing Repos

1. Edit `folders-to-extract.txt` in your extracted repo
2. Add prefixes (`s:` or `c:`) to each line
3. Save the file
4. Next time you run `2-sync-from-main.sh` or `3-sync-to-main.sh`, the new modes take effect

**Example conversion:**

```bash
# Before
libs/project-one
libs/shared/common-controls

# After - add prefixes based on your needs
s:libs/project-one
c:libs/shared/common-controls
```

## Tips

1. **Start with `s:` (sync) by default**, then change specific items to `c:` (copy) as needed
2. **Use `c:` for dependencies** you don't maintain
3. **Use `s:` for your active work** and files you manage
4. **Review your config regularly** - needs change over time
5. **Document your choices** - add comments in `folders-to-extract.txt`

## FAQ

**Q: What happens if I forget the prefix?**
A: Defaults to `s:` (sync mode)

**Q: Can I change a folder from copy to sync mode later?**
A: Yes, just edit `folders-to-extract.txt` and change `c:` to `s:`

**Q: What if I accidentally modify a copy-only folder?**
A: Changes won't push to main repo - they stay local. You can commit them locally if needed.

**Q: Can I mix modes for files within the same folder?**
A: No - the mode applies to the entire folder. But you can add individual files with different modes:

```
s:libs/my-project          # Sync entire folder
c:libs/my-project/temp     # But make one subfolder copy-only
```

**Q: What if I want read-only but not even pull updates?**
A: Don't include it in `folders-to-extract.txt` at all. Copy-only mode still receives updates.

**Q: Can I use both short and long forms in the same file?**
A: Yes! `s:`, `sync:`, `c:`, and `copy:` can all be mixed.

```
s:libs/project-one              # Short form
sync:libs/shared/ngrx    # Long form
c:package.json           # Short form
copy:nx.json             # Long form
```
