#!/usr/bin/env bash
# ==============================================================================
# Cross-Platform STM32 Project Build Configurator
# Auto-generates build_config.sh with the selected CMake Build Type.
# Works on Windows (Git Bash/MSYS2), macOS, and Linux.
# ==============================================================================

# Script setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/build_config.sh"

# Terminal ANSI Color Codes
CYAN='\033[96m'
GREEN='\033[92m'
YELLOW='\033[93m'
RED='\033[91m'
WHITE='\033[97m'
RESET='\033[0m'

# Enable terminal coloring on Windows Git Bash
if [ "$OS" = "Windows_NT" ]; then
    # Git Bash handles ANSI by default, but let's make sure
    export TERM=xterm-256color
fi

# Print logo
show_banner() {
    echo -e "${CYAN}======================================${RESET}"
    echo -e "${CYAN}     STM32 Project Configurator       ${RESET}"
    echo -e "${CYAN}======================================${RESET}"
}

# Print help/usage
show_usage() {
    show_banner
    echo -e "Usage: $0 [options] or $0 <BuildType>"
    echo
    echo -e "${YELLOW}Options:${RESET}"
    echo -e "  -b, --build-type, -BuildType <type>   Set CMake build type"
    echo -e "                                        Options: Debug, Release, MinSizeRel, RelWithDebInfo"
    echo -e "  -h, --help                            Show this help menu"
    echo
    echo -e "${YELLOW}Examples:${RESET}"
    echo -e "  $0 Debug"
    echo -e "  $0 -BuildType Release"
    echo -e "  $0 --build-type MinSizeRel"
    echo
    exit 1
}

# Check if build type is valid
validate_build_type() {
    local type="$1"
    case "$type" in
        Debug|Release|MinSizeRel|RelWithDebInfo)
            return 0
            ;;
        *)
            echo -e "${RED}ERROR: Invalid BuildType '$type'.${RESET}"
            echo -e "Must be one of: ${WHITE}Debug, Release, MinSizeRel, RelWithDebInfo${RESET}"
            exit 1
            ;;
    esac
}

# Load current configuration if exists
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        BUILD_TYPE="Debug"
    fi
}

# Save new configuration
save_config() {
    local type="$1"
    validate_build_type "$type"
    
    # Save the config file with forward slashes for cross-platform compatibility
    cat <<EOF > "$CONFIG_FILE"
# ==============================================================================
# STM32 Build Configuration (Auto-Generated)
# Do not edit manually. To update, run config.sh.
# ==============================================================================
BUILD_TYPE="$type"
EOF
    
    # Ensure it uses LF line endings
    if command -v dos2unix >/dev/null 2>&1; then
        dos2unix "$CONFIG_FILE" >/dev/null 2>&1
    fi
    
    show_banner
    echo -e "${GREEN}[OK] Configuration saved successfully!${RESET}"
    echo -e "  File:       ${WHITE}${CONFIG_FILE}${RESET}"
    echo -e "  Build Type: ${WHITE}${type}${RESET}"
    echo
}

# Main script logic
load_config

# Parse arguments
if [ $# -eq 0 ]; then
    # No args: print current config or ask for one
    show_banner
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "Current Configuration:"
        echo -e "  Build Type: ${GREEN}${BUILD_TYPE}${RESET}"
        echo -e "  File:       ${WHITE}${CONFIG_FILE}${RESET}"
    else
        echo -e "${YELLOW}No active configuration found. Defaulting to Debug...${RESET}"
        save_config "Debug"
    fi
    exit 0
fi

# Parse positional and named options
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            show_usage
            ;;
        -b|--build-type|-BuildType)
            if [ -z "$2" ]; then
                echo -e "${RED}ERROR: Option '$1' requires an argument.${RESET}"
                exit 1
            fi
            save_config "$2"
            exit 0
            ;;
        *)
            # Check if this is a standalone build type
            save_config "$1"
            exit 0
            ;;
    esac
done
