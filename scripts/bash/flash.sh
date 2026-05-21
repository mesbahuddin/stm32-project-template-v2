#!/usr/bin/env bash
# ==============================================================================
# Cross-Platform STM32 Flashing Tool
# Flashes built firmware binaries to STM32 target MCU via J-Link, ST-Link, or DFU.
# Works on Windows (Git Bash/MSYS2), macOS, and Linux.
# ==============================================================================

# Script setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/build_config.sh"

# Terminal ANSI Color Codes
CYAN='\033[96m'
GREEN='\033[92m'
YELLOW='\033[93m'
RED='\033[91m'
WHITE='\033[97m'
GRAY='\033[90m'
RESET='\033[0m'

# Default options
INTERFACE="JLink"
FILE=""
DEVICE="STM32L496ZG"
VERIFY=false
RESET_MCU=true

show_banner() {
    echo -e "${CYAN}======================================${RESET}"
    echo -e "${CYAN}          STM32 Flashing Tool         ${RESET}"
    echo -e "${CYAN}======================================${RESET}"
}

show_usage() {
    show_banner
    echo -e "Usage: $0 [options]"
    echo
    echo -e "${YELLOW}Options:${RESET}"
    echo -e "  -i, --interface, -Interface <type>   Programming interface: JLink (default), STLink, DFU"
    echo -e "  -f, --file, -File <path>             Path to firmware file (.hex, .bin, or .elf)"
    echo -e "                                       (If omitted, auto-detects from build directory)"
    echo -e "  -d, --device, -Device <mcu>          Target microcontroller device name (default: STM32L496ZG)"
    echo -e "  -v, --verify, -Verify                Verify written firmware after programming"
    echo -e "  -r, --reset, -Reset <bool>           Reset MCU after programming (true/false, default: true)"
    echo -e "  -h, --help                           Show this help menu"
    echo
    echo -e "${YELLOW}Examples:${RESET}"
    echo -e "  $0                                   # Auto-detect file, use default J-Link"
    echo -e "  $0 -i STLink                         # Use ST-Link SWD mode"
    echo -e "  $0 -i DFU                            # Use USB DFU mode"
    echo -e "  $0 -f build/Debug/firmware.hex       # Flash specific file"
    echo -e "  $0 -i JLink -v                       # Flash with verification"
    echo
    exit 1
}

# Find J-Link executable path
find_jlink() {
    if command -v JLink.exe >/dev/null 2>&1; then
        echo "JLink.exe"
    elif command -v JLinkExe >/dev/null 2>&1; then
        echo "JLinkExe"
    else
        # Try standard paths based on OS
        if [ "$OS" = "Windows_NT" ]; then
            for path in "C:/Program Files/SEGGER/JLink/JLink.exe" \
                        "C:/Program Files (x86)/SEGGER/JLink/JLink.exe"; do
                if [ -f "$path" ]; then
                    echo "$path"
                    return 0
                fi
            done
        else
            for path in "/usr/local/bin/JLinkExe" \
                        "/usr/bin/JLinkExe" \
                        "/opt/SEGGER/JLink/JLinkExe"; do
                if [ -f "$path" ]; then
                    echo "$path"
                    return 0
                fi
            done
        fi
        echo ""
    fi
}

# Find ST-Link / STM32CubeProgrammer CLI path
find_cubeprog() {
    if command -v STM32_Programmer_CLI.exe >/dev/null 2>&1; then
        echo "STM32_Programmer_CLI.exe"
    elif command -v STM32_Programmer_CLI >/dev/null 2>&1; then
        echo "STM32_Programmer_CLI"
    else
        # Try standard paths based on OS
        if [ "$OS" = "Windows_NT" ]; then
            # Search STMicroelectronics standard installation path or ST toolchains
            for path in "C:/Program Files/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI.exe" \
                        "C:/ST/STM32CubeCLT/STM32CubeProgrammer/bin/STM32_Programmer_CLI.exe"; do
                if [ -f "$path" ]; then
                    echo "$path"
                    return 0
                fi
            done
            # Wildcard search for versioned STM32CubeCLT directories
            local clt_path=$(find /c/ST -maxdepth 3 -name "STM32_Programmer_CLI.exe" 2>/dev/null | head -n 1)
            if [ -n "$clt_path" ]; then
                echo "$clt_path"
                return 0
            fi
        else
            for path in "/usr/local/bin/STM32_Programmer_CLI" \
                        "/usr/bin/STM32_Programmer_CLI" \
                        "/opt/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI" \
                        "/Applications/STMicroelectronics/STM32CubeProgrammer.app/Contents/MacOs/bin/STM32_Programmer_CLI" \
                        "/Applications/STM32CubeProgrammer.app/Contents/MacOs/bin/STM32_Programmer_CLI"; do
                if [ -f "$path" ]; then
                    echo "$path"
                    return 0
                fi
            done
        fi
        echo ""
    fi
}

# Parse parameters
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            show_usage
            ;;
        -i|--interface|-Interface)
            if [ -z "$2" ]; then
                echo -e "${RED}ERROR: Option '$1' requires an argument.${RESET}"
                exit 1
            fi
            INTERFACE="$2"
            shift 2
            ;;
        -f|--file|-File)
            if [ -z "$2" ]; then
                echo -e "${RED}ERROR: Option '$1' requires an argument.${RESET}"
                exit 1
            fi
            FILE="$2"
            shift 2
            ;;
        -d|--device|-Device)
            if [ -z "$2" ]; then
                echo -e "${RED}ERROR: Option '$1' requires an argument.${RESET}"
                exit 1
            fi
            DEVICE="$2"
            shift 2
            ;;
        -v|--verify|-Verify)
            VERIFY=true
            shift
            ;;
        -r|--reset|-Reset)
            if [ -z "$2" ]; then
                echo -e "${RED}ERROR: Option '$1' requires an argument (true/false).${RESET}"
                exit 1
            fi
            if [ "$2" = "false" ]; then
                RESET_MCU=false
            else
                RESET_MCU=true
            fi
            shift 2
            ;;
        *)
            echo -e "${RED}ERROR: Unknown option '$1'.${RESET}"
            show_usage
            ;;
    esac
done

show_banner

# Auto-detect Build Type configuration
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    BUILD_TYPE="Debug"
fi

# Find file if not specified
if [ -z "$FILE" ]; then
    BUILD_DIR="${WORKSPACE_DIR}/build/${BUILD_TYPE}"
    echo -e "Searching for binary in: ${WHITE}${BUILD_DIR}${RESET}..."
    
    # Priority: .hex file, then .bin file, then .elf file
    if [ -d "$BUILD_DIR" ]; then
        # Search files matching the build configuration output
        FILE=$(find "$BUILD_DIR" -maxdepth 1 -name "*.hex" ! -name "CMake*" 2>/dev/null | head -n 1)
        if [ -z "$FILE" ]; then
            FILE=$(find "$BUILD_DIR" -maxdepth 1 -name "*.bin" ! -name "CMake*" 2>/dev/null | head -n 1)
        fi
        if [ -z "$FILE" ]; then
            FILE=$(find "$BUILD_DIR" -maxdepth 1 -name "*.elf" ! -name "CMake*" 2>/dev/null | head -n 1)
        fi
    fi
fi

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    echo -e "${RED}ERROR: No valid firmware file could be found!${RESET}"
    echo -e "Please compile the project first using ${WHITE}build.sh${RESET} or specify a file via ${WHITE}-f <file>${RESET}."
    exit 1
fi

# Normalize path representation (Git Bash requires special care for tool execution)
case "$OS" in
    Windows_NT)
        # Convert path to Windows format if it is absolute or contains standard forward slashes
        if [[ "$FILE" =~ ^/ ]]; then
            FILE_WIN=$(cygpath -w "$FILE")
        else
            FILE_WIN=$(echo "$FILE" | tr '/' '\\')
        fi
        ;;
    *)
        FILE_WIN="$FILE"
        ;;
esac

echo -e "Target Interface: ${GREEN}${INTERFACE}${RESET}"
echo -e "Firmware File:    ${WHITE}${FILE_WIN}${RESET}"
echo -e "MCU Device Name:  ${GREEN}${DEVICE}${RESET}"
echo -e "Verify Write:     ${GREEN}${VERIFY}${RESET}"
echo -e "Reset After:      ${GREEN}${RESET_MCU}${RESET}"
echo

# Standardize interface name casing
INTERFACE_UPPER=$(echo "$INTERFACE" | tr '[:lower:]' '[:upper:]')

case "$INTERFACE_UPPER" in
    JLINK)
        JLINK_PATH=$(find_jlink)
        if [ -z "$JLINK_PATH" ]; then
            echo -e "${RED}ERROR: J-Link commander utility (JLink.exe / JLinkExe) not found!${RESET}"
            echo -e "Please install Segger J-Link or ensure it is added to your environment PATH."
            exit 1
        fi
        
        echo -e "Using J-Link utility: ${GRAY}${JLINK_PATH}${RESET}"
        
        # Determine loading parameters
        LOAD_COMMAND="loadfile \"${FILE_WIN}\""
        # For .bin files, J-Link requires target start address (standard STM32 internal flash is 0x08000000)
        if [[ "$FILE_WIN" =~ \.bin$ ]]; then
            LOAD_COMMAND="loadfile \"${FILE_WIN}\" 0x08000000"
            echo -e "${YELLOW}[INFO] Flash format is raw BIN. Defaulting start address to 0x08000000.${RESET}"
        fi
        
        # Build Segger commander script
        JLINK_SCRIPT_FILE="${WORKSPACE_DIR}/build/flash_cmd.jlink"
        mkdir -p "${WORKSPACE_DIR}/build"
        
        cat <<EOF > "$JLINK_SCRIPT_FILE"
r
h
$LOAD_COMMAND
EOF

        if [ "$VERIFY" = true ]; then
            echo "verifyfile \"${FILE_WIN}\"" >> "$JLINK_SCRIPT_FILE"
        fi

        if [ "$RESET_MCU" = true ]; then
            cat <<EOF >> "$JLINK_SCRIPT_FILE"
r
g
EOF
        fi
        
        echo "qc" >> "$JLINK_SCRIPT_FILE"
        
        # Run J-Link commander
        echo -e "${CYAN}Executing Segger J-Link flashing command...${RESET}"
        
        # Normalize J-Link script file path for Windows if running JLink.exe
        JLINK_SCRIPT_FILE_EXEC="$JLINK_SCRIPT_FILE"
        if [ "$OS" = "Windows_NT" ] && [[ "$JLINK_PATH" =~ \.exe$ ]]; then
            JLINK_SCRIPT_FILE_EXEC=$(cygpath -w "$JLINK_SCRIPT_FILE")
        fi
        
        "$JLINK_PATH" -device "$DEVICE" -if SWD -speed 4000 -autoconnect 1 -CommanderScript "$JLINK_SCRIPT_FILE_EXEC"
        EXIT_CODE=$?
        
        # Cleanup script file
        rm -f "$JLINK_SCRIPT_FILE"
        
        if [ $EXIT_CODE -eq 0 ]; then
            echo -e "\n${GREEN}[OK] MCU programmed successfully via J-Link!${RESET}"
        else
            echo -e "\n${RED}ERROR: Flashing failed with exit code $EXIT_CODE!${RESET}"
            exit 1
        fi
        ;;
        
    STLINK|DFU)
        CUBE_PATH=$(find_cubeprog)
        if [ -z "$CUBE_PATH" ]; then
            echo -e "${RED}ERROR: STM32CubeProgrammer CLI (STM32_Programmer_CLI) not found!${RESET}"
            echo -e "Please install STM32CubeProgrammer or ensure it is added to your environment PATH."
            exit 1
        fi
        
        echo -e "Using STM32CubeProgrammer utility: ${GRAY}${CUBE_PATH}${RESET}"
        
        # Determine port setting
        PORT_PARAM="port=SWD"
        if [ "$INTERFACE_UPPER" = "DFU" ]; then
            PORT_PARAM="port=USB"
            echo -e "${YELLOW}[INFO] USB DFU flashing selected. Ensure the MCU is booted in Bootloader mode (BOOT0 pin high).${RESET}"
        fi
        
        # Build programmer command
        CMD_ARGS=("-c" "$PORT_PARAM" "-d" "$FILE_WIN")
        
        if [ "$VERIFY" = true ]; then
            CMD_ARGS+=("-v")
        fi
        
        if [ "$RESET_MCU" = true ]; then
            # Reset MCU and start execution
            CMD_ARGS+=("-rst" "-hardRst" "-start")
        fi
        
        # Run programmer CLI
        echo -e "${CYAN}Executing STM32CubeProgrammer command...${RESET}"
        "$CUBE_PATH" "${CMD_ARGS[@]}"
        EXIT_CODE=$?
        
        if [ $EXIT_CODE -eq 0 ]; then
            echo -e "\n${GREEN}[OK] MCU programmed successfully via ST-Link/DFU!${RESET}"
        else
            echo -e "\n${RED}ERROR: Flashing failed with exit code $EXIT_CODE!${RESET}"
            exit 1
        fi
        ;;
        
    *)
        echo -e "${RED}ERROR: Unsupported flashing interface '$INTERFACE'.${RESET}"
        echo -e "Supported interfaces: JLink, STLink, DFU"
        exit 1
        ;;
esac
