# Project Context: STM32 Project Template (v2)

This project is a modern, professional-grade template for STM32-based firmware development, specifically targeting the **STM32L496 Discovery** board. It features a modular architecture, a robust CMake build system, and extensive linting/formatting tools.

## Project Overview

- **MCU:** STM32L496xx (Cortex-M4)
- **Board:** STM32L496G-Discovery
- **Toolchain:** GCC for ARM (arm-none-eabi)
- **Build System:** CMake + Ninja/Make
- **Debug Interface:** J-Link (default) or ST-Link
- **Main Technologies:** C11, STM32 HAL, CMSIS, Doxygen, Clang-Format, Clang-Tidy, Cppcheck (MISRA C:2012)

## Architecture

The project follows a modular structure to separate vendor code from application logic:

- `src/main.c`: Application entry point.
- `src/app/`: High-level user application logic.
- `src/bsp/`: Board Support Package.
    - `startup/`: Startup code and vector table.
    - `core/`: MCU core peripheral drivers (GPIO, RCC, UART, etc.) and interrupt handlers.
    - `brd/`: Board-specific components (LEDs, buttons, sensors).
- `src/utils/`: Cross-cutting utilities (logging, error handling).
- `lib/`: Vendor libraries (STM32L4 HAL, CMSIS).
- `scripts/`: Dual-suite PowerShell (Windows native) and POSIX Bash (cross-platform) automation, along with shared Python tools for migration and monitoring.

## Building and Running

### Build Commands

| Command | Description |
|:---|:---|
| `cmake --preset Debug` | Configure the project for Debug. |
| `cmake --build --preset Debug` | Build the project. |
| `cmake --build --preset Debug --target clean` | Clean build artifacts. |

### Automation Scripts

The tools are organized under `scripts/` in dedicated suites:

- **Windows Native PowerShell (`scripts/powershell/`)**:
  - `.\scripts\powershell\build.ps1`: Builds the firmware using CMake presets and calculates precise memory bank usage from the linker script.
  - `.\scripts\powershell\flash.ps1`: Dynamic flashing via ST-Link, J-Link, or USB DFU with autodetected MCU types.
  - `.\scripts\powershell\stm32-dev.ps1`: Master interactive PowerShell developer menu dashboard.
- **Cross-Platform POSIX Bash (`scripts/bash/`)**:
  - `bash scripts/bash/build.sh`: Parallel preset compilation using CMake.
  - `bash scripts/bash/flash.sh`: Dual toolchain automated flashing.
  - `bash scripts/bash/stm32-dev.sh`: Master interactive Bash developer menu dashboard.
- **Shared Python Utilities (`scripts/`)**:
  - `python scripts/migrate_project.py`: Unified, idempotent project migrator for CubeMX codebases.
  - `python scripts/monitor.py`: Dynamic serial COM monitor with severity colorization.

### VS Code Integration

- **Launch:** Use the "Cortex-Debug" configurations in `launch.json` to start a debug session (J-Link default).
- **Tasks:** Build, Flash, and Lint tasks are available via `Ctrl+Shift+B`.

## Development Conventions

### Code Style & Formatting

- **Standard:** C11 for source code.
- **Formatting:** Enforced by `clang-format` using the **LLVM** style (120 column limit).
- **Target:** `cmake --build --preset Debug --target run-format` to reformat files.

### Static Analysis & Linting

- **Clang-Tidy:** Checks for style violations and naming conventions.
- **Cppcheck:** Performs deep static analysis and verifies **MISRA C:2012** compliance.
- **Target:** `cmake --build --preset Debug --target tidy` or `cppcheck`.

### Documentation

- **Style:** Javadoc-style comment blocks in headers and source files.
- **Generation:** Doxygen is used to generate HTML/LaTeX documentation.
- **Target:** `cmake --build --preset Debug --target doxygen`.

## Key Files

- `CMakeLists.txt`: Core build configuration.
- `CMakePresets.json`: Defines build configurations (Debug, Release, etc.).
- `stm32l496xx_flash.ld`: Linker script.
- `.clang-format` & `.clang-tidy`: Tool configurations for style and quality.
- `lint/misra.json`: MISRA-C rule definitions for Cppcheck.
