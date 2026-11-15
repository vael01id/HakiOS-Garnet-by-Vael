# HackiOS — POCO X6 5G (`garnet`) iOS 16.5 Ready-to-Boot

Ready-to-boot **100% RAM-only** HakiOS (Darwin / XNU, iOS 16.5 `arm64`) release package for **Xiaomi POCO X6 5G (`garnet`, Qualcomm Snapdragon 7s Gen 2 / `SM7435-AB`)** with Adreno 710 GPU acceleration (Metal & OpenGL ES) and native FocalTech `FT3683G` touch support.

---

## Step 1: Download `system.apfs` (Required, 2.32 GB)

Because `system.apfs` is **2.32 GB**, it cannot be stored directly in Git. Download it separately and place it inside the [`userland/`](userland/put_system_apfs_here.txt) folder:

> **[Download `system.apfs` (2.32 GB) via Google Drive](<PASTE_GOOGLE_DRIVE_SYSTEM_APFS_LINK_HERE>)**

Put the downloaded file here:

```text
userland/system.apfs
```

Verify checksum before booting (optional):

- **Size:** `2,492,203,008` bytes
- **SHA256:** `ccfdbc0a8c7f3166eed76ca6e14fe9a1060d58884cda408aca2354447d7c55e7`

---

## Step 2: Quick Boot

> **100% RAM-Only Safety Guarantee:** Nothing is ever flashed to NAND/UFS partitions. Holding the physical **Power button for 10–15 seconds** cleanly reboots your phone back into stock Android / HyperOS.

### Windows
1. Enable **USB Debugging** on Android (or hold **Volume Down + Power** to enter Fastboot mode).
2. Double-click **`boot.bat`** (`adb.exe` & `fastboot.exe` are bundled in `tools/platform-tools/`).
3. Choose:
   - **`[1]` Apple Metal Native** — Recommended (Adreno 710 hardware acceleration + `FT3683G` touch + updated `QuartzCore-default.metallib`).
   - **`[2]` OpenGL ES** — Mesa Freedreno / EAGL fallback.
   - **`[3]` / `[4]` Fast Swap** — Skips re-uploading the 2.32 GB `system.apfs` when switching payloads from resident `xnuloader`.

### Linux / macOS
1. Install `android-tools` (`adb` and `fastboot`).
2. Run:
   ```bash
   chmod +x boot.sh
   ./boot.sh
   ```

> **Tip (GMU Cold Reset):** For reliable Adreno 710 GMU initialization, start a fresh session from Android (`adb reboot bootloader`) or Xiaomi Fastboot rather than repeating indefinitely from inside a stale `xnuloader` session.

---

## Included Files

| File | Size | Purpose | SHA256 |
|---|---:|---|---|
| `garnet-boot.img` | `1.65 MB` | RAM-bootable `xnuloader` + UEFI image (`fastboot boot`) | `ab903163d7c2e65dd3a59ee059350d2c2521368717945e481322499003a83489` |
| `payloads/run-metal-fixed-payload.bin` | `41.11 MB` | Prebuilt XNU kernel + `root_metal_fixed.apfs` + Metal cmdline | `6b7409790241e30b617fa6eff6fe443a8064fe0296fd3c0da238d96a9fa15968` |
| `payloads/opengles_payload.bin` | `40.99 MB` | Prebuilt XNU kernel + `root.apfs` + OpenGL ES cmdline | `927bcda239df9c6c587d933c9e7aedefd11add071310b9a80b8f4c900487e66e` |
| `boot.bat` / `boot.sh` | — | Interactive Windows & Linux/macOS RAM boot managers | — |
| `tools/platform-tools/` | `11.7 MB` | Bundled Windows `adb.exe` & `fastboot.exe` (Apache-2.0) | — |

---

## Credits & Upstream Lineage

- **[oosexgang/hakios-xnu-kernel](https://github.com/oosexgang/hakios-xnu-kernel)**, **hakios-xnu-userland**, & **hakios-metal** — Core HakiOS XNU port, `xnuloader`, and Mesa/Metal graphics stack
- **[Project-Silicium/Mu-Silicium](https://github.com/Project-Silicium/Mu-Silicium)** — Qualcomm UEFI EDK2 foundation
- **Apple OSS Distributions (`xnu`)** — XNU kernel under `APSL-2.0` (see [`LICENSE.APSL`](LICENSE.APSL) and [`LEGAL.md`](LEGAL.md))
