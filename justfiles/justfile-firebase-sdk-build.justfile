# Firebase C++ SDK Build Recipes
# Build Firebase SDK from source with debug symbols for debugging crashes
#
# Naming: build-firebase-sdk-<platform>-<target>
#
# NOTE: These recipes build the Firebase C++ SDK from source to enable:
# - Debug symbols (PDB files on Windows) for crash debugging
# - Custom logging within Firebase SDK
# - Understanding internal SDK behavior
# - Patching SDK if needed

# Firebase SDK paths
FIREBASE_SDK_SRC := justfile_directory() + "/extras/firebase-cpp-sdk"
FIREBASE_SDK_OUTPUT := justfile_directory() + "/firebase/firebase_cpp_sdk"

# Windows Firebase SDK build configuration
FIREBASE_WINDOWS_BUILD_DIR := "C:\\firebase-sdk-build"
FIREBASE_WINDOWS_OPENSSL := "C:\\Program Files\\OpenSSL-Win64"

# ================================
# WINDOWS FIREBASE SDK BUILD (Task-436)
# ================================
# Build Firebase C++ SDK from source on Windows physical machine
# This generates debug symbols (PDB) for crash debugging

# Verify Windows physical machine has required dependencies
build-firebase-sdk-windows-check-deps:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔍 Checking Firebase SDK build dependencies on Windows physical..."
    echo ""
    echo "📡 Connecting to {{WIN_PHYSICAL_HOST}}..."

    # Check SSH connection
    if ! ssh -o ConnectTimeout=5 {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "echo Connected" &>/dev/null; then
        echo "❌ Cannot connect to Windows physical machine"
        echo "💡 Ensure machine is online: just win-physical-wake"
        exit 1
    fi
    echo "✅ SSH connection successful"

    # Check Visual Studio
    echo ""
    echo "🔍 Checking Visual Studio 2022..."
    VS_PATH="C:\\Program Files (x86)\\Microsoft Visual Studio\\2022\\BuildTools\\VC\\Auxiliary\\Build\\vcvars64.bat"
    if ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "if exist \"${VS_PATH}\" echo exists" | grep -q exists; then
        echo "✅ Visual Studio 2022 Build Tools found"
    else
        echo "❌ Visual Studio 2022 Build Tools not found"
        echo "   Required: ${VS_PATH}"
        exit 1
    fi

    # Check CMake
    echo ""
    echo "🔍 Checking CMake..."
    if ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "cmake --version" 2>/dev/null; then
        echo "✅ CMake found"
    else
        echo "❌ CMake not found in PATH"
        echo "   Install from: https://cmake.org/download/"
        echo "   Ensure 'Add CMake to system PATH' is selected during install"
        exit 1
    fi

    # Check OpenSSL
    echo ""
    echo "🔍 Checking OpenSSL for Windows..."
    if ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "if exist \"{{FIREBASE_WINDOWS_OPENSSL}}\" echo exists" | grep -q exists; then
        echo "✅ OpenSSL found at {{FIREBASE_WINDOWS_OPENSSL}}"
    else
        echo "❌ OpenSSL not found at {{FIREBASE_WINDOWS_OPENSSL}}"
        echo "   Install from: https://slproweb.com/products/Win32OpenSSL.html"
        echo "   Choose: Win64 OpenSSL v3.x.x (Light)"
        exit 1
    fi

    # Check Python
    echo ""
    echo "🔍 Checking Python..."
    if ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "python --version" 2>/dev/null; then
        echo "✅ Python found"
    else
        echo "⚠️  Python not found (may be required for some SDK features)"
    fi

    echo ""
    echo "✅ All dependencies checked"
    echo ""
    echo "📋 Build Configuration:"
    echo "   Source:      {{FIREBASE_SDK_SRC}}"
    echo "   Output:      {{FIREBASE_SDK_OUTPUT}}"
    echo "   Build Dir:   {{FIREBASE_WINDOWS_BUILD_DIR}}"
    echo "   OpenSSL:     {{FIREBASE_WINDOWS_OPENSSL}}"

# Sync Firebase SDK source to Windows physical machine
build-firebase-sdk-windows-sync:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔄 Syncing Firebase SDK source to Windows physical machine..."
    echo ""

    # Ensure machine is awake
    just _win-physical-ensure-awake

    # Create build directory
    echo "📂 Creating build directory..."
    ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "if not exist \"{{FIREBASE_WINDOWS_BUILD_DIR}}\" mkdir \"{{FIREBASE_WINDOWS_BUILD_DIR}}\""

    # Check if SDK source exists locally
    if [ ! -d "{{FIREBASE_SDK_SRC}}" ]; then
        echo "❌ Firebase SDK source not found locally"
        echo "   Expected: {{FIREBASE_SDK_SRC}}"
        exit 1
    fi

    # Check if git submodule is initialized
    if [ ! -f "{{FIREBASE_SDK_SRC}}/CMakeLists.txt" ]; then
        echo "❌ Firebase SDK submodule not initialized"
        echo "   Run: git submodule update --init extras/firebase-cpp-sdk"
        exit 1
    fi

    echo "✅ SDK source found locally"

    # Sync via tarball (more reliable than rsync to Windows)
    echo "📤 Syncing source files to Windows (this may take a few minutes)..."

    TEMP_TAR="/tmp/firebase-sdk-source.tar.gz"
    echo "   Creating tarball..."
    tar czf "$TEMP_TAR" -C "{{FIREBASE_SDK_SRC}}" .

    echo "   Transferring to Windows..."
    scp "$TEMP_TAR" "{{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}}:/C:/firebase-sdk-source.tar.gz"

    echo "   Extracting on Windows..."
    ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "cd {{FIREBASE_WINDOWS_BUILD_DIR}} && tar xzf C:\\firebase-sdk-source.tar.gz && del C:\\firebase-sdk-source.tar.gz"

    rm -f "$TEMP_TAR"

    echo "✅ Firebase SDK synced to Windows"
    echo "   Remote: {{FIREBASE_WINDOWS_BUILD_DIR}}"

# Build Firebase SDK for Windows (Debug configuration with symbols)
build-firebase-sdk-windows-build-debug:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔨 Building Firebase C++ SDK for Windows (Debug with symbols)..."
    echo ""
    echo "⏱️  Estimated time: 15-30 minutes"
    echo ""

    # Ensure machine is awake
    just _win-physical-ensure-awake

    # Create build directory
    echo "📂 Creating build-debug directory..."
    ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "cd {{FIREBASE_WINDOWS_BUILD_DIR}} && if not exist build-debug mkdir build-debug"

    # Run CMake configuration
    echo "📋 Configuring CMake for Debug build..."
    # Note: Requires CMake 3.x (not 4.x) for compatibility with Firebase SDK external dependencies
    # Firestore is disabled due to missing external project sources in this build workflow
    CMAKE_CMD="cd {{FIREBASE_WINDOWS_BUILD_DIR}}\\build-debug && cmake .. -A x64 -DCMAKE_BUILD_TYPE=Debug -DFIREBASE_INCLUDE_DATABASE=ON -DFIREBASE_INCLUDE_AUTH=ON -DFIREBASE_INCLUDE_ANALYTICS=ON -DFIREBASE_INCLUDE_REMOTE_CONFIG=ON -DFIREBASE_INCLUDE_MESSAGING=ON -DFIREBASE_INCLUDE_FUNCTIONS=ON -DFIREBASE_INCLUDE_STORAGE=ON -DFIREBASE_INCLUDE_FIRESTORE=OFF -DOPENSSL_ROOT_DIR=\"{{FIREBASE_WINDOWS_OPENSSL}}\" -DCMAKE_C_FLAGS_DEBUG=\"/Zi /Od\" -DCMAKE_CXX_FLAGS_DEBUG=\"/Zi /Od\" -DCMAKE_EXE_LINKER_FLAGS_DEBUG=\"/DEBUG /INCREMENTAL:NO\" -DCMAKE_SHARED_LINKER_FLAGS_DEBUG=\"/DEBUG /INCREMENTAL:NO\""

    if ! ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "${CMAKE_CMD}"; then
        echo "❌ CMake configuration failed"
        exit 1
    fi
    echo "✅ CMake configuration complete"

    # Build with MSBuild
    echo "🔨 Building with MSBuild (Debug)..."
    BUILD_CMD="cd {{FIREBASE_WINDOWS_BUILD_DIR}}\\build-debug && cmake --build . --config Debug -- -nologo -verbosity:minimal"

    if ! ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "${BUILD_CMD}"; then
        echo "❌ Build failed"
        exit 1
    fi

    echo "✅ Debug build complete!"
    echo ""
    echo "📦 Build artifacts:"
    echo "   Location: {{FIREBASE_WINDOWS_BUILD_DIR}}\\build-debug"
    echo ""
    echo "🔍 Debug symbols (PDB files):"
    ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "dir /s /b {{FIREBASE_WINDOWS_BUILD_DIR}}\\build-debug\\*.pdb 2>nul || echo No PDB files found yet"

# Build Firebase SDK for Windows (Release configuration)
build-firebase-sdk-windows-build-release:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔨 Building Firebase C++ SDK for Windows (Release)..."
    echo ""
    echo "⏱️  Estimated time: 10-20 minutes"
    echo ""

    # Ensure machine is awake
    just _win-physical-ensure-awake

    # Create build directory
    echo "📂 Creating build-release directory..."
    ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "cd {{FIREBASE_WINDOWS_BUILD_DIR}} && if not exist build-release mkdir build-release"

    # Run CMake configuration
    echo "📋 Configuring CMake for Release build..."
    # Note: Requires CMake 3.x (not 4.x) for compatibility with Firebase SDK external dependencies
    # Firestore is disabled due to missing external project sources in this build workflow
    CMAKE_CMD="cd {{FIREBASE_WINDOWS_BUILD_DIR}}\\build-release && cmake .. -A x64 -DCMAKE_BUILD_TYPE=Release -DFIREBASE_INCLUDE_DATABASE=ON -DFIREBASE_INCLUDE_AUTH=ON -DFIREBASE_INCLUDE_ANALYTICS=ON -DFIREBASE_INCLUDE_REMOTE_CONFIG=ON -DFIREBASE_INCLUDE_MESSAGING=ON -DFIREBASE_INCLUDE_FUNCTIONS=ON -DFIREBASE_INCLUDE_STORAGE=ON -DFIREBASE_INCLUDE_FIRESTORE=OFF -DOPENSSL_ROOT_DIR=\"{{FIREBASE_WINDOWS_OPENSSL}}\""

    if ! ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "${CMAKE_CMD}"; then
        echo "❌ CMake configuration failed"
        exit 1
    fi
    echo "✅ CMake configuration complete"

    # Build with MSBuild
    echo "🔨 Building with MSBuild (Release)..."
    BUILD_CMD="cd {{FIREBASE_WINDOWS_BUILD_DIR}}\\build-release && cmake --build . --config Release -- -nologo -verbosity:minimal"

    if ! ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "${BUILD_CMD}"; then
        echo "❌ Build failed"
        exit 1
    fi

    echo "✅ Release build complete!"
    echo ""
    echo "📦 Build artifacts:"
    echo "   Location: {{FIREBASE_WINDOWS_BUILD_DIR}}\\build-release"

# Build both Debug and Release configurations
build-firebase-sdk-windows-build-all: build-firebase-sdk-windows-build-debug build-firebase-sdk-windows-build-release
    @echo "✅ Firebase SDK Windows builds complete!"

# Package built libraries from Windows back to project
build-firebase-sdk-windows-package-debug:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📦 Packaging Firebase SDK Debug libraries from Windows..."
    echo ""

    # Ensure local output directory exists
    OUTPUT_DIR="{{FIREBASE_SDK_OUTPUT}}/libs/windows/VS2019/MT/x64/Debug"
    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR/symbols"

    # Firebase modules to package (built in subdirectories)
    MODULES="analytics app app_check auth database functions installations messaging remote_config storage"

    # Copy .lib files from module subdirectories
    echo "📥 Copying Debug libraries..."
    for module in $MODULES; do
        LIB_PATH="{{FIREBASE_WINDOWS_BUILD_DIR}}/build-debug/${module}/Debug/firebase_${module}.lib"
        if ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "if exist \"${LIB_PATH}\" echo exists" | grep -q exists; then
            echo "   ✅ firebase_${module}.lib"
            scp "{{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}}:/C:/firebase-sdk-build/build-debug/${module}/Debug/firebase_${module}.lib" "$OUTPUT_DIR/"
        fi
    done

    # Copy app rest lib (nested directory)
    REST_LIB="{{FIREBASE_WINDOWS_BUILD_DIR}}/build-debug/app/rest/Debug/firebase_rest_lib.lib"
    if ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "if exist \"${REST_LIB}\" echo exists" | grep -q exists; then
        echo "   ✅ firebase_rest_lib.lib"
        scp "{{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}}:/C:/firebase-sdk-build/build-debug/app/rest/Debug/firebase_rest_lib.lib" "$OUTPUT_DIR/"
    fi

    # Copy .pdb files from module subdirectories
    echo ""
    echo "📥 Copying Debug symbols (PDB)..."
    for module in $MODULES; do
        PDB_PATH="{{FIREBASE_WINDOWS_BUILD_DIR}}/build-debug/${module}/Debug/firebase_${module}.pdb"
        if ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "if exist \"${PDB_PATH}\" echo exists" | grep -q exists; then
            echo "   ✅ firebase_${module}.pdb"
            scp "{{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}}:/C:/firebase-sdk-build/build-debug/${module}/Debug/firebase_${module}.pdb" "$OUTPUT_DIR/symbols/"
        fi
    done

    # Copy app rest pdb
    REST_PDB="{{FIREBASE_WINDOWS_BUILD_DIR}}/build-debug/app/rest/Debug/firebase_rest_lib.pdb"
    if ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "if exist \"${REST_PDB}\" echo exists" | grep -q exists; then
        echo "   ✅ firebase_rest_lib.pdb"
        scp "{{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}}:/C:/firebase-sdk-build/build-debug/app/rest/Debug/firebase_rest_lib.pdb" "$OUTPUT_DIR/symbols/"
    fi

    echo ""
    echo "✅ Debug libraries packaged"
    echo ""
    echo "📁 Libraries:"
    ls -la "$OUTPUT_DIR"/*.lib 2>/dev/null | awk '{print "   " $NF " (" $5 " bytes)"}' || echo "   (none)"
    echo ""
    echo "🔍 Debug symbols:"
    ls -la "$OUTPUT_DIR/symbols"/*.pdb 2>/dev/null | awk '{print "   " $NF}' || echo "   (none)"

# Package release libraries
build-firebase-sdk-windows-package-release:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📦 Packaging Firebase SDK Release libraries from Windows..."
    echo ""

    # Ensure local output directory exists
    mkdir -p "{{FIREBASE_SDK_OUTPUT}}/libs/windows/VS2019/MT/x64/Release"

    # Copy .lib files
    echo "📥 Copying Release libraries..."
    scp "{{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}}:{{FIREBASE_WINDOWS_BUILD_DIR}}/build-release/*.lib" \
        "{{FIREBASE_SDK_OUTPUT}}/libs/windows/VS2019/MT/x64/Release/" 2>/dev/null || echo "   No .lib files in root build dir"

    echo "✅ Release libraries packaged"
    echo ""
    echo "📁 Contents:"
    ls -la "{{FIREBASE_SDK_OUTPUT}}/libs/windows/VS2019/MT/x64/Release/" 2>/dev/null | head -20 || echo "   (empty)"

# Complete workflow: sync + build + package (Debug)
build-firebase-sdk-windows-debug-complete: build-firebase-sdk-windows-check-deps build-firebase-sdk-windows-sync build-firebase-sdk-windows-build-debug build-firebase-sdk-windows-package-debug
    @echo ""
    @echo "✅ Firebase SDK Windows Debug build complete!"
    @echo ""
    @echo "📦 Libraries packaged to: {{FIREBASE_SDK_OUTPUT}}/libs/windows/VS2019/MT/x64/Debug/"
    @echo "🔍 Debug symbols: {{FIREBASE_SDK_OUTPUT}}/libs/windows/VS2019/MT/x64/Debug/symbols/"
    @echo ""
    @echo "Next steps:"
    @echo "1. Rebuild Godot templates: just win-vm-templates-rebuild"
    @echo "2. Export Windows: just export-windows-debug"
    @echo "3. Test and debug: just test-windows-physical-target <config>"

# Complete workflow: sync + build + package (Release)
build-firebase-sdk-windows-release-complete: build-firebase-sdk-windows-check-deps build-firebase-sdk-windows-sync build-firebase-sdk-windows-build-release build-firebase-sdk-windows-package-release
    @echo ""
    @echo "✅ Firebase SDK Windows Release build complete!"
    @echo ""
    @echo "📦 Libraries packaged to: {{FIREBASE_SDK_OUTPUT}}/libs/windows/VS2019/MT/x64/Release/"
    @echo ""
    @echo "Next steps:"
    @echo "1. Rebuild Godot templates: just win-vm-templates-rebuild"
    @echo "2. Export Windows: just export-windows-release"
    @echo "3. Test: just test-windows-physical-release-target <config>"

# Show Firebase SDK build help
help-firebase-sdk:
    @echo "Firebase C++ SDK Build Recipes (Task-436)"
    @echo "=========================================="
    @echo ""
    @echo "Windows Builds:"
    @echo "  just build-firebase-sdk-windows-check-deps        - Check build dependencies"
    @echo "  just build-firebase-sdk-windows-sync              - Sync source to Windows"
    @echo "  just build-firebase-sdk-windows-build-debug       - Build Debug with symbols"
    @echo "  just build-firebase-sdk-windows-build-release     - Build Release"
    @echo "  just build-firebase-sdk-windows-build-all         - Build Debug + Release"
    @echo "  just build-firebase-sdk-windows-package-debug     - Package Debug libraries"
    @echo "  just build-firebase-sdk-windows-package-release   - Package Release libraries"
    @echo ""
    @echo "Complete Workflows:"
    @echo "  just build-firebase-sdk-windows-debug-complete    - Full Debug build"
    @echo "  just build-firebase-sdk-windows-release-complete  - Full Release build"
    @echo ""
    @echo "📋 Configuration:"
    @echo "   Source:      {{FIREBASE_SDK_SRC}}"
    @echo "   Output:      {{FIREBASE_SDK_OUTPUT}}"
    @echo "   Build Dir:   {{FIREBASE_WINDOWS_BUILD_DIR}}"
    @echo "   OpenSSL:     {{FIREBASE_WINDOWS_OPENSSL}}"
    @echo ""
    @echo "🔧 Debug symbols enable:"
    @echo "   - Stack trace debugging in Visual Studio"
    @echo "   - Sentry crash reports with function names"
    @echo "   - Step-through debugging in Firebase SDK code"
    @echo ""
    @echo "⚠️  Prerequisites:"
    @echo "   1. CMake installed and in PATH"
    @echo "   2. OpenSSL-Win64 at {{FIREBASE_WINDOWS_OPENSSL}}"
    @echo "   3. Visual Studio 2022 Build Tools"
