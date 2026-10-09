# Win_Bulkren_lite
> Renames / Reverts files with a suffix of choice.
> Toggle file suffixes instantly with state detection and built-in transaction safety.
> No setup. No dependencies. Drag & Drop in directory and run.

### Quickstart

#### Prerequisites

* Windows 7+
* Works in `cmd.exe`
* No admin rights needed

#### Setup

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


### What it does

You can:

* Add a suffix (e.g. `.bak`, `.disabled`, `.datebug`)
* Remove it later
* Toggle everything with one click

Works great for:

* Modding workflows (GTA, Elder Scrolls, etc.)
* Config switching
* Build pipelines


### Features

**Core**
- One-click toggle with live state detection
- Handles mixed file states (some renamed, some not)
- Directory scanner with smart file selection
- Built-in config editor

**Safety & Transaction Control**
- **Rolling Transaction Log (`ren_transactions.log`)**: Automatically audits every rename, revert, config change, and abort with timestamps, capped at the last 100 entries.
- **Duplicate & Collision Protection**: Prompts `Skip / Overwrite / Cancel-all` before overwriting target files.
- **Journaled Undo (`ren_undo.log`)**: Reverts the last operation based on disk state with duplicate protection.
- **Built-in Log Viewer**: View recent transaction events directly inside the menu or open in Notepad.
- Zero cache files—reads actual disk state every run.

**Workflow**
- Built-in config editor
- Batch-safe operations
- Zero dependencies, single portable file


### How it works

The script checks files directly on disk and detects:

| State    | Meaning                |
| -------- | ---------------------- |
| original | No suffix present      |
| renamed  | All files have suffix  |
| mixed    | Some renamed, some not |
| empty    | Files missing          |

Then it decides what to do.


### Config (`ren_config.txt`)

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


### Usage

#### Auto Mode (double-click)

* If all original → adds suffix
* If all renamed → removes suffix
* If mixed → prompts to resolve per-file
* If empty → opens menu


#### Menu (manual control)

```
1. Toggle rename/revert
2. Change suffix
3. View file status
4. Scan directory (pick files to add)
5. Add file manually
6. Remove file from config
7. Undo last operation
8. View transaction log
9. Edit config in Notepad
R. Close and reinitialize (restart bat)
0. Exit
```


### File Selection

When scanning directory:

| Input   | Result         |
| ------- | -------------- |
| `3`     | Select file 3  |
| `2-5`   | Range          |
| `1,3,7` | Multiple       |
| `A`     | All files      |
| `N`     | Only new files |
| `0`     | Cancel         |


### Duplicate Protection

If target exists:

```
Skip / Overwrite / Cancel-all? (S/O/C)
```

* Skip → ignore file
* Overwrite → replace
* Cancel-all → abort remaining operations safely and log abort event


### Transaction Control & Undo

Every operation generates timestamped entries in `ren_transactions.log`:

```
[Fri 10/09/2026 05:00:00.00] [TOGGLE_START] Initiating toggle (State: original, Suffix: .bak) [IN_PROGRESS]
[Fri 10/09/2026 05:00:00.05] [RENAME] Renamed 'file1.cfg' -> 'file1.cfg.bak' [SUCCESS]
[Fri 10/09/2026 05:00:00.10] [TOGGLE_END] Toggle completed [SUCCESS]
```

Undo restores files based on disk existence:

* Reads pair entries from `ren_undo.log`
* Detects whether file is currently renamed or original
* Logs every undo restoration to `ren_transactions.log`
* Clears journal when all files are successfully restored


### Files

| File                   | Purpose                                                |
| ---------------------- | ------------------------------------------------------ |
| `renamer.bat`          | Main script                                            |
| `ren_config.txt`       | Config (suffix + tracked file list)                    |
| `ren_undo.log`         | Journal of last operation for undo                     |
| `ren_transactions.log` | Rolling transaction audit log (capped at 100 entries)  |


### Limitations

* Only one suffix per config
* Suffix is appended at the end (`file.cfg` → `file.cfg.bak`)
* Uses relative paths


### License

MIT. Do whatever you want.
