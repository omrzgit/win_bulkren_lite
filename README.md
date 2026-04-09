
# Win_bulkren_lite
> Renames / Reverts files with a suffix of choice.
> For idk who, its a work in progress, currently allows you to rename to Toggle file suffixes instantly.
> No setup. No dependencies. Drag & Drop in directory and run.

## Quickstart

### Prerequisites

* Windows 7+
* Works in `cmd.exe`
* No admin rights needed

### Setup

1. Put `renamer.bat` in your target folder
2. (Optional) Create `ren_config.txt`:

```
.datebug
file1.cfg
file2.cfg
data\maps\test.ipl
```

3. Double-click `renamer.bat`

That’s it. It auto-detects and toggles state.

---

## What it does

You can:

* Add a suffix (e.g. `.bak`, `.disabled`)
* Remove it later
* Toggle everything with one click

Works great for:

* Modding workflows
* Config switching
* Build pipelines

---

## Features

**Core**
- One-click toggle with live state detection
- Handles mixed file states (some renamed, some not)
- Directory scanner with smart file selection
- Optional prefix mode (add to beginning instead of end)

**Safety**
- Duplicate protection: Skip / Overwrite / Cancel
- Single-level undo (restores previous state)
- No cache files—reads actual disk state every run

**Workflow**
- Built-in config editor
- Batch-safe operations
- Zero dependencies, single portable file

---

## How it works

The script checks files directly on disk and detects:

| State    | Meaning                |
| -------- | ---------------------- |
| original | No suffix present      |
| renamed  | All files have suffix  |
| mixed    | Some renamed, some not |
| empty    | Files missing          |

Then it decides what to do.

---

## Config (`ren_config.txt`)

```
.suffix
file1.ext
file2.ext
path\to\file.ext
```

Rules:

* Line 1 = suffix
* One file per line
* `#` = comment
* Blank lines ignored

---

## Usage

### Auto Mode (double-click)

* If all original → adds suffix
* If all renamed → removes suffix
* If mixed → fixes everything
* If empty → opens menu

---

### Menu (manual control)

```
1. Toggle rename/revert
2. Change suffix
3. Refresh file status
4. Scan directory
5. Add file manually
6. Remove file from config
7. Undo last operation
8. Edit config
9. Restart script
0. Exit
```

---

## File Selection

When scanning directory:

| Input   | Result         |
| ------- | -------------- |
| `3`     | Select file 3  |
| `2-5`   | Range          |
| `1,3,7` | Multiple       |
| `A`     | All files      |
| `N`     | Only new files |
| `0`     | Cancel         |

---

## 🛡 Duplicate Protection

If target exists:

```
Skip / Overwrite / Cancel-all?
```

* Skip → ignore file
* Overwrite → replace
* Cancel → stop everything

---

## ↩ Undo

After each operation, a log is saved:

```
file.cfg|file.cfg.bak
```

Undo restores based on what exists.

* Only last operation supported
* Safe retry if something fails

---

## Files

| File             | Purpose      |
| ---------------- | ------------ |
| `renamer.bat`    | Main script  |
| `ren_config.txt` | Config       |
| `ren_undo.log`   | Undo history |

---

## ⚠ Limitations

* Only one suffix per config
* Suffix is appended at the end
  (`file.cfg → file.cfg.bak`)
* Uses relative paths
* Single-level undo only

---

## Extra Modes Todo

* Prefix mode (add before filename)
* Mixed-state smart correction
* Batch-safe operations

---

## License

MIT. Do whatever you want.

```
```
