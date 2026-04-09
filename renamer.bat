@echo off
setlocal enabledelayedexpansion
:: ============================================================
::  Smart File Renamer - Config-driven with auto-mode
::  Uses ren_config.txt for suffix + file list
::  Uses ren_state.txt to track current rename state
:: ============================================================
set "CONFIG=ren_config.txt"
set "STATE=ren_state.txt"
set "UNDO_LOG=ren_undo.log"

:: Auto-mode: if config exists, detect state from disk and act
if exist "%CONFIG%" (
    call :auto_run
    goto :eof
)

:: No config at all: go straight to menu
echo No config found. Launching setup...
echo.
call :menu_main
goto :eof

:: ════════════════════════════════════════════════════════════
:auto_run
:: Always detects state fresh from disk - no state file needed
:: ════════════════════════════════════════════════════════════
call :load_config
if !config_err! equ 1 (
    echo [!] Config invalid. Opening menu...
    timeout /t 2 >nul
    goto :menu_main
)

call :detect_current_state

cls
echo ========================================
echo  Smart File Renamer  [AUTO MODE]
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
    goto :menu_main
)

if "!current_state!"=="mixed" (
    echo [!] Mixed state detected:
    call :show_mixed_details
    echo.
    echo     You can still proceed - the script will handle each file appropriately.
    echo.
    set /p "proceed=Continue with auto-rename? (Y/N, default N): "
    if /i not "!proceed!"=="Y" (
        echo     Opening menu instead.
        pause
        goto :menu_main
    )
    echo.
    echo Action: RENAME -- adding !SUFFIX! to files in original state
    echo.
    call :do_rename_smart
) else if "!current_state!"=="original" (
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
if /i "!go_menu!"=="Y" goto :menu_main
exit /b 0

:: ════════════════════════════════════════════════════════════
:menu_main
:: ════════════════════════════════════════════════════════════
cls
call :load_config
call :detect_current_state

echo ========================================
echo  Smart File Renamer  [MENU]
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
echo  1. Rename files    (add suffix^)
echo  2. Revert files    (remove suffix^)
echo  3. Change suffix
echo  4. Refresh file status
echo  5. Scan directory  (pick files to add^)
echo  6. Add file manually
echo  7. Remove file from config
echo  8. Undo last operation
echo  9. Edit config in Notepad
echo  10. Close and reinitialize (restart bat^)
echo  0. Exit
echo.
set /p "choice=Choose (0-10): "

if "!choice!"=="1" call :action_rename    & goto :menu_main
if "!choice!"=="2" call :action_revert    & goto :menu_main
if "!choice!"=="3" call :action_change_suffix & goto :menu_main
if "!choice!"=="4" call :action_refresh   & goto :menu_main
if "!choice!"=="5" call :action_scan_dir  & goto :menu_main
if "!choice!"=="6" call :action_add_file  & goto :menu_main
if "!choice!"=="7" call :action_remove_file   & goto :menu_main
if "!choice!"=="8" call :action_undo          & goto :menu_main
if "!choice!"=="9" call :action_edit_notepad  & goto :menu_main
if "!choice!"=="10" call :action_reinit       & goto :eof
if "!choice!"=="0" exit /b 0

echo Invalid choice.
timeout /t 1 >nul
goto :menu_main

:: ════════════════════════════════════════════════════════════
:action_rename
:: ════════════════════════════════════════════════════════════
cls
echo ========================================
echo  Rename Files
echo ========================================
if !config_err! equ 1 (echo [!] No valid config. & pause & exit /b)

call :detect_current_state

if "!current_state!"=="empty"   (echo [!] No configured files found on disk. & pause & exit /b)
if "!current_state!"=="renamed" (echo [!] All files are already renamed. Use Revert to undo. & pause & exit /b)

if "!current_state!"=="mixed" (
    echo [!] Mixed state detected:
    call :show_mixed_details
    echo.
    echo     Script will rename only files in ORIGINAL state.
    echo.
)

echo  Will add suffix: !SUFFIX!
echo.
set /p "ok=Proceed? (Y/N): "
if /i not "!ok!"=="Y" exit /b

if "!current_state!"=="mixed" (
    call :do_rename_smart
) else (
    call :do_rename
)

echo.
pause
exit /b

:: ════════════════════════════════════════════════════════════
:action_revert
:: ════════════════════════════════════════════════════════════
cls
echo ========================================
echo  Revert Files
echo ========================================
if !config_err! equ 1 (echo [!] No valid config. & pause & exit /b)

call :detect_current_state

if "!current_state!"=="empty"    (echo [!] No configured files found on disk. & pause & exit /b)
if "!current_state!"=="original" (echo [!] All files are already at original names. & pause & exit /b)

if "!current_state!"=="mixed" (
    echo [!] Mixed state detected:
    call :show_mixed_details
    echo.
    echo     Script will revert only files in RENAMED state.
    echo.
)

echo  Will remove suffix: !SUFFIX!
echo.
set /p "ok=Proceed? (Y/N): "
if /i not "!ok!"=="Y" exit /b

if "!current_state!"=="mixed" (
    call :do_revert_smart
) else (
    call :do_revert
)

echo.
pause
exit /b

:: ════════════════════════════════════════════════════════════
:action_change_suffix
:: ════════════════════════════════════════════════════════════
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
if "!new_suffix!"=="" (echo Nothing entered. & pause & exit /b)

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

:: ════════════════════════════════════════════════════════════
:action_refresh
:: Refreshes and displays current file status
:: ════════════════════════════════════════════════════════════
cls
echo ========================================
echo  Refresh File Status
echo ========================================
if !config_err! equ 1 (
    echo [!] No valid config found.
    echo     Create %CONFIG% or use menu option 5 to add files.
    pause & exit /b
)

call :load_config
call :detect_current_state

echo  Suffix: !SUFFIX!
echo  Overall Status: !current_state!
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
echo [*] Status refreshed from disk.
pause
exit /b

:: ════════════════════════════════════════════════════════════
:show_mixed_details
:: Shows which files are in which state (called when mixed)
:: ════════════════════════════════════════════════════════════
for /l %%i in (1,1,!FILE_COUNT!) do (
    set "orig=!FILE_%%i!"
    set "renamed=!orig!!SUFFIX!"
    if exist "!orig!" (
        echo     - [ORIGINAL] !orig!
    ) else if exist "!renamed!" (
        echo     - [RENAMED ] !renamed!
    )
)
exit /b

:: ════════════════════════════════════════════════════════════
:action_scan_dir
:: ════════════════════════════════════════════════════════════
cls
echo ========================================
echo  Scan Directory - Pick Files to Add
echo ========================================
call :load_config

:: Build file list via temp file (no goto inside for loop)
set "SCAN_TMP=%TEMP%\ren_scan.tmp"
if exist "!SCAN_TMP!" del "!SCAN_TMP!"

for %%F in (*) do (
    set "fname=%%~nxF"
    set "skip=0"
    
    :: Always exclude the renamer and its support files by name
    if /i "!fname!"=="%~nx0"          set "skip=1"
    if /i "!fname!"=="renamer.bat"    set "skip=1"
    if /i "!fname!"=="ren_config.txt" set "skip=1"
    if /i "!fname!"=="ren_state.txt"  set "skip=1"
    if /i "!fname!"=="ren_undo.log"   set "skip=1"
    if /i "!fname!"=="%CONFIG%.tmp"   set "skip=1"
    
    :: Skip files whose name ends with the suffix (already-renamed copies)
    if not "!SUFFIX!"=="" (
        set "_s=!fname:%SUFFIX%=!"
        if /i "!_s!!SUFFIX!"=="!fname!" if not "!fname!"=="!SUFFIX!" set "skip=1"
    )
    
    if "!skip!"=="0" echo !fname!>>"!SCAN_TMP!"
)

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
    goto :scan_do_add
)

:: Numeric selection: commas -> spaces, then parse each token
set "sel_spaced=!sel:,= !"
for %%T in (!sel_spaced!) do (
    set "rA="
    set "rB="
    for /f "tokens=1,2 delims=-" %%A in ("%%T") do (
        set "rA=%%A"
        set "rB=%%B"
    )
    if defined rB (
        :: Range token (e.g. 2-5): validate both sides are digits
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
            echo  [!] Unrecognised: %%T
        )
    ) else (
        :: Single number: check all digits, then use call set for double-expansion
        set "ok=1"
        for /f "delims=0123456789" %%C in ("%%T") do set "ok=0"
        if "!ok!"=="1" (
            if %%T geq 1 if %%T leq !SCAN_COUNT! (
                set /a "_idx=%%T"
                call set "PICK_TMP=%%SCAN_!_idx!%%"
                set /a PICK_COUNT+=1
                set "PICK_!PICK_COUNT!=!PICK_TMP!"
            ) else (
                echo  [!] Out of range: %%T
            )
        ) else (
            echo  [!] Unrecognised: %%T
        )
    )
)

:: Clean up temp vars so they don't leak into load_config later
set "rA="
set "rB="
set "ok="
set "sel_spaced="
set "PICK_TMP="
set "is_range="
set "is_num="
set "tok="

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

echo.
echo  Done.  Added: !added!   Already configured: !skipped!
pause
exit /b

:: ════════════════════════════════════════════════════════════
:action_add_file
:: ════════════════════════════════════════════════════════════
cls
echo ========================================
echo  Add File Manually
echo ========================================
echo  Enter filename (or relative path) to track.
echo  Example: int_veg.ide   or   data\maps\file.img
echo.
set /p "new_file=Filename: "
if "!new_file!"=="" (echo Nothing entered. & pause & exit /b)

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

:: ════════════════════════════════════════════════════════════
:action_remove_file
:: ════════════════════════════════════════════════════════════
cls
echo ========================================
echo  Remove File from Config
echo ========================================
call :load_config

if !config_err! equ 1 (echo No config. & pause & exit /b)
if !FILE_COUNT! equ 0 (echo No files in config. & pause & exit /b)

echo  Configured files:
echo.
for /l %%i in (1,1,!FILE_COUNT!) do (
    echo   %%i. !FILE_%%i!
)
echo.
set /p "del_num=Enter number to remove (0 to cancel): "

if "!del_num!"=="0" exit /b
if !del_num! lss 1  (echo Invalid. & pause & exit /b)
if !del_num! gtr !FILE_COUNT! (echo Invalid. & pause & exit /b)

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
pause
exit /b

:: ════════════════════════════════════════════════════════════
:action_undo
:: ════════════════════════════════════════════════════════════
cls
echo ========================================
echo  Undo Last Operation
echo ========================================

if not exist "%UNDO_LOG%" (
    echo [!] No undo log found. Nothing to undo.
    pause & exit /b
)

set "undo_count=0"
for /f "usebackq tokens=1,2,3 delims=|" %%a in ("%UNDO_LOG%") do (
    set /a undo_count+=1
    set "UNDO_ACT_!undo_count!=%%a"
    set "UNDO_A_!undo_count!=%%b"
    set "UNDO_B_!undo_count!=%%c"
)

if !undo_count! equ 0 (echo Undo log is empty. & pause & exit /b)

:: Check for duplicates on disk BEFORE showing preview
set "dup_found=0"
for /l %%i in (1,1,!undo_count!) do (
    if "!UNDO_ACT_%%i!"=="RENAMED" (
        set "target=!UNDO_A_%%i!"
    ) else (
        set "target=!UNDO_B_%%i!"
    )
    if exist "!target!" set "dup_found=1"
)

echo  Last operation had !undo_count! file(s):
for /l %%i in (1,1,!undo_count!) do (
    if "!UNDO_ACT_%%i!"=="RENAMED" (
        echo    !UNDO_B_%%i! -- will revert to --> !UNDO_A_%%i!
    ) else (
        echo    !UNDO_A_%%i! -- will re-rename to --> !UNDO_B_%%i!
    )
)

if !dup_found! equ 1 (
    echo.
    echo [!] WARNING: Duplicate file(s) detected on disk.
    echo     Target filenames already exist. This would cause conflicts.
    echo.
    echo  Options:
    echo    1. Resolve duplicates (delete existing targets before undo^)
    echo    2. Keep as is (skip conflicting files during undo^)
    echo    0. Cancel undo
    echo.
    set /p "dup_choice=Choose (0-2): "
    
    if "!dup_choice!"=="0" exit /b
    if "!dup_choice!"=="1" (
        echo.
        echo  Resolving duplicates...
        for /l %%i in (1,1,!undo_count!) do (
            if "!UNDO_ACT_%%i!"=="RENAMED" (
                set "target=!UNDO_A_%%i!"
            ) else (
                set "target=!UNDO_B_%%i!"
            )
            if exist "!target!" (
                del "!target!" >nul 2>&1
                if exist "!target!" (
                    echo  [ERR] Could not delete: !target!
                ) else (
                    echo  [OK] Removed duplicate: !target!
                )
            )
        )
        echo.
    )
) else (
    echo.
    set /p "ok=Proceed with undo? (Y/N): "
    if /i not "!ok!"=="Y" exit /b
)

echo.
set "err=0"
for /l %%i in (1,1,!undo_count!) do (
    if "!UNDO_ACT_%%i!"=="RENAMED" (
        if exist "!UNDO_B_%%i!" (
            if exist "!UNDO_A_%%i!" (
                echo [SKIP] Target exists: !UNDO_A_%%i! (not reverting !UNDO_B_%%i!^)
            ) else (
                ren "!UNDO_B_%%i!" "!UNDO_A_%%i!"
                if !errorlevel! equ 0 (
                    echo [OK] Reverted: !UNDO_B_%%i! -^> !UNDO_A_%%i!
                ) else (
                    echo [ERR] Failed: !UNDO_B_%%i!
                    set "err=1"
                )
            )
        ) else (
            echo [SKIP] Not found: !UNDO_B_%%i!
        )
    ) else (
        if exist "!UNDO_A_%%i!" (
            if exist "!UNDO_B_%%i!" (
                echo [SKIP] Target exists: !UNDO_B_%%i! (not re-renaming !UNDO_A_%%i!^)
            ) else (
                ren "!UNDO_A_%%i!" "!UNDO_B_%%i!"
                if !errorlevel! equ 0 (
                    echo [OK] Re-renamed: !UNDO_A_%%i! -^> !UNDO_B_%%i!
                ) else (
                    echo [ERR] Failed: !UNDO_A_%%i!
                    set "err=1"
                )
            )
        ) else (
            echo [SKIP] Not found: !UNDO_A_%%i!
        )
    )
)

if !err! equ 0 (
    del "%UNDO_LOG%" >nul 2>&1
    echo.
    echo [OK] Undo complete. Log cleared.
)

echo.
pause
exit /b

:: ════════════════════════════════════════════════════════════
:action_edit_notepad
:: ════════════════════════════════════════════════════════════
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

:: ════════════════════════════════════════════════════════════
:action_reinit
:: ════════════════════════════════════════════════════════════
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

:: ════════════════════════════════════════════════════════════
:load_config
:: Line 1 = SUFFIX, Lines 2+ = filenames
:: Sets: SUFFIX, FILE_COUNT, FILE_1..FILE_N, config_err
:: ════════════════════════════════════════════════════════════
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

if "!SUFFIX!"=="" set "config_err=1"
exit /b

:: ════════════════════════════════════════════════════════════
:load_state
:: No longer used - state is always detected live from disk
:: ════════════════════════════════════════════════════════════
exit /b

:: ════════════════════════════════════════════════════════════
:detect_current_state
:: Sets current_state: original | renamed | mixed | empty
:: ════════════════════════════════════════════════════════════
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

if !found_any! equ 0 (
    set "current_state=empty"
) else if !found_orig! gtr 0 if !found_ren! gtr 0 (
    set "current_state=mixed"
) else if !found_orig! gtr 0 (
    set "current_state=original"
) else (
    set "current_state=renamed"
)
exit /b

:: ════════════════════════════════════════════════════════════
:do_rename
:: Renames all configured files (assumes all are in original state)
:: ════════════════════════════════════════════════════════════
if exist "%UNDO_LOG%" del "%UNDO_LOG%"
set "op_err=0"

for /l %%i in (1,1,!FILE_COUNT!) do (
    set "orig=!FILE_%%i!"
    set "ren=!orig!!SUFFIX!"
    
    if exist "!orig!" (
        ren "!orig!" "!ren!"
        if !errorlevel! equ 0 (
            echo [OK] Renamed: !orig! -^> !ren!
            echo RENAMED^|!orig!^|!ren!>>"%UNDO_LOG%"
        ) else (
            echo [ERR] Failed to rename: !orig!
            set "op_err=1"
        )
    ) else if exist "!ren!" (
        echo [SKIP] Already renamed: !ren!
    ) else (
        echo [SKIP] Not found: !orig!
    )
)

call :save_state renamed
exit /b

:: ════════════════════════════════════════════════════════════
:do_rename_smart
:: Renames only files in original state (for mixed scenarios)
:: ════════════════════════════════════════════════════════════
if exist "%UNDO_LOG%" del "%UNDO_LOG%"
set "op_err=0"

for /l %%i in (1,1,!FILE_COUNT!) do (
    set "orig=!FILE_%%i!"
    set "ren=!orig!!SUFFIX!"
    
    if exist "!orig!" (
        if exist "!ren!" (
            echo [SKIP] Duplicate exists: !ren! (not renaming !orig!^)
        ) else (
            ren "!orig!" "!ren!"
            if !errorlevel! equ 0 (
                echo [OK] Renamed: !orig! -^> !ren!
                echo RENAMED^|!orig!^|!ren!>>"%UNDO_LOG%"
            ) else (
                echo [ERR] Failed to rename: !orig!
                set "op_err=1"
            )
        )
    ) else if exist "!ren!" (
        echo [SKIP] Already renamed: !ren!
    ) else (
        echo [SKIP] Not found: !orig!
    )
)

call :save_state renamed
exit /b

:: ════════════════════════════════════════════════════════════
:do_revert
:: Reverts all configured files (assumes all are in renamed state)
:: ════════════════════════════════════════════════════════════
if exist "%UNDO_LOG%" del "%UNDO_LOG%"
set "op_err=0"

for /l %%i in (1,1,!FILE_COUNT!) do (
    set "orig=!FILE_%%i!"
    set "ren=!orig!!SUFFIX!"
    
    if exist "!ren!" (
        ren "!ren!" "!orig!"
        if !errorlevel! equ 0 (
            echo [OK] Reverted: !ren! -^> !orig!
            echo REVERTED^|!orig!^|!ren!>>"%UNDO_LOG%"
        ) else (
            echo [ERR] Failed to revert: !ren!
            set "op_err=1"
        )
    ) else if exist "!orig!" (
        echo [SKIP] Already original: !orig!
    ) else (
        echo [SKIP] Not found: !ren!
    )
)

call :save_state original
exit /b

:: ════════════════════════════════════════════════════════════
:do_revert_smart
:: Reverts only files in renamed state (for mixed scenarios)
:: ════════════════════════════════════════════════════════════
if exist "%UNDO_LOG%" del "%UNDO_LOG%"
set "op_err=0"

for /l %%i in (1,1,!FILE_COUNT!) do (
    set "orig=!FILE_%%i!"
    set "ren=!orig!!SUFFIX!"
    
    if exist "!ren!" (
        if exist "!orig!" (
            echo [SKIP] Duplicate exists: !orig! (not reverting !ren!^)
        ) else (
            ren "!ren!" "!orig!"
            if !errorlevel! equ 0 (
                echo [OK] Reverted: !ren! -^> !orig!
                echo REVERTED^|!orig!^|!ren!>>"%UNDO_LOG%"
            ) else (
                echo [ERR] Failed to revert: !ren!
                set "op_err=1"
            )
        )
    ) else if exist "!orig!" (
        echo [SKIP] Already original: !orig!
    ) else (
        echo [SKIP] Not found: !ren!
    )
)

call :save_state original
exit /b

:: ════════════════════════════════════════════════════════════
:save_state
:: ════════════════════════════════════════════════════════════
echo %~1>"%STATE%"
exit /b