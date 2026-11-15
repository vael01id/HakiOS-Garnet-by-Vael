# Legal & Provenance Notice

This repository distributes a ready-to-boot **HakiOS (Darwin / XNU, iOS 16.5 `arm64`)** RAM-boot package for the **Xiaomi POCO X6 5G (`garnet`, Qualcomm Snapdragon 7s Gen 2 / `SM7435-AB`)**.

It is **not affiliated with, endorsed by, or connected to Apple Inc., Qualcomm Inc., or Xiaomi Corporation**.

## Components & Licensing

- **Boot & Kernel Payloads (`garnet-boot.img`, `payloads/*.bin`)**: Includes XNU kernel derivatives under **APSL-2.0** (see `LICENSE.APSL`), `Mu-Silicium` / `xnuloader` (`BSD-2-Clause-Patent` / `MIT`), and open-source Mesa / Freedreno / `hakios-metal` userland bridges (`MIT` / `Apache-2.0`).
- **Windows Launchers & Scripts (`boot.bat`, `boot.sh`)**: Licensed under the **MIT License** (see `LICENSE`).
- **Android Platform Tools (`tools/platform-tools/`)**: `adb.exe`, `fastboot.exe`, and supporting Windows DLLs distributed under **Apache-2.0** (see `tools/platform-tools/NOTICE.txt`).
- **`system.apfs` (External Download)**: Not committed in this Git repository due to GitHub file size limits and Apple system image separation; users obtain `system.apfs` separately from the link in `README.md`.

## Non-Destructive Boot Guarantee

All scripts boot **100% in RAM** using `fastboot boot`, `fastboot stage`, and `fastboot oem run` — internal UFS/NAND storage partitions are never flashed or modified. Holding the physical Power button for 10–15 seconds cleanly reboots back into Android / HyperOS.
