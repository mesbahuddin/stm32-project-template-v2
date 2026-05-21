# stm32-project-template-v2 — Build Guide

Generated from the STM32 Project Template (v2).

## Target Microcontroller Specifications

| Property | Value |
|----------|-------|
| MCU Family | STM32L4 |
| MCU Name | STM32L496G-Discovery |
| Chip Compile Define | `STM32L496xx` |
| Linker Script | `stm32l496xx_flash.ld` |
| Startup Assembly File | `startup_stm32l496xx.s` |

## Compiler Setup and Prerequisites

- **CMake**: >= 3.22
- **Ninja** or **Make**
- **GNU GCC for ARM Toolchain**: (`arm-none-eabi-gcc` must be in PATH or configured via `ARM_GCC_PATH`)

```bash
# Set path manually if not present in your system variables:
export ARM_GCC_PATH=/path/to/gcc-arm-none-eabi/bin
```

## Compilation and Build Commands

```bash
# 1. Configure the workspace
cmake --preset Debug        # Compile without optimizations and full debug flags (-O0 -g3)
cmake --preset Release      # Compile with maximum speed optimization and Link-Time Optimization (-O3 -flto)
cmake --preset MinSizeRel    # Compile with maximum size optimization and Link-Time Optimization (-Os -flto)

# 2. Build executable
cmake --build --preset Debug
cmake --build --preset Release

# 3. Code formatting & linting targets
cmake --build --preset Debug --target check-format   # Verify coding standards
cmake --build --preset Debug --target run-format     # Apply auto formatting
cmake --build --preset Debug --target tidy           # Run clang-tidy
cmake --build --preset Debug --target cppcheck       # Run MISRA compliance static analyzer

# 4. Diagnostic targets
cmake --build --preset Debug --target lto-info       # Verify compiler optimization status
cmake --build --preset Debug --target size-analysis   # Display flash/ram binary footprint summary
```

## RESTURED SOURCE FILE TREE

```text
stm32-project-template-v2/
├── CMakeLists.txt              # Top-level dynamic build configuration
├── CMakePresets.json            # Build presets (Debug, Release, MinSizeRel)
├── stm32l496xx_flash.ld        # Linker Script
├── cmake/
│   ├── microcontrollers/
│   │   ├── common.cmake        # Build-type optimization summaries
│   │   └── stm32l4-gcc.cmake   # Dynamic compilation and optimization flags
│   └── toolchains/
│       └── gcc-arm-none-eabi.cmake  # Cross-compiler toolchain
├── lib/
│   ├── CMakeLists.txt          # Statically compiles vendor drivers and middle-wares
│   └── CMSIS/                  # STM32 low level registers
├── scripts/
│   ├── bash/                   # POSIX Bash shell scripts (.sh)
│   ├── powershell/             # Windows native PowerShell scripts (.ps1)
│   ├── monitor.py              # Serial COM monitor helper
│   └── migrate_project.py      # Project migration script
├── src/
│   ├── main.c                  # Main program entry point
│   ├── bsp/
│   │   ├── startup/            # Assembly startup boot vectors
│   │   ├── core/               # Restructured peripheral code
│   │   └── brd/                # Restructured board buttons, LEDs, and interfaces
│   └── app/                    # Restructured user programs
└── HOW_TO_BUILD.md             # This document
```

## HAL Configuration

The core configuration for hardware capabilities is handled by `stm32l4xx_hal_conf.h` in `src/bsp/core/`.
Configure peripheral features by toggling `#define HAL_*_MODULE_ENABLED` variables.

## Adding Custom C/H Source Files

1. Create files inside:
   - `src/bsp/core/` for MCU peripheral interactions.
   - `src/bsp/brd/` for external hardware driver models.
   - `src/app/` for high-level state machines and software rules.
2. Register the path to the `.c` file inside the `SOURCES_C` block of `CMakeLists.txt`.
3. Re-run building: `cmake --build --preset Debug`.
