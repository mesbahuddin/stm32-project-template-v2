# Plan: Import from temp/scripts/ and temp/.vscode/

## Status: ✅ COMPLETE — All files have been imported and adapted.

## Context

The `temp/` directory contains scripts and VS Code configs from an STM32F407-based project (AGM-6). We needed to import the useful parts into this STM32L496 project, adapting them for our target.

---

## What Was Imported

### 1. PowerShell Build/Flash Scripts ✅

**Imported and adapted from `temp/scripts/`:**
- ✅ `build.ps1` — Build with CMake presets, auto-detect CPU cores, color-coded output
- ✅ `flash.ps1` — Flash firmware via J-Link (default), ST-Link, or DFU
- ✅ `monitor.ps1` — Serial port monitor with auto-detect, color-coded output, logging
- ✅ `clean.ps1` — Clean build artifacts
- ✅ `config.ps1` — Build configuration (simplified for our project)
- ✅ `flash_monitor.ps1` — Flash + monitor combo
- ✅ `flash_gui.ps1` — Flash + monitor combo (GUI not yet available)
- ✅ `launch_gui.ps1` — GUI launcher (placeholder — no GUI yet)
- ✅ `launch_gui.bat` — Windows batch GUI launcher (placeholder — no GUI yet)
- ✅ `agm.ps1` — Master menu interface

### 2. VS Code Configs ✅

**Imported and adapted:**
- ✅ `temp/.vscode/launch.json` — Cortex-Debug config: device=STM32L496xx, interface=jlink
- ✅ `temp/.vscode/c_cpp_properties.json` — Compatible with cmake-tools
- ✅ `temp/.vscode/settings.json` — Updated with our project settings
- ✅ `temp/.vscode/tasks.json` — Added flash tasks (J-Link, ST-Link, CubeProg)

### 3. .clang-format

**Kept the existing one** — LLVM style, ColumnLimit: 120. The temp version is Chromium-style with ColumnLimit: 80 and would require reformatting the entire codebase.

### 4. .clang-tidy

**Kept the existing one** — configured for MISRA-C and our project. The temp version uses Google-style checks instead.

---

## Implementation Steps ✅

### Step 1: Copy PowerShell scripts ✅
Copied all `.ps1` files from `temp/scripts/` to `src/scripts/` (new directory under `src/`).

### Step 2: Adapt `build.ps1` ✅
- Changed firmware filename from `AGM_6_STM32_PORT` → `stm32-project-template-v2`
- Removed ADC resolution mode references
- Kept color-coded output and auto-detect CPU cores
- Simplified build config (no ADC mode)

### Step 3: Adapt `flash.ps1` ✅
- Changed default interface to J-Link (JLink is now the default)
- Changed device from `STM32F407VG` → `STM32L496xx`
- Changed firmware filename → `stm32-project-template-v2`
- Reordered validation set: JLink → STLink → DFU

### Step 4: Adapt `monitor.ps1` ✅
- Kept COM port auto-detect logic (generic)
- Updated title from "AGM-6 STM32 CDC Monitor" → "STM32 Serial Monitor"

### Step 5: Adapt `clean.ps1` ✅
- Updated title and references
- Updated build directory paths to match our CMake preset structure

### Step 6: Adapt `config.ps1` ✅
- Removed ADC mode selection entirely
- Simplified to just BuildType (Debug/Release) and optional Defines

### Step 7: Adapt VS Code configs ✅
- **launch.json**: device=STM32L496xx, interface=jlink, added SVD file, added J-Link server path comment
- **tasks.json**: Added J-Link flash task, ST-Link flash task, Flash+Monitor task, Cppcheck, clang-tidy, Doxygen tasks
- **settings.json**: Updated with our project settings (cmake path, build directory, launch target)
- **c_cpp_properties.json**: Kept as-is (compatible with cmake-tools)

### Step 8: Kept existing configs ✅
- `.clang-format` kept as-is (LLVM style)
- `.clang-tidy` kept as-is (MISRA-C rules)

### Step 9: Adapt `flash_monitor.ps1` ✅
- Changed default flash method to J-Link
- Updated titles and comments

### Step 10: Adapt `flash_gui.ps1` ✅
- Since no GUI exists, converted to flash + monitor combo
- Removed GUI verification and launch code
- Replaced with serial monitor launch

### Step 11: Adapt `launch_gui.ps1` and `launch_gui.bat` ✅
- Converted to placeholder scripts that note GUI is not yet available
- Kept structure for future GUI implementation

### Step 12: Updated `agm.ps1` (master menu) ✅
- Updated titles and menu items
- Removed ADC mode selection
- Updated flash interface options

### Step 13: Updated README.md ✅
- Rewrote for our project's scripts and conventions
- Updated all documentation to match the adapted scripts

---

## Files Imported and Adapted ✅

| Source | Destination | Status |
|--------|-------------|--------|
| `temp/scripts/agm.ps1` | `src/scripts/agm.ps1` | ✅ Adapted |
| `temp/scripts/build.ps1` | `src/scripts/build.ps1` | ✅ Adapted |
| `temp/scripts/build_config.ps1` | `src/scripts/build_config.ps1` | ✅ Adapted |
| `temp/scripts/clean.ps1` | `src/scripts/clean.ps1` | ✅ Adapted |
| `temp/scripts/config.ps1` | `src/scripts/config.ps1` | ✅ Adapted |
| `temp/scripts/flash.ps1` | `src/scripts/flash.ps1` | ✅ Adapted |
| `temp/scripts/flash_gui.ps1` | `src/scripts/flash_gui.ps1` | ✅ Adapted |
| `temp/scripts/flash_monitor.ps1` | `src/scripts/flash_monitor.ps1` | ✅ Adapted |
| `temp/scripts/launch_gui.ps1` | `src/scripts/launch_gui.ps1` | ✅ Adapted (placeholder) |
| `temp/scripts/launch_gui.bat` | `src/scripts/launch_gui.bat` | ✅ Adapted (placeholder) |
| `temp/scripts/monitor.ps1` | `src/scripts/monitor.ps1` | ✅ Adapted |
| `temp/scripts/README.md` | `src/scripts/README.md` | ✅ Rewritten |
| `temp/.vscode/launch.json` | `.vscode/launch.json` | ✅ Adapted |
| `temp/.vscode/tasks.json` | `.vscode/tasks.json` | ✅ Adapted |
| `temp/.vscode/settings.json` | `.vscode/settings.json` | ✅ Adapted |
| `temp/.vscode/c_cpp_properties.json` | `.vscode/c_cpp_properties.json` | ✅ Copied (compatible) |
| `temp/.clang-format` | `.clang-format` | Kept existing (LLVM style) |
| `temp/.clang-tidy` | `.clang-tidy` | Kept existing (MISRA-C) |

## Key Adaptations Summary ✅

1. ✅ **Firmware filename**: `AGM_6_STM32_PORT` → `stm32-project-template-v2`
2. ✅ **MCU target**: `STM32F407VG` → `STM32L496xx`
3. ✅ **Debug interface**: J-Link is now the default (was ST-Link)
4. ✅ **ADC mode selection**: Removed (not applicable to our project)
5. ✅ **J-Link paths**: Updated in flash scripts
6. ✅ **J-Link GDB server**: Added J-Link GDB server config to launch.json
7. ✅ **CMake preset paths**: Match our build directory structure (`build/Debug/`, `build/Release/`)
8. ✅ **Flash + Monitor combo**: Combined flash_monitor.ps1 for quick workflow
9. ✅ **GUI scripts**: Converted to placeholders (no GUI yet)
10. ✅ **Config script**: Simplified (BuildType only, no ADC mode)
