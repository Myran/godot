# Windows Platform Support
# Windows desktop export template building and management for GameTwo
# Native MSVC builds via Windows VM (full Firebase support)
#
# NOTE: MinGW cross-compilation from macOS is NOT supported due to
# Firebase C++ SDK providing only MSVC-compiled libraries (.lib files)
# which are ABI-incompatible with MinGW.

# ================================
# WINDOWS VM CONFIGURATION
# ================================

# Windows VM SSH connection details (UTM ARM64 VM with Visual Studio 2022)
WIN_VM_HOST := "192.168.50.92"
WIN_VM_USER := "runner"
WIN_VM_REPO := "C:\\gametwo"
# Note: vcvars path contains (x86) which requires careful escaping for SSH
WIN_VM_VCVARS := '"C:\\Program Files (x86)\\Microsoft Visual Studio\\2022\\BuildTools\\VC\\Auxiliary\\Build\\vcvars64.bat"'

# ================================
# WINDOWS VM NATIVE BUILDS (MSVC)
# ================================
# These recipes invoke native MSVC builds on Windows VM via SSH
# Required for Firebase C++ SDK integration (MSVC-only libraries)

# Verify Windows VM connectivity and build environment
win-vm-verify:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔍 Verifying Windows VM build environment..."
    echo ""
    echo "📡 SSH Connection: {{WIN_VM_USER}}@{{WIN_VM_HOST}}"

    if ! ssh -o ConnectTimeout=5 {{WIN_VM_USER}}@{{WIN_VM_HOST}} "echo Connected" &>/dev/null; then
        echo "❌ Cannot connect to Windows VM"
        echo "   Ensure VM is running and SSH is accessible"
        exit 1
    fi
    echo "✅ SSH connection successful"
    echo ""

    echo "🔧 Running environment verification on Windows VM..."
    # Use single quotes for the SSH command to avoid bash interpreting (x86)
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} '{{WIN_VM_VCVARS}} && cd {{WIN_VM_REPO}} && just --justfile justfiles\justfile-windows-native.justfile --working-directory . windows-native-verify'

# Build Windows debug template natively on VM (with Firebase support)
win-vm-template-debug jobs="6":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔨 Building Windows debug template on VM (MSVC + Firebase)..."
    echo "   This may take 10-20 minutes on first build"
    echo ""
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} '{{WIN_VM_VCVARS}} && cd {{WIN_VM_REPO}} && just --justfile justfiles\justfile-windows-native.justfile --working-directory . windows-native-template-debug {{jobs}}'

# Build Windows release template natively on VM (with Firebase support)
win-vm-template-release jobs="6":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔨 Building Windows release template on VM (MSVC + Firebase)..."
    echo "   This may take 15-25 minutes on first build"
    echo ""
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} '{{WIN_VM_VCVARS}} && cd {{WIN_VM_REPO}} && just --justfile justfiles\justfile-windows-native.justfile --working-directory . windows-native-template-release {{jobs}}'

# Build both Windows templates natively on VM
win-vm-templates jobs="6":
    just win-vm-template-debug "{{jobs}}"
    just win-vm-template-release "{{jobs}}"
    @echo "✅ Both Windows templates built successfully on VM"

# Package templates from VM (copy to macOS templates/ directory)
win-vm-templates-package:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📦 Packaging Windows templates from VM..."

    # Ensure local templates directory exists
    mkdir -p templates

    # SCP path format for Windows: /C:/path/to/file (forward slashes with drive letter)
    WIN_BIN_PATH="/C:/gametwo/godot/bin"

    # Copy debug template
    echo "📥 Copying debug template..."
    scp "{{WIN_VM_USER}}@{{WIN_VM_HOST}}:${WIN_BIN_PATH}/godot.windows.template_debug.x86_64.exe" templates/

    # Copy release template if it exists
    if ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} 'if exist {{WIN_VM_REPO}}\godot\bin\godot.windows.template_release.x86_64.exe echo exists'; then
        echo "📥 Copying release template..."
        scp "{{WIN_VM_USER}}@{{WIN_VM_HOST}}:${WIN_BIN_PATH}/godot.windows.template_release.x86_64.exe" templates/
    fi

    echo "✅ Windows templates packaged in templates/ directory"
    ls -la templates/godot.windows.template_*.exe 2>/dev/null || true

# Check Windows template build status on VM
win-vm-status:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📊 Windows VM build status..."
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} '{{WIN_VM_VCVARS}} && cd {{WIN_VM_REPO}} && just --justfile justfiles\justfile-windows-native.justfile --working-directory . windows-native-status'

# Build Sentry DLLs natively on VM
win-vm-sentry-all:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔨 Building Sentry DLLs on Windows VM..."
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} '{{WIN_VM_VCVARS}} && cd {{WIN_VM_REPO}} && just --justfile justfiles\justfile-windows-native.justfile --working-directory . windows-native-sentry-all'

# Package Sentry DLLs from VM to macOS
win-vm-sentry-package:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📦 Copying Sentry DLLs from Windows VM..."

    # Ensure local directory exists
    mkdir -p project/addons/sentry/bin/windows/x86_64

    # SCP path format for Windows: /C:/path/to/file (forward slashes with drive letter)
    WIN_SENTRY_PATH="/C:/gametwo/project/addons/sentry/bin/windows/x86_64"
    WIN_CMD_PATH="C:\\gametwo\\project\\addons\\sentry\\bin\\windows\\x86_64"

    # Copy release DLL
    echo "📥 Copying release DLL..."
    if ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "if exist ${WIN_CMD_PATH}\\libsentry.windows.release.x86_64.dll echo exists" | grep -q exists; then
        scp "{{WIN_VM_USER}}@{{WIN_VM_HOST}}:${WIN_SENTRY_PATH}/libsentry.windows.release.x86_64.dll" project/addons/sentry/bin/windows/x86_64/
        echo "✅ Copied libsentry.windows.release.x86_64.dll"
    else
        echo "⚠️  Release DLL not found on VM"
    fi

    # Copy debug DLL
    echo "📥 Copying debug DLL..."
    if ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "if exist ${WIN_CMD_PATH}\\libsentry.windows.debug.x86_64.dll echo exists" | grep -q exists; then
        scp "{{WIN_VM_USER}}@{{WIN_VM_HOST}}:${WIN_SENTRY_PATH}/libsentry.windows.debug.x86_64.dll" project/addons/sentry/bin/windows/x86_64/
        echo "✅ Copied libsentry.windows.debug.x86_64.dll"
    else
        echo "⚠️  Debug DLL not found on VM"
    fi

    # Copy crashpad_handler.exe (critical for crashpad backend)
    echo "📥 Copying crashpad_handler.exe..."
    if ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "if exist ${WIN_CMD_PATH}\\crashpad_handler.exe echo exists" | grep -q exists; then
        scp "{{WIN_VM_USER}}@{{WIN_VM_HOST}}:${WIN_SENTRY_PATH}/crashpad_handler.exe" project/addons/sentry/bin/windows/x86_64/
        echo "✅ Copied crashpad_handler.exe"
    else
        echo "⚠️  crashpad_handler.exe not found on VM"
    fi

    echo "✅ Windows Sentry DLLs packaged"
    ls -la project/addons/sentry/bin/windows/x86_64/

# Build and package Sentry from VM (complete workflow)
win-vm-sentry-complete: win-vm-verify win-vm-sentry-all win-vm-sentry-package
    @echo "✅ Windows Sentry build complete with crashpad backend"

# Sync repository to Windows VM
win-vm-sync:
    #!/usr/bin/env bash
    set -euo pipefail

    # Get current local branch and commit
    LOCAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    LOCAL_COMMIT=$(git rev-parse --short HEAD)

    echo "🔄 Syncing Windows VM to local state..."
    echo "   Branch: ${LOCAL_BRANCH}"
    echo "   Commit: ${LOCAL_COMMIT}"
    echo ""

    # Fetch and hard reset to match origin (avoids merge commits)
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "cd {{WIN_VM_REPO}} && git fetch origin && git checkout ${LOCAL_BRANCH} && git reset --hard origin/${LOCAL_BRANCH}"

    # Sync essential submodules for Windows builds (godot is required, others optional)
    echo "📦 Syncing submodules..."
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "cd {{WIN_VM_REPO}} && git submodule sync && git submodule update --init godot" || true
    # Try other submodules but don't fail if they have unavailable commits
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "cd {{WIN_VM_REPO}} && git submodule update --init extras/firebase-cpp-sdk extras/sentry-godot" 2>/dev/null || echo "   (some optional submodules skipped)"
    # Sentry-godot requires recursive submodule init for crashpad backend
    echo "   Initializing sentry-godot nested submodules (crashpad)..."
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "cd {{WIN_VM_REPO}}/extras/sentry-godot && git submodule update --init --recursive" 2>/dev/null || echo "   (sentry-godot submodules skipped)"

    # Verify alignment
    VM_COMMIT=$(ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "cd {{WIN_VM_REPO}} && git rev-parse --short HEAD")
    if [ "${LOCAL_COMMIT}" = "${VM_COMMIT}" ]; then
        echo "✅ VM synced to ${VM_COMMIT} (matches local)"
    else
        echo "⚠️  WARNING: VM at ${VM_COMMIT}, local at ${LOCAL_COMMIT}"
        echo "   Push local changes first: git push origin ${LOCAL_BRANCH}"
        exit 1
    fi

# Full Windows native pipeline: sync → templates → sentry → package
win-vm-full-pipeline jobs="6": win-vm-sync (win-vm-templates jobs) win-vm-sentry-all win-vm-templates-package
    @echo ""
    @echo "✅ Full Windows native pipeline completed!"
    @echo "   Templates and Sentry DLLs built with MSVC + Firebase support"

# ================================
# ALIGNED PLATFORM COMMANDS
# ================================
# These commands match the naming convention of other platforms
# (Android: build-all-android, iOS: build-ios-all, macOS: build-macos-*)

# Complete Windows build with templates and Sentry (aligned with build-all-android)
build-all-windows force="no" jobs="6": win-vm-verify
    @echo "🪟 FULL BUILD - WINDOWS ONLY (via VM)"
    @echo "======================================"
    @echo "⏱️  Estimated time: 25-40 minutes"
    @echo "📡 Building on Windows VM: {{WIN_VM_HOST}}"
    @echo ""
    just win-vm-sync
    just win-vm-templates "{{jobs}}"
    just win-vm-sentry-all
    just win-vm-templates-package
    @echo ""
    @echo "✅ Windows full build complete!"
    @echo "📁 Templates copied to: templates/"

# Build Windows templates (aligned with build-android-templates, build-macos-templates)
build-windows-templates force="no" jobs="6": win-vm-verify
    @echo "🔨 Building Windows templates on VM..."
    just win-vm-templates "{{jobs}}"
    just win-vm-templates-package

# Export Windows Desktop - Debug only (aligned with export-macos-debug)
export-windows-debug: win-vm-verify
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📦 Exporting Windows Desktop (debug)..."

    # Ensure templates are available locally
    if [ ! -f "templates/godot.windows.template_debug.x86_64.exe" ]; then
        echo "❌ Windows debug template not found locally"
        echo "   Run: just win-vm-templates-package"
        exit 1
    fi

    mkdir -p export/windows

    # Source environment variables
    if [ -f ".env" ]; then
        set -a
        source .env
        set +a
    fi

    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} \
        --export-debug "Windows Desktop" \
        ../export/windows/{{GAME_NAME}}_debug.exe --headless

    echo "✅ Windows debug export completed"
    echo "📁 Debug: export/windows/{{GAME_NAME}}_debug.exe"

# Export Windows Desktop - Release only (aligned with export-macos-release)
export-windows-release: win-vm-verify
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📦 Exporting Windows Desktop (release)..."

    # Ensure templates are available locally
    if [ ! -f "templates/godot.windows.template_release.x86_64.exe" ]; then
        echo "❌ Windows release template not found locally"
        echo "   Run: just win-vm-templates-package"
        exit 1
    fi

    mkdir -p export/windows

    # Source environment variables
    if [ -f ".env" ]; then
        set -a
        source .env
        set +a
    fi

    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} \
        --export-release "Windows Desktop" \
        ../export/windows/{{GAME_NAME}}.exe --headless

    echo "✅ Windows release export completed"
    echo "📁 Release: export/windows/{{GAME_NAME}}.exe"

# Export Windows Desktop - Both debug and release (aligned with export-macos-all)
export-windows-all: export-windows-debug export-windows-release
    @echo "✅ All Windows exports completed successfully"
    @echo "📁 Debug: export/windows/{{GAME_NAME}}_debug.exe"
    @echo "📁 Release: export/windows/{{GAME_NAME}}.exe"

# ================================
# WINDOWS VM TESTING
# ================================

# Clear debug_startup_actions.json from Windows VM
clear-test-windows:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧹 Clearing Windows VM test configuration..."

    WIN_USER_DATA_DIR='C:\Users\{{WIN_VM_USER}}\AppData\Roaming\Godot\app_userdata\gametwo'
    CONFIG_FILE="${WIN_USER_DATA_DIR}\\debug_startup_actions.json"

    # Check if config exists and remove it
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "if exist \"${CONFIG_FILE}\" (del \"${CONFIG_FILE}\" && echo Removed: debug_startup_actions.json) else (echo No config found - already clean)"

    echo "✅ Windows VM test config cleared"
    echo "💡 run-windows will now start without debug actions"

# Clear Windows test cache (alias for consistency with other platforms)
clear-windows-test-cache: clear-test-windows

# ================================
# WINDOWS VM HELPERS
# ================================

# Show Windows help (aligned commands + VM helpers)
help-windows:
    @echo "Windows Build Commands (MSVC via VM)"
    @echo "====================================="
    @echo ""
    @echo "ALIGNED PLATFORM COMMANDS (same as Android/iOS/macOS):"
    @echo "  just build-all-windows       - Complete build: templates + sentry + package"
    @echo "  just build-windows-templates - Build templates and copy to macOS"
    @echo "  just export-windows-debug    - Export debug build"
    @echo "  just export-windows-release  - Export release build"
    @echo "  just export-windows-all      - Export both debug and release"
    @echo ""
    @echo "TESTING (VM):"
    @echo "  just test-windows-target CONFIG  - Run automated test on Windows VM"
    @echo "  just test-windows-manual CONFIG  - Run test manually (stays open)"
    @echo "  just test-windows-update CONFIG  - Update checksum baseline"
    @echo "  just test-windows-reset CONFIG   - Reset checksum baseline"
    @echo "  just clear-test-windows          - Clear test config on VM"
    @echo ""
    @echo "VM MANAGEMENT:"
    @echo "  just win-vm-verify           - Verify VM connectivity and environment"
    @echo "  just win-vm-status           - Check build status on VM"
    @echo "  just win-vm-sync             - Sync git repository to VM"
    @echo ""
    @echo "LOW-LEVEL VM BUILDS:"
    @echo "  just win-vm-template-debug   - Build debug template (~14 min)"
    @echo "  just win-vm-template-release - Build release template (~18 min)"
    @echo "  just win-vm-templates        - Build both templates"
    @echo "  just win-vm-templates-package - Copy templates to macOS"
    @echo "  just win-vm-sentry-all       - Build Sentry DLLs on VM"
    @echo "  just win-vm-full-pipeline    - Full pipeline: sync → build → package"
    @echo ""
    @echo "CONFIGURATION:"
    @echo "  VM Host: {{WIN_VM_HOST}}"
    @echo "  VM User: {{WIN_VM_USER}}"
    @echo "  VM Repo: {{WIN_VM_REPO}}"
    @echo ""
    @echo "NOTE: Windows builds require native MSVC compilation (via Windows VM)"
    @echo "      due to Firebase C++ SDK providing only MSVC-compiled libraries."

# Alias for backward compatibility
win-vm-help: help-windows