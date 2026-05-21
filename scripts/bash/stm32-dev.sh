#!/usr/bin/env bash
# ==============================================================================
# Cross-Platform STM32 Master Interactive Developer Dashboard
# Command dashboard utility that integrates all STM32 development actions.
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

# Ensure scripts are executable
chmod +x "${SCRIPT_DIR}"/*.sh >/dev/null 2>&1

# Detect Python interpreter
PYTHON_CMD=""
if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON_CMD="python"
fi

# Refresh build config
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        BUILD_TYPE="Not Configured"
    fi
}

show_header() {
    clear
    load_config
    echo -e "${CYAN}┌────────────────────────────────────────────────────────┐${RESET}"
    echo -e "${CYAN}│          STM32 MASTER DEVELOPMENT DASHBOARD            │${RESET}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────┘${RESET}"
    echo -e "  Workspace:    ${WHITE}${WORKSPACE_DIR}${RESET}"
    echo -e "  Build Config: ${GREEN}${BUILD_TYPE}${RESET}"
    echo -e "${CYAN}──────────────────────────────────────────────────────────${RESET}"
}

run_config() {
    show_header
    echo -e "${YELLOW}[1] Configure Build Type${RESET}\n"
    echo -e "Select build profile:"
    echo -e "  1) Debug            (Optimizations disabled, full symbols)"
    echo -e "  2) Release          (Full optimizations, size/speed, LTO)"
    echo -e "  3) MinSizeRel       (Minimum size optimized, LTO)"
    echo -e "  4) RelWithDebInfo   (Optimized with debug symbols)"
    echo -e "  5) Back to main menu"
    echo
    read -rp "Enter choice [1-5]: " cfg_choice
    
    case "$cfg_choice" in
        1) bash "${SCRIPT_DIR}/config.sh" Debug ;;
        2) bash "${SCRIPT_DIR}/config.sh" Release ;;
        3) bash "${SCRIPT_DIR}/config.sh" MinSizeRel ;;
        4) bash "${SCRIPT_DIR}/config.sh" RelWithDebInfo ;;
        *) return ;;
    esac
    
    echo -e "\nPress [Enter] to continue..."
    read -r
}

run_build() {
    show_header
    echo -e "${YELLOW}[2] Build Firmware${RESET}\n"
    read -rp "Perform clean rebuild first? (y/N): " clean_choice
    
    local clean_flag=""
    if [[ "$clean_choice" =~ ^[Yy]$ ]]; then
        clean_flag="--clean"
    fi
    
    echo -e "\n${CYAN}Starting build...${RESET}"
    bash "${SCRIPT_DIR}/build.sh" $clean_flag
    
    echo -e "\nPress [Enter] to return to menu..."
    read -r
}

run_flash() {
    show_header
    echo -e "${YELLOW}[3] Flash Target MCU${RESET}\n"
    echo -e "Select programming interface:"
    echo -e "  1) J-Link SWD (Default, ultra-fast)"
    echo -e "  2) ST-Link SWD (STM32CubeProgrammer)"
    echo -e "  3) USB DFU Mode (Direct USB programming)"
    echo -e "  4) Back to main menu"
    echo
    read -rp "Enter choice [1-4]: " flash_choice
    
    local interface=""
    case "$flash_choice" in
        1) interface="JLink" ;;
        2) interface="STLink" ;;
        3) interface="DFU" ;;
        *) return ;;
    esac
    
    read -rp "Verify written image after flashing? (y/N): " verify_choice
    local verify_flag=""
    if [[ "$verify_choice" =~ ^[Yy]$ ]]; then
        verify_flag="-v"
    fi
    
    echo -e "\n${CYAN}Executing flashing operation...${RESET}"
    bash "${SCRIPT_DIR}/flash.sh" -i "$interface" $verify_flag
    
    echo -e "\nPress [Enter] to return to menu..."
    read -r
}

run_clean() {
    show_header
    echo -e "${YELLOW}[4] Clean Build Artifacts${RESET}\n"
    echo -e "  1) Wipe build directory only (Recommended)"
    echo -e "  2) Wipe build directory AND reset build configurations"
    echo -e "  3) Back to main menu"
    echo
    read -rp "Enter choice [1-3]: " clean_choice
    
    case "$clean_choice" in
        1) bash "${SCRIPT_DIR}/clean.sh" ;;
        2) bash "${SCRIPT_DIR}/clean.sh" --all ;;
        *) return ;;
    esac
    
    echo -e "\nPress [Enter] to return to menu..."
    read -r
}

run_monitor() {
    show_header
    echo -e "${YELLOW}[5] Serial Monitor Console${RESET}\n"
    
    if [ -z "$PYTHON_CMD" ]; then
        echo -e "${RED}ERROR: Python is not installed or not in your PATH!${RESET}"
        echo -e "\nPress [Enter] to return to menu..."
        read -r
        return 1
    fi
    
    # Run the python monitor
    echo -e "${CYAN}Launching Python serial monitor...${RESET}"
    "$PYTHON_CMD" "${SCRIPT_DIR}/../monitor.py"
    
    echo -e "\nPress [Enter] to return to menu..."
    read -r
}

run_flash_monitor() {
    show_header
    echo -e "${YELLOW}[6] Flash and Monitor${RESET}\n"
    
    if [ -z "$PYTHON_CMD" ]; then
        echo -e "${RED}ERROR: Python is not installed or not in your PATH!${RESET}"
        echo -e "\nPress [Enter] to return to menu..."
        read -r
        return 1
    fi
    
    echo -e "Select programming interface:"
    echo -e "  1) J-Link SWD"
    echo -e "  2) ST-Link SWD"
    echo -e "  3) USB DFU Mode"
    echo -e "  4) Back to main menu"
    echo
    read -rp "Enter choice [1-4]: " flash_choice
    
    local interface=""
    case "$flash_choice" in
        1) interface="JLink" ;;
        2) interface="STLink" ;;
        3) interface="DFU" ;;
        *) return ;;
    esac
    
    echo -e "\n${CYAN}Step 1: Flashing MCU...${RESET}"
    if bash "${SCRIPT_DIR}/flash.sh" -i "$interface"; then
        echo -e "\n${CYAN}Step 2: Launching Serial Monitor...${RESET}"
        "$PYTHON_CMD" "${SCRIPT_DIR}/../monitor.py"
    else
        echo -e "${RED}ERROR: Flashing failed. Serial monitor launch aborted.${RESET}"
    fi
    
    echo -e "\nPress [Enter] to return to menu..."
    read -r
}

# Execution with parameters (e.g. bash stm32-dev.sh build)
if [ $# -gt 0 ]; then
    case "$1" in
        config)
            shift
            bash "${SCRIPT_DIR}/config.sh" "$@"
            ;;
        build)
            shift
            bash "${SCRIPT_DIR}/build.sh" "$@"
            ;;
        flash)
            shift
            bash "${SCRIPT_DIR}/flash.sh" "$@"
            ;;
        clean)
            shift
            bash "${SCRIPT_DIR}/clean.sh" "$@"
            ;;
        monitor)
            shift
            if [ -z "$PYTHON_CMD" ]; then
                echo -e "${RED}ERROR: Python is not installed or not in your PATH!${RESET}"
                exit 1
            fi
            "$PYTHON_CMD" "${SCRIPT_DIR}/../monitor.py" "$@"
            ;;
        flash-monitor)
            shift
            if bash "${SCRIPT_DIR}/flash.sh" "$@"; then
                if [ -z "$PYTHON_CMD" ]; then
                    echo -e "${RED}ERROR: Python is not installed or not in your PATH!${RESET}"
                    exit 1
                fi
                "$PYTHON_CMD" "${SCRIPT_DIR}/../monitor.py"
            fi
            ;;
        *)
            echo -e "${RED}Unknown command: $1${RESET}"
            echo -e "Available commands: ${WHITE}config, build, flash, clean, monitor, flash-monitor${RESET}"
            exit 1
            ;;
    esac
    exit 0
fi

# Interactive Menu Loop
while true; do
    show_header
    echo -e "  1) Configure Build Profile"
    echo -e "  2) Compile Firmware (build)"
    echo -e "  3) Program MCU Device (flash)"
    echo -e "  4) Clean Build Folders"
    echo -e "  5) Open Serial Console (monitor)"
    echo -e "  6) Flash Device and Start Monitor"
    echo -e "  7) Exit"
    echo -e "${CYAN}──────────────────────────────────────────────────────────${RESET}"
    
    read -rp "Select option [1-7]: " menu_choice
    
    case "$menu_choice" in
        1) run_config ;;
        2) run_build ;;
        3) run_flash ;;
        4) run_clean ;;
        5) run_monitor ;;
        6) run_flash_monitor ;;
        7) 
            show_header
            echo -e "${GREEN}Thank you for using STM32 Master Dashboard! Happy coding!${RESET}\n"
            exit 0 
            ;;
        *)
            echo -e "${RED}Invalid selection. Press [Enter] to retry.${RESET}"
            read -r
            ;;
    esac
done
