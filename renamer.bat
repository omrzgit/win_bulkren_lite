@echo off
setlocal enabledelayedexpansion

rem ============================================================
rem  Bulkren_lite - Config-driven with auto-mode
rem  Uses ren_config.txt for suffix + file list
rem  Uses ren_undo.log to track last operation for undo
rem ============================================================
set "CONFIG=ren_config.txt"
set "UNDO_LOG=ren_undo.log"

rem Auto-mode: if config exists, detect state from disk and act
if exist "%CONFIG%" (
    call :auto_run
    goto :eof
)

rem No config at all: go straight to menu
echo No config found. Launching setup...
echo.
call :menu_main
goto :eof


rem ════════════════════════════════════════════════════════════
:auto_run
rem Loads config, detects live disk state, and toggles.
rem ════════════════════════════════════════════════════════════
call :load_config
if !config_err! equ 1 (
    echo [!] Config invalid. Opening menu...
    timeout /t 2 >nul
    call :menu_main
    exit /b
)

call :detect_current_state

cls
echo ========================================
echo  Bulkren_lite  [AUTO MODE]
echo ========================================
echo  Suffix : !SUFFIX!
echo  Files  : !FILE_COUNT! configured
echo  Status : !current_state!
echo ========================================
echo.

if "!current_state!"=="empty" (
    echo [!] None of the configured files were found on disk.
    echo     Use the menu to verify paths or update config.
    echo.
    pause
    call :menu_main
    exit /b
)

if "!current_state!"=="mixed" (
    echo [!] Mixed state - some files renamed, some not.
    echo     Opening menu to resolve manually.
    echo.
    pause
    call :menu_main
    exit /b
)

if "!current_state!"=="original" (
    echo Action: RENAME -- adding !SUFFIX!
    echo.
    call :do_rename
) else (
    echo Action: REVERT -- removing !SUFFIX!
    echo.
    call :do_revert
)

echo.
echo Operation complete.
echo.
set /p "go_menu=Open menu? (Y/N, default N): "
if /i "!go_menu!"=="Y" call :menu_main
exit /b


rem ════════════════════════════════════════════════════════════
:menu_main
rem ════════════════════════════════════════════════════════════
cls
call :load_config
call :detect_current_state

echo ========================================
echo  Bulkren_lite  [MENU]
echo ========================================
if !config_err! equ 1 (
    echo  Config : NOT FOUND / INVALID
) else (
    echo  Suffix : !SUFFIX!
    echo  Files  : !FILE_COUNT! configured
    echo  Status : !current_state!
)
echo ========================================
echo.
rem Build the toggle label from live state so the menu self-describes.
rem current_state was already set by detect_current_state above.
set "_tl=Toggle rename / revert"
if "!current_state!"=="original" set "_tl=Rename files   (will ADD suffix^)"
if "!current_state!"=="renamed"  set "_tl=Revert files   (will REMOVE suffix^)"
if "!current_state!"=="mixed"    set "_tl=Toggle (mixed - will process each file^)"
if "!current_state!"=="empty"    set "_tl=Toggle (no files found on disk^)"
echo  1. !_tl!
set "_tl="
echo  2. Change suffix
echo  3. View file status
echo  4. Scan directory  (pick files to add^)
echo  5. Add file manually
echo  6. Remove file from config
echo  7. Undo last operation
echo  8. Edit config in Notepad
echo  9. Close and reinitialize (restart bat^)
echo  0. Exit
echo.
set /p "choice=Choose (0-9): "

if "!choice!"=="1" ( call :action_toggle        & goto :menu_main )
if "!choice!"=="2" ( call :action_change_suffix & goto :menu_main )
if "!choice!"=="3" ( call :action_status        & goto :menu_main )
if "!choice!"=="4" ( call :action_scan_dir      & goto :menu_main )
if "!choice!"=="5" ( call :action_add_file      & goto :menu_main )
if "!choice!"=="6" ( call :action_remove_file   & goto :menu_main )
if "!choice!"=="7" ( call :action_undo          & goto :menu_main )
if "!choice!"=="8" ( call :action_edit_notepad  & goto :menu_main )
if "!choice!"=="9" ( call :action_reinit        & goto :eof )
if "!choice!"=="0" exit /b 0

echo Invalid choice.
timeout /t 1 >nul
goto :menu_main


rem ════════════════════════════════════════════════════════════
:action_toggle
rem then calls do_rename or do_revert accordingly.
rem All guards from the previous two subroutines are preserved:
rem   - empty  -> hard stop, nothing to do
rem   - mixed  -> allowed, each do_* processes per-file
rem   - original -> calls do_rename
rem   - renamed  -> calls do_revert
rem ════════════════════════════════════════════════════════════
cls
echo ========================================
echo  Rename / Revert Toggle
echo ========================================
if !config_err! equ 1 ( echo [!] No valid config. & pause & exit /b )

rem Fresh state read - never trust the menu snapshot for operations
call :detect_current_state

if "!current_state!"=="empty" (
    echo [!] No configured files found on disk.
    echo     Use Scan Directory or Add File to configure files first.
    pause & exit /b
)

if "!current_state!"=="original" (
    echo  State    : ORIGINAL
    echo  Action   : RENAME  ^(will add "!SUFFIX!"^)
    echo  Scope    : all configured files
)
if "!current_state!"=="renamed" (
    echo  State    : RENAMED
    echo  Action   : REVERT  ^(will remove "!SUFFIX!"^)
    echo  Scope    : all configured files
)
if "!current_state!"=="mixed" (
    echo  State    : MIXED
    echo  Action   : process each file by its individual state
    echo             ^(un-suffixed files RENAMED, suffixed files REVERTED^)
)
echo.
set /p "ok=Proceed? (Y/N): "
if /i not "!ok!"=="Y" exit /b

if "!current_state!"=="original" ( call :do_rename & goto :toggle_done )
if "!current_state!"=="renamed"  ( call :do_revert & goto :toggle_done )
if "!current_state!"=="mixed" (
    rem Mixed: rename the originals, revert the renamed ones.
    rem do_rename and do_revert are each per-file safe - they skip
    rem files not in their applicable state, so calling both is safe
    rem and produces no double-operations or duplicate conflicts.
    echo  [NOTE] Normalising mixed state: renaming originals first...
    call :do_rename
    echo.
    echo  [NOTE] Now reverting already-suffixed files...
    call :do_revert
)

:toggle_done
echo.
pause
exit /b


rem ════════════════════════════════════════════════════════════
:action_change_suffix
rem ════════════════════════════════════════════════════════════
cls
echo ========================================
echo  Change Suffix
echo ========================================
call :load_config
echo  Current suffix: !SUFFIX!
echo.
echo  NOTE: Changing suffix does NOT revert already-renamed
echo        files. Revert first before changing suffix.
echo.
set /p "new_suffix=New suffix (e.g. .bak or .disabled): "
if "!new_suffix!"=="" ( echo Nothing entered. & pause & exit /b )

set "tmp_cfg=%CONFIG%.tmp"
if exist "!tmp_cfg!" del "!tmp_cfg!"
echo !new_suffix!>"!tmp_cfg!"
for /l %%i in (1,1,!FILE_COUNT!) do (
    echo !FILE_%%i!>>"!tmp_cfg!"
)
move /y "!tmp_cfg!" "%CONFIG%" >nul
echo [OK] Suffix changed to: !new_suffix!
pause
exit /b


rem ════════════════════════════════════════════════════════════
:action_status
rem Shows per-file disk state: ORIGINAL, RENAMED, or MISSING.
rem Each file checked independently for clear mixed view.
rem ════════════════════════════════════════════════════════════
cls
echo ========================================
echo  File Status
echo ========================================
if !config_err! equ 1 (
    echo [!] No valid config found.
    echo     Create %CONFIG% or use menu option 5 to add files.
    pause & exit /b
)
echo  Suffix: !SUFFIX!
echo.
for /l %%i in (1,1,!FILE_COUNT!) do (
    set "orig=!FILE_%%i!"
    set "renamed=!orig!!SUFFIX!"
    if exist "!orig!" (
        echo  [ORIGINAL]  !orig!
    ) else if exist "!renamed!" (
        echo  [RENAMED ]  !renamed!
    ) else (
        echo  [MISSING ]  !orig!  (neither version found^)
    )
)
echo.
pause
exit /b


rem ════════════════════════════════════════════════════════════
:action_scan_dir
rem Scans cwd and lets user pick files to add to config.
rem ════════════════════════════════════════════════════════════
cls
echo ========================================
echo  Scan Directory - Pick Files to Add
echo ========================================
call :load_config

set "SCAN_TMP=%TEMP%\ren_scan.tmp"
if exist "!SCAN_TMP!" del "!SCAN_TMP!"

for %%F in (*) do (
    set "fname=%%~nxF"
    set "skip=0"
    if /i "!fname!"=="%~nx0"          set "skip=1"
    if /i "!fname!"=="renamer.bat"    set "skip=1"
    if /i "!fname!"=="ren_config.txt" set "skip=1"
    if /i "!fname!"=="ren_state.txt"  set "skip=1"
    if /i "!fname!"=="ren_undo.log"   set "skip=1"
    if /i "!fname!"=="%CONFIG%.tmp"   set "skip=1"
    rem Skip already-suffixed copies
    if not "!SUFFIX!"=="" (
        set "_tail=!fname:*%SUFFIX%=!"
        if "!_tail!"=="" if not "!fname!"=="!SUFFIX!" set "skip=1"
    )
    if "!skip!"=="0" echo !fname!>>"!SCAN_TMP!"
)
set "skip="
set "fname="
set "_tail="

set "SCAN_COUNT=0"
if exist "!SCAN_TMP!" (
    for /f "usebackq tokens=* delims=" %%L in ("!SCAN_TMP!") do (
        set /a SCAN_COUNT+=1
        set "SCAN_!SCAN_COUNT!=%%L"
    )
    del "!SCAN_TMP!"
)

if !SCAN_COUNT! equ 0 (
    echo  No files found in current directory.
    pause & exit /b
)

echo  Files in current directory:
echo  (* = already in config^)
echo.
for /l %%i in (1,1,!SCAN_COUNT!) do (
    set "scan_f=!SCAN_%%i!"
    set "mark= "
    for /l %%j in (1,1,!FILE_COUNT!) do (
        if /i "!FILE_%%j!"=="!scan_f!" set "mark=*"
    )
    echo    %%i. [!mark!] !scan_f!
)
set "scan_f="
set "mark="

echo.
echo  How to select:
echo    Single   : 3
echo    Range    : 2-5
echo    Multiple : 1,3,7
echo    All      : A
echo    New only : N  (skips * files^)
echo    Cancel   : 0
echo.
set /p "sel=Select: "
if /i "!sel!"=="0" exit /b
if "!sel!"==""     exit /b

set "PICK_COUNT=0"

if /i "!sel!"=="A" (
    for /l %%i in (1,1,!SCAN_COUNT!) do (
        set /a PICK_COUNT+=1
        set "PICK_!PICK_COUNT!=!SCAN_%%i!"
    )
    goto :scan_do_add
)

if /i "!sel!"=="N" (
    for /l %%i in (1,1,!SCAN_COUNT!) do (
        set "scan_f=!SCAN_%%i!"
        set "in_cfg=0"
        for /l %%j in (1,1,!FILE_COUNT!) do (
            if /i "!FILE_%%j!"=="!scan_f!" set "in_cfg=1"
        )
        if "!in_cfg!"=="0" (
            set /a PICK_COUNT+=1
            set "PICK_!PICK_COUNT!=!scan_f!"
        )
    )
    set "scan_f="
    set "in_cfg="
    goto :scan_do_add
)

rem ── Numeric/range/comma selection ──
rem Replace commas with spaces so we can iterate tokens.
set "sel_spaced=!sel:,= !"

for %%T in (!sel_spaced!) do (
    rem Use a /f loop to split on "-" - gives us up to two tokens
    set "rA="
    set "rB="
    for /f "tokens=1,2 delims=-" %%A in ("%%T") do (
        if not defined rA set "rA=%%A"
        if not defined rB (
            rem only set rB if it differs from rA (true range)
            if not "%%B"=="%%A" if not "%%B"=="" set "rB=%%B"
        )
    )

    if defined rB (
        rem Range token (e.g. 2-5)
        set "ok=1"
        for /f "delims=0123456789" %%C in ("!rA!") do set "ok=0"
        for /f "delims=0123456789" %%C in ("!rB!") do set "ok=0"
        if "!ok!"=="1" (
            if !rA! lss 1 set "rA=1"
            if !rB! gtr !SCAN_COUNT! set "rB=!SCAN_COUNT!"
            for /l %%R in (!rA!,1,!rB!) do (
                set /a PICK_COUNT+=1
                set "PICK_!PICK_COUNT!=!SCAN_%%R!"
            )
        ) else (
            echo  [!] Unrecognised token: %%T
        )
    ) else (
        rem Single number
        set "ok=1"
        for /f "delims=0123456789" %%C in ("%%T") do set "ok=0"
        if "!ok!"=="1" (
            set "_idx=%%T"
            if !_idx! geq 1 if !_idx! leq !SCAN_COUNT! (
                set /a PICK_COUNT+=1
                rem Double-expand SCAN_N using call
                call set "PICK_TMP=%%SCAN_!_idx!%%"
                set "PICK_!PICK_COUNT!=!PICK_TMP!"
            ) else (
                echo  [!] Out of range: %%T
            )
        ) else (
            echo  [!] Unrecognised token: %%T
        )
    )
)
rem Clean temp vars so they don't bleed into load_config
set "rA=" & set "rB=" & set "ok=" & set "_idx=" & set "PICK_TMP=" & set "sel_spaced="

:scan_do_add
if !PICK_COUNT! equ 0 (
    echo.
    echo  Nothing to add.
    pause & exit /b
)

echo.
echo  Adding !PICK_COUNT! file(s):
set "added=0"
set "skipped=0"
for /l %%i in (1,1,!PICK_COUNT!) do (
    set "pf=!PICK_%%i!"
    set "dup=0"
    for /l %%j in (1,1,!FILE_COUNT!) do (
        if /i "!FILE_%%j!"=="!pf!" set "dup=1"
    )
    if "!dup!"=="1" (
        echo  [SKIP] Already configured: !pf!
        set /a skipped+=1
    ) else (
        echo !pf!>>"%CONFIG%"
        echo  [OK]   Added: !pf!
        set /a added+=1
    )
)
set "pf=" & set "dup="
echo.
echo  Done.  Added: !added!   Already configured: !skipped!
set "added=" & set "skipped="
pause
exit /b


rem ════════════════════════════════════════════════════════════
:action_add_file
rem ════════════════════════════════════════════════════════════
cls
echo ========================================
echo  Add File Manually
echo ========================================
echo  Enter filename (or relative path) to track.
echo  Example: int_veg.ide   or   data\maps\file.img
echo.
set /p "new_file=Filename: "
if "!new_file!"=="" ( echo Nothing entered. & pause & exit /b )

call :load_config
for /l %%i in (1,1,!FILE_COUNT!) do (
    if /i "!FILE_%%i!"=="!new_file!" (
        echo [!] That file is already in the config.
        pause & exit /b
    )
)

if not exist "!new_file!" (
    echo [!] Warning: "!new_file!" not found in current directory.
    set /p "cont=Add anyway? (Y/N): "
    if /i not "!cont!"=="Y" exit /b
)

echo !new_file!>>"%CONFIG%"
echo [OK] Added: !new_file!
pause
exit /b


rem ════════════════════════════════════════════════════════════
:action_remove_file
rem ════════════════════════════════════════════════════════════
cls
echo ========================================
echo  Remove File from Config
echo ========================================
call :load_config
if !config_err! equ 1 ( echo No config. & pause & exit /b )
if !FILE_COUNT! equ 0 ( echo No files in config. & pause & exit /b )

echo  Configured files:
echo.
for /l %%i in (1,1,!FILE_COUNT!) do (
    echo   %%i. !FILE_%%i!
)
echo.
set /p "del_num=Enter number to remove (0 to cancel): "
if "!del_num!"=="0" exit /b
if !del_num! lss 1  ( echo Invalid. & pause & exit /b )
if !del_num! gtr !FILE_COUNT! ( echo Invalid. & pause & exit /b )

set "to_remove=!FILE_%del_num%!"
echo Removing: !to_remove!

set "tmp_cfg=%CONFIG%.tmp"
if exist "!tmp_cfg!" del "!tmp_cfg!"
echo !SUFFIX!>"!tmp_cfg!"
for /l %%i in (1,1,!FILE_COUNT!) do (
    if /i not "!FILE_%%i!"=="!to_remove!" (
        echo !FILE_%%i!>>"!tmp_cfg!"
    )
)
move /y "!tmp_cfg!" "%CONFIG%" >nul
echo [OK] Removed: !to_remove!
set "to_remove="
pause
exit /b


rem ════════════════════════════════════════════════════════════
:action_undo
rem Reads ORIGINAL|RENAMED pairs from undo log.
rem Determines direction by checking which version is on disk.
rem ════════════════════════════════════════════════════════════
cls
echo ========================================
echo  Undo Last Operation
echo ========================================
if not exist "%UNDO_LOG%" (
    echo [!] No undo log found. Nothing to undo.
    pause & exit /b
)

set "undo_count=0"
for /f "usebackq tokens=1,2 delims=|" %%a in ("%UNDO_LOG%") do (
    set /a undo_count+=1
    set "UNDO_ORIG_!undo_count!=%%a"
    set "UNDO_REN_!undo_count!=%%b"
)

if !undo_count! equ 0 ( echo Undo log is empty. & pause & exit /b )

echo  Last operation had !undo_count! file pair(s):
echo.
for /l %%i in (1,1,!undo_count!) do (
    set "u_orig=!UNDO_ORIG_%%i!"
    set "u_ren=!UNDO_REN_%%i!"
    if exist "!u_ren!" (
        echo   %%i. [RENAMED on disk]  !u_ren!  --> will revert to  !u_orig!
    ) else if exist "!u_orig!" (
        echo   %%i. [ORIGINAL on disk] !u_orig!  --> will re-rename to  !u_ren!
    ) else (
        echo   %%i. [MISSING]  Neither "!u_orig!" nor "!u_ren!" found.
    )
)
set "u_orig=" & set "u_ren="
echo.
set /p "ok=Proceed with undo? (Y/N): "
if /i not "!ok!"=="Y" exit /b

set "err=0"
for /l %%i in (1,1,!undo_count!) do (
    set "u_orig=!UNDO_ORIG_%%i!"
    set "u_ren=!UNDO_REN_%%i!"

    if exist "!u_ren!" (
        rem Renamed version on disk -> revert it back to original
        rem Duplicate check before overwrite
        if exist "!u_orig!" (
            echo [WARN] Undo skipped: "!u_orig!" already exists on disk.
            echo        Remove it manually then retry.
            set "err=1"
        ) else (
            ren "!u_ren!" "!u_orig!"
            call :check_ren "!u_orig!" "!u_ren!" revert
        )
    ) else if exist "!u_orig!" (
        rem Original on disk -> re-rename it
        rem Duplicate check
        if exist "!u_ren!" (
            echo [WARN] Undo skipped: "!u_ren!" already exists on disk.
            echo        Remove it manually then retry.
            set "err=1"
        ) else (
            ren "!u_orig!" "!u_ren!"
            call :check_ren "!u_ren!" "!u_orig!" rename
        )
    ) else (
        echo [SKIP] Neither version found for: !u_orig!
    )
)
set "u_orig=" & set "u_ren="

if "!err!"=="0" (
    del "%UNDO_LOG%" >nul 2>&1
    echo.
    echo [OK] Undo complete. Log cleared.
) else (
    echo.
    echo [!] One or more files could not be undone. Log kept.
)
echo.
pause
exit /b


rem ════════════════════════════════════════════════════════════
:action_edit_notepad
rem ════════════════════════════════════════════════════════════
if not exist "%CONFIG%" (
    echo Creating default config...
    echo .datebug>"%CONFIG%"
    echo int_veg.ide>>"%CONFIG%"
    echo ext_veg.ide>>"%CONFIG%"
    echo.
    echo Default config created. Edit it in Notepad.
    echo Line 1 = suffix. Remaining lines = filenames.
)
start notepad "%CONFIG%"
echo Notepad opened. Changes take effect next time the menu loads.
timeout /t 2 >nul
exit /b


rem ════════════════════════════════════════════════════════════
:action_reinit
rem ════════════════════════════════════════════════════════════
cls
echo ========================================
echo  Reinitialize
echo ========================================
echo [*] Closing current session and restarting...
echo     This clears the environment and fixes certain bugs.
echo.
timeout /t 2 >nul
%0
exit /b


rem ════════════════════════════════════════════════════════════
:load_config
rem Line 1 = SUFFIX, Lines 2+ = filenames
rem Sets: SUFFIX, FILE_COUNT, FILE_1..FILE_N, config_err
rem Blank lines and lines starting with # are skipped.
rem ════════════════════════════════════════════════════════════
set "config_err=0"
set "FILE_COUNT=0"
set "SUFFIX="

if not exist "%CONFIG%" (
    set "config_err=1"
    exit /b
)

set "line_num=0"
for /f "usebackq tokens=* delims=" %%L in ("%CONFIG%") do (
    set /a line_num+=1
    if !line_num! equ 1 (
        set "SUFFIX=%%L"
    ) else (
        set "_ln=%%L"
        if not "!_ln!"=="" if not "!_ln:~0,1!"=="#" (
            set /a FILE_COUNT+=1
            set "FILE_!FILE_COUNT!=%%L"
        )
    )
)
set "_ln="

if "!SUFFIX!"=="" set "config_err=1"
exit /b


rem ════════════════════════════════════════════════════════════
:detect_current_state
rem Checks every configured file individually on disk.
rem Sets current_state: original | renamed | mixed | empty
rem ════════════════════════════════════════════════════════════
set "found_orig=0"
set "found_ren=0"
set "found_any=0"

for /l %%i in (1,1,!FILE_COUNT!) do (
    set "orig=!FILE_%%i!"
    set "ren=!orig!!SUFFIX!"
    if exist "!orig!" (
        set /a found_orig+=1
        set /a found_any+=1
    ) else if exist "!ren!" (
        set /a found_ren+=1
        set /a found_any+=1
    )
)
set "orig=" & set "ren="

rem Evaluate state with explicit arithmetic - no nested ifs
if !found_any! equ 0 (
    set "current_state=empty"
    exit /b
)

rem mixed = both kinds present
set /a "_mixed=found_orig * found_ren"
if !_mixed! gtr 0 (
    set "current_state=mixed"
    set "_mixed="
    exit /b
)
set "_mixed="

if !found_orig! gtr 0 (
    set "current_state=original"
) else (
    rem          Now it fires correctly when all files are renamed.
    set "current_state=renamed"
)
exit /b


rem ════════════════════════════════════════════════════════════
:do_rename
rem Renames ORIGINAL files to ORIGINAL+SUFFIX.
rem Skips files already renamed or missing.
rem ════════════════════════════════════════════════════════════
if exist "%UNDO_LOG%" del "%UNDO_LOG%"
set "op_err=0"

for /l %%i in (1,1,!FILE_COUNT!) do (
    set "orig=!FILE_%%i!"
    set "ren=!orig!!SUFFIX!"

    if exist "!orig!" (
        if exist "!ren!" (
            echo [WARN] Target already exists: "!ren!"
            set /p "_choice=  Skip / Overwrite / Cancel-all? (S/O/C): "
            if /i "!_choice!"=="C" (
                echo [ABORT] Rename cancelled by user.
                set "op_err=1"
                rem Set flag to break remaining iterations
                set "ren_abort=1"
            )
            if /i "!_choice!"=="O" (
                del "!ren!" >nul 2>&1
                ren "!orig!" "!ren!"
                call :check_ren "!ren!" "!orig!" rename
            )
            rem S or anything else: skip silently
            if /i "!_choice!"=="S" echo  [SKIP] Skipped: !orig!
        ) else (
            ren "!orig!" "!ren!"
            call :check_ren "!ren!" "!orig!" rename
        )
    ) else if exist "!ren!" (
        echo  [SKIP] Already renamed: !ren!
    ) else (
        echo  [SKIP] Not found: !orig!
    )

    rem Abort flag check (can't goto out of for loop safely)
    if defined ren_abort (
        set "op_err=1"
    )
)
set "orig=" & set "ren=" & set "_choice=" & set "ren_abort="
exit /b


rem ════════════════════════════════════════════════════════════
:do_revert
rem Reverts ORIGINAL+SUFFIX files back to ORIGINAL.
rem ════════════════════════════════════════════════════════════
if exist "%UNDO_LOG%" del "%UNDO_LOG%"
set "op_err=0"

for /l %%i in (1,1,!FILE_COUNT!) do (
    set "orig=!FILE_%%i!"
    set "ren=!orig!!SUFFIX!"

    if exist "!ren!" (
        rem Duplicate target check
        if exist "!orig!" (
            echo [WARN] Target already exists: "!orig!"
            set /p "_choice=  Skip / Overwrite / Cancel-all? (S/O/C): "
            if /i "!_choice!"=="C" (
                echo [ABORT] Revert cancelled by user.
                set "op_err=1"
                set "rev_abort=1"
            )
            if /i "!_choice!"=="O" (
                del "!orig!" >nul 2>&1
                ren "!ren!" "!orig!"
                call :check_ren "!orig!" "!ren!" revert
            )
            if /i "!_choice!"=="S" echo  [SKIP] Skipped: !ren!
        ) else (
            ren "!ren!" "!orig!"
            call :check_ren "!orig!" "!ren!" revert
        )
    ) else if exist "!orig!" (
        echo  [SKIP] Already original: !orig!
    ) else (
        echo  [SKIP] Not found: !ren!
    )

    if defined rev_abort set "op_err=1"
)
set "orig=" & set "ren=" & set "_choice=" & set "rev_abort="
exit /b


rem ════════════════════════════════════════════════════════════
:check_ren  
rem <expected_on_disk>  <old_name>  <rename|revert>
rem Logs ORIGINAL|RENAMED pair to undo log on success.
rem ════════════════════════════════════════════════════════════
set "_expected=%~1"
set "_old=%~2"
set "_dir=%~3"

if exist "!_expected!" (
    rem Determine which is orig and which is renamed for the log
    if /i "!_dir!"=="rename" (
        rem _old was original, _expected is renamed
        echo !_old!^|!_expected!>>"%UNDO_LOG%"
        echo  [OK] Renamed : !_old! -^> !_expected!
    ) else (
        rem _old was renamed, _expected is original
        echo !_expected!^|!_old!>>"%UNDO_LOG%"
        echo  [OK] Reverted: !_old! -^> !_expected!
    )
) else (
    echo  [ERR] Operation failed: !_old! could not be processed.
    set "op_err=1"
)
set "_expected=" & set "_old=" & set "_dir="
exit /b