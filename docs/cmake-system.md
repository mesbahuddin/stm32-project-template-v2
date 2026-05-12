# CMake Build System Reference

This document describes the CMake build system architecture used in this project.
It is intended as a reference for replicating this setup in other STM32 projects.

## Table of Contents

- [Overview](#overview)
- [File Map](#file-map)
- [Execution Order](#execution-order)
- [File-by-File Reference](#file-by-file-reference)
  - [CMakePresets.json](#cmakepresetsjson)
  - [cmake/toolchains/gcc-arm-none-eabi.cmake](#cmaketoolchainsgcc-arm-none-eabicmake)
  - [CMakeLists.txt (root)](#cmakeliststxt-root)
  - [cmake/microcontrollers/common.cmake](#cmakemicrocontrollerscommoncmake)
  - [cmake/microcontrollers/stm32l4-gcc.cmake](#cmakemicrocontrollersstm32l4-gcccmake)
  - [cmake/tools/clang-tools.cmake](#cmaketoolsclang-toolscmake)
  - [cmake/tools/python.cmake](#cmaketoolspythoncmake)
  - [lib/CMakeLists.txt](#libcmakeliststxt)
- [How to Replicate for a New Project](#how-to-replicate-for-a-new-project)
- [Common Commands](#common-commands)

---

## Overview

The build system is structured around these design principles:

1. **Separation of concerns** — toolchain, MCU-specific flags, build-type
   optimization flags, and code quality tools are each in their own CMake
   module file.
2. **Preset-driven workflow** — users interact through `CMakePresets.json`
   instead of passing flags manually.
3. **Explicit source listing** — no `file(GLOB ...)` is used. All source files
   are listed explicitly for reliable incremental builds.
4. **Integrated code quality** — clang-format, clang-tidy, cppcheck (MISRA C),
   and Doxygen are custom build targets available from the same build system.
5. **Vendor code isolation** — third-party libraries (CMSIS, HAL) are wrapped in
   an `INTERFACE` library to keep them separate from project code.

---

## File Map

```text
project-root/
├── CMakeLists.txt                              # Main build configuration
├── CMakePresets.json                            # Build presets (Debug, Release, etc.)
├── cmake/
│   ├── microcontrollers/
│   │   ├── common.cmake                        # Optimization flags per build type
│   │   └── stm32l4-gcc.cmake                   # MCU-specific flags + linker script
│   ├── toolchains/
│   │   └── gcc-arm-none-eabi.cmake             # Cross-compiler toolchain definition
│   └── tools/
│       ├── clang-tools.cmake                   # clang-format & clang-tidy setup
│       └── python.cmake                        # Python interpreter discovery
├── lib/
│   ├── CMakeLists.txt                          # INTERFACE library for vendor code
│   ├── CMSIS/                                  # ARM CMSIS headers
│   └── STM32L4xx_HAL_Driver/                   # ST HAL driver source + headers
└── script/
    └── clang_format.py                         # Python wrapper for clang-format
```

---

## Execution Order

When you run `cmake --preset Debug`, CMake processes files in this order:

```text
1. CMakePresets.json
   └─ Selects toolchain file, generator (Ninja), build directory, build type

2. cmake/toolchains/gcc-arm-none-eabi.cmake       [loaded by CMake BEFORE project()]
   └─ Defines cross-compiler, objcopy, size tool, executable suffix
   └─ Extracts TOOLCHAIN_SYSROOT from the compiler

3. CMakeLists.txt (root)                           [project() is declared here]
   ├─ include(cmake/tools/clang-tools.cmake)       → finds clang-format, clang-tidy
   ├─ include(cmake/tools/python.cmake)            → finds Python interpreter
   ├─ include(cmake/microcontrollers/common.cmake) → sets -Og/-O3/-Os/-O2 per build type
   ├─ include(cmake/microcontrollers/stm32l4-gcc.cmake) → sets MCU flags, linker script
   ├─ add_subdirectory(lib)                        → processes lib/CMakeLists.txt
   │   └─ lib/CMakeLists.txt                       → creates INTERFACE library
   ├─ Defines sources, includes, defines
   ├─ Creates executable target
   ├─ Adds post-build commands (size, .bin, .hex)
   └─ Adds custom targets (format, tidy, cppcheck, doxygen)
```

> **Key point**: The toolchain file runs *before* `project()`. This is a CMake
> requirement for cross-compilation — it must know the compiler before it
> tries to test it.

---

## File-by-File Reference

### CMakePresets.json

**Purpose**: Provides named build configurations so users don't need to
remember compiler flags.

**Key structure**:

```json
{
    "version": 3,
    "configurePresets": [
        {
            "name": "default",
            "hidden": true,
            "generator": "Ninja",
            "binaryDir": "${sourceDir}/build/${presetName}",
            "toolchainFile": "${sourceDir}/cmake/toolchains/gcc-arm-none-eabi.cmake"
        },
        {
            "name": "Debug",
            "inherits": "default",
            "cacheVariables": { "CMAKE_BUILD_TYPE": "Debug" }
        }
    ],
    "buildPresets": [
        {
            "name": "Debug",
            "configurePreset": "Debug"
        }
    ]
}
```

**Variables to change for a new project**:

| Variable | What to change |
|----------|---------------|
| `generator` | Keep `Ninja` (or change to `Unix Makefiles` if preferred) |
| `toolchainFile` | Path to your toolchain file (keep the same if using GCC ARM) |
| `binaryDir` | Output directory pattern (default: `build/<presetName>/`) |

**Available presets**:

| Preset | Build Type | Optimization |
|--------|-----------|-------------|
| `Debug` | Debug | `-Og -g` |
| `Release` | Release | `-O3` |
| `MinSizeRel` | MinSizeRel | `-Os` + LTO |
| `RelWithDebInfo` | RelWithDebInfo | `-O2 -g` |

---

### cmake/toolchains/gcc-arm-none-eabi.cmake

**Purpose**: Tells CMake how to cross-compile for ARM bare-metal targets.

**What it does**:

1. Sets `CMAKE_SYSTEM_NAME` to `Generic` (bare-metal, no OS).
2. Sets `CMAKE_SYSTEM_PROCESSOR` to `arm`.
3. Finds cross-compiler tools (`arm-none-eabi-gcc`, `arm-none-eabi-objcopy`,
   etc.) on PATH or at a hardcoded fallback path.
4. Sets executable suffix to `.elf`.
5. Sets `CMAKE_TRY_COMPILE_TARGET_TYPE` to `STATIC_LIBRARY` to prevent
   CMake's compiler test from failing (no OS = can't run executables).
6. Extracts and normalizes `TOOLCHAIN_SYSROOT` by running
   `arm-none-eabi-gcc -print-sysroot`. This is later used by clang-tidy.

**Variables to change for a new project**:

| Variable | What to change |
|----------|---------------|
| `CROSS_COMPILER_BIN_PATH` | Path to your GCC ARM installation (if not on PATH) |
| `CROSS_COMPILER_PREFIX` | Keep `arm-none-eabi` for Cortex-M targets |

**Key variables it exports**:

| Variable | Used by |
|----------|---------|
| `CMAKE_C_COMPILER` | CMake (compilation) |
| `CMAKE_OBJCOPY` | Root CMakeLists.txt (post-build .bin/.hex generation) |
| `CMAKE_SIZE` | Root CMakeLists.txt (post-build size report) |
| `TOOLCHAIN_SYSROOT` | clang-tools.cmake (clang-tidy `--sysroot`) |

---

### CMakeLists.txt (root)

**Purpose**: Main build configuration — ties everything together.

**Sections breakdown**:

#### Section 1: Project Setup (lines 1–21)

> **Note**: When forking this project, change `stm32-project-template` to your project name.

```cmake
cmake_minimum_required(VERSION 3.22)
project(stm32-project-template)
enable_language(C CXX ASM)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)   # Generates compile_commands.json
set(CMAKE_C_STANDARD              11)
set(CMAKE_C_STANDARD_REQUIRED     ON)
set(CMAKE_C_EXTENSIONS            ON)   # Allow GNU extensions
```

- `CMAKE_EXPORT_COMPILE_COMMANDS ON` generates `compile_commands.json` in the
  build directory. This file is consumed by clangd (IDE IntelliSense),
  clang-tidy, and cppcheck.
- `enable_language(ASM)` is required for the startup `.s` file.

#### Section 2: Include Modules (lines 28–34)

```cmake
include(cmake/tools/clang-tools.cmake)
include(cmake/tools/python.cmake)
include(cmake/microcontrollers/common.cmake)
include(cmake/microcontrollers/stm32l4-gcc.cmake)
```

Order matters: `clang-tools.cmake` needs `TOOLCHAIN_SYSROOT` from the
toolchain file (already loaded). MCU files must come after `common.cmake`
because `stm32l4-gcc.cmake` appends to flags set by `common.cmake`.

#### Section 3: Vendor Library (line 37)

```cmake
add_subdirectory(lib)
```

Processes `lib/CMakeLists.txt`, which creates the `lib` INTERFACE target.

#### Section 4: Project Defines (lines 40–45)

```cmake
set(DEFINES
    STM32L496xx                                   # Chip selection
    USE_HAL_DRIVER                                # Enable HAL
    USE_FULL_ASSERT                               # Enable assert_failed()
    $<IF:$<CONFIG:Debug>,DEBUG,NDEBUG>            # DEBUG or NDEBUG
)
```

- `STM32L496xx` — change this to your target chip (e.g., `STM32H750xx`).
- The generator expression `$<IF:$<CONFIG:Debug>,DEBUG,NDEBUG>` defines
  `DEBUG` for Debug builds and `NDEBUG` for all other build types.

#### Section 5: Source and Include Lists (lines 48–70)

```cmake
set(INCLUDES
    ${PROJECT_SOURCE_DIR}/mcal/st-stm32l4/include
    ${PROJECT_SOURCE_DIR}/include
)

set(SOURCES_ASM
    ${PROJECT_SOURCE_DIR}/mcal/st-stm32l4/gcc-arm/startup_stm32l496xx.s
)

set(SOURCES_C
    ${PROJECT_SOURCE_DIR}/mcal/st-stm32l4/source/gpio.c
    ${PROJECT_SOURCE_DIR}/source/main.c
    # ... all other .c files
)
```

- All files use absolute paths via `${PROJECT_SOURCE_DIR}`.
- No `file(GLOB ...)` — explicit listing ensures CMake detects when files are
  added/removed.

#### Section 6: Executable Target (lines 73–94)

```cmake
add_executable(${CMAKE_PROJECT_NAME})

target_compile_definitions(${CMAKE_PROJECT_NAME} PRIVATE ${DEFINES})
target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE ${INCLUDES})
target_sources(${CMAKE_PROJECT_NAME} PRIVATE ${SOURCES_ASM} ${SOURCES_C})
target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE lib)
```

- `PRIVATE` means these definitions/includes/sources only apply to this
  target (not to dependents). This is correct for an executable.
- `target_link_libraries(... lib)` pulls in the INTERFACE library's sources
  and include paths.

#### Section 7: Post-Build Commands (lines 97–111)

```cmake
# Print size information
add_custom_command(TARGET ${CMAKE_PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_SIZE} $<TARGET_FILE:${CMAKE_PROJECT_NAME}>
)

# Generate .bin
add_custom_command(TARGET ${CMAKE_PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_OBJCOPY} -O binary
            $<TARGET_FILE:${CMAKE_PROJECT_NAME}>
            ${CMAKE_PROJECT_NAME}.bin
)

# Generate .hex
add_custom_command(TARGET ${CMAKE_PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_OBJCOPY} -O ihex
            $<TARGET_FILE:${CMAKE_PROJECT_NAME}>
            ${CMAKE_PROJECT_NAME}.hex
)
```

These run automatically after every successful build. `$<TARGET_FILE:...>`
resolves to the output `.elf` path.

#### Section 8: Custom Quality Targets (lines 113–188)

**check-format / run-format**: Run `script/clang_format.py` via Python.
The `--check` flag makes it report-only (non-zero exit on errors).

**tidy**: Runs clang-tidy. Requires transforming the defines and includes
into compiler-style flags:

```cmake
list(TRANSFORM CLANG_TIDY_DEFINES PREPEND -D)          # FOO → -DFOO
list(TRANSFORM CLANG_TIDY_INCLUDES PREPEND -I)          # path/ → -Ipath/
list(TRANSFORM CLANG_TIDY_SYSTEM_INCLUDES PREPEND -isystem)  # lib/ → -isystem lib/
```

The `--` separator tells clang-tidy that everything after it is a compiler
flag, not a clang-tidy flag.

**cppcheck**: Uses the `compile_commands.json` generated during configure.
Runs MISRA C 2012 checks via the `--addon` flag pointing to `lint/misra.json`.

**doxygen**: Runs Doxygen using the configuration in `docs/doxygen/Doxyfile`.

---

### cmake/microcontrollers/common.cmake

**Purpose**: Defines optimization flags for each build type. These are
MCU-independent and can be reused across any ARM project.

**What it sets**:

| Build Type | ASM Flags | C Flags | C++ Flags |
|-----------|-----------|---------|-----------|
| Debug | `-Og -g` | `-Og -g` | `-Og -g` |
| Release | `-O3` | `-O3` | `-O3` |
| MinSizeRel | `-Os` | `-Os` | `-Os` |
| RelWithDebInfo | `-O2 -g` | `-O2 -g` | `-O2 -g` |

**How it works**: Uses `CMAKE_<LANG>_FLAGS_<CONFIG>` variables, which CMake
automatically appends to the compiler command based on the active build type.

**Variables to change for a new project**: Generally none — these are standard
optimization levels.

---

### cmake/microcontrollers/stm32l4-gcc.cmake

**Purpose**: MCU-specific compiler and linker flags. **This is the main file
you replace when targeting a different chip.**

**What it defines**:

| Category | Flags | Purpose |
|----------|-------|---------|
| **Linker script** | `-T<path>` | Points to the `.ld` file with FLASH/SRAM memory layout |
| **MCU flags** | `-mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard` | CPU core, instruction set, FPU configuration |
| **Warning flags** | `-Wall -Werror -Wextra -pedantic` | Strict warning policy |
| **Section flags** | `-fdata-sections -ffunction-sections` | Enable dead code elimination |
| **Dependency flags** | `-MMD -MP` | Generate `.d` files for incremental builds |
| **Linker specs** | `-specs=nano.specs -specs=nosys.specs` | Use minimal C library (newlib-nano) |
| **Linker GC** | `-Wl,--gc-sections` | Remove unused sections (needs `-ffunction-sections`) |
| **Linker output** | `-Wl,-Map=<name>.map,--cref -Wl,--print-memory-usage` | Generate map file and print FLASH/RAM usage |
| **C++ specific** | `-fno-rtti -fno-exceptions -fno-threadsafe-statics` | Disable C++ features unsuitable for embedded |
| **LTO** | `-flto` (MinSizeRel only) | Link-time optimization for minimum size |

**How flags are assembled**: Each category is a CMake list. They're joined
into single strings and assigned to `CMAKE_<LANG>_FLAGS`:

```cmake
set(CMAKE_C_FLAGS ${MCU_FLAGS} ${C_FLAGS} ${COMMON_FLAGS})
list(JOIN CMAKE_C_FLAGS " " CMAKE_C_FLAGS)
```

**Variables to change for a new project**:

| Variable | What to change |
|----------|---------------|
| `LINKER_SCRIPT` | Path to your `.ld` file |
| `-mcpu=` | Your CPU core (e.g., `cortex-m7`, `cortex-m33`) |
| `-mfpu=` | Your FPU type (e.g., `fpv5-d16`, or remove for no FPU) |
| `-mfloat-abi=` | `hard`, `soft`, or `softfp` |

---

### cmake/tools/clang-tools.cmake

**Purpose**: Locates clang-format and clang-tidy and configures their
arguments.

**What it does**:

1. Optionally prepends a hardcoded LLVM path to `CMAKE_PREFIX_PATH`.
2. Finds `clang-format` and `clang-tidy` executables via `find_program()`.
3. Sets clang-tidy arguments:

```cmake
set(CLANG_TIDY_ARGS
    -format-style=file          # Use .clang-format for formatting checks
)

set(CLANG_TIDY_EXTRA_ARGS
    -Wall -Wextra -Werror -pedantic
    -Weverything                # ALL warnings (very strict)
    --target=arm-none-eabi      # Cross-compilation target triple
    --sysroot=${TOOLCHAIN_SYSROOT}  # Point to GCC ARM's include directory
)
```

**Why `--sysroot` is needed**: clang-tidy uses the Clang frontend internally.
Without `--sysroot`, it can't find ARM-specific standard headers like
`<stdint.h>`, `<stdlib.h>`, etc.

**Variables to change for a new project**:

| Variable | What to change |
|----------|---------------|
| `CLANG_TOOLS_BIN_PATH` | Path to your LLVM/Clang installation (if not on PATH) |
| `--target=` | Keep `arm-none-eabi` for Cortex-M |

---

### cmake/tools/python.cmake

**Purpose**: Finds the Python interpreter, preferring a virtualenv if one is
active.

**How it works**:

```cmake
find_package(Python)

# If virtualenv is active, prefer it
find_program(VIRTUALENV virtualenv)
if(VIRTUALENV AND DEFINED ENV{VIRTUAL_ENV})
    set(Python_FIND_VIRTUALENV FIRST)
    unset(Python_EXECUTABLE)
    find_package(Python)
endif()
```

The resulting `Python_EXECUTABLE` variable is used by the `check-format` and
`run-format` targets in the root `CMakeLists.txt`.

**Variables to change for a new project**: None.

---

### lib/CMakeLists.txt

**Purpose**: Wraps third-party vendor code (CMSIS + HAL) as an INTERFACE
library.

**What it does**:

```cmake
add_library(lib INTERFACE)

target_include_directories(lib INTERFACE
    CMSIS/Device/ST/STM32L4xx/Include
    CMSIS/Include
    STM32L4xx_HAL_Driver/Inc
    STM32L4xx_HAL_Driver/Inc/Legacy
)

target_sources(lib INTERFACE
    STM32L4xx_HAL_Driver/Src/stm32l4xx_hal_gpio.c
    STM32L4xx_HAL_Driver/Src/stm32l4xx_hal_rcc.c
    # ... all HAL source files needed
)
```

**Why INTERFACE**: An INTERFACE library has no compiled output of its own.
Its sources, includes, and defines are injected into any target that links
against it. This means the HAL `.c` files are compiled as part of the main
executable, using the same compiler flags.

**Clang-tidy system includes export**: The file also exports HAL/CMSIS
include paths to the parent scope for clang-tidy to use with `-isystem`,
which suppresses all warnings from vendor headers:

```cmake
set(CLANG_TIDY_SYSTEM_INCLUDES
    ${CLANG_TIDY_SYSTEM_INCLUDES}
    ${LIB_CLANG_TIDY_SYSTEM_INCLUDES}
    PARENT_SCOPE
)
```

**Variables to change for a new project**:

| Variable | What to change |
|----------|---------------|
| Include paths | Update for your chip family's CMSIS/HAL structure |
| Source list | Include only the HAL modules your project uses |

---

## How to Replicate for a New Project

### Step 1: Copy the build system skeleton

```text
new-project/
├── CMakeLists.txt                  ← copy and modify
├── CMakePresets.json               ← copy as-is (usually no changes needed)
├── cmake/
│   ├── microcontrollers/
│   │   ├── common.cmake            ← copy as-is
│   │   └── <your-mcu>-gcc.cmake    ← copy stm32l4-gcc.cmake and modify
│   ├── toolchains/
│   │   └── gcc-arm-none-eabi.cmake ← copy as-is (update path if needed)
│   └── tools/
│       ├── clang-tools.cmake       ← copy as-is (update path if needed)
│       └── python.cmake            ← copy as-is
├── lib/
│   ├── CMakeLists.txt              ← copy and modify for your vendor libs
│   ├── CMSIS/                      ← your chip's CMSIS
│   └── <Vendor>_HAL_Driver/        ← your chip's HAL
├── script/
│   └── clang_format.py             ← copy as-is
├── .clang-format                   ← copy as-is (or customize)
├── .clang-tidy                     ← copy as-is (or customize)
└── lint/
    ├── misra.json                  ← copy as-is
    └── suppressions.txt            ← start fresh for your project
```

### Step 2: Modify the MCU-specific cmake file

In `cmake/microcontrollers/<your-mcu>-gcc.cmake`, update:

```cmake
# 1. Linker script path
set(LINKER_SCRIPT ${PROJECT_SOURCE_DIR}/mcal/<your-mcu>/gcc-arm/<your-chip>_flash.ld)

# 2. CPU core flags
set(MCU_FLAGS
    "-mcpu=cortex-m7"           # Your core (cortex-m0, m3, m4, m7, m33, etc.)
    "-mthumb"
    "-mfpu=fpv5-d16"            # Your FPU (or remove for no FPU)
    "-mfloat-abi=hard"          # hard/soft/softfp
)
```

### Step 3: Modify root CMakeLists.txt

Update these sections:

```cmake
# 1. Project name
project(your-project-name)

# 2. Include your MCU file instead of stm32l4
include(cmake/microcontrollers/<your-mcu>-gcc.cmake)

# 3. Chip define
set(DEFINES
    YOUR_CHIP_DEFINE            # e.g., STM32H750xx, STM32F407xx
    USE_HAL_DRIVER
    ...
)

# 4. Include paths
set(INCLUDES
    ${PROJECT_SOURCE_DIR}/mcal/<your-mcu>/include
    ${PROJECT_SOURCE_DIR}/include
)

# 5. Source files — list all your .s and .c files
set(SOURCES_ASM ...)
set(SOURCES_C ...)
```

### Step 4: Update lib/CMakeLists.txt

List the CMSIS and HAL include paths and source files for your chip family.
Only include the HAL modules you actually use.

### Step 5: Verify

```bash
cmake --preset Debug
cmake --build --preset Debug
```

---

## Common Commands

| Command | Description |
|---------|-------------|
| `cmake --list-presets` | List all available presets |
| `cmake --preset Debug` | Configure for Debug build |
| `cmake --build --preset Debug` | Build the firmware |
| `cmake --build --preset Debug --target clean` | Clean build artifacts |
| `cmake --build --preset Debug --target check-format` | Check code formatting |
| `cmake --build --preset Debug --target run-format` | Auto-format code |
| `cmake --build --preset Debug --target tidy` | Run clang-tidy analysis |
| `cmake --build --preset Debug --target cppcheck` | Run cppcheck + MISRA C |
| `cmake --build --preset Debug --target doxygen` | Generate documentation |
