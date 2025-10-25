# Sync Modes - Quick Reference

## Syntax

```
s:path/to/folder    or    sync:path/to/folder    →  Bidirectional sync
c:path/to/folder    or    copy:path/to/folder    →  One-time copy (then independent)
```

## When to Use

| Use `s:` (sync) when...           | Use `c:` (copy) when...           |
| --------------------------------- | --------------------------------- |
| ✍️ You actively develop this code | 🍴 You want to fork and customize |
| 📝 You maintain these files       | � You need a starting template    |
| 🔄 Changes should go back to main | 🆓 You want full independence     |
| 🎯 Your project-specific code     | 📦 You'll diverge from original   |

## Examples

```
# folders-to-extract.txt

# My active work - stay in sync
s:libs/my-project
s:apps/my-app
sync:package.json

# Copy once, then customize independently
c:libs/shared/common-components
c:libs/shared/utils
copy:tsconfig.base.json
copy:nx.json
```

## Script Behavior

| Script                  | Sync Mode (`s:`)  | Copy Mode (`c:`)       |
| ----------------------- | ----------------- | ---------------------- |
| **2-sync-from-main.sh** | ✅ Pulls updates  | ⏭️ Skips (independent) |
| **3-sync-to-main.sh**   | ✅ Pushes changes | ⏭️ Skips (independent) |

## Quick Decision Tree

```
Do you want this folder to stay in sync with main repo?
│
├─ YES → Use s: or sync:
│        Examples: Your project code, configs you manage
│
└─ NO  → Use c: or copy:
         Examples: Templates to customize, code to fork
```

## Real-World Example

**Scenario:** Building project-one app, forking some shared components

```
s:libs/project-one                        ← Your app code (stays in sync)
s:libs/project-one-be-core-api-feature    ← Your backend (stays in sync)
c:libs/shared/common-controls      ← Copy once, customize freely
c:libs/shared/common-styles        ← Copy once, customize freely
sync:package.json                  ← Keep in sync
copy:nx.json                       ← Copy once, customize
```

**Result:**

- ✅ Your project-one code syncs with main
- ✅ Copied libraries are yours to modify
- ✅ Simple: synced items sync, copied items are independent

## Changing Modes

Just edit `folders-to-extract.txt` and change the prefix:

```diff
- c:libs/my-folder
+ s:libs/my-folder
```

Next sync operation will use the new mode!

## Default Behavior

No prefix? Defaults to sync mode (`s:`):

```
# These are equivalent:
libs/my-folder
s:libs/my-folder
sync:libs/my-folder
```

---

📖 [Full Documentation](./SYNC_MODES.md) | 📘 [Main README](./README.md)
