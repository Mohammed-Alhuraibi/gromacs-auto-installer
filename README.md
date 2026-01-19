# GROMACS Auto-Installer

A comprehensive bash script for automatically installing GROMACS molecular dynamics software with intelligent compatibility patching for modern compilers.

## Features

- ✅ **Version Flexibility**: Install any GROMACS version by specifying it as an argument
- ✅ **Dry Run Mode**: Preview installation steps without making changes
- ✅ **Auto Dependency Detection**: Automatically detects and installs required build tools
- ✅ **Cross-Platform Support**: Works across different Linux distributions (Ubuntu, CentOS, Fedora, Arch, openSUSE)
- ✅ **Smart FFTW Management**: Uses system FFTW libraries when available, builds own as fallback
- ✅ **Compiler Compatibility**: Automatically patches source code for GCC compatibility issues
- ✅ **Environment Setup**: Automatically configures shell environment and adds to ~/.bashrc
- ✅ **Version Management**: Detects existing installations and handles version conflicts
- ✅ **Comprehensive Error Handling**: Robust error handling with helpful suggestions

## Quick Start

```bash
# Download the script
wget https://raw.githubusercontent.com/YOUR_USERNAME/gromacs-auto-installer/main/install-gromacs.sh
chmod +x install-gromacs.sh

# Install GROMACS 2025.4
./install-gromacs.sh 2025.4

# Install GROMACS 2020 with dry run first
./install-gromacs.sh 2020 --dry-run
./install-gromacs.sh 2020
```

## Usage

```bash
./install-gromacs.sh <version> [--dry-run]
```

### Examples

```bash
# Install latest version
./install-gromacs.sh 2025.4

# Install older version with compatibility patches
./install-gromacs.sh 2020

# Preview installation without executing
./install-gromacs.sh 2023.1 --dry-run

# Get help
./install-gromacs.sh --help
```

## System Requirements

### Supported Operating Systems
- Ubuntu/Debian (apt)
- CentOS/RHEL (yum)
- Fedora (dnf)
- Arch Linux (pacman)
- openSUSE (zypper)

### Required Dependencies
The script automatically detects and installs:
- CMake (≥3.13)
- Make
- GCC/G++
- wget
- unzip
- pkg-config
- FFTW3 development libraries

## Compatibility Features

### Automatic Compiler Patching
The script intelligently detects and fixes compatibility issues between older GROMACS versions and newer GCC compilers:

- **Problem**: GROMACS 2020 and earlier versions may fail to compile with GCC 11+
- **Solution**: Automatically adds missing `#include <limits>` headers where needed
- **Smart Detection**: Only patches files that actually need it, regardless of version

### Version Management
- Detects existing GROMACS installations
- Automatically removes different versions before installing new ones
- Skips installation if the same version is already installed
- Cleans up shell configuration files from previous installations

## Installation Process

1. **Dependency Check**: Verifies and installs required build tools
2. **Compiler Compatibility**: Checks GCC version and provides recommendations
3. **Version Detection**: Checks for existing GROMACS installations
4. **Source Download**: Downloads source code from GitHub releases
5. **Compatibility Patching**: Applies necessary patches for compiler compatibility
6. **Configuration**: Runs CMake with optimized settings
7. **Compilation**: Builds GROMACS with parallel compilation
8. **Testing**: Runs available test suites
9. **Installation**: Installs to `/usr/local/gromacs`
10. **Environment Setup**: Configures shell environment automatically

## Configuration Options

The script uses optimized build settings:
- **FFTW**: Uses system libraries when available, builds own otherwise
- **SIMD**: Automatically detects and enables best SIMD instructions
- **OpenMP**: Enabled for parallel processing
- **Installation Path**: `/usr/local/gromacs`
- **Parallel Build**: Uses available CPU cores (limited to 4 for stability)

## Troubleshooting

### Common Issues

**Build fails with GCC compatibility errors**
- The script automatically patches these issues
- For persistent problems, try a newer GROMACS version

**Missing dependencies**
- The script auto-installs dependencies
- On unsupported distributions, install manually: `cmake make gcc g++ wget unzip pkg-config libfftw3-dev`

**Permission errors during installation**
- The script uses `sudo` for system installation
- Ensure your user has sudo privileges

**FFTW library issues**
- Script first tries system FFTW, then builds own
- For manual override, modify CMAKE_OPTIONS in the script

### Getting Help

1. Run with `--dry-run` to preview actions
2. Check the detailed output for specific error messages
3. Ensure all dependencies are available
4. Try a different GROMACS version if compatibility issues persist

## Advanced Usage

### Custom Installation Path
To install to a different location, modify the `GROMACS_INSTALL_DIR` variable in the script.

### Build Options
The script uses these CMake options by default:
```bash
-DREGRESSIONTEST_DOWNLOAD=OFF
-DGMX_BUILD_OWN_FFTW=OFF  # (or ON if system FFTW unavailable)
-DGMX_DEFAULT_SUFFIX=OFF
-DGMX_BINARY_SUFFIX=
-DGMX_LIBS_SUFFIX=
-Wno-dev
```

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Test your changes on different systems
4. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- GROMACS development team for the excellent molecular dynamics software
- Community contributors for testing and feedback

## Support

If you encounter issues:
1. Check the [Issues](https://github.com/YOUR_USERNAME/gromacs-auto-installer/issues) page
2. Create a new issue with:
   - Your operating system and version
   - GCC version (`gcc --version`)
   - GROMACS version you're trying to install
   - Complete error output

---

**Note**: Replace `YOUR_USERNAME` with your actual GitHub username before publishing.