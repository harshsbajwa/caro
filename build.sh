#!/usr/bin/env bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Defaults
BUILD_DIR="build"
BUILD_TYPE="Release"
CLEAN=false
RUN_FORMAT=false
RUN_LINT=false
JOBS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

detect_clang_format() {
    for version in 21 19 18 ""; do
        cmd="clang-format${version:+-$version}"
        if command -v "$cmd" &> /dev/null; then
            echo "$cmd"
            return 0
        fi
    done
    echo ""
}

detect_clang_tidy() {
    for version in 21 19 18 ""; do
        cmd="clang-tidy${version:+-$version}"
        if command -v "$cmd" &> /dev/null; then
            echo "$cmd"
            return 0
        fi
    done
    echo ""
}

CLANG_FORMAT=$(detect_clang_format)
CLANG_TIDY=$(detect_clang_tidy)

while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN=true
            shift
            ;;
        --debug)
            BUILD_TYPE="Debug"
            shift
            ;;
        --release)
            BUILD_TYPE="Release"
            shift
            ;;
        --format)
            RUN_FORMAT=true
            shift
            ;;
        --lint)
            RUN_LINT=true
            shift
            ;;
        --jobs)
            JOBS="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --clean       Clean build directory before building"
            echo "  --debug       Build in Debug mode (default: Release)"
            echo "  --release     Build in Release mode"
            echo "  --format      Run clang-format checks"
            echo "  --lint        Run clang-tidy checks"
            echo "  --jobs N      Number of parallel jobs (default: auto)"
            echo "  --help        Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Submodules
if [ ! -f "external/Vulkan-Headers/CMakeLists.txt" ] || [ ! -f "external/Vulkan-Hpp/CMakeLists.txt" ]; then
    echo -e "${YELLOW}Initializing git submodules...${NC}"
    git submodule update --init --recursive
fi

# Format
if [ "$RUN_FORMAT" = true ]; then
    if [ -z "$CLANG_FORMAT" ]; then
        echo -e "${RED}Error: clang-format not found${NC}"
        exit 1
    fi
    echo -e "${GREEN}Running $CLANG_FORMAT checks...${NC}"
    find src -name '*.cpp' -o -name '*.h' -o -name '*.hpp' | \
        xargs "$CLANG_FORMAT" --dry-run --Werror
    echo -e "${GREEN}Format check passed!${NC}"
fi

if [ "$CLEAN" = true ]; then
    echo -e "${YELLOW}Cleaning build directory...${NC}"
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"

echo -e "${GREEN}Configuring with CMake (${BUILD_TYPE})...${NC}"
cmake -S . -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -G Ninja

# Build
echo -e "${GREEN}Building with ${JOBS} parallel jobs...${NC}"
cmake --build "$BUILD_DIR" --parallel "$JOBS"

# Copy compile_commands.json to root for clangd
if [ -f "$BUILD_DIR/compile_commands.json" ]; then
    cp "$BUILD_DIR/compile_commands.json" .
fi

# Lint
if [ "$RUN_LINT" = true ]; then
    if [ -z "$CLANG_TIDY" ]; then
        echo -e "${RED}Error: clang-tidy not found${NC}"
        exit 1
    fi
    echo -e "${GREEN}Running $CLANG_TIDY checks...${NC}"
    find src -name '*.cpp' | \
        xargs "$CLANG_TIDY" -p "$BUILD_DIR" --warnings-as-errors='*'
    echo -e "${GREEN}Lint check passed!${NC}"
fi

echo -e "${GREEN}Build complete!${NC}"
echo -e "Executable: ${BUILD_DIR}/caro"
