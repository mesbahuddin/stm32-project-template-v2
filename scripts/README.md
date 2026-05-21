# STM32 Firmware Development Scripts

This directory contains dual-suite developer tools designed for maximum ease of use depending on your operating system, structured into dedicated subdirectories:
1. **Windows Native (`scripts/powershell/`)**: Modern Windows-native PowerShell scripts (`.ps1`) for optimal compilation, dynamic memory audits from linker scripts, and robust toolchain discovery without virtual machine/WSL boundaries.
2. **Cross-Platform POSIX (`scripts/bash/`)**: Universal Bash scripts (`.sh`) designed for macOS, Linux, WSL, Git Bash, or other POSIX shell environments.
3. **Shared Helper Tools (`scripts/`)**: Platform-independent Python scripts for serial monitoring, code formatting, and CubeMX migrations.

---

## 📁 Directory Structure
```text
scripts/
├── bash/                    <- Cross-platform POSIX Bash suite (.sh)
│   ├── config.sh            <- Generates build preset parameters
│   ├── build.sh             <- Compiles firmware using CMake presets
│   ├── flash.sh             <- Flashes MCU via JLink / STLink / DFU
│   ├── clean.sh             <- Wipes build folders and settings
│   └── stm32-dev.sh         <- Master Bash interactive developer menu
│
├── powershell/              <- Windows-native PowerShell 5.1+ suite (.ps1)
│   ├── config.ps1           <- Generates build preset parameters
│   ├── build.ps1            <- Compiles and performs dynamic linker memory audits
│   ├── flash.ps1            <- Flashes MCU (robust STLink, JLink, or DFU paths)
│   ├── clean.ps1            <- Wipes build folders and settings
│   ├── monitor.ps1          <- Native PowerShell Serial COM Monitor
│   ├── flash_monitor.ps1    <- Combined flash and COM serial monitor script
│   └── stm32-dev.ps1        <- Master PowerShell interactive developer menu
│
├── clang_format.py          <- Code formatter helper
├── migrate_project.py       <- Unified idempotent project migrator
├── monitor.py               <- Cross-platform serial monitor tool
└── README.md                <- Document reference
```

---

## ⚡ Quick Start (Windows PowerShell)

If you are developing natively on Windows (highly recommended for automatic USB device detection), use the PowerShell suite:

### Option 1: Interactive Menu (Recommended)
```powershell
cd scripts/powershell
.\stm32-dev.ps1
```
This launches a native, high-performance interactive menu dashboard for all development operations.

### Option 2: Individual Scripts
```powershell
cd scripts/powershell
.\config.ps1 Debug
.\build.ps1
.\flash.ps1 -Interface STLink
.\monitor.ps1
```

---

## 🐧 Quick Start (macOS, Linux, WSL, Git Bash)

If you are on Linux, macOS, or running in a POSIX container, use the Bash suite:

### Option 1: Interactive Menu (Recommended)
```bash
cd scripts/bash
./stm32-dev.sh
```

### Option 2: Individual Scripts (For Automation & Advanced Workflows)
```bash
cd scripts/bash

# 1. Configure Build profile (Debug, Release, MinSizeRel, RelWithDebInfo)
./config.sh Debug

# 2. Build / Compile firmware
./build.sh

# 3. Flash to target MCU
./flash.sh -i JLink

# 4. Launch serial monitor
python3 ../monitor.py
```

---

## 🛠️ Toolchain & Host Setup Requirements

### Windows (Primary Host)
All tools (`cmake`, `ninja`, `arm-none-eabi-gcc`, etc.) must be in your system Environment PATH.

### Segger J-Link Flashing
Requires the Segger J-Link software suite. The scripts search standard installations:
- Windows: `C:\Program Files\SEGGER\JLink`
- macOS: `/Applications`
- Linux: `/opt/SEGGER`

### ST-Link / DFU Flashing
Requires the STM32CubeProgrammer software suite. The PowerShell suite features a robust `Find-CubeProgrammer` engine which automatically searches:
- Custom installations/versioned CLT toolchains (`C:\ST\STM32CubeCLT_*` in descending version order)
- Environment system `PATH`
- Standard `Program Files` and `Program Files (x86)` installations
