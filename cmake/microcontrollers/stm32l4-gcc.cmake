# Set linker script
set(LINKER_SCRIPT
    ${PROJECT_SOURCE_DIR}/stm32l496xx_flash.ld
)
if(NOT EXISTS ${LINKER_SCRIPT})
    message(FATAL_ERROR "Linker script \"${LINKER_SCRIPT}\" does not exist!")
endif()

# Set microcontroller-specific compiler flags
set(MCU_FLAGS
    "-mcpu=cortex-m4"
    "-mthumb"
    "-mfpu=fpv4-sp-d16"
    "-mfloat-abi=hard"
)

# Set assembler flags
set(ASM_FLAGS
    "-x assembler-with-cpp"
)

# Set C compiler flags
set(C_FLAGS
    "-MMD"
    "-MP"
)

# Set CXX compiler flags
set(CXX_FLAGS
    "-fno-rtti"
    "-fno-exceptions"
    "-fno-threadsafe-statics"
)

# Set common compiler flags
set(COMMON_FLAGS
    "-Wall"
    "-Werror"
    "-Wextra"
    "-pedantic"
    "-fdata-sections"
    "-ffunction-sections"
)

# Set linker flags
set(LINKER_FLAGS
    "-T${LINKER_SCRIPT}"
    "-specs=nano.specs"
    "-specs=nosys.specs"
    "-Wl,-Map=${CMAKE_PROJECT_NAME}.map,--cref"
    "-Wl,--gc-sections"
    "-Wl,--start-group -lc -lm -lnosys -Wl,--end-group"
    "-Wl,--print-memory-usage"
)

# Build type specific optimization flags with LTO support
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    # Debug: No optimization, full debug info
    list(APPEND C_FLAGS "-O0" "-g3")
    list(APPEND CXX_FLAGS "-O0" "-g3")
    # No LTO for Debug (slower compilation, debug symbols preferred)
elseif(CMAKE_BUILD_TYPE STREQUAL "Release")
    # Release: Maximum optimization, no debug info
    list(APPEND C_FLAGS "-O3")
    list(APPEND CXX_FLAGS "-O3")
    # Enable LTO for Release (performance optimization)
    list(APPEND C_FLAGS "-flto")
    list(APPEND CXX_FLAGS "-flto")
    list(APPEND LINKER_FLAGS "-flto")
    set_property(GLOBAL PROPERTY LTO_ENABLED TRUE)
elseif(CMAKE_BUILD_TYPE STREQUAL "MinSizeRel")
    # MinSizeRel: Optimize for size, no debug info
    list(APPEND C_FLAGS "-Os")
    list(APPEND CXX_FLAGS "-Os")
    # Enable LTO for MinSizeRel (critical for size reduction)
    list(APPEND C_FLAGS "-flto")
    list(APPEND CXX_FLAGS "-flto")
    list(APPEND LINKER_FLAGS "-flto")
    set_property(GLOBAL PROPERTY LTO_ENABLED TRUE)
elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
    # RelWithDebInfo: Balanced optimization with debug info
    list(APPEND C_FLAGS "-O2" "-g")
    list(APPEND CXX_FLAGS "-O2" "-g")
    # No LTO for RelWithDebInfo (debug symbols + LTO can conflict)
endif()

# For all languages:
# Specify the compiler flags and join all flags into one string
set(CMAKE_ASM_FLAGS ${ASM_FLAGS} ${MCU_FLAGS} ${C_FLAGS} ${COMMON_FLAGS})
list(JOIN CMAKE_ASM_FLAGS " " CMAKE_ASM_FLAGS)

set(CMAKE_C_FLAGS   ${MCU_FLAGS} ${C_FLAGS} ${COMMON_FLAGS})
list(JOIN CMAKE_C_FLAGS " " CMAKE_C_FLAGS)

set(CMAKE_CXX_FLAGS ${MCU_FLAGS} ${C_FLAGS} ${CXX_FLAGS} ${COMMON_FLAGS})
list(JOIN CMAKE_CXX_FLAGS " " CMAKE_CXX_FLAGS)

# Specify the linker flags and join all flags into one string
set(CMAKE_EXE_LINKER_FLAGS  ${MCU_FLAGS} ${LINKER_FLAGS})
list(JOIN CMAKE_EXE_LINKER_FLAGS " " CMAKE_EXE_LINKER_FLAGS)
