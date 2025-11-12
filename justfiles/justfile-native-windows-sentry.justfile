# Windows Sentry DLL Build Commands for GameTwo
# Cross-compilation from macOS to Windows using MinGW-w64
# Runtime GDExtension loaded by Godot at runtime

# Windows Sentry DLL paths (shared variables defined in main Sentry justfile)

# Default Windows Sentry DLL build target
default-sentry-windows:
    @echo "🪟 Windows Sentry DLL Build Commands for GameTwo"
    @echo ""
    @just help-sentry-windows

# Show Windows Sentry DLL build help
help-sentry-windows:
    @echo "🪟 Windows Sentry DLL Build Commands"
    @echo "==================================="
    @echo ""
    @echo "🔧 WINDOWS DLL BUILDS:"
    @echo "  just sentry-windows-build            # Build Windows Sentry DLLs for all architectures"
    @echo "  just sentry-windows-build-x86_64     # Build Windows Sentry DLL for x86_64"
    @echo "  just sentry-windows-build-x86_32     # Build Windows Sentry DLL for x86_32"
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

# All architecture Windows Sentry DLL builds
sentry-windows-build: sentry-windows-build-x86_64 sentry-windows-build-x86_32
    @echo "✅ Windows Sentry DLL builds for all architectures completed"

# Build Windows Sentry DLL for x86_64 architecture
sentry-windows-build-x86_64:
    #!/usr/bin/env bash
    set -euo pipefail
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

    # Create output directory
    mkdir -p {{SENTRY_ADDON_PATH}}/bin/windows/x86_64

    # Copy built files to addon directory
    echo "📦 Copying Windows x86_64 DLL files..."
    if [ -f "libsentry.dll" ]; then
        mkdir -p {{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/
        cp libsentry.dll {{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.release.x86_64.dll
        echo "✅ Copied libsentry.windows.release.x86_64.dll to project/addons/sentry/bin/windows/x86_64/"
    else
        echo "⚠️  libsentry.dll not found in build output"
    fi

    if [ -f "crashpad_handler.exe" ]; then
        mkdir -p {{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/
        cp crashpad_handler.exe {{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/
        echo "✅ Copied crashpad_handler.exe"
    else
        echo "⚠️  crashpad_handler.exe not found in build output"
    fi

    # Look for crashpad_wer.dll
    find . -name "crashpad_wer.dll" -exec cp {} {{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/ \; 2>/dev/null || echo "⚠️  crashpad_wer.dll not found"

# Build Windows Sentry DLL for x86_32 architecture
sentry-windows-build-x86_32:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🏗️  Building Windows Sentry DLL for x86_32..."

    # Check MinGW-w32 cross-compiler
    if ! command -v i686-w64-mingw32-gcc &> /dev/null; then
        echo "❌ MinGW-w32 cross-compiler not found"
        echo "💡 Install with: brew install mingw-w64"
        exit 1
    fi

    # Create build directory
    mkdir -p {{SENTRY_PATH}}/build/windows-x86_32
    cd {{SENTRY_PATH}}/build/windows-x86_32

    # Configure with CMake for MinGW-w32 cross-compilation
    echo "🔧 Configuring CMake for Windows x86_32..."
    cmake ../../modules/sentry-native \
        -DCMAKE_SYSTEM_NAME=Windows \
        -DCMAKE_SYSTEM_PROCESSOR=x86_32 \
        -DCMAKE_C_COMPILER=i686-w64-mingw32-gcc \
        -DCMAKE_CXX_COMPILER=i686-w64-mingw32-g++ \
        -DCMAKE_RC_COMPILER=i686-w64-mingw32-windres \
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
    echo "🔨 Building Sentry DLL for Windows x86_32..."
    make -j$(nproc) sentry
    make -j$(nproc) crashpad_handler

    echo "✅ Windows Sentry DLL x86_32 build completed"

    # Create output directory
    mkdir -p {{SENTRY_ADDON_PATH}}/bin/windows/x86_32

    # Copy built files to addon directory
    echo "📦 Copying Windows x86_32 DLL files..."
    if [ -f "libsentry.dll" ]; then
        mkdir -p {{PROJECT_SENTRY_PATH}}/bin/windows/x86_32/
        cp libsentry.dll {{PROJECT_SENTRY_PATH}}/bin/windows/x86_32/libsentry.windows.release.x86_32.dll
        echo "✅ Copied libsentry.windows.release.x86_32.dll to project/addons/sentry/bin/windows/x86_32/"
    else
        echo "⚠️  libsentry.dll not found in build output"
    fi

    if [ -f "crashpad_handler.exe" ]; then
        mkdir -p {{PROJECT_SENTRY_PATH}}/bin/windows/x86_32/
        cp crashpad_handler.exe {{PROJECT_SENTRY_PATH}}/bin/windows/x86_32/
        echo "✅ Copied crashpad_handler.exe"
    else
        echo "⚠️  crashpad_handler.exe not found in build output"
    fi

    # Look for crashpad_wer.dll
    find . -name "crashpad_wer.dll" -exec cp {} {{PROJECT_SENTRY_PATH}}/bin/windows/x86_32/ \; 2>/dev/null || echo "⚠️  crashpad_wer.dll not found"

# Build debug variants for both architectures
sentry-windows-build-debug:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🐛 Building Windows Sentry Debug DLLs..."

    # Build x86_64 debug
    echo "🔨 Building debug variant for x86_64..."
    mkdir -p {{SENTRY_PATH}}/build/windows-x86_64-debug
    cd {{SENTRY_PATH}}/build/windows-x86_64-debug

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
        -G "Unix Makefiles"

    make -j$(nproc) sentry

    if [ -f "libsentry.dll" ]; then
        cp libsentry.dll {{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.debug.x86_64.dll
        echo "✅ Copied libsentry.windows.debug.x86_64.dll"
    fi

    # Build x86_32 debug
    echo "🔨 Building debug variant for x86_32..."
    mkdir -p {{SENTRY_PATH}}/build/windows-x86_32-debug
    cd {{SENTRY_PATH}}/build/windows-x86_32-debug

    cmake ../../modules/sentry-native \
        -DCMAKE_SYSTEM_NAME=Windows \
        -DCMAKE_SYSTEM_PROCESSOR=x86_32 \
        -DCMAKE_C_COMPILER=i686-w64-mingw32-gcc \
        -DCMAKE_CXX_COMPILER=i686-w64-mingw32-g++ \
        -DCMAKE_RC_COMPILER=i686-w64-mingw32-windres \
        -DCMAKE_BUILD_TYPE=Debug \
        -DSENTRY_BUILD_RUNTIMESTD=ON \
        -DSENTRY_BUILD_SHARED_LIBS=ON \
        -DSENTRY_BUILD_TESTS=OFF \
        -DSENTRY_BUILD_EXAMPLES=OFF \
        -G "Unix Makefiles"

    make -j$(nproc) sentry

    if [ -f "libsentry.dll" ]; then
        cp libsentry.dll {{PROJECT_SENTRY_PATH}}/bin/windows/x86_32/libsentry.windows.debug.x86_32.dll
        echo "✅ Copied libsentry.windows.debug.x86_32.dll"
    fi

    echo "✅ Windows Sentry debug DLLs build completed"

# Package Windows DLLs with all dependencies
sentry-windows-package:
    @echo "📦 Packaging Windows Sentry DLLs..."
    @mkdir -p {{SENTRY_ADDON_PATH}}/bin/windows/x86_64
    @mkdir -p {{SENTRY_ADDON_PATH}}/bin/windows/x86_32
    @echo "✅ Windows directories ready for packaging"

# Install Windows DLLs to addon directory (already done by build commands)
sentry-windows-install: sentry-windows-package
    @echo "📥 Windows Sentry DLLs are already installed during build process"
    @if [ -f "{{SENTRY_ADDON_PATH}}/bin/windows/x86_64/libsentry.windows.release.x86_64.dll" ]; then \
        echo "✅ Windows x86_64 release DLL installed"; \
    else \
        echo "⚠️  Windows x86_64 release DLL missing - run build first"; \
    fi
    @if [ -f "{{SENTRY_ADDON_PATH}}/bin/windows/x86_32/libsentry.windows.release.x86_32.dll" ]; then \
        echo "✅ Windows x86_32 release DLL installed"; \
    else \
        echo "⚠️  Windows x86_32 release DLL missing - run build first"; \
    fi

# Verify Windows Sentry SDK
sentry-windows-verify:
    @echo "🔍 Verifying Windows Sentry SDK setup..."
    @if ! command -v x86_64-w64-mingw32-gcc &> /dev/null; then \
        echo "❌ MinGW-w64 x86_64 cross-compiler not found"; \
        echo "💡 Install with: brew install mingw-w64"; \
        exit 1; \
    fi
    @if ! command -v i686-w64-mingw32-gcc &> /dev/null; then \
        echo "❌ MinGW-w32 cross-compiler not found"; \
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
    @echo "📊 Windows Sentry DLL Build Status"
    @echo "================================="
    @echo "🔧 MinGW-w64 x86_64: $(x86_64-w64-mingw32-gcc --version | head -1 || echo '❌ Not found')"
    @echo "🔧 MinGW-w32 x86_32: $(i686-w64-mingw32-gcc --version | head -1 || echo '❌ Not found')"
    @echo "📂 Sentry submodule: {{SENTRY_PATH}}"
    @if [ -d "{{SENTRY_PATH}}" ]; then echo "✅ Found"; else echo "❌ Missing"; fi
    @echo "📂 Sentry addon: {{SENTRY_ADDON_PATH}}"
    @if [ -d "{{SENTRY_ADDON_PATH}}" ]; then echo "✅ Found"; else echo "❌ Missing"; fi
    @echo "📂 Windows x86_64 DLL: {{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.release.x86_64.dll"
    @if [ -f "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.release.x86_64.dll" ]; then echo "✅ Built"; else echo "❌ Not built"; fi
    @echo "📂 Windows x86_32 DLL: {{PROJECT_SENTRY_PATH}}/bin/windows/x86_32/libsentry.windows.release.x86_32.dll"
    @if [ -f "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_32/libsentry.windows.release.x86_32.dll" ]; then echo "✅ Built"; else echo "❌ Not built"; fi

# Validate Windows DLL integration
sentry-windows-validate:
    @echo "🔧 Validating Windows Sentry DLL integration..."
    @if [ ! -f "{{SENTRY_ADDON_PATH}}/sentry.gdextension" ]; then \
        echo "❌ Sentry GDExtension not found"; \
        exit 1; \
    fi
    @if [ ! -f "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/libsentry.windows.release.x86_64.dll" ]; then \
        echo "❌ Windows x86_64 release DLL not built - run 'just sentry-windows-build-x86_64'"; \
        exit 1; \
    fi
    @if [ ! -f "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_64/crashpad_handler.exe" ]; then \
        echo "⚠️  crashpad_handler.exe missing for x86_64 (not required with inproc backend)"; \
    fi
    @if [ ! -f "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_32/libsentry.windows.release.x86_32.dll" ]; then \
        echo "❌ Windows x86_32 release DLL not built - run 'just sentry-windows-build-x86_32'"; \
        exit 1; \
    fi
    @if [ ! -f "{{PROJECT_SENTRY_PATH}}/bin/windows/x86_32/crashpad_handler.exe" ]; then \
        echo "⚠️  crashpad_handler.exe missing for x86_32 (not required with inproc backend)"; \
    fi
    @echo "✅ Windows Sentry DLL validation passed"

# Complete build + package + install workflow
sentry-windows-complete:
    @just sentry-windows-verify
    @just sentry-windows-build
    @just sentry-windows-build-debug
    @just sentry-windows-validate
    @echo "🎉 Windows Sentry complete DLL build workflow finished"