# Build System & Template Generation
# Complete build infrastructure for Godot editor and export templates
# Handles compilation, template generation, and build workflows

# Note: Variables and validation functions inherited from imported modules

# ================================
# BUILD DEPENDENCIES
# ================================

# Build Swappy Frame Pacing library from source
build-swappy force="no":
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if libraries already exist
    if [ "{{force}}" != "yes" ] && [ "{{force}}" != "force=yes" ] && [ -f "{{GODOT_SUBMODULE_PATH}}/thirdparty/swappy-frame-pacing/arm64-v8a/libswappy_static.a" ]; then
        echo "✅ Swappy Frame Pacing libraries already installed"
        echo "   Use 'just build-swappy force=yes' to rebuild"
        exit 0
    fi

    if [ "{{force}}" = "yes" ] || [ "{{force}}" = "force=yes" ]; then
        echo "🔥 Force rebuild enabled - rebuilding Swappy Frame Pacing libraries..."
    else
        echo "❌ Swappy Frame Pacing libraries not found, building..."
    fi

    echo "🔨 Building Swappy Frame Pacing from source..."

    # Check prerequisites
    if [ -z "${ANDROID_HOME:-}" ]; then
        echo "❌ Error: ANDROID_HOME environment variable not set"
        exit 1
    fi
    if [ -z "${JAVA_HOME:-}" ]; then
        echo "❌ Error: JAVA_HOME environment variable not set"
        exit 1
    fi

    # Set NDK path
    export ANDROID_NDK="${ANDROID_HOME}/ndk/21.4.7075529"
    if [ ! -d "$ANDROID_NDK" ]; then
        echo "❌ Error: NDK 21.4.7075529 not found at $ANDROID_NDK"
        echo "   Install it using Android Studio SDK Manager"
        exit 1
    fi

    cd extras/godot-swappy

    # Clean up stale lock files if they exist
    if [ -d "build/.repo" ]; then
        echo "🧹 Cleaning up stale repo lock files..."
        find build/.repo -name "*.lock" -delete 2>/dev/null || true
    fi

    # Run build script
    echo "📦 Running build.bash..."
    ./build.bash

    # Extract the built libraries
    echo "📦 Extracting libraries from gamesdk.zip..."
    cd build/package/local
    unzip -q -o gamesdk.zip

    # Extract the AAR file
    echo "📦 Extracting games-frame-pacing-release.aar..."
    unzip -q games-frame-pacing-release.aar -d aar_extracted

    # Copy libraries to Godot thirdparty directory
    echo "📁 Installing libraries to Godot thirdparty..."

    # Define source and destination paths (relative to current dir: build/package/local)
    SOURCE_DIR="aar_extracted/prefab/modules/swappy_static/libs"
    DEST_DIR="{{GODOT_SUBMODULE_PATH}}/thirdparty/swappy-frame-pacing"

    # Create target directories if they don't exist
    mkdir -p "$DEST_DIR/arm64-v8a"
    mkdir -p "$DEST_DIR/armeabi-v7a"
    mkdir -p "$DEST_DIR/x86"
    mkdir -p "$DEST_DIR/x86_64"

    # Copy libraries with proper error handling
    echo "  Copying ARM64-v8a library..."
    if [ -f "$SOURCE_DIR/android.arm64-v8a/libswappy_static.a" ]; then
        cp "$SOURCE_DIR/android.arm64-v8a/libswappy_static.a" "$DEST_DIR/arm64-v8a/"
        echo "  ✅ ARM64-v8a library copied successfully"
    else
        echo "  ❌ ARM64-v8a library not found: $SOURCE_DIR/android.arm64-v8a/libswappy_static.a"
        ls -la "$SOURCE_DIR/android.arm64-v8a/" 2>/dev/null || echo "  🐍 Directory contents: NOT FOUND"
        exit 1
    fi

    echo "  Copying ARMv7-a library..."
    if [ -f "$SOURCE_DIR/android.armeabi-v7a/libswappy_static.a" ]; then
        cp "$SOURCE_DIR/android.armeabi-v7a/libswappy_static.a" "$DEST_DIR/armeabi-v7a/"
        echo "  ✅ ARMv7-a library copied successfully"
    else
        echo "  ❌ ARMv7-a library not found: $SOURCE_DIR/android.armeabi-v7a/libswappy_static.a"
        ls -la "$SOURCE_DIR/android.armeabi-v7a/" 2>/dev/null || echo "  🐍 Directory contents: NOT FOUND"
    fi

    echo "  Copying x86 library..."
    if [ -f "$SOURCE_DIR/android.x86/libswappy_static.a" ]; then
        cp "$SOURCE_DIR/android.x86/libswappy_static.a" "$DEST_DIR/x86/"
        echo "  ✅ x86 library copied successfully"
    else
        echo "  ❌ x86 library not found: $SOURCE_DIR/android.x86/libswappy_static.a"
        ls -la "$SOURCE_DIR/android.x86/" 2>/dev/null || echo "  🐍 Directory contents: NOT FOUND"
    fi

    echo "  Copying x86_64 library..."
    if [ -f "$SOURCE_DIR/android.x86_64/libswappy_static.a" ]; then
        cp "$SOURCE_DIR/android.x86_64/libswappy_static.a" "$DEST_DIR/x86_64/"
        echo "  ✅ x86_64 library copied successfully"
    else
        echo "  ❌ x86_64 library not found: $SOURCE_DIR/android.x86_64/libswappy_static.a"
        ls -la "$SOURCE_DIR/android.x86_64/" 2>/dev/null || echo "  🐍 Directory contents: NOT FOUND"
    fi

    cd ../../../..

    echo "✅ Swappy Frame Pacing built and installed successfully!"
    echo "   Libraries installed to {{GODOT_SUBMODULE_PATH}}/thirdparty/swappy-frame-pacing/"

# ================================

# ================================
# BUILD GODOT
# ================================

# Build custom Godot editor from source
build-editor force="no":
    #!/usr/bin/env bash
    set -euo pipefail

    if [ "{{force}}" != "yes" ] && [ "{{force}}" != "force=yes" ] && [ -f "editor/{{GODOT_EXECUTABLE}}" ]; then
        echo "✅ Godot editor already built: editor/{{GODOT_EXECUTABLE}}"
        echo "⏭️  Skipping editor rebuild (saves 20+ minutes)"
        echo "   Use 'just build-editor force=yes' to rebuild"
        exit 0
    fi

    if [ "{{force}}" = "yes" ] || [ "{{force}}" = "force=yes" ]; then
        echo "🔥 Force rebuild enabled - rebuilding Godot editor..."
    else
        echo "🔨 Building Godot editor (this will take 20+ minutes)..."
    fi

    echo "🔨 Building Godot editor..."
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=macos target=editor production=yes --jobs={{jobs}} # vulkan_sdk_path=
    mv bin/godot.macos.editor.arm64 ../editor/{{GODOT_EXECUTABLE}}

# Build iOS export templates (complete chain)
templates-ios force="no":
    just ios-build-template {{force}}
    just package-ios-template {{force}}

# Build Android export templates (complete chain)
# Use force=yes to rebuild Swappy libraries even if they exist
templates-android force="no":
    # Build Android templates with proper parameters
    just build-android-templates force={{force}}

    just setup-android

# Build all export templates (iOS + Android + Windows)
templates-all force="no":
    just build-moltenvk {{force}}
    just templates-ios {{force}}
    just templates-android force={{force}}
    just build-windows-templates {{force}}

# Build macOS export templates
build-macos-templates: validate-env
    @echo "Building export templates..."
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=macos target=template_debug --jobs={{jobs}}
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=macos target=template_release production=yes --jobs={{jobs}}
    mkdir -p templates
    cp {{GODOT_SUBMODULE_PATH}}/bin/godot.macos.template_debug.* templates/
    cp {{GODOT_SUBMODULE_PATH}}/bin/godot.macos.template_release.* templates/

# Build and package iOS templates
build-and-package-ios-templates force="no": validate-env
    just build-moltenvk {{force}}
    just ios-build-template {{force}}
    just package-ios-template {{force}}

# Build iOS template
ios-build-template force="no":
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if iOS template artifacts already exist
    if [ "{{force}}" != "yes" ] && [ "{{force}}" != "force=yes" ] && [ -f "{{GODOT_SUBMODULE_PATH}}/bin/libgodot.ios.template_release.arm64.a" ] && [ -f "{{GODOT_SUBMODULE_PATH}}/bin/libgodot.ios.template_debug.arm64.a" ]; then
        echo "✅ iOS templates already built"
        echo "   Use 'just ios-build-template force=yes' to rebuild"
        exit 0
    fi

    if [ "{{force}}" = "yes" ] || [ "{{force}}" = "force=yes" ]; then
        echo "🔥 Force rebuild enabled - rebuilding iOS templates..."
    else
        echo "❌ iOS templates not found, building..."
    fi

    echo "🔨 Building iOS templates..."
    echo "============================="
    echo "BUILDING IOS EXECUTABLES"
    echo "============================="
    cd {{justfile_directory()}}/{{GODOT_SUBMODULE_PATH}} && scons platform=ios target=template_debug arch=arm64 --jobs={{jobs}}
    cd {{justfile_directory()}}/{{GODOT_SUBMODULE_PATH}} && scons platform=ios target=template_release arch=arm64 production=yes optimize=size --jobs={{jobs}}

    echo "=========================="
    echo "PREPARING IOS TEMPLATES"
    echo "=========================="
    cd {{justfile_directory()}}/{{GODOT_SUBMODULE_PATH}} && chmod +x bin/libgodot*.a
    cd {{justfile_directory()}}/{{GODOT_SUBMODULE_PATH}} && mkdir -p misc/dist/ios_xcode/libgodot.ios.template_release.xcframework/ios-arm64
    cd {{justfile_directory()}}/{{GODOT_SUBMODULE_PATH}} && mkdir -p misc/dist/ios_xcode/libgodot.ios.template_debug.xcframework/ios-arm64
    cd {{justfile_directory()}}/{{GODOT_SUBMODULE_PATH}} && cp bin/libgodot.ios.template_release.arm64.a misc/dist/ios_xcode/libgodot.ios.template_release.xcframework/ios-arm64/libgodot.a
    cd {{justfile_directory()}}/{{GODOT_SUBMODULE_PATH}} && cp bin/libgodot.ios.template_debug.arm64.a misc/dist/ios_xcode/libgodot.ios.template_debug.xcframework/ios-arm64/libgodot.a

    # Copying to current xcode framework
    cd {{justfile_directory()}}/{{GODOT_SUBMODULE_PATH}} && chmod +x bin/libgodot*
    mkdir -p {{justfile_directory()}}/export/ios/{{GAME_NAME}}.xcframework/ios-arm64
    cp {{justfile_directory()}}/{{GODOT_SUBMODULE_PATH}}/bin/libgodot.ios.template_release.arm64.a {{justfile_directory()}}/export/ios/{{GAME_NAME}}.xcframework/ios-arm64/libgodot.a

# Package iOS template
package-ios-template force="no":
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if iOS template package already exists
    if [ "{{force}}" != "yes" ] && [ "{{force}}" != "force=yes" ] && [ -f "templates/ios.zip" ]; then
        echo "✅ iOS template package already built"
        echo "   Use 'just package-ios-template force=yes' to rebuild"
        exit 0
    fi

    if [ "{{force}}" = "yes" ] || [ "{{force}}" = "force=yes" ]; then
        echo "🔥 Force rebuild enabled - rebuilding iOS template package..."
    else
        echo "❌ iOS template package not found, building..."
    fi

    echo "📦 Packaging iOS templates..."
    echo "=========================="
    echo "PACKAGING IOS TEMPLATES"
    echo "=========================="
    rm -f templates/ios.zip
    mkdir -p templates
    cd {{GODOT_SUBMODULE_PATH}}/misc/dist/ios_xcode && zip -9 -r ../../../../templates/ios.zip *

    echo "iOS templates built and packaged successfully."

# Note: iOS executable building is now handled by templates-ios function

# ================================
# FORCE PARAMETER VALIDATION
# ================================

# Validate force parameter consistency across build system
validate-force-usage:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🔍 Validating force parameter consistency across build system..."
    echo ""

    FORCE_PATTERNS=(
        "templates-ios.*force="
        "templates-android.*force="
        "templates-all.*force="
        "build-toolchain.*force="
        "build-artifacts.*force="
        "build-pipeline.*force="
        "ios-build-template.*force="
        "package-ios-template.*force="
        "build-and-package-ios-templates.*force="
        "sentry-native-ios-build.*force="
        "build-sentry-native-ios-debug.*force="
        "build-sentry-native-ios-release.*force="
        "sentry-windows-build.*force="
        "build-sentry-native-windows-release.*force="
    )

    echo "Checking for consistent force parameter patterns..."
    for pattern in "${FORCE_PATTERNS[@]}"; do
        if rg -q "$pattern" justfiles/; then
            echo "✅ Found: $pattern"
        else
            echo "❌ Missing: $pattern"
        fi
    done

    echo ""
    echo "Checking for deprecated patterns..."
    if rg -q "force_swappy" justfiles/; then
        echo "❌ Found deprecated 'force_swappy' pattern - should be 'force'"
        rg "force_swappy" justfiles/
    else
        echo "✅ No deprecated 'force_swappy' patterns found"
    fi

    if rg -q "_check-or-build-" justfiles/; then
        echo "❌ Found deprecated '_check-or-build-' patterns - should use direct build recipes with force parameter"
        rg "_check-or-build-" justfiles/
    else
        echo "✅ No deprecated '_check-or-build-' patterns found"
    fi

    echo ""
    echo "🎉 Force parameter validation complete!"

# ================================
# THREE-TIER BUILD SYSTEM
# ================================

# Tier 1: Build Toolchain (Foundation) - Editor + Templates
build-toolchain force="no": validate-env
    @echo "🔧 Building toolchain (editor + templates)..."
    just build-editor {{force}}
    just templates-all {{force}}
    @echo "✅ Toolchain complete"

# Tier 2: Build Artifacts (Deployable Files) - All distribution files
build-artifacts force="no": validate-env
    @echo "📦 Building artifacts (all deployable files)..."
    just build-toolchain {{force}}
    just setup-android-templates {{force}}
    just export-all-android {{force}}
    just build-ios-all {{force}}
    @echo "✅ All artifacts complete"

# Tier 3: Complete Pipeline (Zero to Device Deployment)
build-pipeline force="no": validate-env
    @echo "🚀 Complete pipeline - source to device deployment..."
    just build-artifacts {{force}}
    just install-apk-android-debug
    @echo "✅ Complete pipeline finished!"

# ================================
# C++ DEVELOPMENT WORKFLOW
# ================================

# Complete C++ development workflow - rebuild templates and deploy to device
# Use this after making changes to C++ modules (Firebase, custom modules)
cpp-dev:
    @echo "🔧 C++ Development Workflow - Building templates and deploying..."
    @echo ""
    @echo "Step 1: Building Android templates (C++ → .aar)..."
    just build-android-templates
    @echo ""
    @echo "Step 2: Installing Android template..."
    just install-android-template
    @echo ""
    @echo "Step 3: Fast build and deploy to device..."
    just fastbuild-android
    @echo ""
    @echo "✅ C++ development workflow complete - app deployed to device"
    @echo "📱 Android: Deployed to device"
    @echo "🍎 iOS: Ready for device deployment"
    @echo "💡 Use 'just run-ios-iphone' to deploy iOS to iPhone"
    @echo "💡 Use 'just run-ios-ipad' to deploy iOS to iPad"

# Legacy: Original build-all (now alias for build-toolchain)
build-all: build-toolchain

# Note: Platform-specific commands provided by platform justfiles