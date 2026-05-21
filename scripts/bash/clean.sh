#!/usr/bin/env bash
# ==============================================================================
# Cross-Platform STM32 Project Clean Utility
# Removes CMake build directories, temporary files, and optionally configurations.
# Works on Windows (Git Bash/MSYS2), macOS, and Linux.
# ==============================================================================

# Script setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/build_config.sh"
BUILD_DIR="${WORKSPACE_DIR}/build"

# Terminal ANSI Color Codes
CYAN='\033[96m'
GREEN='\033[92m'
YELLOW='\033[93m'
RED='\033[91m'
WHITE='\033[97m'
GRAY='\033[90m'
RESET='\033[0m'

show_banner() {
    echo -e "${CYAN}======================================${RESET}"
    echo -e "${CYAN}         STM32 Build Cleaner          ${RESET}"
    echo -e "${CYAN}======================================${RESET}"
}

show_usage() {
    show_banner
    echo -e "Usage: $0 [options]"
    echo
    echo -e "${YELLOW}Options:${RESET}"
    echo -e "  -a, --all, -All           Clean build directory AND delete build_config.sh"
    echo -e "  -h, --help                Show this help menu"
    echo
    echo -e "${YELLOW}Examples:${RESET}"
    echo -e "  $0                        # standard build folder clean"
    echo -e "  $0 --all                  # full reset, including configuration"
    echo
    exit 1
}

# Parse parameters
CLEAN_ALL=false

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            show_usage
            ;;
        -a|--all|-All)
            CLEAN_ALL=true
            shift
            ;;
        *)
            echo -e "${RED}ERROR: Unknown option '$1'.${RESET}"
            show_usage
            ;;
    esac
done

show_banner

# Step 1: Clean build directories
echo -e "Cleaning project build artifacts..."
if [ -d "$BUILD_DIR" ]; then
    echo -e "  Removing directory: ${WHITE}${BUILD_DIR}${RESET}..."
    rm -rf "$BUILD_DIR"
    echo -e "  ${GREEN}[OK] Build artifacts wiped!${RESET}"
else
    echo -e "  ${GRAY}Build directory does not exist. Already clean.${RESET}"
fi

# Step 2: Clean configuration if requested
if [ "$CLEAN_ALL" = true ]; then
    echo -e "\nFull configuration reset requested..."
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "  Deleting: ${WHITE}${CONFIG_FILE}${RESET}..."
        rm -f "$CONFIG_FILE"
        echo -e "  ${GREEN}[OK] Build configuration deleted!${RESET}"
    else
        echo -e "  ${GRAY}Configuration file not found. Already reset.${RESET}"
    fi
fi

echo -e "\n${GREEN}======================================${RESET}"
echo -e "${GREEN}        CLEANUP COMPLETE (100%)       ${RESET}"
echo -e "${GREEN}======================================${RESET}"
echo
