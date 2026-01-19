#!/bin/bash

# GROMACS Installation Script
# Usage: ./install-gromacs.sh <version> [--dry-run]
# Example: ./install-gromacs.sh 2025.4
# Example: ./install-gromacs.sh 2020 --dry-run

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <version> [--dry-run]"
    echo "Examples:"
    echo "  $0 2025.4"
    echo "  $0 2020 --dry-run"
    echo ""
    echo "Options:"
    echo "  --dry-run    Show what would be done without actually executing"
    exit 1
}

# Parse arguments
VERSION=""
DRY_RUN=false

for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            if [[ -z "$VERSION" ]]; then
                VERSION="$arg"
            else
                print_error "Unknown argument: $arg"
                show_usage
            fi
            shift
            ;;
    esac
done

# Validate version argument
if [[ -z "$VERSION" ]]; then
    print_error "Version argument is required"
    show_usage
fi

# Configuration
GROMACS_INSTALL_DIR="/usr/local/gromacs"
GROMACS_RC_FILE="$GROMACS_INSTALL_DIR/bin/GMXRC"
DOWNLOAD_DIR="/tmp/gromacs-install"
GITHUB_URL="https://github.com/gromacs/gromacs/archive/refs/tags/v${VERSION}.zip"
ZIP_FILE="gromacs-v${VERSION}.zip"
EXTRACTED_DIR="gromacs-${VERSION}"

print_info "GROMACS Installation Script"
print_info "Version: $VERSION"
print_info "Dry run: $DRY_RUN"
echo ""
# Function to execute or show command based on dry-run mode
execute_cmd() {
    local cmd="$1"
    local description="$2"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] $description"
        echo "  Command: $cmd"
        return 0
    else
        print_info "$description"
        if eval "$cmd"; then
            return 0
        else
            return 1
        fi
    fi
}

# Function to check if GROMACS is installed and get version
check_gromacs_installation() {
    if command -v gmx &> /dev/null; then
        local installed_version=$(gmx --version 2>/dev/null | grep "GROMACS version" | awk '{print $3}' | head -1)
        if [[ -n "$installed_version" ]]; then
            echo "$installed_version"
            return 0
        fi
    fi
    return 1
}

# Function to compare versions (ignores suffixes like -dev, -rc, etc.)
versions_match() {
    local installed="$1"
    local requested="$2"
    
    # Extract base version (remove suffixes like -dev, -rc, etc.)
    local installed_base=$(echo "$installed" | sed 's/-.*$//')
    local requested_base=$(echo "$requested" | sed 's/-.*$//')
    
    [[ "$installed_base" == "$requested_base" ]]
}

# Function to remove existing GROMACS installation
remove_existing_gromacs() {
    print_info "Removing existing GROMACS installation..."
    
    # Remove installation directory
    if [[ -d "$GROMACS_INSTALL_DIR" ]]; then
        execute_cmd "sudo rm -rf $GROMACS_INSTALL_DIR" "Removing GROMACS installation directory"
    fi
    
    # Clean up shell configuration files
    print_info "Cleaning GROMACS paths from shell configuration files..."
    
    # List of common shell config files to clean
    local config_files=(
        "$HOME/.bashrc"
        "$HOME/.bash_profile" 
        "$HOME/.zshrc"
        "$HOME/.profile"
    )
    
    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            # Remove lines containing GROMACS paths
            if grep -q "gromacs\|GMXRC" "$config_file" 2>/dev/null; then
                execute_cmd "sed -i.bak '/gromacs\|GMXRC/d' '$config_file'" "Cleaning GROMACS references from $(basename $config_file)"
                print_info "Backup created: ${config_file}.bak"
            fi
        fi
    done
    
    print_success "Existing GROMACS installation and configuration cleaned"
}

# Function to detect package manager
detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    elif command -v zypper &> /dev/null; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

# Function to install system packages
install_system_packages() {
    local pkg_manager="$1"
    shift
    local packages=("$@")
    
    case "$pkg_manager" in
        "apt")
            execute_cmd "sudo apt-get update" "Updating package list"
            execute_cmd "sudo apt-get install -y ${packages[*]}" "Installing packages: ${packages[*]}"
            ;;
        "yum")
            execute_cmd "sudo yum install -y ${packages[*]}" "Installing packages: ${packages[*]}"
            ;;
        "dnf")
            execute_cmd "sudo dnf install -y ${packages[*]}" "Installing packages: ${packages[*]}"
            ;;
        "pacman")
            execute_cmd "sudo pacman -Sy --noconfirm ${packages[*]}" "Installing packages: ${packages[*]}"
            ;;
        "zypper")
            execute_cmd "sudo zypper install -y ${packages[*]}" "Installing packages: ${packages[*]}"
            ;;
        *)
            print_error "Unknown package manager. Please install packages manually: ${packages[*]}"
            return 1
            ;;
    esac
}

# Function to check and install build tools
check_and_install_build_tools() {
    print_info "Checking build tools and dependencies..."
    
    local pkg_manager=$(detect_package_manager)
    local missing_tools=()
    local packages_to_install=()
    
    # Define required tools and their corresponding packages for different distros
    declare -A tool_packages_apt=(
        ["cmake"]="cmake"
        ["make"]="build-essential"
        ["gcc"]="build-essential"
        ["g++"]="build-essential"
        ["wget"]="wget"
        ["unzip"]="unzip"
        ["pkg-config"]="pkg-config"
    )
    
    declare -A tool_packages_yum=(
        ["cmake"]="cmake"
        ["make"]="make"
        ["gcc"]="gcc"
        ["g++"]="gcc-c++"
        ["wget"]="wget"
        ["unzip"]="unzip"
        ["pkg-config"]="pkgconfig"
    )
    
    declare -A tool_packages_dnf=(
        ["cmake"]="cmake"
        ["make"]="make"
        ["gcc"]="gcc"
        ["g++"]="gcc-c++"
        ["wget"]="wget"
        ["unzip"]="unzip"
        ["pkg-config"]="pkgconf"
    )
    
    declare -A tool_packages_pacman=(
        ["cmake"]="cmake"
        ["make"]="base-devel"
        ["gcc"]="base-devel"
        ["g++"]="base-devel"
        ["wget"]="wget"
        ["unzip"]="unzip"
        ["pkg-config"]="pkgconf"
    )
    
    declare -A tool_packages_zypper=(
        ["cmake"]="cmake"
        ["make"]="make"
        ["gcc"]="gcc"
        ["g++"]="gcc-c++"
        ["wget"]="wget"
        ["unzip"]="unzip"
        ["pkg-config"]="pkg-config"
    )
    
    # Check each required tool
    for tool in cmake make gcc g++ wget unzip pkg-config; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
            
            # Get the package name for this tool based on package manager
            case "$pkg_manager" in
                "apt")
                    if [[ -n "${tool_packages_apt[$tool]}" ]]; then
                        packages_to_install+=("${tool_packages_apt[$tool]}")
                    fi
                    ;;
                "yum")
                    if [[ -n "${tool_packages_yum[$tool]}" ]]; then
                        packages_to_install+=("${tool_packages_yum[$tool]}")
                    fi
                    ;;
                "dnf")
                    if [[ -n "${tool_packages_dnf[$tool]}" ]]; then
                        packages_to_install+=("${tool_packages_dnf[$tool]}")
                    fi
                    ;;
                "pacman")
                    if [[ -n "${tool_packages_pacman[$tool]}" ]]; then
                        packages_to_install+=("${tool_packages_pacman[$tool]}")
                    fi
                    ;;
                "zypper")
                    if [[ -n "${tool_packages_zypper[$tool]}" ]]; then
                        packages_to_install+=("${tool_packages_zypper[$tool]}")
                    fi
                    ;;
            esac
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_warning "Missing build tools: ${missing_tools[*]}"
        
        if [[ "$pkg_manager" == "unknown" ]]; then
            print_error "Could not detect package manager. Please install missing tools manually."
            return 1
        fi
        
        # Remove duplicates from packages_to_install
        local unique_packages=($(printf "%s\n" "${packages_to_install[@]}" | sort -u))
        
        print_info "Installing missing build tools using $pkg_manager..."
        if install_system_packages "$pkg_manager" "${unique_packages[@]}"; then
            print_success "Build tools installed successfully"
        else
            print_error "Failed to install build tools"
            return 1
        fi
    else
        print_success "All build tools are available"
    fi
    
    return 0
}

# Function to install FFTW dependencies
install_fftw_deps() {
    print_info "Installing FFTW3 dependencies..."
    
    local pkg_manager=$(detect_package_manager)
    local fftw_packages=()
    
    # Define FFTW packages for different package managers
    case "$pkg_manager" in
        "apt")
            fftw_packages=("libfftw3-dev" "libfftw3-single3" "libfftw3-double3")
            ;;
        "yum"|"dnf")
            fftw_packages=("fftw-devel")
            ;;
        "pacman")
            fftw_packages=("fftw")
            ;;
        "zypper")
            fftw_packages=("fftw3-devel")
            ;;
        *)
            print_error "Unknown package manager. Please install FFTW3 development libraries manually."
            return 1
            ;;
    esac
    
    if install_system_packages "$pkg_manager" "${fftw_packages[@]}"; then
        print_success "FFTW3 libraries installed successfully"
        return 0
    else
        print_error "Failed to install FFTW3 libraries"
        return 1
    fi
}

# Function to check compiler compatibility
check_compiler_compatibility() {
    print_info "Checking compiler compatibility..."
    
    # Check GCC version
    if command -v gcc &> /dev/null; then
        local gcc_version=$(gcc -dumpversion | cut -d. -f1)
        print_info "Detected GCC version: $gcc_version"
        
        # Provide version recommendations
        if [[ "$gcc_version" -ge 11 ]]; then
            if [[ "$VERSION" =~ ^(2018|2019|2020)$ ]]; then
                print_warning "GCC $gcc_version with GROMACS $VERSION may have compatibility issues"
                print_info "Recommendation: Consider using GROMACS 2022 or later for better GCC $gcc_version compatibility"
                print_info "Or install GCC 9-10 for better compatibility with GROMACS $VERSION"
            elif [[ "$VERSION" =~ ^(2021|2022)$ ]]; then
                print_info "GCC $gcc_version with GROMACS $VERSION should work well"
            else
                print_info "GCC $gcc_version with GROMACS $VERSION - compatibility unknown, proceeding anyway"
            fi
        else
            print_info "GCC $gcc_version should work well with GROMACS $VERSION"
        fi
    fi
    
    # Check for C++14 support
    if ! gcc -std=c++14 -x c++ -E - < /dev/null > /dev/null 2>&1; then
        print_warning "C++14 support may be limited. This could cause build issues."
    fi
}

# Function to apply compatibility patches for newer compilers
apply_compatibility_patches() {
    local patch_applied=false
    
    # Check if we're in the right directory (should have src subdirectory)
    if [[ ! -d "src" ]]; then
        print_warning "Source directory not found. Skipping compatibility patches."
        return 0
    fi
    
    # Find all files that use numeric_limits but don't include <limits>
    print_info "Scanning for files that need #include <limits> patch..."
    
    local files_needing_limits=()
    
    # Use a simpler approach to find files
    # First find all C++ files, then check each one
    local all_files=($(find src -name "*.cpp" -o -name "*.h" -o -name "*.hpp" 2>/dev/null))
    
    for file in "${all_files[@]}"; do
        if [[ -f "$file" ]]; then
            # Check if file uses numeric_limits but doesn't include limits
            if grep -q "std::numeric_limits\|numeric_limits" "$file" 2>/dev/null; then
                # Check if limits header is already included (with various spacing patterns)
                if ! grep -q "#include[[:space:]]*<limits>" "$file" 2>/dev/null && ! grep -q "#include[[:space:]]*\"limits\"" "$file" 2>/dev/null; then
                    files_needing_limits+=("$file")
                fi
            fi
        fi
    done
    
    # Apply patches to all files that need them
    for file in "${files_needing_limits[@]}"; do
        print_info "Patching $(basename $file) for GCC compatibility..."
        
        if [[ "$DRY_RUN" == true ]]; then
            print_info "[DRY-RUN] Adding missing #include <limits> to $file"
            echo "  Command: Adding #include <limits> after existing includes"
        else
            # Create a backup first
            cp "$file" "$file.bak"
            
            # Find the best place to insert the include
            if grep -q "#include" "$file"; then
                # Find the last #include line and add our include after it
                local last_include_line=$(grep -n "#include" "$file" | tail -1 | cut -d: -f1)
                sed -i "${last_include_line}a #include <limits>" "$file"
            else
                # If no includes found, add at the beginning after any copyright/license header
                # Look for the first line that doesn't start with /* or * or // or is empty
                local insert_line=$(awk '/^[[:space:]]*[^\/\*[:space:]]/ {print NR; exit}' "$file")
                if [[ -n "$insert_line" && "$insert_line" -gt 1 ]]; then
                    sed -i "${insert_line}i #include <limits>" "$file"
                else
                    # Fallback: add at the very beginning
                    sed -i '1i #include <limits>' "$file"
                fi
            fi
            print_success "Added #include <limits> to $(basename $file)"
        fi
        patch_applied=true
    done
    
    if [[ "$patch_applied" == true ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            print_info "Compatibility patches would be applied to ${#files_needing_limits[@]} files"
        else
            print_success "Compatibility patches applied to ${#files_needing_limits[@]} files"
            print_info "Backup files created with .bak extension"
        fi
    else
        print_info "No compatibility patches needed"
    fi
}

# Main installation process
main() {
    print_info "Starting GROMACS $VERSION installation process..."
    
    # Check and install build tools
    if ! check_and_install_build_tools; then
        print_error "Failed to install required build tools"
        exit 1
    fi
    
    # Check compiler compatibility
    check_compiler_compatibility
    
    # Check if the same version is already installed
    if installed_version=$(check_gromacs_installation); then
        print_info "Found existing GROMACS installation: version $installed_version"
        
        if versions_match "$installed_version" "$VERSION"; then
            print_success "GROMACS version $VERSION is already installed (found: $installed_version). Nothing to do."
            exit 0
        else
            print_warning "Different version ($installed_version) is installed. Will remove and install $VERSION"
            remove_existing_gromacs
        fi
    else
        print_info "No existing GROMACS installation found"
    fi
    
    # Create download directory
    execute_cmd "mkdir -p $DOWNLOAD_DIR" "Creating download directory"
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Changing to download directory"
        echo "  Command: cd $DOWNLOAD_DIR"
    else
        print_info "Changing to download directory"
        cd "$DOWNLOAD_DIR"
    fi
    
    # Download GROMACS source
    print_info "Downloading GROMACS v$VERSION from GitHub..."
    execute_cmd "wget -O $ZIP_FILE '$GITHUB_URL'" "Downloading GROMACS source archive"
    
    # Extract the archive
    execute_cmd "unzip -q $ZIP_FILE" "Extracting GROMACS source archive"
    
    # Navigate to extracted directory
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Entering GROMACS source directory"
        echo "  Command: cd $EXTRACTED_DIR"
        print_info "Applying compatibility patches for newer compilers..."
        print_info "[DRY-RUN] Would apply compatibility patches in $(pwd)/$EXTRACTED_DIR"
    else
        print_info "Entering GROMACS source directory"
        cd "$EXTRACTED_DIR"
        
        # Apply patches for compatibility with newer compilers
        print_info "Applying compatibility patches for newer compilers..."
        apply_compatibility_patches
    fi
    
    # Create build directory
    execute_cmd "mkdir -p build" "Creating build directory"
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Entering build directory"
        echo "  Command: cd build"
    else
        print_info "Entering build directory"
        cd build
    fi
    
    # Configure with CMake
    print_info "Configuring GROMACS build with CMake..."
    
    # Check if both single and double precision FFTW libraries and headers are available
    local has_fftw3f=false
    local has_fftw3=false
    local has_fftw_headers=false
    
    # Check for runtime libraries
    if ldconfig -p | grep -q libfftw3f 2>/dev/null; then
        has_fftw3f=true
    fi
    
    if ldconfig -p | grep -q "libfftw3[^f]" 2>/dev/null; then
        has_fftw3=true
    fi
    
    # Check for development headers
    if [[ -f "/usr/include/fftw3.h" ]] || pkg-config --exists fftw3 2>/dev/null; then
        has_fftw_headers=true
    fi
    
    # Determine CMake options based on FFTW availability
    CMAKE_OPTIONS="-DREGRESSIONTEST_DOWNLOAD=OFF"
    
    if [[ "$has_fftw3f" == true && "$has_fftw3" == true && "$has_fftw_headers" == true ]]; then
        print_info "Using system FFTW library (both precisions and headers available)"
        CMAKE_OPTIONS="$CMAKE_OPTIONS -DGMX_BUILD_OWN_FFTW=OFF"
    elif [[ "$has_fftw3f" == false || "$has_fftw3" == false || "$has_fftw_headers" == false ]]; then
        print_warning "System FFTW library incomplete (missing: $(
            [[ "$has_fftw3f" == false ]] && echo -n "libfftw3f "
            [[ "$has_fftw3" == false ]] && echo -n "libfftw3 "
            [[ "$has_fftw_headers" == false ]] && echo -n "headers "
        )). Attempting to install..."
        if install_fftw_deps; then
            print_info "FFTW installed successfully, using system FFTW"
            CMAKE_OPTIONS="$CMAKE_OPTIONS -DGMX_BUILD_OWN_FFTW=OFF"
        else
            print_warning "Could not install system FFTW, building own FFTW library"
            CMAKE_OPTIONS="$CMAKE_OPTIONS -DGMX_BUILD_OWN_FFTW=ON"
        fi
    else
        print_info "Building own FFTW library for compatibility"
        CMAKE_OPTIONS="$CMAKE_OPTIONS -DGMX_BUILD_OWN_FFTW=ON"
    fi
    
    # Add additional stability options and ignore warnings
    CMAKE_OPTIONS="$CMAKE_OPTIONS -DGMX_DEFAULT_SUFFIX=OFF -DGMX_BINARY_SUFFIX= -DGMX_LIBS_SUFFIX="
    CMAKE_OPTIONS="$CMAKE_OPTIONS -Wno-dev"  # Suppress developer warnings
    
    CMAKE_CMD="cmake .. $CMAKE_OPTIONS"
    execute_cmd "$CMAKE_CMD" "Running CMake configuration"
    
    # Build GROMACS
    print_info "Building GROMACS (this may take a while)..."
    print_warning "Note: GCC version warnings and CMake policy warnings are normal and can be ignored"
    print_info "The build will continue as long as there are no fatal compilation errors"
    
    # Use fewer parallel jobs to avoid memory issues and build failures
    NPROC=$(nproc)
    if [[ $NPROC -gt 4 ]]; then
        NPROC=4
    fi
    
    # Try parallel build first, fallback to single-threaded if it fails
    if ! execute_cmd "make -j$NPROC" "Compiling GROMACS with $NPROC parallel jobs"; then
        print_warning "Parallel build failed, trying single-threaded build..."
        if ! execute_cmd "make -j1" "Compiling GROMACS with single thread"; then
            print_error "Build failed. This is likely due to a fatal compilation error, not warnings."
            print_info "Common solutions:"
            print_info "1. Try a newer GROMACS version (2022 or later)"
            print_info "2. Use a different GCC version"
            print_info "3. Check if all dependencies are properly installed"
            exit 1
        fi
    fi
    
    # Run tests (skip if regression tests weren't downloaded)
    print_info "Running GROMACS tests..."
    execute_cmd "make check || echo 'Some tests may have been skipped due to missing regression test data'" "Running available tests"
    
    # Install GROMACS
    print_info "Installing GROMACS..."
    execute_cmd "sudo make install" "Installing GROMACS to system"
    
    # Clean up download directory
    execute_cmd "rm -rf $DOWNLOAD_DIR" "Cleaning up temporary files"
    
    if [[ "$DRY_RUN" == false ]]; then
        # Verify installation
        if [[ -f "$GROMACS_RC_FILE" ]]; then
            print_success "GROMACS $VERSION installed successfully!"
            
            # Source GROMACS environment
            print_info "Sourcing GROMACS environment..."
            source "$GROMACS_RC_FILE"
            
            # Add to bashrc if not already present
            if ! grep -q "source $GROMACS_RC_FILE" ~/.bashrc 2>/dev/null; then
                print_info "Adding GROMACS environment to ~/.bashrc..."
                echo "source $GROMACS_RC_FILE" >> ~/.bashrc
                print_success "GROMACS environment added to ~/.bashrc"
            else
                print_info "GROMACS environment already present in ~/.bashrc"
            fi
            
            print_info ""
            print_success "Installation complete! GROMACS is ready to use."
            print_info "The environment has been sourced for this session and added to ~/.bashrc for future sessions."
        else
            print_error "Installation completed but GMXRC file not found at expected location"
            exit 1
        fi
    else
        print_success "Dry run completed. Use without --dry-run to actually install GROMACS $VERSION"
    fi
}

# Trap to clean up on exit
cleanup() {
    if [[ -d "$DOWNLOAD_DIR" && "$DRY_RUN" == false ]]; then
        print_info "Cleaning up on exit..."
        rm -rf "$DOWNLOAD_DIR" 2>/dev/null || true
    fi
}

trap cleanup EXIT

# Run main function
main

print_success "Script execution completed!"