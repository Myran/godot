# Windows Sentry DLL Build Commands for GameTwo
# Cross-compilation from macOS to Windows using MinGW-w64
# Runtime GDExtension loaded by Godot at runtime

# Windows Sentry DLL paths (shared variables defined in main Sentry justfile)

# Show Windows Sentry DLL build help
help-sentry-windows:
    @echo "🪟 Windows Sentry DLL Build Commands (x86_64 only)"
    @echo "==============================================="
    @echo ""
    @echo "🔧 WINDOWS DLL BUILDS:"
    @echo "  just build-sentry-native-windows-release   # Build Windows Sentry DLL (Release) for x86_64"
    @echo "  just build-sentry-native-windows-debug     # Build Windows Sentry DLL (Debug) for x86_64"
    @echo ""
    @echo "📦 PACKAGING:"
    @echo "  just sentry-windows-package          # Package Windows DLLs with dependencies"
    @echo "  just sentry-windows-install          # Install Windows DLLs to addon directory"
    @echo ""
    @echo "🔧 MAINTENANCE:"
    @echo "  just sentry-windows-clean            # Clean build artifacts"
    @echo "  just sentry-windows-status           # Check build status"
    @echo "  just sentry-windows-validate         # Validate Windows DLL integration"
    @echo ""
    @echo "🚀 WORKFLOWS:"
    @echo "  just sentry-windows-complete        # Complete build + package + install"

# Build Windows Sentry DLL for x86_64 architecture (Release)
build-sentry-native-windows-release force="no":
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if Windows Sentry DLL already exists
    if [ "{{force}}" != "yes" ] && [ "{{force}}" != "force=yes" ] && [ -f "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.release.x86_64.dll" ]; then
        echo "✅ Windows Sentry DLL x86_64 already built"
        echo "   Use 'just build-sentry-native-windows-release force=yes' to rebuild"
        exit 0
    fi

    echo "🏗️  Building Windows Sentry DLL for x86_64..."

    # Check MinGW-w64 cross-compiler
    if ! command -v x86_64-w64-mingw32-gcc &> /dev/null; then
        echo "❌ MinGW-w64 x86_64 cross-compiler not found"
        echo "💡 Install with: brew install mingw-w64"
        exit 1
    fi

    # Create build directory
    mkdir -p {{SENTRY_PATH}}/build/windows-x86_64
    cd {{SENTRY_PATH}}/build/windows-x86_64

    # Configure with CMake for MinGW-w64 cross-compilation
    echo "🔧 Configuring CMake for Windows x86_64..."
    cmake ../../modules/sentry-native \
        -DCMAKE_SYSTEM_NAME=Windows \
        -DCMAKE_SYSTEM_PROCESSOR=x86_64 \
        -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
        -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
        -DCMAKE_RC_COMPILER=x86_64-w64-mingw32-windres \
        -DCMAKE_BUILD_TYPE=Release \
        -DSENTRY_BUILD_RUNTIMESTD=ON \
        -DSENTRY_BUILD_SHARED_LIBS=ON \
        -DSENTRY_BUILD_TESTS=OFF \
        -DSENTRY_BUILD_EXAMPLES=OFF \
        -DCMAKE_INSTALL_PREFIX=install \
        -DSENTRY_TRANSPORT=winhttp \
        -DSENTRY_BACKEND=inproc \
        -DSENTRY_TRANSPORT_COMPRESSION=OFF \
        -G "Unix Makefiles"

    # Build the library
    echo "🔨 Building Sentry DLL for Windows x86_64..."
    make -j$(nproc) sentry

    echo "✅ Windows Sentry DLL x86_64 build completed"

    # Create necessary directories
    echo "📁 Creating output directories..."
    mkdir -p {{justfile_directory()}}/{{SENTRY_ADDON_PATH}}/bin/windows/x86_64
    mkdir -p {{justfile_directory()}}/{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64

    # Copy built files to addon directory
    echo "📦 Copying Windows x86_64 DLL files..."
    # We're currently in the build directory, file is in current directory
    if [ -f "libsentry.dll" ]; then
        cp -v libsentry.dll {{justfile_directory()}}/{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.release.x86_64.dll
        echo "✅ Copied libsentry.windows.release.x86_64.dll to project/addons/sentry/bin/windows/x86_64/"
    else
        echo "❌ libsentry.dll not found in build output"
        echo "📁 Current directory: $(pwd)"
        echo "📁 Current directory contents: $(ls -la)"
        exit 1
    fi

    if [ -f "crashpad_handler.exe" ]; then
        cp crashpad_handler.exe {{justfile_directory()}}/{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/
        echo "✅ Copied crashpad_handler.exe"
    else
        echo "⚠️  crashpad_handler.exe not found in build output"
    fi

    # Look for crashpad_wer.dll
    find . -name "crashpad_wer.dll" -exec cp {} {{justfile_directory()}}/{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/ \; 2>/dev/null || echo "⚠️  crashpad_wer.dll not found"


# Build debug variant for x86_64
build-sentry-native-windows-debug:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🐛 Building Windows Sentry Debug DLL (x86_64 only)..."

    # Build x86_64 debug
    echo "🔨 Building debug variant for x86_64..."
    mkdir -p {{SENTRY_PATH}}/build/windows-x86_64-debug
    cd {{SENTRY_PATH}}/build/windows-x86_64-debug

    # Configure with CMake for MinGW-w64 cross-compilation (DEBUG)
    echo "🔧 Configuring CMake for Windows x86_64 (Debug)..."
    cmake ../../modules/sentry-native \
        -DCMAKE_SYSTEM_NAME=Windows \
        -DCMAKE_SYSTEM_PROCESSOR=x86_64 \
        -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
        -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
        -DCMAKE_RC_COMPILER=x86_64-w64-mingw32-windres \
        -DCMAKE_BUILD_TYPE=Debug \
        -DSENTRY_BUILD_RUNTIMESTD=ON \
        -DSENTRY_BUILD_SHARED_LIBS=ON \
        -DSENTRY_BUILD_TESTS=OFF \
        -DSENTRY_BUILD_EXAMPLES=OFF \
        -DCMAKE_INSTALL_PREFIX=install \
        -DSENTRY_TRANSPORT=winhttp \
        -DSENTRY_BACKEND=inproc \
        -DSENTRY_TRANSPORT_COMPRESSION=OFF \
        -G "Unix Makefiles"

    # Build the library (DEBUG)
    echo "🔨 Building Sentry DLL for Windows x86_64 (Debug)..."
    make -j$(nproc) sentry

    echo "✅ Windows Sentry DLL x86_64 (Debug) build completed"

    # Create necessary directories
    echo "📁 Creating output directories for debug build..."
    mkdir -p {{justfile_directory()}}/{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64

    # Copy built files to addon directory (DEBUG)
    echo "📦 Copying Windows x86_64 DLL files (Debug)..."
    # We're currently in the debug build directory, file is in current directory
    if [ -f "libsentry.dll" ]; then
        cp -v libsentry.dll {{justfile_directory()}}/{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.debug.x86_64.dll
        echo "✅ Copied libsentry.windows.debug.x86_64.dll to project/addons/sentry/bin/windows/x86_64/"
    else
        echo "❌ libsentry.dll not found in debug build output"
        echo "📁 Current directory: $(pwd)"
        echo "📁 Current directory contents: $(ls -la)"
        exit 1
    fi

    echo "✅ Windows Sentry debug DLL build and copy completed successfully"

# Package Windows DLLs with all dependencies
sentry-windows-package:
    @echo "📦 Packaging Windows Sentry DLLs..."
    @mkdir -p {{SENTRY_ADDON_PATH}}/bin/windows/x86_64
    @echo "✅ Windows x86_64 directory ready for packaging"

# Install Windows DLLs to addon directory (already done by build commands)
sentry-windows-install: sentry-windows-package
    @echo "📥 Windows Sentry DLLs are already installed during build process"
    @if [ -f "{{SENTRY_ADDON_PATH}}/bin/windows/x86_64/libsentry.windows.release.x86_64.dll" ]; then \
        echo "✅ Windows x86_64 release DLL installed"; \
    else \
        echo "⚠️  Windows x86_64 release DLL missing - run build first"; \
    fi

# Verify Windows Sentry SDK
sentry-windows-verify:
    @echo "🔍 Verifying Windows Sentry SDK setup (x86_64 only)..."
    @if ! command -v x86_64-w64-mingw32-gcc &> /dev/null; then \
        echo "❌ MinGW-w64 x86_64 cross-compiler not found"; \
        echo "💡 Install with: brew install mingw-w64"; \
        exit 1; \
    fi
    @if [ ! -d "{{SENTRY_PATH}}" ]; then \
        echo "❌ Sentry submodule not found at {{SENTRY_PATH}}"; \
        exit 1; \
    fi
    @if [ ! -d "{{SENTRY_ADDON_PATH}}" ]; then \
        echo "❌ Sentry addon not found at {{SENTRY_ADDON_PATH}}"; \
        exit 1; \
    fi
    @echo "✅ Windows Sentry SDK setup verified"

# Clean build artifacts
sentry-windows-clean:
    @echo "🧹 Cleaning Windows Sentry build artifacts..."
    @rm -rf {{SENTRY_PATH}}/build/windows-*
    @rm -rf {{SENTRY_ADDON_PATH}}/bin/windows/
    @echo "✅ Windows Sentry build artifacts cleaned"

# Check build status
sentry-windows-status:
    @echo "📊 Windows Sentry DLL Build Status (x86_64 only)"
    @echo "=============================================="
    @echo "🔧 MinGW-w64 x86_64: $(x86_64-w64-mingw32-gcc --version | head -1 || echo '❌ Not found')"
    @echo "📂 Sentry submodule: {{SENTRY_PATH}}"
    @if [ -d "{{SENTRY_PATH}}" ]; then echo "✅ Found"; else echo "❌ Missing"; fi
    @echo "📂 Sentry addon: {{SENTRY_ADDON_PATH}}"
    @if [ -d "{{SENTRY_ADDON_PATH}}" ]; then echo "✅ Found"; else echo "❌ Missing"; fi
    @echo "📂 Windows x86_64 Release DLL: {{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.release.x86_64.dll"
    @if [ -f "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.release.x86_64.dll" ]; then echo "✅ Built"; else echo "❌ Not built"; fi
    @echo "📂 Windows x86_64 Debug DLL: {{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.debug.x86_64.dll"
    @if [ -f "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.debug.x86_64.dll" ]; then echo "✅ Built"; else echo "❌ Not built"; fi

# Validate Windows DLL integration
sentry-windows-validate:
    @echo "🔧 Validating Windows Sentry DLL integration..."
    @if [ ! -f "{{SENTRY_ADDON_PATH}}/sentry.gdextension" ]; then \
        echo "❌ Sentry GDExtension not found"; \
        exit 1; \
    fi
    @if [ ! -f "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.release.x86_64.dll" ]; then \
        echo "❌ Windows x86_64 release DLL not built - run 'just build-sentry-native-windows-release'"; \
        exit 1; \
    fi
    @if [ ! -f "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/crashpad_handler.exe" ]; then \
        echo "⚠️  crashpad_handler.exe missing for x86_64 (not required with inproc backend)"; \
    fi
    @echo "✅ Windows Sentry DLL validation passed"

# Complete build + package + install workflow
sentry-windows-complete:
    @just sentry-windows-verify
    @just sentry-windows-build
    @just sentry-windows-build-debug
    @just sentry-windows-validate
    @echo "🎉 Windows Sentry complete DLL build workflow finished"