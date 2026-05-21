#!/usr/bin/env bash
# ==============================================================================
# Cross-Platform STM32 Compiler Manager
# Compiles the firmware using CMake presets with dynamic parallel core count.
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
RESET='\033[0m'

show_banner() {
    echo -e "${CYAN}======================================${RESET}"
    echo -e "${CYAN}        STM32 Compiler Manager        ${RESET}"
    echo -e "${CYAN}======================================${RESET}"
}

show_usage() {
    show_banner
    echo -e "Usage: $0 [options]"
    echo
    echo -e "${YELLOW}Options:${RESET}"
    echo -e "  -c, --clean, -Clean       Wipe build directory before compiling"
    echo -e "  -j, --jobs, -Jobs <num>   Override parallel build jobs (default: auto-detect)"
    echo -e "  -h, --help                Show this help menu"
    echo
    echo -e "${YELLOW}Examples:${RESET}"
    echo -e "  $0"
    echo -e "  $0 --clean"
    echo -e "  $0 -j 8"
    echo -e "  $0 -Clean -Jobs 4"
    echo
    exit 1
}

# Auto-detect CPU cores for parallel compilation
detect_cores() {
    if [ -n "$NUMBER_OF_PROCESSORS" ]; then
        echo "$NUMBER_OF_PROCESSORS"
    elif command -v nproc >/dev/null 2>&1; then
        echo "$(nproc)"
    elif command -v sysctl >/dev/null 2>&1; then
        echo "$(sysctl -n hw.ncpu)"
    elif command -v getconf >/dev/null 2>&1; then
        echo "$(getconf _NPROCESSORS_ONLN)"
    else
        echo "4" # Conservative fallback
    fi
}

# Parse parameters
CLEAN_BUILD=false
JOBS=""

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            show_usage
            ;;
        -c|--clean|-Clean)
            CLEAN_BUILD=true
            shift
            ;;
        -j|--jobs|-Jobs)
            if [ -z "$2" ] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
                echo -e "${RED}ERROR: Option '$1' requires a valid integer argument.${RESET}"
                exit 1
            fi
            JOBS="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}ERROR: Unknown option '$1'.${RESET}"
            show_usage
            ;;
    esac
done

show_banner

# Ensure build config is loaded, otherwise auto-initialize it
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}[INFO] Build configuration not found. Initializing default (Debug)...${RESET}"
    if [ -f "${SCRIPT_DIR}/config.sh" ]; then
        bash "${SCRIPT_DIR}/config.sh" "Debug" >/dev/null
    else
        echo -e "${RED}ERROR: config.sh not found in ${SCRIPT_DIR}!${RESET}"
        exit 1
    fi
fi

# Source configuration
source "$CONFIG_FILE"
if [ -z "$BUILD_TYPE" ]; then
    echo -e "${RED}ERROR: Invalid configuration file. BUILD_TYPE is not set.${RESET}"
    exit 1
fi

# Set default jobs if not specified
if [ -z "$JOBS" ]; then
    JOBS=$(detect_cores)
fi

echo -e "Building configuration: ${GREEN}${BUILD_TYPE}${RESET}"
echo -e "Parallel Compile Jobs:  ${GREEN}${JOBS}${RESET}"
echo -e "Workspace Path:         ${WHITE}${WORKSPACE_DIR}${RESET}"
echo

# Perform clean if requested
BUILD_DIR="${WORKSPACE_DIR}/build/${BUILD_TYPE}"
if [ "$CLEAN_BUILD" = true ]; then
    echo -e "${YELLOW}Cleaning build directory: ${BUILD_DIR}...${RESET}"
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
        echo -e "${GREEN}[OK] Cleaned!${RESET}"
    else
        echo -e "${GRAY}Build directory does not exist yet. Clean skipped.${RESET}"
    fi
    echo
fi

# Navigate to workspace directory to ensure CMake runs in context
cd "$WORKSPACE_DIR" || exit 1

# Step 1: Configure using CMake Presets
echo -e "${CYAN}Running CMake configuration...${RESET}"
if ! cmake --preset "$BUILD_TYPE"; then
    echo -e "${RED}ERROR: CMake configuration failed!${RESET}"
    exit 1
fi
echo -e "${GREEN}[OK] CMake configuration complete!${RESET}"
echo

# Step 2: Build using CMake Presets
echo -e "${CYAN}Running compiler (jobs: $JOBS)...${RESET}"
if ! cmake --build --preset "$BUILD_TYPE" -j "$JOBS"; then
    echo -e "${RED}ERROR: Compilation failed!${RESET}"
    exit 1
fi

echo -e "\n${GREEN}======================================${RESET}"
echo -e "${GREEN}      BUILD SUCCESSFUL (100%)         ${RESET}"
echo -e "${GREEN}======================================${RESET}"
echo
