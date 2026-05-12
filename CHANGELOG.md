# Changelog

## [Unreleased]

### Added
- Fork of the original STM32 Project Template by Akos Pasztor
- Added Mesbah Uddin as co-author

## [1.0.0]

### Changed
- **Major directory reorganization**: Restructured project into `src/bsp/core/`, `src/bsp/brd/`, `src/utils/` for better separation of concerns between MCU core peripherals, board-specific components, and cross-cutting utilities.
- Removed `include/` folder — headers now co-locate with their source files (flat include strategy).
- Removed `mcal/` folder — MCAL files moved to `src/bsp/core/`.
- Updated all `#include` paths in source files to match new layout.
- Updated `CMakeLists.txt` include paths and source lists for new directory structure.
- Updated `cmake/microcontrollers/stm32l4-gcc.cmake` linker script path.
- Added `src/bsp/core` to `INCLUDES` in `CMakeLists.txt` so the HAL driver can find `stm32l4xx_hal_conf.h`.
- Moved `system_clock.h` from `src/bsp/brd/` to `src/bsp/core/` to co-locate with `system_clock.c`.
- Moved `error_handler.h` and `log.h` from `src/bsp/brd/` to `src/utils/` to co-locate with their source files.
