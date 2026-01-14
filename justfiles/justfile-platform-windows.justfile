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

# Windows VM SSH connection details
# WIN_VM_HOST, WIN_VM_USER, WIN_VM_REPO, WIN_VM_VCVARS defined in justfile-core-config.justfile

# ================================
# WINDOWS VM NATIVE BUILDS (MSVC)
# ================================
# These recipes invoke native MSVC builds on Windows VM via SSH
# Required for Firebase C++ SDK integration (MSVC-only libraries)

# Verify Windows VM connectivity and build environment (backward compatibility alias)
win-vm-verify:
    just build-windows-vm-verify

# Build Windows debug template natively on VM (backward compatibility alias)
win-vm-template-debug jobs="6":
    just build-windows-vm-template-debug "{{jobs}}"

# Build Windows release template natively on VM (backward compatibility alias)
win-vm-template-release jobs="6":
    just build-windows-vm-template-release "{{jobs}}"

# Build both Windows templates natively on VM (backward compatibility alias)
win-vm-templates jobs="6":
    just build-windows-vm-templates "{{jobs}}"

# Clean Windows template build cache on VM (forces full rebuild)
# Use this when SCsub/LINKFLAGS changes but no source files changed
win-vm-templates-clean:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧹 Cleaning Windows template build cache on VM..."
    echo "   This will force SCons to rebuild from scratch"
    echo ""
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} 'cd {{WIN_VM_REPO}}\godot && if exist .sconsign.dblite del .sconsign.dblite && echo Deleted SCons cache'
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} 'cd {{WIN_VM_REPO}}\godot && if exist bin\obj rmdir /s /q bin\obj && echo Deleted object files'
    echo "✅ Windows template build cache cleaned"
    echo "   Next build will be a full rebuild (~15-25 min)"

# Force clean rebuild of Windows templates on VM
win-vm-templates-rebuild jobs="6": win-vm-templates-clean
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔨 Force clean rebuild of Windows templates on VM..."
    just win-vm-templates "{{jobs}}"
    echo "✅ Clean rebuild completed"

# Package templates from VM (copy to macOS templates/ directory) - backward compatibility alias
win-vm-templates-package:
    just build-windows-vm-templates-package

# Check Windows template build status on VM - backward compatibility alias
win-vm-status:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📊 Windows VM build status..."
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} '{{WIN_VM_VCVARS}} && cd {{WIN_VM_REPO}} && just --justfile justfiles\justfile-windows-native.justfile --working-directory . windows-native-status'

# Build Sentry DLLs natively on VM (native Sentry - compiled into Godot executable)
build-sentry-native-windows-vm-build-all:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔨 Building Sentry DLLs on Windows VM..."
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} '{{WIN_VM_VCVARS}} && cd {{WIN_VM_REPO}} && just --justfile justfiles\justfile-windows-native.justfile --working-directory . windows-native-sentry-all'

# Package Sentry DLLs from VM to macOS (native Sentry - compiled into Godot executable)
build-sentry-native-windows-vm-package:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📦 Copying Sentry DLLs and PDBs from Windows VM..."

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

    # Copy release PDB
    echo "📥 Copying release PDB..."
    if ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "if exist ${WIN_CMD_PATH}\\libsentry.windows.release.x86_64.pdb echo exists" | grep -q exists; then
        scp "{{WIN_VM_USER}}@{{WIN_VM_HOST}}:${WIN_SENTRY_PATH}/libsentry.windows.release.x86_64.pdb" project/addons/sentry/bin/windows/x86_64/
        echo "✅ Copied libsentry.windows.release.x86_64.pdb"
    else
        echo "⚠️  Release PDB not found on VM"
    fi

    # Copy debug DLL
    echo "📥 Copying debug DLL..."
    if ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "if exist ${WIN_CMD_PATH}\\libsentry.windows.debug.x86_64.dll echo exists" | grep -q exists; then
        scp "{{WIN_VM_USER}}@{{WIN_VM_HOST}}:${WIN_SENTRY_PATH}/libsentry.windows.debug.x86_64.dll" project/addons/sentry/bin/windows/x86_64/
        echo "✅ Copied libsentry.windows.debug.x86_64.dll"
    else
        echo "⚠️  Debug DLL not found on VM"
    fi

    # Copy debug PDB
    echo "📥 Copying debug PDB..."
    if ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "if exist ${WIN_CMD_PATH}\\libsentry.windows.debug.x86_64.pdb echo exists" | grep -q exists; then
        scp "{{WIN_VM_USER}}@{{WIN_VM_HOST}}:${WIN_SENTRY_PATH}/libsentry.windows.debug.x86_64.pdb" project/addons/sentry/bin/windows/x86_64/
        echo "✅ Copied libsentry.windows.debug.x86_64.pdb"
    else
        echo "⚠️  Debug PDB not found on VM"
    fi

    # Copy crashpad_handler.exe (critical for crashpad backend)
    echo "📥 Copying crashpad_handler.exe..."
    if ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "if exist ${WIN_CMD_PATH}\\crashpad_handler.exe echo exists" | grep -q exists; then
        scp "{{WIN_VM_USER}}@{{WIN_VM_HOST}}:${WIN_SENTRY_PATH}/crashpad_handler.exe" project/addons/sentry/bin/windows/x86_64/
        echo "✅ Copied crashpad_handler.exe"
    else
        echo "⚠️  crashpad_handler.exe not found on VM"
    fi

    # Copy crashpad_wer.dll (optional, for Windows Error Reporting integration)
    echo "📥 Copying crashpad_wer.dll..."
    if ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "if exist ${WIN_CMD_PATH}\\crashpad_wer.dll echo exists" | grep -q exists; then
        scp "{{WIN_VM_USER}}@{{WIN_VM_HOST}}:${WIN_SENTRY_PATH}/crashpad_wer.dll" project/addons/sentry/bin/windows/x86_64/
        echo "✅ Copied crashpad_wer.dll"
    else
        echo "⚠️  crashpad_wer.dll not found on VM (optional)"
    fi

    echo "✅ Windows Sentry GDExtension packaged"
    ls -la project/addons/sentry/bin/windows/x86_64/

# Build and package Sentry from VM (complete workflow)
build-sentry-native-windows-vm-complete: win-vm-verify build-sentry-native-windows-vm-build-all build-sentry-native-windows-vm-package
    @echo "✅ Windows Sentry build complete with crashpad backend"

# Sync repository to Windows VM - backward compatibility alias
win-vm-sync:
    just build-windows-vm-sync

# Full Windows native pipeline: sync → templates → sentry → package
win-vm-full-pipeline jobs="6": win-vm-sync (win-vm-templates jobs) build-sentry-native-windows-vm-build-all win-vm-templates-package
    @echo ""
    @echo "✅ Full Windows native pipeline completed!"
    @echo "   Templates and Sentry DLLs built with MSVC + Firebase support"

# ================================
# WINDOWS TEMPLATE BUILD COMMANDS (Standard Naming)
# ================================
# Following the <action>-<platform>-<target> pattern used by Android/iOS/macOS
# build-windows-vm-* = Build templates on VM (aliases for win-vm-*)
# build-windows-physical-* = Build templates on physical machine (NEW)

# Shared template build recipe - works on VM or physical via attributes
# Usage: just _build-windows-templates <host> <user> <repo> <vcvars> <jobs> <target>
_build-windows-templates host user repo vcvars jobs target:
    #!/usr/bin/env bash
    set -euo pipefail
    HOST="{{host}}"
    USER="{{user}}"
    REPO="{{repo}}"
    VCVARS="{{vcvars}}"
    JOBS="{{jobs}}"
    TARGET="{{target}}"

    echo "🔨 Building Windows ${TARGET} template on ${HOST}..."
    ssh ${USER}@${HOST} "\"${VCVARS}\" && cd ${REPO} && just --justfile justfiles\justfile-windows-native.justfile --working-directory . windows-native-${TARGET} ${JOBS}"

# Verify Windows VM build environment (standard naming)
build-windows-vm-verify:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔍 Verifying Windows VM build environment..."
    echo ""
    echo "📡 SSH Connection: {{WIN_VM_USER}}@{{WIN_VM_HOST}}"
    if ! ssh -o ConnectTimeout=5 {{WIN_VM_USER}}@{{WIN_VM_HOST}} "echo Connected" &>/dev/null; then
        echo "❌ Cannot connect to Windows VM"
        exit 1
    fi
    echo "✅ SSH connection successful"
    echo ""
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} '{{WIN_VM_VCVARS}} && cd {{WIN_VM_REPO}} && just --justfile justfiles\justfile-windows-native.justfile --working-directory . windows-native-verify'

# Sync repository to Windows VM (standard naming)
build-windows-vm-sync:
    #!/usr/bin/env bash
    set -euo pipefail
    LOCAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    LOCAL_COMMIT=$(git rev-parse --short HEAD)
    echo "🔄 Syncing Windows VM to local state..."
    echo "   Branch: ${LOCAL_BRANCH}"
    echo "   Commit: ${LOCAL_COMMIT}"
    echo ""
    if [ "${LOCAL_BRANCH}" = "HEAD" ]; then
        ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "cd {{WIN_VM_REPO}} && git checkout ${LOCAL_COMMIT}"
    else
        ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "cd {{WIN_VM_REPO}} && git fetch origin && git checkout ${LOCAL_BRANCH} && git reset --hard origin/${LOCAL_BRANCH}"
    fi
    echo "📦 Syncing submodules..."
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "cd {{WIN_VM_REPO}} && git submodule sync && git submodule update --init godot" || true
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "cd {{WIN_VM_REPO}} && git submodule update --init extras/firebase-cpp-sdk extras/sentry-godot" 2>/dev/null || true
    echo "   Initializing sentry-godot nested submodules..."
    ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "cd {{WIN_VM_REPO}}/extras/sentry-godot && git submodule update --init --recursive" 2>/dev/null || true
    VM_COMMIT=$(ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "cd {{WIN_VM_REPO}} && git rev-parse --short HEAD")
    if [ "${LOCAL_COMMIT}" = "${VM_COMMIT}" ]; then
        echo "✅ VM synced to ${VM_COMMIT} (matches local)"
    else
        echo "⚠️  WARNING: VM at ${VM_COMMIT}, local at ${LOCAL_COMMIT}"
        exit 1
    fi

# Build Windows debug template on VM (standard naming)
build-windows-vm-template-debug jobs="6":
    just _build-windows-templates "{{WIN_VM_HOST}}" "{{WIN_VM_USER}}" "{{WIN_VM_REPO}}" {{WIN_VM_VCVARS}} "{{jobs}}" "template-debug"

# Build Windows release template on VM (standard naming)
build-windows-vm-template-release jobs="6":
    just _build-windows-templates "{{WIN_VM_HOST}}" "{{WIN_VM_USER}}" "{{WIN_VM_REPO}}" {{WIN_VM_VCVARS}} "{{jobs}}" "template-release"

# Build both Windows templates on VM (standard naming)
build-windows-vm-templates jobs="6":
    just build-windows-vm-template-debug "{{jobs}}"
    just build-windows-vm-template-release "{{jobs}}"
    @echo "✅ Both Windows templates built successfully on VM"

# Package templates from VM to macOS (standard naming)
build-windows-vm-templates-package:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📦 Packaging Windows templates from VM..."
    mkdir -p templates
    WIN_BIN_PATH="/C:/gametwo/godot/bin"
    echo "📥 Copying debug template..."
    scp "{{WIN_VM_USER}}@{{WIN_VM_HOST}}:${WIN_BIN_PATH}/godot.windows.template_debug.x86_64.exe" templates/
    if ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} 'if exist {{WIN_VM_REPO}}\godot\bin\godot.windows.template_release.x86_64.exe echo exists'; then
        echo "📥 Copying release template..."
        scp "{{WIN_VM_USER}}@{{WIN_VM_HOST}}:${WIN_BIN_PATH}/godot.windows.template_release.x86_64.exe" templates/
    fi
    echo "✅ Windows templates packaged in templates/ directory"

# Verify Windows physical machine build environment (NEW)
build-windows-physical-verify:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔍 Verifying Windows physical machine build environment..."
    echo ""
    echo "📡 SSH Connection: {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}}"
    if ! ssh -o ConnectTimeout=5 {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "echo Connected" &>/dev/null; then
        echo "❌ Cannot connect to Windows physical machine"
        exit 1
    fi
    echo "✅ SSH connection successful"
    echo ""
    ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} '{{WIN_PHYSICAL_VCVARS}} && cd {{WIN_PHYSICAL_REPO}} && just --justfile justfiles\justfile-windows-native.justfile --working-directory . windows-native-verify'

# Sync repository to Windows physical machine (NEW)
build-windows-physical-sync:
    #!/usr/bin/env bash
    set -euo pipefail
    LOCAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    LOCAL_COMMIT=$(git rev-parse --short HEAD)
    echo "🔄 Syncing Windows physical machine to local state..."
    echo "   Branch: ${LOCAL_BRANCH}"
    echo "   Commit: ${LOCAL_COMMIT}"
    echo ""

    # Check if repo exists on physical machine, clone if not
    if ! ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "cd {{WIN_PHYSICAL_REPO}} 2>/dev/null" 2>/dev/null; then
        echo "📦 Repository not found on physical machine, cloning..."
        echo "   Using shallow clone for faster initial transfer..."
        ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "git clone --depth 1 --single-branch --branch ${LOCAL_BRANCH} git@github.com:Myran/gametwo {{WIN_PHYSICAL_REPO}}"
        echo "✅ Initial shallow clone completed"
    fi

    if [ "${LOCAL_BRANCH}" = "HEAD" ]; then
        ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "cd {{WIN_PHYSICAL_REPO}} && git checkout ${LOCAL_COMMIT}"
    else
        ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "cd {{WIN_PHYSICAL_REPO}} && git fetch origin && git checkout ${LOCAL_BRANCH} && git reset --hard origin/${LOCAL_BRANCH}"
    fi
    echo "📦 Syncing submodules..."
    ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "cd {{WIN_PHYSICAL_REPO}} && git submodule sync && git submodule update --init godot" || true
    ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "cd {{WIN_PHYSICAL_REPO}} && git submodule update --init extras/firebase-cpp-sdk extras/sentry-godot" 2>/dev/null || true
    echo "   Initializing sentry-godot nested submodules..."
    ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "cd {{WIN_PHYSICAL_REPO}}/extras/sentry-godot && git submodule update --init --recursive" 2>/dev/null || true
    PHYSICAL_COMMIT=$(ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "cd {{WIN_PHYSICAL_REPO}} && git rev-parse --short HEAD")
    if [ "${LOCAL_COMMIT}" = "${PHYSICAL_COMMIT}" ]; then
        echo "✅ Physical machine synced to ${PHYSICAL_COMMIT} (matches local)"
    else
        echo "⚠️  WARNING: Physical machine at ${PHYSICAL_COMMIT}, local at ${LOCAL_COMMIT}"
        exit 1
    fi

# Build Windows debug template on physical machine (NEW)
build-windows-physical-template-debug jobs="6":
    just _build-windows-templates "{{WIN_PHYSICAL_HOST}}" "{{WIN_PHYSICAL_USER}}" "{{WIN_PHYSICAL_REPO}}" {{WIN_PHYSICAL_VCVARS}} "{{jobs}}" "template-debug"

# Build Windows release template on physical machine (NEW)
build-windows-physical-template-release jobs="6":
    just _build-windows-templates "{{WIN_PHYSICAL_HOST}}" "{{WIN_PHYSICAL_USER}}" "{{WIN_PHYSICAL_REPO}}" {{WIN_PHYSICAL_VCVARS}} "{{jobs}}" "template-release"

# Build both Windows templates on physical machine (NEW)
build-windows-physical-templates jobs="6":
    just build-windows-physical-template-debug "{{jobs}}"
    just build-windows-physical-template-release "{{jobs}}"
    @echo "✅ Both Windows templates built successfully on physical machine"

# Package templates from physical machine to macOS (NEW)
build-windows-physical-templates-package:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📦 Packaging Windows templates from physical machine..."
    mkdir -p templates
    WIN_BIN_PATH="/C:/gametwo/godot/bin"
    echo "📥 Copying debug template..."
    scp "{{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}}:${WIN_BIN_PATH}/godot.windows.template_debug.x86_64.exe" templates/
    if ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} 'if exist {{WIN_PHYSICAL_REPO}}\godot\bin\godot.windows.template_release.x86_64.exe echo exists'; then
        echo "📥 Copying release template..."
        scp "{{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}}:${WIN_BIN_PATH}/godot.windows.template_release.x86_64.exe" templates/
    fi
    echo "✅ Windows templates packaged in templates/ directory"

# ================================
# ALIGNED PLATFORM COMMANDS
# ================================
# These commands match the naming convention of other platforms
# (Android: build-all-android, iOS: build-all-ios, macOS: build-macos-*)

# Complete Windows build with templates and Sentry (default: VM)
build-all-windows force="no" jobs="6": build-windows-vm-verify
    @echo "🪟 FULL BUILD - WINDOWS ONLY (via VM)"
    @echo "======================================"
    @echo "⏱️  Estimated time: 25-40 minutes"
    @echo "📡 Building on Windows VM: {{WIN_VM_HOST}}"
    @echo ""
    just build-windows-vm-sync
    just build-windows-vm-templates "{{jobs}}"
    just build-sentry-native-windows-vm-build-all
    just build-windows-vm-templates-package
    @echo ""
    @echo "✅ Windows full build complete!"
    @echo "📁 Templates copied to: templates/"

# Complete Windows build on physical machine (NEW)
build-all-windows-physical force="no" jobs="6": build-windows-physical-verify
    @echo "🪟 FULL BUILD - WINDOWS ONLY (via Physical Machine)"
    @echo "=============================================="
    @echo "⏱️  Estimated time: 25-40 minutes"
    @echo "📡 Building on Windows physical: {{WIN_PHYSICAL_HOST}}"
    @echo ""
    just build-windows-physical-sync
    just build-windows-physical-templates "{{jobs}}"
    just build-sentry-native-windows-vm-build-all
    just build-windows-physical-templates-package
    @echo ""
    @echo "✅ Windows full build complete!"
    @echo "📁 Templates copied to: templates/"

# Complete Windows build on VM (explicit variant)
build-all-windows-vm force="no" jobs="6": build-windows-vm-verify
    @echo "🪟 FULL BUILD - WINDOWS ONLY (via VM)"
    @echo "======================================"
    @echo "⏱️  Estimated time: 25-40 minutes"
    @echo "📡 Building on Windows VM: {{WIN_VM_HOST}}"
    @echo ""
    just build-windows-vm-sync
    just build-windows-vm-templates "{{jobs}}"
    just build-sentry-native-windows-vm-build-all
    just build-windows-vm-templates-package
    @echo ""
    @echo "✅ Windows full build complete!"
    @echo "📁 Templates copied to: templates/"

# Build Windows templates (default: VM, aligned with build-android-templates)
build-windows-templates force="no" jobs="6": build-windows-vm-verify
    @echo "🔨 Building Windows templates on VM..."
    just build-windows-vm-templates "{{jobs}}"
    just build-windows-vm-templates-package

# Build Windows templates on physical machine (NEW)
build-windows-templates-physical force="no" jobs="6": build-windows-physical-verify
    @echo "🔨 Building Windows templates on physical machine..."
    just build-windows-physical-templates "{{jobs}}"
    just build-windows-physical-templates-package

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

# Validate Windows export with Firebase and Sentry integration
validate-windows-export:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🔍 Validating Windows Export"
    echo "================================"
    echo ""

    # Check if exports exist
    DEBUG_EXE="export/windows/{{GAME_NAME}}_debug.exe"
    RELEASE_EXE="export/windows/{{GAME_NAME}}.exe"

    if [ ! -f "$DEBUG_EXE" ]; then
        echo "❌ Debug export not found: $DEBUG_EXE"
        echo "💡 Run 'just export-windows-debug' first"
        exit 1
    fi

    if [ ! -f "$RELEASE_EXE" ]; then
        echo "❌ Release export not found: $RELEASE_EXE"
        echo "💡 Run 'just export-windows-release' first"
        exit 1
    fi

    echo "✅ Executables found"

    # Check PCK files
    if [ ! -f "export/windows/{{GAME_NAME}}_debug.pck" ]; then
        echo "⚠️ Debug PCK file missing"
    fi

    if [ ! -f "export/windows/{{GAME_NAME}}.pck" ]; then
        echo "⚠️ Release PCK file missing"
    fi

    echo "✅ PCK files checked"

    # Check Firebase config
    if [ ! -f "firebase/google-services-desktop.json" ]; then
        echo "⚠️ Firebase config missing: firebase/google-services-desktop.json"
        echo "   Firebase features will not work without this"
    else
        echo "✅ Firebase config found"
    fi

    # Check Sentry DLLs
    SENTRY_DIR="project/addons/sentry/bin/windows/x86_64"
    MISSING_SENTRY=()

    if [ ! -f "$SENTRY_DIR/libsentry.windows.debug.x86_64.dll" ]; then
        MISSING_SENTRY+=("libsentry.windows.debug.x86_64.dll")
    fi

    if [ ! -f "$SENTRY_DIR/libsentry.windows.release.x86_64.dll" ]; then
        MISSING_SENTRY+=("libsentry.windows.release.x86_64.dll")
    fi

    if [ ! -f "$SENTRY_DIR/crashpad_handler.exe" ]; then
        MISSING_SENTRY+=("crashpad_handler.exe")
    fi

    if [ ! -f "$SENTRY_DIR/crashpad_wer.dll" ]; then
        MISSING_SENTRY+=("crashpad_wer.dll")
    fi

    if [ ${#MISSING_SENTRY[@]} -gt 0 ]; then
        echo "❌ Missing Sentry files:"
        printf '   %s\n' "${MISSING_SENTRY[@]}"
        echo "💡 Run 'just build-sentry-native-windows-vm-complete' to build missing files"
        exit 1
    else
        echo "✅ Sentry DLLs found"
    fi

    # Check file sizes (basic integrity check)
    DEBUG_SIZE=$(stat -f%z "$DEBUG_EXE" 2>/dev/null || echo 0)
    RELEASE_SIZE=$(stat -f%z "$RELEASE_EXE" 2>/dev/null || echo 0)

    if [ "$DEBUG_SIZE" -lt 1000000 ]; then  # Less than 1MB
        echo "⚠️ Debug executable seems small ($DEBUG_SIZE bytes)"
    fi

    if [ "$RELEASE_SIZE" -lt 1000000 ]; then  # Less than 1MB
        echo "⚠️ Release executable seems small ($RELEASE_SIZE bytes)"
    fi

    echo ""
    echo "✅ Windows export validation completed successfully"
    echo ""
    echo "📋 Summary:"
    echo "   Debug: $DEBUG_EXE ($(printf '%.1f' $(echo "$DEBUG_SIZE/1048576" | bc -l)) MB)"
    echo "   Release: $RELEASE_EXE ($(printf '%.1f' $(echo "$RELEASE_SIZE/1048576" | bc -l)) MB)"
    echo "   Firebase: $([ -f firebase/google-services-desktop.json ] && echo '✅' || echo '❌')"
    echo "   Sentry: ✅"

# Complete Windows export pipeline (build + export + validate)
windows-export-pipeline: export-windows-all validate-windows-export win-physical-deploy
    @echo ""
    @echo "🎉 Complete Windows export pipeline finished!"
    @echo ""
    @echo "Next steps:"
    @echo "1. Test on physical machine: just test-windows-physical-target <config>"
    @echo "2. View logs: just logs-windows-physical <test_id>"
    @echo "3. Manual testing: just test-windows-physical-manual <config>"

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

# Clear debug_startup_actions.json from Windows physical machine
clear-test-windows-physical:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧹 Clearing Windows physical machine test configuration..."

    CONFIG_FILE='C:\Users\{{WIN_PHYSICAL_USER}}\AppData\Roaming\Godot\app_userdata\gametwo\debug_startup_actions.json'

    # Check if config exists and remove it
    ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "if exist \"${CONFIG_FILE}\" (del \"${CONFIG_FILE}\" && echo Removed: debug_startup_actions.json) else (echo No config found - already clean)"

    echo "✅ Windows physical test config cleared"
    echo "💡 deploy-windows will now start without debug actions"

# Clear Windows physical test cache (alias for consistency)
clear-windows-physical-test-cache: clear-test-windows-physical

# ================================
# WINDOWS VM HELPERS
# ================================

# Show Windows help (VM + Physical machine)
help-windows:
    @echo "Windows Development Commands"
    @echo "============================"
    @echo ""
    @echo "📋 TWO-MACHINE ARCHITECTURE (Task-368):"
    @echo "  • VM ({{WIN_VM_HOST}}) → Building templates (MSVC)"
    @echo "  • Physical ({{WIN_PHYSICAL_HOST}}) → Can build OR test exports"
    @echo ""
    @echo "📋 NAMING CONVENTION: <action>-<platform>-<target>"
    @echo "  • build-windows-vm-*           - Build on VM (standard naming)"
    @echo "  • build-windows-physical-*     - Build on physical (NEW)"
    @echo "  • win-vm-*                     - Backward compatibility aliases"
    @echo "  • test-windows-physical-*      - Test on physical (GUI mode)"
    @echo ""
    @echo "─────────────────────────────────────────────────────────────"
    @echo "🔨 TEMPLATE BUILD (Standard Naming)"
    @echo "─────────────────────────────────────────────────────────────"
    @echo ""
    @echo "VM BUILD:"
    @echo "  just build-windows-vm-verify           - Verify VM build environment"
    @echo "  just build-windows-vm-sync             - Sync repo to VM"
    @echo "  just build-windows-vm-templates         - Build both templates"
    @echo "  just build-windows-vm-templates-package - Copy templates to Mac"
    @echo ""
    @echo "PHYSICAL MACHINE BUILD (NEW):"
    @echo "  just build-windows-physical-verify           - Verify physical build env"
    @echo "  just build-windows-physical-sync             - Sync repo to physical"
    @echo "  just build-windows-physical-templates         - Build both templates"
    @echo "  just build-windows-physical-templates-package - Copy templates to Mac"
    @echo ""
    @echo "UNIFIED BUILD COMMANDS:"
    @echo "  just build-all-windows             - Build on VM (default)"
    @echo "  just build-all-windows-vm         - Build on VM (explicit)"
    @echo "  just build-all-windows-physical   - Build on physical machine"
    @echo "  just build-windows-templates       - Build templates on VM"
    @echo "  just build-windows-templates-physical - Build templates on physical"
    @echo ""
    @echo "BACKWARD COMPATIBILITY (old names still work):"
    @echo "  just win-vm-verify                  - Same as build-windows-vm-verify"
    @echo "  just win-vm-sync                    - Same as build-windows-vm-sync"
    @echo "  just win-vm-templates                - Same as build-windows-vm-templates"
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
    @echo "DEPLOY (Development - export → install → run):"
    @echo "  just deploy-windows           - Deploy to physical machine (export → install → run)"
    @echo "  just win-physical-deploy      - Deploy files only (no run)"
    @echo ""
    @echo "TESTING (Physical, GUI mode):"
    @echo "  just test-windows-physical-target CONFIG  - Run automated test with GUI"
    @echo "  just test-windows-physical-manual CONFIG  - Run test, stays open for inspection"
    @echo "  just test-windows-physical-update CONFIG  - Update checksum baseline"
    @echo "  just test-windows-physical-reset CONFIG   - Reset checksum baseline"
    @echo ""
    @echo "LOGS:"
    @echo "  just logs-windows-physical TEST_ID        - Retrieve test logs"
    @echo "  just logs-windows-physical-errors TEST_ID - Error-focused analysis"
    @echo ""
    @echo "─────────────────────────────────────────────────────────────"
    @echo "🔄 DEVELOPMENT WORKFLOWS"
    @echo "─────────────────────────────────────────────────────────────"
    @echo ""
    @echo "📦 FULL BUILD + TEST (code changes → validation):"
    @echo "  # Using VM (default)"
    @echo "  1. just build-all-windows              # Sync + build templates + package"
    @echo "  2. just export-windows-debug            # Export Windows app"
    @echo "  3. just win-physical-deploy             # Deploy to physical machine"
    @echo "  4. just test-windows-physical-target CONFIG  # Run automated tests"
    @echo ""
    @echo "  # Using Physical Machine for building"
    @echo "  1. just build-all-windows-physical      # Sync + build templates + package"
    @echo "  2. just export-windows-debug            # Export Windows app"
    @echo "  3. just win-physical-deploy             # Deploy to physical machine"
    @echo "  4. just test-windows-physical-target CONFIG  # Run automated tests"
    @echo ""
    @echo "⚡ QUICK TEMPLATE UPDATE (C++/Firebase changes):"
    @echo "  # VM"
    @echo "  just build-windows-vm-sync && just build-windows-vm-templates && just build-windows-vm-templates-package"
    @echo ""
    @echo "  # Physical"
    @echo "  just build-windows-physical-sync && just build-windows-physical-templates && just build-windows-physical-templates-package"
    @echo ""
    @echo "⚡ QUICK TEST CYCLE (GDScript changes, templates current):"
    @echo "  rm export/windows/gametwo_debug.pck && just export-windows-debug"
    @echo "  just win-physical-deploy && just test-windows-physical-target CONFIG"
    @echo ""
    @echo "─────────────────────────────────────────────────────────────"
    @echo "⚙️  CONFIGURATION"
    @echo "─────────────────────────────────────────────────────────────"
    @echo ""
    @echo "Physical Machine:"
    @echo "  WIN_PHYSICAL_HOST:    {{WIN_PHYSICAL_HOST}}"
    @echo "  WIN_PHYSICAL_USER:    {{WIN_PHYSICAL_USER}}"
    @echo "  WIN_PHYSICAL_MAC:     {{WIN_PHYSICAL_MAC}} (Wake-on-LAN)"
    @echo "  WIN_PHYSICAL_REPO:    {{WIN_PHYSICAL_REPO}}"
    @echo ""
    @echo "VM Machine:"
    @echo "  WIN_VM_HOST:          {{WIN_VM_HOST}}"
    @echo "  WIN_VM_USER:          {{WIN_VM_USER}}"
    @echo "  WIN_VM_REPO:          {{WIN_VM_REPO}}"
    @echo ""
    @echo "💡 TIP: Physical machine may be sleeping. Use 'just win-physical-wake' first."
    @echo "💡 TIP: Use 'just build-all-windows-physical' if VM is unavailable."

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
# SCP-friendly paths (forward slashes required for scp protocol)
WIN_PHYSICAL_BUILDS_SCP := "/C:/GameTwoTests/builds"
WIN_PHYSICAL_USER_DATA_SCP := "/C:/Users/" + WIN_PHYSICAL_USER + "/AppData/Roaming/Godot/app_userdata/gametwo"

# Internal helper: Deploy Windows export with build type selection
_win-physical-deploy-internal BUILD_TYPE="debug":
    #!/usr/bin/env bash
    set -euo pipefail

    BUILD_TYPE="{{BUILD_TYPE}}"
    echo "📦 Deploying Windows $BUILD_TYPE export to physical machine..."
    echo ""

    # Check export exists locally based on build type
    if [ "$BUILD_TYPE" = "debug" ]; then
        WIN_EXE_PATH="export/windows/{{GAME_NAME}}_debug.exe"
        WIN_PCK_PATH="export/windows/{{GAME_NAME}}_debug.pck"
    elif [ "$BUILD_TYPE" = "release" ]; then
        WIN_EXE_PATH="export/windows/{{GAME_NAME}}.exe"
        WIN_PCK_PATH="export/windows/{{GAME_NAME}}.pck"
    else
        echo "❌ Invalid build type: $BUILD_TYPE. Use 'debug' or 'release'"
        exit 1
    fi

    if [ ! -f "$WIN_EXE_PATH" ]; then
        echo "❌ Windows executable not found at: $WIN_EXE_PATH"
        echo "💡 Run 'just export-windows-$BUILD_TYPE' first"
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

    # Copy the specific export files
    echo "📤 Copying Windows $BUILD_TYPE export files..."
    scp "$WIN_EXE_PATH" "$WIN_PCK_PATH" "{{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}}:{{WIN_PHYSICAL_BUILDS_SCP}}/"

    # Copy Firebase config if exists
    if [ -f "firebase/google-services-desktop.json" ]; then
        echo "🔥 Copying Firebase config..."
        scp firebase/google-services-desktop.json "{{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}}:{{WIN_PHYSICAL_BUILDS_SCP}}/"
    fi

    # Copy Sentry DLLs if they exist
    if [ -d "project/addons/sentry/bin/windows/x86_64" ]; then
        echo "🛡️ Copying Sentry DLLs..."
        scp project/addons/sentry/bin/windows/x86_64/*.dll "{{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}}:{{WIN_PHYSICAL_BUILDS_SCP}}/"
        scp project/addons/sentry/bin/windows/x86_64/*.exe "{{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}}:{{WIN_PHYSICAL_BUILDS_SCP}}/"
    fi

    # Verify deployment
    echo ""
    echo "📋 Deployed files:"
    ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "dir {{WIN_PHYSICAL_DIR}}\\builds /B" 2>/dev/null | sed 's/^/   /'

    echo ""
    echo "✅ Windows $BUILD_TYPE export deployed to physical machine"

# Deploy Windows export to physical machine (debug - default)
win-physical-deploy: (_win-physical-deploy-internal "debug")

# Deploy Windows release export to physical machine
win-physical-deploy-release: (_win-physical-deploy-internal "release")


# ================================
# WINDOWS COMBINED EXPORT+INSTALL WORKFLOWS
# ================================
# Platform parity with Android: export-install-android-debug, export-install-android-launch-debug

# Export and install Windows debug build (no launch)
export-install-windows-debug: export-windows-debug win-physical-deploy
    @echo "🔄 Windows: Export and install debug workflow completed"

# Export and install Windows release build (no launch)
export-install-windows-release: export-windows-release win-physical-deploy-release
    @echo "🔄 Windows: Export and install release workflow completed"

# Export, install, and launch Windows debug build
export-install-windows-launch-debug: export-windows-debug run-windows
    @echo "🔄 Windows: Export, install, and launch debug workflow completed"


# ================================
# DEPLOY: Development device workflow (export → install → run)
# ================================
# Note: Windows has no app store, so no 'ship-windows' equivalent

# Deploy to Windows physical machine (complete workflow: export → install → run)
# This is the primary command for development iteration
deploy-windows: export-install-windows-launch-debug
    @echo "🖥️ Deploy to Windows complete"


# Run Windows app on physical machine (wake, deploy, launch)
run-windows:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🚀 Starting Windows app on physical machine..."
    echo ""

    # Ensure physical machine is awake and reachable
    just win-physical-wake-wait

    # Deploy latest build
    just win-physical-deploy

    # Launch the app on physical machine
    echo ""
    echo "🎮 Launching Windows app..."

    # Stop any existing instances first
    just _win-physical-stop-app

    # Launch the game via start command (Windows equivalent of macOS open)
    ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "cd /c/GameTwoTests/builds && start {{GAME_NAME}}_debug.exe --test-mode" || {
        echo "⚠️ Launch command sent (app runs in background on Windows)"
    }

    echo ""
    echo "✅ Windows app launched on physical machine"
    echo "💡 Use 'just win-physical-ssh' to connect for manual inspection"

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
    scp "$CONFIG_PATH" "{{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}}:{{WIN_PHYSICAL_USER_DATA_SCP}}/debug_startup_actions.json"

    echo "✅ Config deployed"

# Stop running game on physical machine
_win-physical-stop-app:
    @ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "taskkill /IM {{GAME_NAME}}*.exe /F 2>nul || echo No processes to kill" || true

# ================================
# SHARED PLATFORM HELPERS
# ================================
# These follow the naming convention used by _execute-test-with-analysis
# to enable windows-physical to use the shared config resolution logic

# Deploy config to Windows physical machine (shared helper interface)
_deploy-config-windows-physical config_path:
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_PATH="{{config_path}}"

    echo "🪟 Deploying configuration to Windows physical machine..."

    # Ensure physical machine is awake
    just _win-physical-ensure-awake

    # Check export is deployed
    if ! ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "if exist \"{{WIN_PHYSICAL_DIR}}\\builds\\{{GAME_NAME}}_debug.exe\" echo exists" | grep -q exists; then
        echo "❌ Windows export not deployed to physical machine"
        echo "💡 Run 'just win-physical-deploy' first"
        exit 1
    fi

    # Use existing deploy helper
    just _win-physical-deploy-config "$CONFIG_PATH"

    # Clear old logs
    echo "🧹 Clearing old logs..."
    ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "del \"{{WIN_PHYSICAL_USER_DATA}}\\logs\\*.log\" 2>nul || echo No old logs"

# Execute test on Windows physical machine (shared helper interface)
_execute-test-windows-physical config_name test_id:
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_NAME="{{config_name}}"
    TEST_ID="{{test_id}}"

    echo "🪟 Starting Windows physical machine test execution..."
    echo "📍 Target: {{WIN_PHYSICAL_HOST}} (GUI mode)"
    echo ""

    # Ensure machine is awake before running test (checks first, wakes if needed)
    just win-physical-wake-wait
    echo ""

    # Run test with GUI using PowerShell Start-Process
    echo "🚀 Starting test with GUI..."
    echo ""

    # Use PowerShell to start the process and wait for it
    ssh {{WIN_PHYSICAL_USER}}@{{WIN_PHYSICAL_HOST}} "powershell -Command \"Start-Process -FilePath '{{WIN_PHYSICAL_DIR}}\\builds\\{{GAME_NAME}}_debug.exe' -ArgumentList '--test-mode','--auto-quit' -WorkingDirectory '{{WIN_PHYSICAL_DIR}}\\builds' -Wait\""

    TEST_EXIT_CODE=$?

    echo ""
    echo "📊 Windows Physical Test Execution Summary"
    echo "================================"
    echo ""
    echo "**Status**: $(if [[ $TEST_EXIT_CODE -eq 0 ]]; then echo '✅ COMPLETED'; else echo '❌ FAILED'; fi)"

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

        # Also save with windows-physical prefix for log analysis tools
        PREFIXED_LOG="logs/windows-physical_${TEST_ID}.log"
        cp "$LOG_FILE" "$PREFIXED_LOG" 2>/dev/null || true
    else
        echo "⚠️  No log file found on physical machine"
    fi

    echo ""
    echo "🎯 Test completed on Windows physical machine"

    exit $TEST_EXIT_CODE

# Run test on physical machine with GUI (automated mode)
# Uses shared _execute-test-with-analysis for consistent config resolution
# Supports: debug configs, test lists, @ references, folder patterns
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
    echo "📦 Using shared config resolution (supports test lists, @ refs, folders)"
    echo ""

    # Create session timestamp for multi-config orchestration
    if [[ -n "${MULTI_PLATFORM_SESSION:-}" ]]; then
        TEST_SESSION="$MULTI_PLATFORM_SESSION"
    else
        TEST_SESSION="$(date +%s)"
    fi

    # Use the shared unified execution pattern
    # This handles: debug configs, test lists, @ references, folder patterns
    just _execute-test-with-analysis "$CONFIG_NAME" "windows-physical" "$TEST_SESSION"

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

# ================================
# WINDOWS PHYSICAL CHECKSUM BASELINE MANAGEMENT
# Platform parity with Android/macOS/iOS (Task-363)
# ================================

# Windows-Physical checksum baseline management - update baseline after legitimate changes
test-windows-physical-update config_name="":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_NAME="{{config_name}}"

    # If no config name provided, show interactive selector for checksum-enabled configs
    if [[ -z "$CONFIG_NAME" ]]; then
        echo "🔍 Selecting checksum test configuration..."

        # Find all checksum-enabled configs
        CHECKSUM_CONFIGS=""

        if [[ -d "{{DEBUG_CONFIG_DIR}}" ]]; then
            while IFS= read -r -d '' config_file; do
                if [[ -f "$config_file" ]] && jq -e '.checksum_config' "$config_file" >/dev/null 2>&1; then
                    basename=$(basename "$config_file" .json)
                    state_type=$(jq -r '.checksum_config.state_type // "unknown"' "$config_file")
                    expected_checksums_count=$(jq -r '.checksum_config.expected_checksums | length' "$config_file")
                    description=$(jq -r '.description // "No description"' "$config_file")

                    # Determine status
                    if [[ "$expected_checksums_count" -eq 0 ]]; then
                        status="❌ NO BASELINE SET"
                    else
                        status="✅ BASELINE SET"
                    fi

                    # Format for fzf
                    CHECKSUM_CONFIGS="${CHECKSUM_CONFIGS}📸 ${basename} (${state_type}) ${status} - ${description}\n"
                fi
            done < <(find "{{DEBUG_CONFIG_DIR}}" -name "*.json" -type f -print0)
        fi

        if [[ -z "$CHECKSUM_CONFIGS" ]]; then
            echo "❌ No checksum-enabled configurations found"
            echo ""
            echo "To enable checksum testing, add a checksum_config section to your configuration."
            exit 1
        fi

        echo "📸 Available checksum configurations:"
        echo "===================================="

        # Use fzf for selection if available, otherwise show list
        if command -v fzf >/dev/null 2>&1; then
            SELECTED=$(echo -e "$CHECKSUM_CONFIGS" | fzf --prompt="Select checksum config to update: " --height=10 --layout=reverse)
            if [[ -z "$SELECTED" ]]; then
                echo "❌ No configuration selected"
                exit 1
            fi

            # Extract config name from selection
            CONFIG_NAME=$(echo "$SELECTED" | sed 's/📸 \([^ ]*\) .*/\1/')
        else
            echo -e "$CHECKSUM_CONFIGS"
            echo ""
            echo "❌ fzf not available for interactive selection"
            echo "Please specify a configuration name: just test-windows-physical-update CONFIG_NAME"
            echo ""
            echo "Available configurations:"
            echo -e "$CHECKSUM_CONFIGS" | sed 's/📸 \([^ ]*\) .*/  • \1/'
            exit 1
        fi
    fi

    # Call shared update function
    just _update-checksum-baseline "windows-physical" "$CONFIG_NAME"

# Windows-Physical checksum baseline management - reset baseline to start fresh
test-windows-physical-reset config_name="":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_NAME="{{config_name}}"

    # If no config name provided, show interactive selector for checksum-enabled configs
    if [[ -z "$CONFIG_NAME" ]]; then
        echo "🔍 Selecting checksum test configuration to reset..."

        # Find all checksum-enabled configs
        CHECKSUM_CONFIGS=""

        if [[ -d "{{DEBUG_CONFIG_DIR}}" ]]; then
            while IFS= read -r -d '' config_file; do
                if [[ -f "$config_file" ]] && jq -e '.checksum_config' "$config_file" >/dev/null 2>&1; then
                    basename=$(basename "$config_file" .json)
                    state_type=$(jq -r '.checksum_config.state_type // "unknown"' "$config_file")
                    expected_checksums_count=$(jq -r '.checksum_config.expected_checksums | length' "$config_file")
                    description=$(jq -r '.description // "No description"' "$config_file")

                    # Determine status
                    if [[ "$expected_checksums_count" -eq 0 ]]; then
                        status="❌ NO BASELINE"
                    else
                        status="✅ HAS BASELINE ($expected_checksums_count)"
                    fi

                    # Format for fzf
                    CHECKSUM_CONFIGS="${CHECKSUM_CONFIGS}📸 ${basename} (${state_type}) ${status} - ${description}\n"
                fi
            done < <(find "{{DEBUG_CONFIG_DIR}}" -name "*.json" -type f -print0)
        fi

        if [[ -z "$CHECKSUM_CONFIGS" ]]; then
            echo "❌ No checksum-enabled configurations found"
            exit 1
        fi

        echo "📸 Available checksum configurations:"
        echo "===================================="

        # Use fzf for selection if available, otherwise show list
        if command -v fzf >/dev/null 2>&1; then
            SELECTED=$(echo -e "$CHECKSUM_CONFIGS" | fzf --prompt="Select checksum config to RESET: " --height=10 --layout=reverse)
            if [[ -z "$SELECTED" ]]; then
                echo "❌ No configuration selected"
                exit 1
            fi

            # Extract config name from selection
            CONFIG_NAME=$(echo "$SELECTED" | sed 's/📸 \([^ ]*\) .*/\1/')
        else
            echo -e "$CHECKSUM_CONFIGS"
            echo ""
            echo "❌ fzf not available for interactive selection"
            echo "Please specify a configuration name: just test-windows-physical-reset CONFIG_NAME"
            exit 1
        fi
    fi

    CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${CONFIG_NAME}.json"

    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo "❌ Config not found: $CONFIG_PATH"
        exit 1
    fi

    echo "🔄 Resetting checksum baseline for: $CONFIG_NAME (Windows-Physical)"
    echo "================================================================="

    # Clear the expected_checksums array
    TEMP_FILE=$(mktemp)
    jq '.checksum_config.expected_checksums = []' "$CONFIG_PATH" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$CONFIG_PATH"

    echo "✅ Checksum baseline reset for $CONFIG_NAME"
    echo "💡 Next test run will create a new baseline"