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
# WIN_VM_HOST and WIN_VM_USER defined in justfile-core-config.justfile
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

# Show Windows help (VM + Physical machine)
help-windows:
    @echo "Windows Development Commands"
    @echo "============================"
    @echo ""
    @echo "📋 MACHINE DISTINCTION:"
    @echo "  • win-vm-* → Building templates, headless ({{WIN_VM_HOST}})"
    @echo "  • win-physical-* → Testing exports with GUI ({{WIN_PHYSICAL_HOST}})"
    @echo ""
    @echo "─────────────────────────────────────────────────────────────"
    @echo "🖥️  PHYSICAL MACHINE TESTING ({{WIN_PHYSICAL_HOST}})"
    @echo "─────────────────────────────────────────────────────────────"
    @echo ""
    @echo "CONNECTIVITY:"
    @echo "  just win-physical-status      - Check if machine is awake/reachable"
    @echo "  just win-physical-wake        - Send Wake-on-LAN packet"
    @echo "  just win-physical-wake-wait   - Wake and wait for SSH availability"
    @echo "  just win-physical-verify      - Full connectivity verification"
    @echo "  just win-physical-ssh         - Open interactive SSH session"
    @echo "  just win-physical-cmd CMD     - Run single command via SSH"
    @echo ""
    @echo "DEPLOYMENT:"
    @echo "  just win-physical-deploy      - Deploy latest Windows export (auto-wakes)"
    @echo ""
    @echo "TESTING (Physical, GUI mode):"
    @echo "  just test-windows-physical-target CONFIG  - Run automated test with GUI"
    @echo "  just test-windows-physical-manual CONFIG  - Run test, stays open for inspection"
    @echo ""
    @echo "LOGS:"
    @echo "  just logs-windows-physical TEST_ID        - Retrieve test logs"
    @echo "  just logs-windows-physical-errors TEST_ID - Error-focused analysis"
    @echo ""
    @echo "─────────────────────────────────────────────────────────────"
    @echo "🔧 VM BUILD SYSTEM ({{WIN_VM_HOST}})"
    @echo "─────────────────────────────────────────────────────────────"
    @echo ""
    @echo "ALIGNED PLATFORM COMMANDS:"
    @echo "  just build-all-windows       - Complete build: templates + sentry + package"
    @echo "  just build-windows-templates - Build templates and copy to macOS"
    @echo "  just export-windows-debug    - Export debug build"
    @echo "  just export-windows-release  - Export release build"
    @echo "  just export-windows-all      - Export both debug and release"
    @echo ""
    @echo "TESTING (VM, headless):"
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
    @echo "─────────────────────────────────────────────────────────────"
    @echo "⚙️  CONFIGURATION"
    @echo "─────────────────────────────────────────────────────────────"
    @echo ""
    @echo "Physical Machine:"
    @echo "  WIN_PHYSICAL_HOST: {{WIN_PHYSICAL_HOST}}"
    @echo "  WIN_PHYSICAL_USER: {{WIN_PHYSICAL_USER}}"
    @echo "  WIN_PHYSICAL_MAC:  {{WIN_PHYSICAL_MAC}} (Wake-on-LAN)"
    @echo ""
    @echo "VM Machine:"
    @echo "  WIN_VM_HOST: {{WIN_VM_HOST}}"
    @echo "  WIN_VM_USER: {{WIN_VM_USER}}"
    @echo "  WIN_VM_REPO: {{WIN_VM_REPO}}"
    @echo ""
    @echo "💡 TIP: Physical machine may be sleeping. Use 'just win-physical-wake' first."

# Alias for backward compatibility
win-vm-help: help-windows

# ================================
# WINDOWS PHYSICAL TEST MACHINE
# ================================
# Physical Windows machine for GUI testing (not headless)
# Separate from VM - this machine runs tests only, no building
#
# Machine distinction:
#   win-vm-*   = Windows VM (192.168.50.92) - for BUILDING templates
#   win-physical-* = Windows physical (192.168.50.80) - for TESTING exports

# Windows physical machine SSH connection details
# WIN_PHYSICAL_HOST, WIN_PHYSICAL_USER, WIN_PHYSICAL_MAC defined in justfile-core-config.justfile
WIN_PHYSICAL_DIR := "C:\\GameTwoTests"

# Wake on LAN timeout (seconds to wait for machine to boot)
WIN_PHYSICAL_WAKE_TIMEOUT := "60"

# Send Wake-on-LAN packet to physical machine
win-physical-wake:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📡 Sending Wake-on-LAN to {{WIN_PHYSICAL_HOST}} ({{WIN_PHYSICAL_MAC}})..."
    # Use Python to send magic packet (more portable than wakeonlan)
    python3 -c "import socket; mac='{{WIN_PHYSICAL_MAC}}'.replace(':','').replace('-',''); magic=b'\\xff'*6+bytes.fromhex(mac)*16; s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.setsockopt(socket.SOL_SOCKET,socket.SO_BROADCAST,1); s.sendto(magic,('255.255.255.255',9)); s.close()"
    echo "✅ WoL packet sent"

# Wake physical machine and wait for SSH to be available
win-physical-wake-wait:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🔌 Waking Windows physical machine..."
    echo ""

    # Check if already online
    if ssh -o ConnectTimeout=2 {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "echo ok" &>/dev/null; then
        echo "✅ Machine already online"
        exit 0
    fi

    # Send WoL packet using Python
    echo "📡 Sending Wake-on-LAN packet..."
    python3 -c "import socket; mac='{{WIN_PHYSICAL_MAC}}'.replace(':','').replace('-',''); magic=b'\\xff'*6+bytes.fromhex(mac)*16; s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.setsockopt(socket.SOL_SOCKET,socket.SO_BROADCAST,1); s.sendto(magic,('255.255.255.255',9)); s.close()"

    # Wait for SSH to become available
    echo "⏳ Waiting for machine to boot (timeout: {{WIN_PHYSICAL_WAKE_TIMEOUT}}s)..."
    TIMEOUT={{WIN_PHYSICAL_WAKE_TIMEOUT}}
    ELAPSED=0
    INTERVAL=5

    while [ $ELAPSED -lt $TIMEOUT ]; do
        if ssh -o ConnectTimeout=2 {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "echo ok" &>/dev/null; then
            echo ""
            echo "✅ Machine online after ${ELAPSED}s"
            exit 0
        fi
        echo "   Waiting... (${ELAPSED}s)"
        sleep $INTERVAL
        ELAPSED=$((ELAPSED + INTERVAL))
    done

    echo ""
    echo "❌ Machine did not respond within ${TIMEOUT}s"
    exit 1

# Ensure physical machine is awake (wake if needed, silent if already online)
_win-physical-ensure-awake:
    #!/usr/bin/env bash
    set -euo pipefail

    # Quick check if already online
    if ssh -o ConnectTimeout=3 {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "echo ok" &>/dev/null; then
        exit 0
    fi

    # Not online, wake it
    echo "💤 Machine sleeping, sending Wake-on-LAN..."
    just win-physical-wake-wait

# Verify Windows physical machine connectivity
win-physical-verify:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔍 Verifying Windows physical machine..."
    echo ""
    echo "📡 SSH Connection: {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}}"

    if ! ssh -o ConnectTimeout=5 {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "echo Connected" &>/dev/null; then
        echo "❌ Cannot connect to Windows physical machine"
        echo "   Ensure machine is on and SSH is accessible"
        exit 1
    fi
    echo "✅ SSH connection successful"
    echo ""

    echo "📂 Test directory structure:"
    ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "dir {{WIN_PHYSICAL_DIR}}"

# Open interactive SSH session to Windows physical machine
win-physical-ssh:
    @echo "🖥️  Connecting to Windows physical machine ({{WIN_PHYSICAL_HOST}})..."
    @ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}}

# Run a command on Windows physical machine
win-physical-cmd cmd:
    @ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "{{cmd}}"

# Check Windows physical machine status
win-physical-status:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📊 Windows Test Machine Status"
    echo "=============================="
    echo ""
    echo "Host: {{WIN_PHYSICAL_HOST}}"
    echo "User: {{WIN_PHYSICAL_USER}}"
    echo ""

    if ! ssh -o ConnectTimeout=5 {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "echo ok" &>/dev/null; then
        echo "Status: ❌ OFFLINE"
        exit 1
    fi

    echo "Status: ✅ ONLINE"
    echo ""
    echo "System Info:"
    ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "hostname && echo. && echo User: %USERNAME%"
    echo ""
    echo "Test Directory:"
    ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "dir {{WIN_PHYSICAL_DIR}} 2>nul || echo (not found)"

# ================================
# WINDOWS PHYSICAL TESTING
# ================================
# Testing on physical Windows machine with full GUI (not headless)
# Uses separate deployment and execution from VM testing

# Windows physical machine paths
WIN_PHYSICAL_BUILDS := WIN_PHYSICAL_DIR + "\\builds"
WIN_PHYSICAL_LOGS := WIN_PHYSICAL_DIR + "\\logs"
WIN_PHYSICAL_CONFIGS := WIN_PHYSICAL_DIR + "\\configs"
# Godot user data on physical machine
WIN_PHYSICAL_USER_DATA := "C:\\Users\\" + WIN_PHYSICAL_USER + "\\AppData\\Roaming\\Godot\\app_userdata\\gametwo"

# Deploy Windows export to physical machine
win-physical-deploy:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "📦 Deploying Windows export to physical machine..."
    echo ""

    # Check export exists locally
    WIN_EXE_PATH="export/windows/{{GAME_NAME}}_debug.exe"
    WIN_PCK_PATH="export/windows/{{GAME_NAME}}_debug.pck"

    if [ ! -f "$WIN_EXE_PATH" ]; then
        echo "❌ Windows executable not found at: $WIN_EXE_PATH"
        echo "💡 Run 'just export-windows-debug' first"
        exit 1
    fi

    if [ ! -f "$WIN_PCK_PATH" ]; then
        echo "❌ Windows PCK not found at: $WIN_PCK_PATH"
        echo "💡 Ensure export_presets.cfg has binary_format/embed_pck=false"
        exit 1
    fi

    # Ensure physical machine is awake
    just _win-physical-ensure-awake

    echo "✅ Physical machine reachable"

    # Prepare builds directory
    echo "📂 Preparing builds directory..."
    ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "if exist \"{{WIN_PHYSICAL_DIR}}\\builds\" (rmdir /S /Q \"{{WIN_PHYSICAL_DIR}}\\builds\" && mkdir \"{{WIN_PHYSICAL_DIR}}\\builds\") else (mkdir \"{{WIN_PHYSICAL_DIR}}\\builds\")"

    # Copy entire export/windows folder
    echo "📤 Copying Windows export files..."
    scp -r export/windows/* "{{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}}:/C:/GameTwoTests/builds/"

    # Copy Firebase config if exists
    if [ -f "firebase/google-services-desktop.json" ]; then
        echo "🔥 Copying Firebase config..."
        scp firebase/google-services-desktop.json "{{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}}:/C:/GameTwoTests/builds/"
    fi

    # Verify deployment
    echo ""
    echo "📋 Deployed files:"
    ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "dir {{WIN_PHYSICAL_DIR}}\\builds /B" 2>/dev/null | sed 's/^/   /'

    echo ""
    echo "✅ Windows export deployed to physical machine"

# Deploy debug config to physical machine
_win-physical-deploy-config config_path:
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_PATH="{{config_path}}"
    CONFIG_NAME=$(basename "$CONFIG_PATH" .json)

    echo "📋 Deploying config to physical machine: $CONFIG_NAME"

    # Stop any running game instances
    just _win-physical-stop-app

    # Ensure user data directory exists
    ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "if not exist \"{{WIN_PHYSICAL_USER_DATA}}\" mkdir \"{{WIN_PHYSICAL_USER_DATA}}\""
    ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "if not exist \"{{WIN_PHYSICAL_USER_DATA}}\\logs\" mkdir \"{{WIN_PHYSICAL_USER_DATA}}\\logs\""

    # Remove old config
    ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "del \"{{WIN_PHYSICAL_USER_DATA}}\\debug_startup_actions.json\" 2>nul || echo No old config"

    # Copy new config
    scp "$CONFIG_PATH" "{{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}}:/C:/Users/{{WIN_PHYSICAL_USER}}/AppData/Roaming/Godot/app_userdata/gametwo/debug_startup_actions.json"

    echo "✅ Config deployed"

# Stop running game on physical machine
_win-physical-stop-app:
    @ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "taskkill /IM {{GAME_NAME}}*.exe /F 2>nul || echo No processes to kill" || true

# Run test on physical machine with GUI (automated mode)
test-windows-physical-target config_name="":
    #!/usr/bin/env bash
    set -euo pipefail

    # If no config provided, show fzf selection
    if [ -z "{{config_name}}" ]; then
        selected=$(just _fzf-select-config "windows" "all")
        if [ "$?" -eq 0 ] && [ -n "$selected" ]; then
            CONFIG_NAME="$selected"
        else
            echo "❌ No selection made"
            exit 1
        fi
    else
        CONFIG_NAME="{{config_name}}"
    fi

    echo "🖥️  Windows Physical Machine Testing: $CONFIG_NAME"
    echo "=================================================="
    echo ""
    echo "📍 Target: {{WIN_PHYSICAL_HOST}} (GUI mode)"
    echo ""

    # Ensure physical machine is awake
    just _win-physical-ensure-awake

    # Validate config exists
    CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${CONFIG_NAME}.json"
    if [ ! -f "$CONFIG_PATH" ]; then
        echo "❌ Config not found: $CONFIG_PATH"
        exit 1
    fi

    # Check export is deployed
    if ! ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "if exist \"{{WIN_PHYSICAL_DIR}}\\builds\\{{GAME_NAME}}_debug.exe\" echo exists" | grep -q exists; then
        echo "❌ Windows export not deployed to physical machine"
        echo "💡 Run 'just win-physical-deploy' first"
        exit 1
    fi

    # Generate test ID
    TEST_ID="${CONFIG_NAME}_windows-physical_$(date +%s)"
    echo "🔍 Test ID: $TEST_ID"
    echo ""

    # Create temp config with auto_quit=true
    TEMP_CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${CONFIG_NAME}_physical_automated.json"
    just _inject-auto-quit-metadata "$CONFIG_PATH" "$TEMP_CONFIG_PATH" "true"

    # Deploy config
    just _win-physical-deploy-config "$TEMP_CONFIG_PATH"
    rm -f "$TEMP_CONFIG_PATH"

    # Clear old logs
    echo "🧹 Clearing old logs..."
    ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "del \"{{WIN_PHYSICAL_USER_DATA}}\\logs\\*.log\" 2>nul || echo No old logs"

    # Run test with GUI using PowerShell Start-Process
    # This allows the process to run with GUI even over SSH
    echo "🚀 Starting test with GUI..."
    echo ""

    # Use PowerShell to start the process and wait for it
    ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "powershell -Command \"Start-Process -FilePath '{{WIN_PHYSICAL_DIR}}\\builds\\{{GAME_NAME}}_debug.exe' -ArgumentList '--test-mode','--auto-quit' -WorkingDirectory '{{WIN_PHYSICAL_DIR}}\\builds' -Wait\""

    TEST_EXIT_CODE=$?

    echo ""
    echo "📊 Test Execution: $(if [[ $TEST_EXIT_CODE -eq 0 ]]; then echo '✅ COMPLETED'; else echo '❌ FAILED'; fi)"

    # Retrieve logs
    echo ""
    echo "📥 Retrieving logs..."
    mkdir -p logs
    LOG_FILE="logs/${TEST_ID}.log"

    # Get the latest log file from the physical machine
    REMOTE_LOG=$(ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "powershell -Command \"Get-ChildItem '{{WIN_PHYSICAL_USER_DATA}}\\logs\\*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName\"" 2>/dev/null | tr -d '\r')

    if [ -n "$REMOTE_LOG" ]; then
        # Convert Windows path to SCP format
        SCP_PATH=$(echo "$REMOTE_LOG" | sed 's/\\/\//g' | sed 's/C:/\/C:/')
        scp "{{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}}:${SCP_PATH}" "$LOG_FILE" 2>/dev/null || echo "Warning: Could not retrieve log file"
        echo "📄 Log saved: $LOG_FILE"
    else
        echo "⚠️  No log file found on physical machine"
    fi

    echo ""
    echo "✅ Test completed on Windows physical machine"
    echo "📋 Test ID: $TEST_ID"

# Run test on physical machine in manual mode (stays open)
test-windows-physical-manual config_name:
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_NAME="{{config_name}}"

    echo "🖥️  Windows Physical Machine Testing (Manual Mode): $CONFIG_NAME"
    echo "=============================================================="
    echo ""
    echo "📍 Target: {{WIN_PHYSICAL_HOST}} (GUI mode - stays open)"
    echo ""

    # Ensure physical machine is awake
    just _win-physical-ensure-awake

    # Validate config exists
    CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${CONFIG_NAME}.json"
    if [ ! -f "$CONFIG_PATH" ]; then
        echo "❌ Config not found: $CONFIG_PATH"
        exit 1
    fi

    # Check export is deployed
    if ! ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "if exist \"{{WIN_PHYSICAL_DIR}}\\builds\\{{GAME_NAME}}_debug.exe\" echo exists" | grep -q exists; then
        echo "❌ Windows export not deployed to physical machine"
        echo "💡 Run 'just win-physical-deploy' first"
        exit 1
    fi

    # Create temp config with auto_quit=false
    TEMP_CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${CONFIG_NAME}_physical_manual.json"
    just _inject-auto-quit-metadata "$CONFIG_PATH" "$TEMP_CONFIG_PATH" "false"

    # Deploy config
    just _win-physical-deploy-config "$TEMP_CONFIG_PATH"
    rm -f "$TEMP_CONFIG_PATH"

    # Launch app in background (doesn't wait)
    echo "🚀 Launching app in manual mode..."
    ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "powershell -Command \"Start-Process -FilePath '{{WIN_PHYSICAL_DIR}}\\builds\\{{GAME_NAME}}_debug.exe' -ArgumentList '--test-mode' -WorkingDirectory '{{WIN_PHYSICAL_DIR}}\\builds'\""

    echo ""
    echo "✅ App launched on Windows physical machine"
    echo "💡 The app will stay open for manual inspection"
    echo "💡 Connect via RDP to interact: {{WIN_PHYSICAL_HOST}}"
    echo "🛑 To stop: just _win-physical-stop-app"

# Retrieve logs from physical machine
logs-windows-physical test_id="":
    #!/usr/bin/env bash
    set -euo pipefail

    if [ -z "{{test_id}}" ]; then
        # List available logs
        echo "📋 Available logs on physical machine:"
        ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "dir \"{{WIN_PHYSICAL_USER_DATA}}\\logs\" /B 2>nul" | sed 's/^/   /' || echo "   No logs found"
        echo ""
        echo "💡 Usage: just logs-windows-physical TEST_ID"
    else
        # Retrieve specific log
        TEST_ID="{{test_id}}"
        LOG_FILE="logs/${TEST_ID}.log"

        if [ -f "$LOG_FILE" ]; then
            cat "$LOG_FILE"
        else
            echo "❌ Log file not found locally: $LOG_FILE"
            echo "💡 Logs may still be on the physical machine"
        fi
    fi

# Show errors from physical machine logs
logs-windows-physical-errors test_id:
    #!/usr/bin/env bash
    set -euo pipefail

    TEST_ID="{{test_id}}"
    LOG_FILE="logs/${TEST_ID}.log"

    if [ -f "$LOG_FILE" ]; then
        echo "🔍 Errors in $TEST_ID:"
        echo ""
        grep -i "error\|exception\|fatal\|failed" "$LOG_FILE" || echo "No errors found"
    else
        echo "❌ Log file not found: $LOG_FILE"
    fi