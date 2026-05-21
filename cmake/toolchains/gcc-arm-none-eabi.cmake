set(CMAKE_SYSTEM_NAME               Generic)
set(CMAKE_SYSTEM_VERSION            1)
set(CMAKE_SYSTEM_PROCESSOR          arm)

set(CMAKE_C_COMPILER_FORCED         TRUE)
set(CMAKE_CXX_COMPILER_FORCED       TRUE)

set(CROSS_COMPILER_PREFIX           arm-none-eabi)

# --- Automatic toolchain discovery ---
# Priority:
#   1. CMake variable  -DARM_GCC_PATH=/path/to/bin   (highest)
#   2. Environment var ARM_GCC_PATH
#   3. System PATH

if(NOT ARM_GCC_PATH)
    set(ARM_GCC_PATH "" CACHE FILEPATH "Path to arm-none-eabi-gcc bin/ directory")
endif()

if(ARM_GCC_PATH)
    message(STATUS "Using ARM GCC from ARM_GCC_PATH: ${ARM_GCC_PATH}")
    list(APPEND CMAKE_PREFIX_PATH ${ARM_GCC_PATH})
elseif(DEFINED ENV{ARM_GCC_PATH})
    message(STATUS "Using ARM GCC from ARM_GCC_PATH env: $ENV{ARM_GCC_PATH}")
    list(APPEND CMAKE_PREFIX_PATH "$ENV{ARM_GCC_PATH}")
endif()

# Find the compiler and tools (searches PATH + any CMAKE_PREFIX_PATH)
find_program(CMAKE_C_COMPILER       ${CROSS_COMPILER_PREFIX}-gcc)
find_program(CMAKE_CXX_COMPILER     ${CROSS_COMPILER_PREFIX}-g++)
find_program(CMAKE_ASM_COMPILER     ${CROSS_COMPILER_PREFIX}-gcc)
find_program(CMAKE_LINKER           ${CROSS_COMPILER_PREFIX}-g++)
find_program(CMAKE_OBJCOPY          ${CROSS_COMPILER_PREFIX}-objcopy)
find_program(CMAKE_OBJDUMP          ${CROSS_COMPILER_PREFIX}-objdump)
find_program(CMAKE_SIZE             ${CROSS_COMPILER_PREFIX}-size)

# Validate that the compiler was found
if(NOT CMAKE_C_COMPILER)
    message(FATAL_ERROR
        "ARM GCC cross-compiler not found!\n"
        "Ensure 'arm-none-eabi-gcc' is in your PATH, or set ARM_GCC_PATH:\n"
        "  cmake -DARM_GCC_PATH=/path/to/bin ..\n"
        "  export ARM_GCC_PATH=/path/to/bin"
    )
endif()

set(CMAKE_EXECUTABLE_SUFFIX_ASM     ".elf")
set(CMAKE_EXECUTABLE_SUFFIX_C       ".elf")
set(CMAKE_EXECUTABLE_SUFFIX_CXX     ".elf")

set(CMAKE_TRY_COMPILE_TARGET_TYPE   STATIC_LIBRARY)

# Export the normalized toolchain sysroot path (required for clang-tidy)
execute_process(
    COMMAND ${CMAKE_C_COMPILER} -print-sysroot
    OUTPUT_VARIABLE TOOLCHAIN_SYSROOT
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
cmake_path(SET TOOLCHAIN_SYSROOT NORMALIZE ${TOOLCHAIN_SYSROOT})
