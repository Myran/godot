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
    if [ "{{force}}" != "yes" ] && [ -f "{{GODOT_SUBMODULE_PATH}}/thirdparty/swappy-frame-pacing/arm64-v8a/libswappy_static.a" ]; then
        echo "✅ Swappy Frame Pacing libraries already installed"
        echo "   Use 'just build-swappy force=yes' to rebuild"
        exit 0
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
    unzip -q gamesdk.zip

    # Extract the AAR file
    echo "📦 Extracting games-frame-pacing-release.aar..."
    unzip -q games-frame-pacing-release.aar -d aar_extracted

    # Copy libraries to Godot thirdparty directory
    echo "📁 Installing libraries to Godot thirdparty..."
    cd ../../../..

    # Create target directories
    mkdir -p {{GODOT_SUBMODULE_PATH}}/thirdparty/swappy-frame-pacing/arm64-v8a
    mkdir -p {{GODOT_SUBMODULE_PATH}}/thirdparty/swappy-frame-pacing/armeabi-v7a
    mkdir -p {{GODOT_SUBMODULE_PATH}}/thirdparty/swappy-frame-pacing/x86
    mkdir -p {{GODOT_SUBMODULE_PATH}}/thirdparty/swappy-frame-pacing/x86_64

    # Copy libraries
    cp extras/godot-swappy/build/package/local/aar_extracted/prefab/modules/swappy_static/libs/android.arm64-v8a/libswappy_static.a \
       {{GODOT_SUBMODULE_PATH}}/thirdparty/swappy-frame-pacing/arm64-v8a/
    cp extras/godot-swappy/build/package/local/aar_extracted/prefab/modules/swappy_static/libs/android.armeabi-v7a/libswappy_static.a \
       {{GODOT_SUBMODULE_PATH}}/thirdparty/swappy-frame-pacing/armeabi-v7a/
    cp extras/godot-swappy/build/package/local/aar_extracted/prefab/modules/swappy_static/libs/android.x86/libswappy_static.a \
       {{GODOT_SUBMODULE_PATH}}/thirdparty/swappy-frame-pacing/x86/
    cp extras/godot-swappy/build/package/local/aar_extracted/prefab/modules/swappy_static/libs/android.x86_64/libswappy_static.a \
       {{GODOT_SUBMODULE_PATH}}/thirdparty/swappy-frame-pacing/x86_64/

    echo "✅ Swappy Frame Pacing built and installed successfully!"
    echo "   Libraries installed to {{GODOT_SUBMODULE_PATH}}/thirdparty/swappy-frame-pacing/"

# Ensure Sentry binaries are available for Android builds
ensure-sentry-binaries:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🔔 Ensuring Sentry binaries are available..."

    # Check if Android AAR files exist
    if [ -f "project/addons/sentry/bin/android/sentry_android_godot_plugin.debug.aar" ] && [ -f "project/addons/sentry/bin/android/sentry_android_godot_plugin.release.aar" ]; then
        echo "✅ Sentry Android AAR files already available"
    else
        # Try to move from root directory if they exist there
        if [ -f "project/addons/sentry/sentry_android_godot_plugin.debug.aar" ] && [ -f "project/addons/sentry/sentry_android_godot_plugin.release.aar" ]; then
            echo "📁 Moving Sentry AAR files to correct location..."
            mkdir -p project/addons/sentry/bin/android
            mv project/addons/sentry/sentry_android_godot_plugin.debug.aar project/addons/sentry/bin/android/
            mv project/addons/sentry/sentry_android_godot_plugin.release.aar project/addons/sentry/bin/android/
            echo "✅ Sentry Android AAR files moved successfully"
        else
            echo "⚠️  Sentry Android AAR files not found"
            echo "💡 Run 'just build-sentry-all' to build Sentry from source"
        fi
    fi

# ================================
# BUILD GODOT
# ================================

# Build custom Godot editor from source
build-editor: validate-env
    @echo "Building Godot editor..."
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=macos target=editor production=yes --jobs={{jobs}} # vulkan_sdk_path=
    mv {{GODOT_SUBMODULE_PATH}}/bin/godot.macos.editor.* editor/

# Build iOS export templates (complete chain)
templates-ios:
    just build-and-package-ios-templates

# Build Android export templates (complete chain)
# Use force_swappy=yes to rebuild Swappy libraries even if they exist
templates-android minimal="no" force_swappy="no":
    @[ "{{force_swappy}}" = "yes" ] && just build-swappy force=yes || true
    just build-android-templates minimal={{minimal}}
    just setup-android

# Build all export templates (iOS + Android + Windows)
templates-all:
    just ensure-sentry-binaries
    just ensure-moltenvk
    just templates-ios
    just templates-android
    just build-windows-templates

# Build macOS export templates
build-macos-templates: validate-env
    @echo "Building export templates..."
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=macos target=template_debug --jobs={{jobs}}
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=macos target=template_release production=yes --jobs={{jobs}}
    mkdir -p templates
    cp {{GODOT_SUBMODULE_PATH}}/bin/godot.macos.template_debug.* templates/
    cp {{GODOT_SUBMODULE_PATH}}/bin/godot.macos.template_release.* templates/

# Build and package iOS templates
build-and-package-ios-templates: validate-env
    just ensure-moltenvk
    just ios-build-template
    just package-ios-template

# Build iOS template
ios-build-template:
    @echo "============================="
    @echo "BUILDING IOS EXECUTABLES"
    @echo "============================="
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=ios target=template_debug arch=arm64 --jobs={{jobs}}
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=ios target=template_release arch=arm64 production=yes optimize=size --jobs={{jobs}}

    @echo "=========================="
    @echo "PREPARING IOS TEMPLATES"
    @echo "=========================="
    chmod +x {{GODOT_SUBMODULE_PATH}}/bin/libgodot*.a
    mkdir -p {{GODOT_SUBMODULE_PATH}}/misc/dist/ios_xcode/libgodot.ios.template_release.xcframework/ios-arm64
    mkdir -p {{GODOT_SUBMODULE_PATH}}/misc/dist/ios_xcode/libgodot.ios.template_debug.xcframework/ios-arm64
    cp {{GODOT_SUBMODULE_PATH}}/bin/libgodot.ios.template_release.arm64.a {{GODOT_SUBMODULE_PATH}}/misc/dist/ios_xcode/libgodot.ios.template_release.xcframework/ios-arm64/libgodot.a
    cp {{GODOT_SUBMODULE_PATH}}/bin/libgodot.ios.template_debug.arm64.a {{GODOT_SUBMODULE_PATH}}/misc/dist/ios_xcode/libgodot.ios.template_debug.xcframework/ios-arm64/libgodot.a

    # Copying to current xcode framework
    chmod +x {{GODOT_SUBMODULE_PATH}}/bin/libgodot*
    mkdir -p export/ios/{{GAME_NAME}}.xcframework/ios-arm64
    cp {{GODOT_SUBMODULE_PATH}}/bin/libgodot.ios.template_release.arm64.a export/ios/{{GAME_NAME}}.xcframework/ios-arm64/libgodot.a

# Package iOS template
package-ios-template:
    @echo "=========================="
    @echo "PACKAGING IOS TEMPLATES"
    @echo "=========================="
    rm -f templates/ios.zip
    mkdir -p templates
    cd {{GODOT_SUBMODULE_PATH}}/misc/dist/ios_xcode && zip -9 -r ../../../../templates/ios.zip *

    @echo "iOS templates built and packaged successfully."

# Note: build-ios-executable is provided by justfile-platform-ios.justfile

# ================================
# THREE-TIER BUILD SYSTEM
# ================================

# Tier 1: Build Toolchain (Foundation) - Editor + Templates
build-toolchain: validate-env
    @echo "🔧 Building toolchain (editor + templates)..."
    just build-editor
    just templates-all
    @echo "✅ Toolchain complete"

# Tier 2: Build Artifacts (Deployable Files) - All distribution files
build-artifacts: validate-env
    @echo "📦 Building artifacts (all deployable files)..."
    just build-toolchain
    just setup-android-templates
    just export-all-android
    just export-all-ios
    @echo "✅ All artifacts complete"

# Tier 3: Complete Pipeline (Zero to Device Deployment)
build-pipeline: validate-env
    @echo "🚀 Complete pipeline - source to device deployment..."
    just build-artifacts
    just install-apk-android
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
    @echo "💡 Use 'just launch-ios-iphone' to deploy iOS to iPhone"
    @echo "💡 Use 'just launch-ios-ipad' to deploy iOS to iPad"

# Legacy: Original build-all (now alias for build-toolchain)
build-all: build-toolchain

# Note: Platform-specific commands provided by platform justfiles