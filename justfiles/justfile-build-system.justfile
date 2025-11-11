# Build System & Template Generation
# Complete build infrastructure for Godot editor and export templates
# Handles compilation, template generation, and build workflows

# Note: Variables and validation functions inherited from imported modules

# Build custom Godot editor from source
build-editor: validate-env
    @echo "Building Godot editor..."
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=macos target=editor production=yes --jobs={{jobs}} # vulkan_sdk_path=
    mv {{GODOT_SUBMODULE_PATH}}/bin/godot.macos.editor.* editor/

# Build iOS export templates (complete chain)
templates-ios:
    just build-and-package-ios-templates

# Build Android export templates (complete chain)  
templates-android minimal="no":
    just build-android-templates minimal={{minimal}}
    just setup-android

# Build all export templates (iOS + Android)
templates-all:
    just templates-ios
    just templates-android

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