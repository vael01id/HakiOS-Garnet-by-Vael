#!/usr/bin/env bash
set -u
cd "$(dirname "$(readlink -f "$0")")" || exit 1

BOOTIMG="garnet-boot.img"
SYSTEM="userland/system.apfs"
[ -f "$SYSTEM" ] || [ ! -f "system.apfs" ] || SYSTEM="system.apfs"
PAYLOAD_METAL="payloads/run-metal-fixed-payload.bin"
PAYLOAD_GLES="payloads/opengles_payload.bin"

require_tools() {
    command -v fastboot >/dev/null 2>&1 || {
        echo "[ERR] 'fastboot' not found. Please install android-tools / platform-tools first."
        exit 1
    }
}

device_state() {
    local fb_out
    fb_out=$(fastboot devices 2>/dev/null || true)
    if echo "$fb_out" | grep -qi "xnuloader"; then
        echo "xnuloader"
    elif [ -n "$fb_out" ]; then
        echo "fastboot"
    elif command -v adb >/dev/null 2>&1 && adb devices 2>/dev/null | grep -vq "attached" | grep -qw "device"; then
        echo "android"
    else
        echo "absent"
    fi
}

# Honest USB transfer activity bar + elapsed timer + real MB/s on finish.
# (fastboot stage does not report mid-transfer byte offsets, so percentages are never faked.)
stage_with_progress() {
    local file="$1"
    local label="$2"
    local bytes mb tmp_out tmp_err t0 pid rc dt rate
    local pos=0 dir=1 w=16 bar_w=4

    bytes=$(wc -c < "$file" | tr -d '[:space:]')
    mb=$(awk "BEGIN { printf \"%.1f\", $bytes / 1048576 }")
    tmp_out=$(mktemp)
    tmp_err=$(mktemp)

    t0=$(date +%s%N 2>/dev/null || date +%s)
    fastboot stage "$file" >"$tmp_out" 2>"$tmp_err" &
    pid=$!

    while kill -0 "$pid" 2>/dev/null; do
        local left right now sec mm ss
        left=$(printf '%*s' "$pos" '')
        right=$(printf '%*s' $((w - bar_w - pos)) '')
        now=$(date +%s%N 2>/dev/null || date +%s)
        if [ ${#t0} -gt 12 ]; then
            sec=$(( (now - t0) / 1000000000 ))
        else
            sec=$(( now - t0 ))
        fi
        mm=$(( sec / 60 ))
        ss=$(( sec % 60 ))
        printf '\r    %s (%s MB)  [%s<==>%s]  %02d:%02d elapsed   ' "$label" "$mb" "$left" "$right" "$mm" "$ss"
        pos=$((pos + dir))
        if [ "$pos" -ge $((w - bar_w)) ] || [ "$pos" -le 0 ]; then
            dir=$((-dir))
        fi
        sleep 0.15
    done

    wait "$pid"
    rc=$?
    local t1
    t1=$(date +%s%N 2>/dev/null || date +%s)
    if [ ${#t0} -gt 12 ]; then
        dt=$(awk "BEGIN { d = ($t1 - $t0) / 1000000000; if (d < 0.1) d = 0.1; printf \"%.1f\", d }")
    else
        dt=$(awk "BEGIN { d = ($t1 - $t0); if (d < 0.1) d = 0.1; printf \"%.1f\", d }")
    fi
    rate=$(awk "BEGIN { printf \"%.1f\", $mb / $dt }")

    printf '\r%*s\r' 80 ''
    if [ "$rc" -eq 0 ]; then
        echo "[OK] $label staged ($mb MB in ${dt}s @ ${rate} MB/s)"
    else
        echo "[ERR] Failed to stage $label after ${dt}s (exit code $rc)"
        [ -s "$tmp_out" ] && cat "$tmp_out"
        [ -s "$tmp_err" ] && cat "$tmp_err"
    fi
    rm -f "$tmp_out" "$tmp_err"
    return "$rc"
}

boot_loader_stage() {
    echo "[*] Booting $BOOTIMG into RAM via fastboot boot..."
    fastboot boot "$BOOTIMG" || { echo "[ERR] fastboot boot failed."; return 1; }
    echo "[*] Waiting for xnuloader in RAM..."
    for _ in $(seq 1 40); do
        sleep 2
        if [ "$(device_state)" = "xnuloader" ]; then
            echo "[OK] xnuloader is active!"
            return 0
        fi
    done
    echo "[ERR] Timeout waiting for xnuloader. Hold POWER button for 15s to reset."
    return 1
}

run_boot() {
    local payload="$1"
    local label="$2"
    local skip_apfs="$3"

    require_tools
    [ -f "$BOOTIMG" ] || { echo "[ERR] $BOOTIMG not found."; return 1; }
    [ -f "$payload" ] || { echo "[ERR] $payload not found."; return 1; }
    if [ "$skip_apfs" = "0" ] && [ ! -f "$SYSTEM" ]; then
        echo "[ERR] userland/system.apfs not found!"
        echo "      Download system.apfs (2.32 GB) from the Google Drive link in README.md"
        echo "      and place it at: userland/system.apfs"
        return 1
    fi

    echo "[*] Detecting POCO X6 5G ($label)..."
    while true; do
        case "$(device_state)" in
            xnuloader) echo "[OK] Detected xnuloader mode."; break ;;
            fastboot)  echo "[OK] Detected Fastboot mode."; boot_loader_stage || return 1; break ;;
            android)
                echo "[OK] Detected Android. Rebooting to Fastboot..."
                adb reboot bootloader
                for _ in $(seq 1 25); do
                    sleep 2
                    [ "$(device_state)" = "fastboot" ] && break
                done
                [ "$(device_state)" = "fastboot" ] || { echo "[ERR] Timeout waiting for Fastboot."; return 1; }
                boot_loader_stage || return 1
                break
                ;;
            absent)
                echo "[!] Device not detected via ADB/Fastboot. Connect USB cable and press Enter..."
                read -r _
                ;;
        esac
    done

    if [ "$skip_apfs" = "0" ]; then
        fastboot oem stop >/dev/null 2>&1 || true
        sleep 3
        local ok=0
        for attempt in 1 2 3 4 5; do
            echo "[*] [1/2] Preparing resident ramdisk allocation ($attempt/5)..."
            if fastboot oem ramdisk >/dev/null 2>&1; then
                ok=1
                break
            fi
            fastboot oem stop >/dev/null 2>&1 || true
            sleep 3
        done
        [ "$ok" = "1" ] || { echo "[ERR] fastboot oem ramdisk failed."; return 1; }

        echo "[*] Uploading iOS rootfs to RAM (transfer speed depends on USB 2.0/3.0 link)..."
        stage_with_progress "$SYSTEM" "system.apfs" || return 1
    else
        echo "[*] Fast Swap mode: skipping system.apfs upload."
    fi

    fastboot oem stop >/dev/null 2>&1 || true
    sleep 4
    local staged=0
    for attempt in 1 2 3 4 5; do
        echo "[*] [2/2] Uploading kernel payload $label ($attempt/5)..."
        if stage_with_progress "$payload" "payload"; then
            staged=1
            break
        fi
        fastboot oem stop >/dev/null 2>&1 || true
        sleep 3
    done
    [ "$staged" = "1" ] || { echo "[ERR] Failed to stage $payload."; return 1; }

    echo "[*] Launching Darwin XNU (fastboot oem run)..."
    fastboot oem run || { echo "[ERR] fastboot oem run failed."; return 1; }
    echo "[SUCCESS] iOS 16.5 is booting ($label) - 100% in RAM."
    echo "          Hold physical POWER button for 10-15 seconds to return to Android."
}

while true; do
    echo "================================================================"
    echo "    HACKIOS GARNET BOOT MANAGER - POCO X6 5G | iOS 16.5"
    echo "================================================================"
    echo "  [1] Apple Metal Native   (Adreno 710 120Hz + Haptics + Touch + ADSP)"
    echo "  [2] OpenGL ES            (Mesa Freedreno / EAGL Fallback)"
    echo "  [3] Fast Swap to Metal   (skip system.apfs)"
    echo "  [4] Fast Swap to OpenGL ES (skip system.apfs)"
    echo "  [5] Exit"
    echo "================================================================"
    printf "Select option [1-5]: "
    read -r choice
    case "$choice" in
        1) run_boot "$PAYLOAD_METAL" "Metal Native" 0 ;;
        2) run_boot "$PAYLOAD_GLES" "OpenGL ES" 0 ;;
        3) run_boot "$PAYLOAD_METAL" "Metal Native [Fast Swap]" 1 ;;
        4) run_boot "$PAYLOAD_GLES" "OpenGL ES [Fast Swap]" 1 ;;
        5) exit 0 ;;
        *) echo "[!] Invalid option." ;;
    esac
done
