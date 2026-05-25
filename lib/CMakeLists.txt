cmake_minimum_required(VERSION 3.22)

project(lib)
enable_language(C CXX ASM)

add_library(lib STATIC)

# Suppress all warnings for vendor code
target_compile_options(lib PRIVATE "-w")

target_compile_definitions(lib PRIVATE
    STM32L496xx
    USE_HAL_DRIVER
)

# Set include paths
set(INCLUDES_LIB_CMSIS
    CMSIS/Device/ST/STM32L4xx/Include
    CMSIS/Include
)

set(INCLUDES_LIB_STM32L4XX_HAL_DRIVER
    STM32L4xx_HAL_Driver/Inc
    STM32L4xx_HAL_Driver/Inc/Legacy
)

target_include_directories(lib PUBLIC
    ${INCLUDES_LIB_CMSIS}
    ${INCLUDES_LIB_STM32L4XX_HAL_DRIVER}
    ${CMAKE_SOURCE_DIR}/src/bsp/core
)

# Set source files
set(SOURCES_LIB_STM32L4XX_HAL_Driver
    STM32L4xx_HAL_Driver/Src/stm32l4xx_hal_cortex.c
    STM32L4xx_HAL_Driver/Src/stm32l4xx_hal_dma.c
    STM32L4xx_HAL_Driver/Src/stm32l4xx_hal_exti.c
    STM32L4xx_HAL_Driver/Src/stm32l4xx_hal_flash_ex.c
    STM32L4xx_HAL_Driver/Src/stm32l4xx_hal_flash_ramfunc.c
    STM32L4xx_HAL_Driver/Src/stm32l4xx_hal_flash.c
    STM32L4xx_HAL_Driver/Src/stm32l4xx_hal_gpio.c
    STM32L4xx_HAL_Driver/Src/stm32l4xx_hal_pwr_ex.c
    STM32L4xx_HAL_Driver/Src/stm32l4xx_hal_pwr.c
    STM32L4xx_HAL_Driver/Src/stm32l4xx_hal_rcc_ex.c
    STM32L4xx_HAL_Driver/Src/stm32l4xx_hal_rcc.c
    STM32L4xx_HAL_Driver/Src/stm32l4xx_hal_uart_ex.c
    STM32L4xx_HAL_Driver/Src/stm32l4xx_hal_uart.c
    STM32L4xx_HAL_Driver/Src/stm32l4xx_hal.c
)

target_sources(lib PRIVATE
    ${SOURCES_LIB_STM32L4XX_HAL_Driver}
)

# Export include paths for clang-tidy as system includes
set(LIB_CLANG_TIDY_SYSTEM_INCLUDES
    ${INCLUDES_LIB_CMSIS}
    ${INCLUDES_LIB_STM32L4XX_HAL_DRIVER}
)

# Prepend the include list with the path of the current directory
list(TRANSFORM LIB_CLANG_TIDY_SYSTEM_INCLUDES
     PREPEND ${CMAKE_CURRENT_SOURCE_DIR}/
)

# Export the collected system includes to the clang-tidy system includes list
set(CLANG_TIDY_SYSTEM_INCLUDES
    ${CLANG_TIDY_SYSTEM_INCLUDES}
    ${LIB_CLANG_TIDY_SYSTEM_INCLUDES}
    PARENT_SCOPE
)
