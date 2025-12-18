# GDScript Sentry SDK Build Commands for GameTwo
# Uses pre-built binaries from GitHub releases for consistency across all platforms

# Show GDScript Sentry build help
help-sentry-gdscript:
    @echo "🎮 GDScript Sentry SDK Commands"
    @echo "==============================="
    @echo ""
    @echo "📦 PRE-BUILT BINARIES (from GitHub releases):"
    @echo "  just download-sentry-gdscript           # Download pre-built binaries for all platforms"
    @echo "  just build-sentry-gdscript-all          # Download (if needed) + install all platforms"
    @echo ""
    @echo "🔧 PLATFORM-SPECIFIC INSTALL:"
    @echo "  just build-sentry-gdscript-macos        # Install macOS binaries"
    @echo "  just build-sentry-gdscript-ios          # Install iOS binaries"
    @echo "  just build-sentry-gdscript-android      # Install Android binaries"
    @echo "  just build-sentry-gdscript-windows      # Install Windows binaries"
    @echo "  just build-sentry-gdscript-linux        # Install Linux binaries"
    @echo ""
    @echo "🔧 MAINTENANCE:"
    @echo "  just sentry-gdscript-clean              # Clean installed binaries"
    @echo "  just sentry-gdscript-status             # Check installation status"
    @echo "  just sentry-gdscript-validate           # Validate Sentry integration"
    @echo ""
    @echo "📋 VERSION INFO:"
    @echo "  Sentry version: {{SENTRY_VERSION}}"
    @echo "  GDExtension commit: {{SENTRY_GDEXT_COMMIT}}"
    @echo "  Source: github.com/getsentry/sentry-godot/releases"

# Download Sentry GDExtension pre-built binaries from GitHub releases
download-sentry-gdscript:
    #!/usr/bin/env bash
    set -euo pipefail

    RELEASE_TAG="{{SENTRY_VERSION}}"
    ASSET_NAME="sentry-godot-gdextension-{{SENTRY_VERSION}}+{{SENTRY_GDEXT_COMMIT}}.zip"
    EXTRACT_DIR="{{SENTRY_GDEXT_DIR}}"

    # Check if already downloaded and extracted
    if [ -d "$EXTRACT_DIR/addons/sentry/bin" ]; then
        echo "✅ Sentry GDExtension v{{SENTRY_VERSION}} already downloaded"
        echo "   📂 $EXTRACT_DIR"
        exit 0
    fi

    echo "📥 Downloading Sentry GDExtension v{{SENTRY_VERSION}} from GitHub..."

    # Create extras directory if needed
    mkdir -p extras

    # Download using gh CLI
    if ! command -v gh &> /dev/null; then
        echo "❌ GitHub CLI (gh) not installed"
        echo "💡 Install with: brew install gh"
        exit 1
    fi

    # Download release asset
    cd extras
    gh release download "$RELEASE_TAG" \
        --repo getsentry/sentry-godot \
        --pattern "$ASSET_NAME" \
        --clobber

    # Extract
    echo "📦 Extracting $ASSET_NAME..."
    unzip -q "$ASSET_NAME"
    rm "$ASSET_NAME"

    echo "✅ Sentry GDExtension v{{SENTRY_VERSION}} downloaded"
    echo "   📂 $EXTRACT_DIR"

# Install all platform binaries from pre-built release
build-sentry-gdscript-all:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🎮 Installing Sentry GDExtension for all platforms..."
    echo "   Version: {{SENTRY_VERSION}}+{{SENTRY_GDEXT_COMMIT}}"

    # Download if not present
    if [ ! -d "{{SENTRY_GDEXT_DIR}}/addons/sentry/bin" ]; then
        just download-sentry-gdscript
    fi

    # Install all platforms
    just build-sentry-gdscript-macos
    just build-sentry-gdscript-ios
    just build-sentry-gdscript-android
    just build-sentry-gdscript-windows
    just build-sentry-gdscript-linux

    echo ""
    echo "✅ Sentry GDExtension installed for all platforms"
    just sentry-gdscript-status

# Install macOS binaries
build-sentry-gdscript-macos:
    #!/usr/bin/env bash
    set -euo pipefail

    SRC="{{SENTRY_GDEXT_DIR}}/addons/sentry/bin/macos"
    DEST="project/addons/sentry/bin/macos"

    if [ ! -d "$SRC" ]; then
        echo "❌ macOS binaries not found. Run: just download-sentry-gdscript"
        exit 1
    fi

    echo "🍎 Installing macOS Sentry binaries..."
    mkdir -p "$DEST"
    cp -R "$SRC"/* "$DEST"/
    echo "   ✅ Copied frameworks to $DEST"

# Install iOS binaries
build-sentry-gdscript-ios:
    #!/usr/bin/env bash
    set -euo pipefail

    SRC="{{SENTRY_GDEXT_DIR}}/addons/sentry/bin/ios"
    DEST_ADDON="project/addons/sentry/bin/ios"
    DEST_EXPORT="{{IOS_EXPORT_PATH}}"

    if [ ! -d "$SRC" ]; then
        echo "❌ iOS binaries not found. Run: just download-sentry-gdscript"
        exit 1
    fi

    echo "📱 Installing iOS Sentry binaries..."

    # Copy to addon directory (for reference)
    mkdir -p "$DEST_ADDON"
    cp -R "$SRC"/* "$DEST_ADDON"/

    # Copy xcframeworks to iOS export directory (where .gdextension expects them)
    mkdir -p "$DEST_EXPORT"
    if [ -d "$SRC/libsentry.ios.release.xcframework" ]; then
        cp -R "$SRC/libsentry.ios.release.xcframework" "$DEST_EXPORT"/
    fi
    if [ -d "$SRC/libsentry.ios.debug.xcframework" ]; then
        cp -R "$SRC/libsentry.ios.debug.xcframework" "$DEST_EXPORT"/
    fi
    if [ -d "$SRC/Sentry.xcframework" ]; then
        cp -R "$SRC/Sentry.xcframework" "$DEST_EXPORT"/
    fi

    echo "   ✅ Copied xcframeworks to $DEST_EXPORT"

    # Fix iOS dylib install names (pre-built binaries have incorrect paths)
    # The dylibs need @rpath/libname.dylib instead of build-time paths
    echo "🔧 Fixing iOS dylib install names..."
    for location in "$DEST_ADDON" "$DEST_EXPORT"; do
        for dylib in "$location"/libsentry.ios.*.xcframework/ios-arm64/*.dylib 2>/dev/null; do
            if [ -f "$dylib" ]; then
                name=$(basename "$dylib")
                install_name_tool -id "@rpath/$name" "$dylib" 2>/dev/null || true
                echo "   Fixed: $name"
            fi
        done
    done
    echo "   ✅ iOS dylib install names fixed"

# Install Android binaries
build-sentry-gdscript-android:
    #!/usr/bin/env bash
    set -euo pipefail

    SRC="{{SENTRY_GDEXT_DIR}}/addons/sentry/bin/android"
    DEST="project/addons/sentry/bin/android"
    DEST_AAR="project/addons/sentry"

    if [ ! -d "$SRC" ]; then
        echo "❌ Android binaries not found. Run: just download-sentry-gdscript"
        exit 1
    fi

    echo "🤖 Installing Android Sentry binaries..."
    mkdir -p "$DEST"
    cp "$SRC"/*.so "$DEST"/
    echo "   ✅ Copied .so files to $DEST"

    # Copy AAR files to addon root (required by Godot Android plugin system)
    cp "$SRC"/*.aar "$DEST_AAR"/
    echo "   ✅ Copied .aar files to $DEST_AAR"

# Install Windows binaries
build-sentry-gdscript-windows:
    #!/usr/bin/env bash
    set -euo pipefail

    SRC="{{SENTRY_GDEXT_DIR}}/addons/sentry/bin/windows/x86_64"
    DEST="project/addons/sentry/bin/windows/x86_64"

    if [ ! -d "$SRC" ]; then
        echo "❌ Windows binaries not found. Run: just download-sentry-gdscript"
        exit 1
    fi

    echo "🪟 Installing Windows Sentry binaries..."
    mkdir -p "$DEST"
    cp "$SRC"/*.dll "$DEST"/
    cp "$SRC"/*.exe "$DEST"/
    echo "   ✅ Copied DLLs and crashpad_handler.exe to $DEST"

# Install Linux binaries
build-sentry-gdscript-linux:
    #!/usr/bin/env bash
    set -euo pipefail

    SRC="{{SENTRY_GDEXT_DIR}}/addons/sentry/bin/linux"
    DEST="project/addons/sentry/bin/linux"

    if [ ! -d "$SRC" ]; then
        echo "❌ Linux binaries not found. Run: just download-sentry-gdscript"
        exit 1
    fi

    echo "🐧 Installing Linux Sentry binaries..."
    mkdir -p "$DEST/x86_64" "$DEST/x86_32"
    cp "$SRC/x86_64"/*.so "$DEST/x86_64"/ 2>/dev/null || true
    cp "$SRC/x86_32"/*.so "$DEST/x86_32"/ 2>/dev/null || true
    echo "   ✅ Copied .so files to $DEST"

# Clean installed Sentry binaries (preserves downloaded release)
sentry-gdscript-clean:
    @echo "🧹 Cleaning installed Sentry GDExtension binaries..."
    @rm -rf project/addons/sentry/bin/macos/libsentry.macos.*.framework
    @rm -rf project/addons/sentry/bin/macos/Sentry.framework
    @rm -rf project/addons/sentry/bin/ios
    @rm -f project/addons/sentry/bin/android/*.so
    @rm -f project/addons/sentry/*.aar
    @rm -rf project/addons/sentry/bin/windows
    @rm -rf project/addons/sentry/bin/linux
    @rm -rf {{IOS_EXPORT_PATH}}/libsentry.ios.*.xcframework
    @rm -rf {{IOS_EXPORT_PATH}}/Sentry.xcframework
    @echo "✅ Sentry GDExtension binaries cleaned"
    @echo "💡 Downloaded release preserved at: {{SENTRY_GDEXT_DIR}}"

# Check Sentry installation status
sentry-gdscript-status:
    @echo "📊 Sentry GDExtension Status (v{{SENTRY_VERSION}})"
    @echo "============================================"
    @echo ""
    @echo "📥 Downloaded release:"
    @if [ -d "{{SENTRY_GDEXT_DIR}}/addons/sentry/bin" ]; then echo "   ✅ {{SENTRY_GDEXT_DIR}}"; else echo "   ❌ Not downloaded"; fi
    @echo ""
    @echo "🍎 macOS:"
    @if [ -d "project/addons/sentry/bin/macos/libsentry.macos.release.framework" ]; then echo "   ✅ Installed"; else echo "   ❌ Not installed"; fi
    @echo "📱 iOS:"
    @if [ -d "{{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework" ]; then echo "   ✅ Installed"; else echo "   ❌ Not installed"; fi
    @echo "🤖 Android:"
    @if [ -f "project/addons/sentry/bin/android/libsentry.android.release.arm64.so" ]; then echo "   ✅ Installed"; else echo "   ❌ Not installed"; fi
    @echo "🪟 Windows:"
    @if [ -f "project/addons/sentry/bin/windows/x86_64/libsentry.windows.release.x86_64.dll" ]; then echo "   ✅ Installed"; else echo "   ❌ Not installed"; fi
    @echo "🐧 Linux:"
    @if [ -f "project/addons/sentry/bin/linux/x86_64/libsentry.linux.release.x86_64.so" ]; then echo "   ✅ Installed"; else echo "   ❌ Not installed"; fi

# Validate Sentry integration
sentry-gdscript-validate:
    @echo "🔧 Validating Sentry GDExtension integration..."
    @if [ ! -f "{{SENTRY_ADDON_PATH}}/sentry.gdextension" ]; then \
        echo "❌ sentry.gdextension not found"; \
        exit 1; \
    fi
    @if [ ! -f "project/addons/sentry/bin/macos/libsentry.macos.release.framework/libsentry.macos.release" ]; then \
        echo "❌ macOS binary not found"; \
        exit 1; \
    fi
    @if [ ! -d "{{IOS_EXPORT_PATH}}/libsentry.ios.release.xcframework" ]; then \
        echo "❌ iOS xcframework not found in export path"; \
        exit 1; \
    fi
    @if [ ! -f "project/addons/sentry/bin/android/libsentry.android.release.arm64.so" ]; then \
        echo "❌ Android binary not found"; \
        exit 1; \
    fi
    @if [ ! -f "project/addons/sentry/bin/windows/x86_64/libsentry.windows.release.x86_64.dll" ]; then \
        echo "❌ Windows binary not found"; \
        exit 1; \
    fi
    @echo "✅ Sentry GDExtension validation passed"

# Verify sentry-godot submodule (for reference/customization only)
sentry-gdscript-verify-submodule:
    @echo "🔍 Verifying sentry-godot submodule..."
    @if [ ! -d "{{SENTRY_PATH}}" ]; then \
        echo "❌ Sentry submodule not found at {{SENTRY_PATH}}"; \
        echo "💡 Run: git submodule update --init extras/sentry-godot"; \
        exit 1; \
    fi
    @echo "✅ Sentry submodule present at {{SENTRY_PATH}}"
    @cd {{SENTRY_PATH}} && echo "   📌 Commit: $(git rev-parse --short HEAD)"
    @cd {{SENTRY_PATH}} && echo "   🏷️  Version: $(git describe --tags --abbrev=0 2>/dev/null || echo 'no tag')"

# Complete workflow: download + install + validate
sentry-gdscript-complete:
    @just build-sentry-gdscript-all
    @just sentry-gdscript-validate
    @echo "🎉 Sentry GDExtension complete setup finished"
