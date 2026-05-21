# Changelog

## [Unreleased]

### Added
- Fork of the original STM32 Project Template by Akos Pasztor
- Added Mesbah Uddin as co-author
- Added `scripts/migrate_project.py` tool to automatically migrate standard STM32CubeMX projects into the modular template structure.
- Automatic ARM GCC toolchain discovery via `ARM_GCC_PATH` CMake variable, environment variable, or system PATH.
- Added cross-platform POSIX Bash script suite: `config.sh`, `build.sh`, `flash.sh`, `clean.sh` to fully support Windows (Git Bash/MSYS2/WSL), macOS, and Linux.
- Added `scripts/stm32-dev.sh` master interactive terminal dashboard.
- Added `scripts/monitor.py` cross-platform Python serial monitor with auto-dependency installer, ST VCP auto-detection, and log output colorization.

### Changed
- Transitioned compile and debug scripts completely from Windows-only PowerShell (`.ps1`) to universal POSIX Bash (`.sh`) and Python (`.py`).
- Updated `.vscode/tasks.json` in template to execute universal `bash` and `python` commands instead of PowerShell.
- `lib/CMakeLists.txt` now uses `STATIC` library instead of `INTERFACE` to suppress vendor warnings with `-w`, preventing `-Werror` issues in Release builds.
- Migration script generates `STATIC` lib with proper `target_compile_definitions` (STM32xxxxxx, USE_HAL_DRIVER) and `src/bsp/core` include path.
- Migration script now removes unused template MCU cmake files (e.g. `stm32l4-gcc.cmake`) after copying.

### Fixed
- Release build failure caused by vendor HAL warnings promoted to errors by `-Werror` under `-O3` optimization.
- Migration script now generates correct `lib/CMakeLists.txt` that compiles HAL with required defines and include paths.

## [1.0.0]

### Changed
- **Major directory reorganization**: Restructured project into `src/bsp/startup/`, `src/bsp/core/`, `src/bsp/brd/`, `src/utils/` for better separation of concerns.
- Relocated `startup_<chip>.s` to `src/bsp/startup/`.
- Relocated linker script `<chip>_flash.ld` to project root.
- Removed `include/` folder — headers now co-locate with their source files (flat include strategy).
- Removed `mcal/` folder — MCAL files moved to `src/bsp/core/`.
- Updated all `#include` paths in source files to match new layout.
- Updated `CMakeLists.txt` include paths and source lists for new directory structure.
- Updated `cmake/microcontrollers/stm32l4-gcc.cmake` linker script path to root.
- Added `src/bsp/core` to `INCLUDES` in `CMakeLists.txt` so the HAL driver can find `stm32l4xx_hal_conf.h`.
- Moved `system_clock.h` from `src/bsp/brd/` to `src/bsp/core/` to co-locate with `system_clock.c`.
- Moved `error_handler.h` and `log.h` from `src/bsp/brd/` to `src/utils/` to co-locate with their source files.
