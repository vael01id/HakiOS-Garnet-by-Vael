# HakiOS — POCO X6 5G (`garnet`) iOS 16.5

RAM-only Darwin / XNU (iOS 16.5 `arm64`) boot package for **Xiaomi POCO X6 5G (`garnet`, Snapdragon 7s Gen 2 / `SM7435-AB`)** via `xnuloader`. Nothing is flashed to UFS; hold the Power button for 10–15 seconds to reboot back into Android.

## 1. Download `system.apfs` (2.32 GiB)

`userland/system.apfs` is too large for Git and must be downloaded separately:

- **Download:** [`system.apfs` (Google Drive)](https://drive.google.com/drive/folders/1Y-K-KpTB9W_ciMqKAiWjXcV79APk6QmJ?usp=sharing)
- **Place at:** `userland/system.apfs`
- **Size:** `2,492,203,008` bytes
- **SHA256:** `ccfdbc0a8c7f3166eed76ca6e14fe9a1060d58884cda408aca2354447d7c55e7`

## 2. Boot

Requires an unlocked bootloader, USB data cable, and Android USB Debugging enabled (or the phone already in Fastboot via `Volume Down + Power`).

**Windows:** run `boot.bat` (`adb.exe` and `fastboot.exe` are bundled in `tools/platform-tools/`).

**Linux / macOS:** install `android-tools`, then run:

```bash
chmod +x boot.sh
./boot.sh
```

Menu options:
- `[1] Apple Metal Native` — Full boot (`system.apfs` + Native Metal 120 Hz + Haptics + Touch + ADSP + Torch payload).
- `[2] OpenGL ES` — Full boot with Mesa Freedreno / EAGL OpenGL ES 120 Hz payload (same kernel & drivers, `gl=1`).
- `[3]` / `[4]` **Fast Swap** — Uploads only the kernel payload when switching between Metal and OpenGL ES while `xnuloader` already has `system.apfs` in RAM.

For reliable Adreno 710 GMU init, boot from Android (`adb reboot bootloader`) or a fresh Fastboot session instead of looping soft resets in `xnuloader`.

## Status

| Feature | State | Notes |
|---|---|---|
| Display & GPU | Works | **Real Hardware 120 Hz** (`garnet_120hz=1`, `fb_hz=120`, `fb_intf=0x0ae36000` hardware-beam phase-locked VSync, panel DCS `0x6c 0x02` + `CTL_INTF_FLUSH` DPU 8.x) — **Major upgrade over previous release (ultra-smooth 120 FPS UI)** + **Native Metal (`metal=1`)** on Adreno 710 @ 940 MHz (zero black glitches, Spotlight Search top black bar fixed, level 0 mipmap blur fix, full backdrop transparency, `fbscale=2`, `anim_max=1`, `fb_queue=2`, `fb_threads=7`), safe HS-mode OLED DBV sleep/wake (`DCS 0x51`) |
| Wi-Fi | In Progress / WIP | Native WCN3990 / Adrastea SNOC (`wifi=1`): TrustZone PAS WPSS firmware boot & CE SPIs integration in progress (not yet functional in iOS Settings). |
| Haptics | Works | PM8350B HV-Haptics (`haptic=5`, `/dev/hakios-haptic`, SPMI v7 `HAP_CFG` `0x3f0` / `HAP_PAT` `0x3f1` / `PMK8350 HAP_SDAM` `0x09d`, zero OLED conflict) |
| Flashlight | Works | PM6150L 3-channel SPMI v7 torch (`torch=3`, `/dev/hakios-torch`, 100 mA/LED cap, thermal stage 0 verified) |
| Touch & Power key | Works | FocalTech `FT3683G` touchscreen (priority 93 kernel thread, 1 ms max idle latency, `touch_poll_us=500` / 2000 Hz active polling, ~2.4 MHz `spin_ns(180)` SPI, hardware-beam phase-locked VSync); Power button sleep/wake |
| Audio & ADSP | Partial | ADSP (`adsp=1`) + `battmgr` telemetry active; Garnet ADSP is AudioReach/SPF (GPR) rather than legacy APR (`apr_audio_svc`), so speaker/mic APR paths are not active on Garnet |
| Battery & Clock | Partial | Battery %, voltage, current, temperature, and USB status via ADSP `battmgr` (no fast charging); PMIC RTC ticks from boot `epoch` |
| Brightness & Vol keys | Works | Control Center brightness slider (`kern.hakios.brightness`); `Vol+`/`Vol-` HUD events |
| Other Peripherals | Missing | Wi-Fi (WIP / not yet functional), Bluetooth (`bt_wcn3990` on `HSUART0`, upstream HakiOS has no HCI/IOBluetooth stack yet), Microphone (`WCD937x` on AudioReach/SPF), Cellular (~125 MB modem blobs), Camera, GPS |

Debug / rollback boot-args if needed: `wifi=0` (disable Wi-Fi), `haptic=0` (disable PM8350B haptics), `garnet_120hz=0 fb_hz=60` (revert to 60 Hz scanout), `gpu_gmem_base=0` (disable Adreno 710 GMEM), `garnet_dsi=0` (disable DSI0 brightness/power DCS), `torch=0` (disable PM6150L flashlight).

## Included Files

| File | Size | Notes |
|---|---:|---|
| `garnet-boot.img` | `2.51 MiB` (`2,627,584` B) | `xnuloader` + UEFI (`fastboot boot`, auto-detects 8/12 GB RAM) |
| `payloads/run-metal-fixed-payload.bin` | `53.93 MiB` (`56,549,608` B) | XNU kernel + APFS ramdisk + **Real 120 Hz Beam-Locked VSync** (major upgrade over previous release, ultra-smooth 120 FPS UI) + **Native Metal (`metal=1`)** with Spotlight Search top black bar & blur backdrop fixes + PM8350B HV-Haptics (`haptic=5`) + 2000 Hz / 2.4 MHz SPI Touch + ADSP `battmgr` + PM6150L Torch (`torch=3`) |
| `payloads/opengles_payload.bin` | `53.93 MiB` (`56,549,528` B) | XNU kernel + APFS ramdisk + OpenGL ES (`gl=1`) + Real 120 Hz + Haptics + Touch + ADSP + Torch (100% Fast Swap compatible) |
| `boot.bat` / `boot.sh` | — | Windows & Unix RAM boot scripts (`tools/stage.ps1` transfer monitor) |
| `tools/platform-tools/` | — | Bundled Windows `adb` & `fastboot` (`Apache-2.0`, `NOTICE.txt`) |

## Credits & Licenses

- [`oosexgang/hakios-xnu-kernel`](https://github.com/oosexgang/hakios-xnu-kernel), `hakios-xnu-userland`, `hakios-metal` — XNU port, `xnuloader`, Mesa/Metal stack
- [`Project-Silicium/Mu-Silicium`](https://github.com/Project-Silicium/Mu-Silicium) — Qualcomm UEFI base
- Licenses: [`LICENSE.APSL`](LICENSE.APSL) (`APSL-2.0`), [`LICENSE`](LICENSE) (`MIT`), [`LEGAL.md`](LEGAL.md)
