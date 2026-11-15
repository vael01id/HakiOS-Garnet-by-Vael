@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

title HackiOS Garnet - Boot Manager

set "ADB=tools\platform-tools\adb.exe"
if not exist "%ADB%" set "ADB=adb.exe"
set "FB=tools\platform-tools\fastboot.exe"
if not exist "%FB%" set "FB=fastboot.exe"

set "BOOTIMG=garnet-boot.img"
set "SYSTEM=userland\system.apfs"
if not exist "%SYSTEM%" if exist "system.apfs" set "SYSTEM=system.apfs"
set "PAYLOAD_METAL=payloads\run-metal-fixed-payload.bin"
set "PAYLOAD_GLES=payloads\opengles_payload.bin"

REM ================================================================
REM MAIN MENU
REM ================================================================
:menu
cls
echo ================================================================
echo     HACKIOS GARNET BOOT MANAGER - POCO X6 5G ^| iOS 16.5
echo ================================================================
echo.
echo   Full Boot (stage system.apfs + payload + oem run):
echo   [1] Apple Metal Native   (Adreno 710 + FT3683G Touch)
echo   [2] OpenGL ES            (Mesa Freedreno / EAGL Fallback)
echo.
echo   Fast Swap (skip system.apfs, swap payload + oem run only):
echo   [3] Fast Swap to Metal
echo   [4] Fast Swap to OpenGL ES
echo.
echo   [5] Exit
echo.
echo ================================================================
set /p "CHOICE=Select option [1-5]: "

if "%CHOICE%"=="1" goto :opt_full_metal
if "%CHOICE%"=="2" goto :opt_full_gles
if "%CHOICE%"=="3" goto :opt_fast_metal
if "%CHOICE%"=="4" goto :opt_fast_gles
if "%CHOICE%"=="5" exit /b 0

echo [!] Invalid choice.
pause
goto :menu

:opt_full_metal
set "PAYLOAD=%PAYLOAD_METAL%"
set "LABEL=Metal Native"
set "SKIP_APFS=0"
goto :start_flow

:opt_full_gles
set "PAYLOAD=%PAYLOAD_GLES%"
set "LABEL=OpenGL ES"
set "SKIP_APFS=0"
goto :start_flow

:opt_fast_metal
set "PAYLOAD=%PAYLOAD_METAL%"
set "LABEL=Metal Native [Fast Swap]"
set "SKIP_APFS=1"
goto :start_flow

:opt_fast_gles
set "PAYLOAD=%PAYLOAD_GLES%"
set "LABEL=OpenGL ES [Fast Swap]"
set "SKIP_APFS=1"
goto :start_flow

REM ================================================================
REM STEP 1 - Verify Required Files
REM ================================================================
:start_flow
cls
echo ================================================================
echo     BOOT TARGET: %LABEL%
echo ================================================================
echo.
echo [1/4] Checking required files...
if not exist "%BOOTIMG%" (
    echo [ERR] File %BOOTIMG% not found!
    pause
    goto :menu
)
if "!SKIP_APFS!"=="0" (
    if not exist "%SYSTEM%" (
        echo [ERR] userland\system.apfs not found!
        echo       Download system.apfs ^(2.32 GB^) from the Google Drive link in README.md
        echo       and place it at: userland\system.apfs
        pause
        goto :menu
    )
)
if not exist "%PAYLOAD%" (
    echo [ERR] Payload %PAYLOAD% not found!
    pause
    goto :menu
)
echo [OK] All required files verified.

REM ================================================================
REM STEP 2 - Detect Device Connection
REM ================================================================
echo.
echo [2/4] Detecting POCO X6 5G connection...

:detect_loop
"%FB%" devices 2>nul | findstr /i "xnuloader" >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Device detected already in xnuloader mode.
    goto :stage_process
)

"%FB%" devices 2>nul | findstr /v /i "devices" | findstr /i "fastboot" >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Device detected in standard Fastboot mode.
    goto :boot_loader
)

"%ADB%" devices 2>nul | findstr /v /i "attached" | findstr /i "device" >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Device detected in Android / HyperOS.
    echo [*] Rebooting device to Fastboot mode...
    "%ADB%" reboot bootloader
    goto :wait_fastboot
)

echo [!] Device not detected via ADB or Fastboot.
echo     Make sure USB cable is connected and USB Debugging / Fastboot is active.
echo Press any key to retry detection...
pause >nul
goto :detect_loop

:wait_fastboot
echo [*] Waiting for device to enter Fastboot mode...
set /a attempts=0
:loop_wfb
ping -n 2 127.0.0.1 >nul
"%FB%" devices 2>nul | findstr /v /i "devices" | findstr /i "fastboot" >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Fastboot connected!
    goto :boot_loader
)
set /a attempts+=1
if !attempts! geq 25 (
    echo [ERR] Timeout waiting for Fastboot mode.
    pause
    goto :menu
)
goto :loop_wfb

REM ================================================================
REM STEP 3 - Boot xnuloader into RAM
REM ================================================================
:boot_loader
echo.
echo [3/4] Booting xnuloader into RAM via fastboot boot...
"%FB%" boot "%BOOTIMG%"
if %errorlevel% neq 0 (
    echo [ERR] Failed to boot xnuloader image into RAM!
    pause
    goto :menu
)

echo [*] Waiting for xnuloader initialization in RAM...
set /a attempts=0
:loop_wxnu
ping -n 2 127.0.0.1 >nul
"%FB%" devices 2>nul | findstr /i "xnuloader" >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] xnuloader active and ready to receive data!
    goto :stage_process
)
set /a attempts+=1
if !attempts! geq 40 (
    echo [ERR] Timeout waiting for xnuloader. Hold POWER button for 15s to reset.
    pause
    goto :menu
)
goto :loop_wxnu

REM ================================================================
REM STEP 4 - Stage & Launch Kernel
REM ================================================================
:stage_process
echo.
echo [4/4] Staging images to RAM...

if "!SKIP_APFS!"=="1" (
    echo [*] [Fast Swap Mode] Skipping system.apfs upload.
    goto :stage_kernel_prep
)

"%FB%" oem stop >nul 2>&1
ping -n 4 127.0.0.1 >nul

set /a rd_attempts=0
:try_ramdisk
echo [*] [1/2] Preparing resident RAM allocation ^(fastboot oem ramdisk^)...
"%FB%" oem ramdisk >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Resident ramdisk allocation ready.
    goto :do_push_system
)

set /a rd_attempts+=1
if !rd_attempts! leq 5 (
    echo [*] Previous kernel still stopping, waiting 3s... ^(!rd_attempts!/5^)
    "%FB%" oem stop >nul 2>&1
    ping -n 4 127.0.0.1 >nul
    goto :try_ramdisk
)

echo [ERR] fastboot oem ramdisk failed!
echo       Previous kernel did not respond to oem stop.
echo       Hold physical POWER button for 10-15s to reboot phone back to Fastboot.
pause
goto :menu

:do_push_system
echo [*] Uploading iOS rootfs to RAM ^(transfer speed depends on USB 2.0/3.0 link^)...
call :stage_with_progress "%SYSTEM%" "system.apfs"
if %errorlevel% neq 0 (
    echo [ERR] Failed to stage system.apfs to RAM!
    pause
    goto :menu
)

:stage_kernel_prep
echo [*] Stopping previous kernel session if running ^(fastboot oem stop^)...
"%FB%" oem stop >nul 2>&1
echo [*] Waiting for kernel to return control to loader ^(3-4s^)...
ping -n 5 127.0.0.1 >nul

set /a kp_attempts=0
:loop_stage_payload
echo.
echo [*] [2/2] Uploading kernel payload: %LABEL%...
call :stage_with_progress "%PAYLOAD%" "payload"
if %errorlevel% equ 0 goto :stage_payload_ok

set /a kp_attempts+=1
if !kp_attempts! leq 5 (
    echo [*] Waiting for previous kernel release... ^(!kp_attempts!/5^)
    "%FB%" oem stop >nul 2>&1
    ping -n 4 127.0.0.1 >nul
    goto :loop_stage_payload
)

echo [ERR] Failed to stage kernel payload!
echo       If you see "a kernel is running", hold POWER for 10-15s to reboot phone.
pause
goto :menu

:stage_payload_ok
echo.
echo [*] Launching Darwin XNU kernel ^(fastboot oem run^)...
"%FB%" oem run
if %errorlevel% neq 0 (
    echo [ERR] fastboot oem run failed!
    pause
    goto :menu
)
echo [OK] fastboot oem run command sent!

echo.
echo ================================================================
echo   [SUCCESS] iOS 16.5 IS NOW BOOTING! ^(%LABEL%^)
echo ================================================================
echo.
echo   1. Screen transitions from cyan loader to Apple logo ^(~35-38s^).
echo   2. Once Home Screen appears, USB cable can be unplugged safely.
echo   3. Runs 100%% in RAM ^(no NAND/UFS storage partitions touched^).
echo   4. To return to Android: hold physical POWER button for 10-15 seconds.
echo.
pause
goto :menu

REM ================================================================
REM HELPER - Honest USB Transfer Activity Bar + Real Speed Summary
REM (Note: fastboot stage does not report mid-transfer USB byte
REM  counts, so this shows live elapsed time and real MB/s on finish
REM  without faking percentages.)
REM ================================================================
:stage_with_progress
if not exist "tools\stage.ps1" goto :stage_raw
where powershell >nul 2>&1
if %errorlevel% neq 0 goto :stage_raw
powershell -NoProfile -InputFormat None -ExecutionPolicy Bypass -File "tools\stage.ps1" "%FB%" "%~1" "%~2"
exit /b %errorlevel%

:stage_raw
"%FB%" stage "%~1"
exit /b %errorlevel%
