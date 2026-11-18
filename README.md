# HakiOS — POCO X6 5G (`garnet`) iOS 16.5

RAM-only Darwin / XNU (iOS 16.5 `arm64`) boot package for **Xiaomi POCO X6 5G (`garnet`, Snapdragon 7s Gen 2 / `SM7435-AB`)** via `xnuloader`. Nothing is flashed to UFS; hold the Power button for 10–15 seconds to reboot back into Android / HyperOS.

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
- `[1] Apple Metal Native` — Full boot (`system.apfs` + Metal/ADSP payload: Adreno 710 Metal, touch, speaker audio, battery reading).
- `[2] OpenGL ES` — Full boot with Mesa Freedreno fallback payload (older kernel without ADSP audio/battery).
- `[3]` / `[4]` **Fast Swap** — Uploads only the kernel payload when switching modes while `xnuloader` already has `system.apfs` in RAM.

For reliable Adreno 710 GMU init, boot from Android (`adb reboot bootloader`) or a fresh Fastboot session instead of looping soft resets in `xnuloader`.

## Status

| Feature | State | Notes |
|---|---|---|
| Display & GPU | Works | Adreno 710 (Metal & OpenGL ES); panel refresh is 60 Hz, UI currently ~26–46 fps |
| Touch & Power key | Works | FocalTech `FT3683G` touchscreen; Power button sleep/wake |
| Audio & ADSP | Works | Speaker output, Control Center volume slider, and `Vol+`/`Vol-` buttons |
| Battery & Clock | Partial | Battery % and USB status via ADSP (no fast charging); PMIC RTC ticks from boot `epoch` |
| Brightness & Vol keys | Works | Control Center brightness slider (`kern.hakios.brightness`); `Vol+`/`Vol-` HUD events |
| Connectivity & Peripherals | Missing | Wi-Fi, Bluetooth, Cellular, Camera, GPS, Microphone |

## Included Files

| File | Size | Notes | SHA256 |
|---|---:|---|---|
| `garnet-boot.img` | `2.51 MiB` (`2,627,584` B) | `xnuloader` + UEFI (`fastboot boot`, auto-detects 8/12 GB RAM) | `b6628f7eaabe2dcd7c71fb0e8af939d290142697628b41d32d55aad740e9d778` |
| `payloads/run-metal-fixed-payload.bin` | `50.53 MiB` (`52,979,496` B) | XNU kernel + APFS ramdisk + Metal/ADSP cmdline | `4df68e08790ae762b232f627952fb3871c66ddcc4c53f582190b83d15d32d88c` |
| `payloads/opengles_payload.bin` | `40.99 MiB` (`42,983,128` B) | XNU kernel + OpenGL ES fallback ramdisk | `927bcda239df9c6c587d933c9e7aedefd11add071310b9a80b8f4c900487e66e` |
| `boot.bat` / `boot.sh` | — | Windows & Unix RAM boot scripts (`tools/stage.ps1` transfer monitor) | — |
| `tools/platform-tools/` | — | Bundled Windows `adb` & `fastboot` (`Apache-2.0`, `NOTICE.txt`) | — |

## Credits & Licenses

- [`oosexgang/hakios-xnu-kernel`](https://github.com/oosexgang/hakios-xnu-kernel), `hakios-xnu-userland`, `hakios-metal` — XNU port, `xnuloader`, Mesa/Metal stack
- [`Project-Silicium/Mu-Silicium`](https://github.com/Project-Silicium/Mu-Silicium) — Qualcomm UEFI base
- Licenses: [`LICENSE.APSL`](LICENSE.APSL) (`APSL-2.0`), [`LICENSE`](LICENSE) (`MIT`), [`LEGAL.md`](LEGAL.md)
"# HakiOS-Garnet-by-Vael" 
