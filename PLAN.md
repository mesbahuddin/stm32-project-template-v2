# Plan: Directory Structure Reorganization

## Context

The user wants to reorganize the directory structure of the STM32 Project Template for better separation of concerns and easier future maintenance.

## Current Structure

```
project-root/
├── CMakeLists.txt
├── CMakePresets.json
├── LICENSE.md
├── README.md
├── CHANGELOG.md
├── PLAN.md
├── .clang-format
├── .clang-tidy
├── .clangd
├── .devcontainer/
├── .editorconfig
├── .github/
├── .settings/
├── .vscode/
├── .gitignore
├── cmake/
│   ├── microcontrollers/
│   ├── toolchains/
│   └── tools/
├── docs/
│   └── doxygen/
├── include/          ← project-level headers (6 files)
├── lib/              ← vendor HAL/CMSIS (unchanged)
├── lint/
├── mcal/             ← MCU-specific drivers (8 .c/.h + startup + linker)
│   └── st-stm32l4/
│       ├── gcc-arm/
│       ├── include/
│       ├── source/
│       └── svd/
├── project/
├── requirements.txt
├── script/
├── source/           ← application files (12 files)
│   ├── main.c
│   ├── led.c
│   ├── button.c
│   ├── log.c
│   ├── error_handler.c
│   ├── system_clock.c
│   ├── system_stm32l4xx.c
│   └── stm32l4xx_it.c
└── temp/
```

## Proposed Structure

### Option A: Flat Include (Recommended — fewer CMake paths, headers co-locate with sources)

```
project-root/
├── CMakeLists.txt
├── CMakePresets.json
├── LICENSE.md
├── README.md
├── CHANGELOG.md
├── PLAN.md
├── .clang-format
├── .clang-tidy
├── .clangd
├── .devcontainer/
├── .editorconfig
├── .github/
├── .settings/
├── .vscode/
├── .gitignore
├── cmake/
│   ├── microcontrollers/
│   ├── toolchains/
│   └── tools/
├── docs/
│   └── doxygen/
├── lint/
├── lib/              ← unchanged
├── project/
├── requirements.txt
├── script/
├── src/
│   ├── main.c                    ← app entry point
│   ├── app/                      ← user application modules
│   │   └── (future app files)
│   ├── bsp/
│   │   ├── core/                 ← MCU core peripherals
│   │   │   ├── gpio.c
│   │   │   ├── gpio.h
│   │   │   ├── rcc.c
│   │   │   ├── rcc.h
│   │   │   ├── uart.c
│   │   │   ├── uart.h
│   │   │   ├── systick.c
│   │   │   ├── systick.h
│   │   │   ├── system_clock.c
│   │   │   ├── system_clock.h
│   │   │   ├── stm32l4xx_it.c
│   │   │   ├── system_stm32l4xx.c
│   │   │   ├── startup_stm32l496xx.s
│   │   │   └── stm32l496xx_flash.ld
│   │   └── brd/                  ← board-specific components
│   │       ├── led.c
│   │       ├── led.h
│   │       ├── button.c
│   │       └── button.h
│   └── utils/                    ← cross-cutting utilities
│       ├── log.c
│       ├── log.h
│       ├── error_handler.c
│       └── error_handler.h
└── temp/
```

### Option B: Separate Include (headers in `include/` alongside `src/`)

```
project-root/
├── include/                  ← project-level headers (6 files)
│   ├── button.h
│   ├── error_handler.h
│   ├── led.h
│   ├── log.h
│   ├── system_clock.h
│   └── stm32l4xx_hal_conf.h
├── src/
│   ├── main.c
│   ├── app/
│   ├── bsp/
│   │   ├── core/
│   │   │   ├── gpio.c
│   │   │   ├── rcc.c
│   │   │   ├── uart.c
│   │   │   ├── systick.c
│   │   │   ├── system_clock.c
│   │   │   ├── stm32l4xx_it.c
│   │   │   ├── system_stm32l4xx.c
│   │   │   ├── startup_stm32l496xx.s
│   │   │   └── stm32l496xx_flash.ld
│   │   └── brd/
│   │       ├── led.c
│   │       └── button.c
│   └── utils/
│       ├── log.c
│       └── error_handler.c
└── ...
```

### Option C: Hybrid (headers co-locate with sources, but also copy to include/ for IDE convenience)

Same as Option A, but also maintain `include/` as symlinks or copies for IDE convenience.

## File Mapping (Option A — flat include)

| Current File | New File | Notes |
|-------------|----------|-------|
| `source/main.c` | `src/main.c` | Entry point, stays at src root |
| `source/led.c` | `src/bsp/brd/led.c` | Board driver |
| `source/led.h` | `src/bsp/brd/led.h` | Board driver header |
| `source/button.c` | `src/bsp/brd/button.c` | Board driver |
| `source/button.h` | `src/bsp/brd/button.h` | Board driver header |
| `source/log.c` | `src/utils/log.c` | Utility module |
| `source/log.h` | `src/utils/log.h` | Utility header |
| `source/error_handler.c` | `src/utils/error_handler.c` | Utility module |
| `source/error_handler.h` | `src/utils/error_handler.h` | Utility header |
| `source/system_clock.c` | `src/bsp/core/system_clock.c` | MCU core config |
| `source/stm32l4xx_it.c` | `src/bsp/core/stm32l4xx_it.c` | Interrupt handlers |
| `source/system_stm32l4xx.c` | `src/bsp/core/system_stm32l4xx.c` | CMSIS SystemInit |
| `mcal/st-stm32l4/source/gpio.c` | `src/bsp/core/gpio.c` | GPIO driver |
| `mcal/st-stm32l4/include/gpio.h` | `src/bsp/core/gpio.h` | GPIO header |
| `mcal/st-stm32l4/source/rcc.c` | `src/bsp/core/rcc.c` | RCC driver |
| `mcal/st-stm32l4/include/rcc.h` | `src/bsp/core/rcc.h` | RCC header |
| `mcal/st-stm32l4/source/uart.c` | `src/bsp/core/uart.c` | UART driver |
| `mcal/st-stm32l4/include/uart.h` | `src/bsp/core/uart.h` | UART header |
| `mcal/st-stm32l4/source/systick.c` | `src/bsp/core/systick.c` | SysTick driver |
| `mcal/st-stm32l4/include/systick.h` | `src/bsp/core/systick.h` | SysTick header |
| `mcal/st-stm32l4/gcc-arm/startup_stm32l496xx.s` | `src/bsp/core/startup_stm32l496xx.s` | Startup file |
| `mcal/st-stm32l4/gcc-arm/stm32l496xx_flash.ld` | `src/bsp/core/stm32l496xx_flash.ld` | Linker script |
| `include/stm32l4xx_hal_conf.h` | `src/bsp/core/stm32l4xx_hal_conf.h` | HAL config |

## Decisions

1. **Option A** — Flat include strategy, headers co-locate with sources, `include/` folder removed entirely.
2. **`include/` folder** — Removed entirely (headers move with their source files).
3. **`mcal/` folder** — Removed entirely; SVD files not required.
4. **`project/ozone/` folder** — Keep at root (debugger-specific, not part of source tree).
5. **`temp/` folder** — Keep at root (workspace-specific, not part of source tree).

## Files That Need Changes

| Category | Files |
|----------|-------|
| **File moves** | 22 `.c`, `.h`, `.s` files (see mapping above) |
| **CMakeLists.txt** | Update include paths, source lists, linker script, startup file paths |
| **CMakeLists.txt (root)** | Update `${CMAKE_PROJECT_NAME}` references, post-build targets |
| **cmake/microcontrollers/stm32l4-gcc.cmake** | Update linker script path |
| **cmake/tools/clang-tools.cmake** | Might need `--sysroot` update |
| **cmake/tools/python.cmake** | No change needed |
| **cmake/microcontrollers/common.cmake** | No change needed |
| **.clang-tidy** | Might need `HeaderFilterRegex` update if include paths change |
| **.vscode/c_cpp_properties.json** | Update include paths |
| **.vscode/settings.json** | Might need update |
| **.clangd** | Might need update |
| **.github/workflows/ci-pipeline.yml** | No change needed (builds from CMake) |
| **.devcontainer/devcontainer.json** | No change needed |
| **All source files** | Update `#include` paths to match new layout |
| **README.md** | Update repository structure diagram |
| **CHANGELOG.md** | Add reorganization entry |
| **docs/cmake-system.md** | Update file map and execution order |
| **CMakePresets.json** | No change needed |
| **LICENSE.md** | No change needed |
| **CHANGELOG.md** | No change needed |

## Steps

- [ ] Choose include strategy (Option A / B / C)
- [ ] Move files to new structure
- [ ] Update all `#include` paths in source files
- [ ] Update `CMakeLists.txt` (root) — include dirs, source lists, linker script, startup file
- [ ] Update `cmake/microcontrollers/stm32l4-gcc.cmake` — linker script path
- [ ] Update `cmake/tools/clang-tools.cmake` — if sysroot path changed
- [ ] Update `.vscode/c_cpp_properties.json` — include paths
- [ ] Update `.vscode/settings.json` — if needed
- [ ] Update `.clangd` — if needed
- [ ] Update `.clang-tidy` — if HeaderFilterRegex needed
- [ ] Update `README.md` — repository structure diagram
- [ ] Update `docs/cmake-system.md` — file map and execution order
- [ ] Update `CHANGELOG.md` — reorganization entry
- [ ] Decide on `mcal/svd/` — move or delete?
- [ ] Decide on `project/ozone/` — move or delete?
- [ ] Decide on `temp/` — delete or ignore?
- [ ] Test build: `cmake --preset Debug && cmake --build --preset Debug`
- [ ] Test linting: `cmake --build --preset Debug --target tidy && cmake --build --preset Debug --target cppcheck`
- [ ] Commit changes
