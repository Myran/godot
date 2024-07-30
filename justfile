# Comprehensive Justfile for Godot 4 Projects

# Set default shell
set shell := ["bash", "-c"]

# Environment variables
export GAME_NAME := env_var_or_default("CI_PROJECT_NAME", "gametwo")
export GODOT_VERSION := "4.0"
export GODOT_BUILD_VERSION :="4.3.rc"
export GODOT_EXECUTABLE := "godot.macos.editor.arm64"  # For Apple Silicon Macs
# Use the following line instead for Intel Macs:
# export GODOT_EXECUTABLE := "godot.macos.editor.x86_64"
export PROJECT_PATH := justfile_directory() + "/project"
export ANDROID_SDK_PATH := env_var_or_default("ANDROID_SDK_PATH", "~/Library/Android/sdk")
export ANDROID_NDK_PATH := env_var_or_default("ANDROID_NDK_PATH", ANDROID_SDK_PATH + "/ndk/25.1.8937393")
export ANDROID_PACKAGE_NAME := env_var_or_default("ANDROID_PACKAGE_NAME", "org.godotengine." + GAME_NAME)
export IOS_BUNDLE_IDENTIFIER := env_var_or_default("IOS_BUNDLE_IDENTIFIER", "com.godotengine." + GAME_NAME)
export KEYSTORE_PATH := env_var_or_default("KEYSTORE_PATH", "./keys/" + GAME_NAME + ".keystore")
export KEYSTORE_PASSWORD := env_var_or_default("KEYSTORE_PASSWORD", "lovegametwo")
export KEY_PASSWORD := env_var_or_default("KEY_PASSWORD", "lovegametwo")
export APPLE_TEAM_ID := env_var_or_default("APPLE_TEAM_ID", "123")
export APPLE_ID := env_var_or_default("APPLE_ID", "123")
export APP_STORE_CONNECT_API_KEY_PATH := env_var_or_default("APP_STORE_CONNECT_API_KEY_PATH", "123")
export IOS_PROVISIONING_PROFILE_UUID := env_var_or_default("IOS_PROVISIONING_PROFILE_UUID", "123")
#export ANDROID_GRADLE_DIR := "build/gradle"
#export EDITOR_SCALE := env_var_or_default("EDITOR_SCALE", "3.0")

# Godot submodule settings
GODOT_REPO := "https://github.com/godotengine/godot.git"
GODOT_BRANCH := "gametwo"  # Replace with your custom branch name
GODOT_SUBMODULE_PATH := "godot"

# Default Android device IP (can be overridden)
ANDROID_DEVICE_IP := "192.168.1.100"

# Utility functions
timestamp := `date +%Y%m%d%H%M%S`
jobs := `sysctl -n hw.logicalcpu`

default:
    @just --list
        
# Setup environment submodule
# Validate environment variables
validate-env:
    #!/usr/bin/env bash
    set -euo pipefail
    missing_vars=()
    [[ -z "$GAME_NAME" ]] && missing_vars+=("GAME_NAME")
    [[ -z "$KEYSTORE_PASSWORD" ]] && missing_vars+=("KEYSTORE_PASSWORD")
    [[ -z "$KEY_PASSWORD" ]] && missing_vars+=("KEY_PASSWORD")
    [[ -z "$APPLE_TEAM_ID" ]] && missing_vars+=("APPLE_TEAM_ID")
    [[ -z "$APPLE_ID" ]] && missing_vars+=("APPLE_ID")
    [[ -z "$IOS_PROVISIONING_PROFILE_UUID" ]] && missing_vars+=("IOS_PROVISIONING_PROFILE_UUID")
    if [ ${#missing_vars[@]} -ne 0 ]; then
        echo "Error: The following environment variables are not set:"
        printf '%s\n' "${missing_vars[@]}"
        exit 1
    fi
    echo "All required environment variables are set."

# Install dependencies
install-deps:
    @echo "Installing dependencies..."
    brew install scons
    brew install yasm
    brew install pipx
    brew install ninja
    pipx install "gdtoolkit==4.*"
    pipx inject gdtoolkit setuptools
#   pip3 install "gdtoolkit==4.*" # For linting and formatting
install-ios-deps:
    cd extras/MoltenVK
    ./fetchDependencies --ios
    make ios
    cd../..
    cp -R extras/MoltenVk/Package/Latest/MoltenVK/Static/MoltenVK.xcframework export/ios
# Build Godot editor
build-editor: validate-env
    @echo "Building Godot editor..."
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=macos target=editor use_lto=yes --jobs={{jobs}}
    mv {{GODOT_SUBMODULE_PATH}}/bin/godot.macos.editor.* editor/

# Build export templates
build-templates: validate-env
    @echo "Building export templates..."
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=macos target=template_debug --jobs={{jobs}}
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=macos target=template_release --jobs={{jobs}}
    mkdir -p templates
    cp {{GODOT_SUBMODULE_PATH}}/bin/godot.macos.template_debug.* templates/
    cp {{GODOT_SUBMODULE_PATH}}/bin/godot.macos.template_release.* templates/

# Run Godot editor
run-editor:
    @echo "Running Godot editor..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --editor

# Pre-build hook
pre-build:
    @echo "Running pre-build tasks..."
    just update-export-presets
    just update-project-settings

# Export project for different platforms

# Build and package iOS templates
build-and-package-ios-templates: validate-env
    @echo "============================="
    @echo "BUILDING IOS EXECUTABLES"
    @echo "============================="
    # Build debug and release templates
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=ios target=template_debug arch=arm64 --jobs={{jobs}}
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=ios target=template_release arch=arm64 --jobs={{jobs}}

    @echo "=========================="
    @echo "PREPARING IOS TEMPLATES"
    @echo "=========================="
    # Change access permissions
    chmod +x {{GODOT_SUBMODULE_PATH}}/bin/libgodot*.a
    # Create necessary directories
    mkdir -p {{GODOT_SUBMODULE_PATH}}/misc/dist/ios_xcode/libgodot.ios.template_release.xcframework/ios-arm64
    mkdir -p {{GODOT_SUBMODULE_PATH}}/misc/dist/ios_xcode/libgodot.ios.template_debug.xcframework/ios-arm64
    # Copy binaries to appropriate locations
    cp {{GODOT_SUBMODULE_PATH}}/bin/libgodot.ios.template_release.arm64.a {{GODOT_SUBMODULE_PATH}}/misc/dist/ios_xcode/libgodot.ios.template_release.xcframework/ios-arm64/libgodot.a
    cp {{GODOT_SUBMODULE_PATH}}/bin/libgodot.ios.template_debug.arm64.a {{GODOT_SUBMODULE_PATH}}/misc/dist/ios_xcode/libgodot.ios.template_debug.xcframework/ios-arm64/libgodot.a

    # Copying to current xcode framework
    chmod +x {{GODOT_SUBMODULE_PATH}}/bin/libgodot*
    cp {{GODOT_SUBMODULE_PATH}}/bin/libgodot.ios.template_release.arm64.a export/ios/{{GAME_NAME}}.xcframework/ios-arm64/libgodot.a
    # cp {{GODOT_SUBMODULE_PATH}}/bin/libgodot.ios.template_debug.arm64.a export/ios/{{GAME_NAME}}-debug.xcframework/ios-arm64/libgodot.debug.a



    @echo "=========================="
    @echo "PACKAGING IOS TEMPLATES"
    @echo "=========================="
    # Remove old template if it exists
    rm -f templates/ios.zip
    # Create templates directory if it doesn't exist
    mkdir -p templates
    # Package the template
    cd {{GODOT_SUBMODULE_PATH}}/misc/dist/ios_xcode && zip -9 -r ../../../../templates/ios.zip *

    @echo "iOS templates built and packaged successfully."



export-project platform: pre-build
    @echo "Exporting project for {{platform}}..."
    mkdir -p export/{{platform}}
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --export-{{platform}} export/{{platform}}/{{GAME_NAME}}
build-android-templates:
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=android target=template_debug arch=arm32 --jobs=$(sysctl -n hw.logicalcpu) module_bmp_enabled=no module_bullet_enabled=no module_csg_enabled=no module_dds_enabled=no module_enet_enabled=no module_etc_enabled=no module_gdnative_enabled=no module_gridmap_enabled=no module_hdr_enabled=no module_mbedtls_enabled=yes module_mobile_vr_enabled=no module_opus_enabled=no module_pvr_enabled=no module_recast_enabled=no module_regex_enabled=no module_squish_enabled=no module_tga_enabled=no module_thekla_unwrap_enabled=no module_theora_enabled=no module_tinyexr_enabled=no module_vorbis_enabled=no module_webm_enabled=no module_websocket_enabled=no disable_advanced_gui=no disable_3d=yes optimize=size use_lto=yes
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=android target=template_debug arch=arm64 --jobs=$(sysctl -n hw.logicalcpu) module_bmp_enabled=no module_bullet_enabled=no module_csg_enabled=no module_dds_enabled=no module_enet_enabled=no module_etc_enabled=no module_gdnative_enabled=no module_gridmap_enabled=no module_hdr_enabled=no module_mbedtls_enabled=yes module_mobile_vr_enabled=no module_opus_enabled=no module_pvr_enabled=no module_recast_enabled=no module_regex_enabled=no module_squish_enabled=no module_tga_enabled=no module_thekla_unwrap_enabled=no module_theora_enabled=no module_tinyexr_enabled=no module_vorbis_enabled=no module_webm_enabled=no module_websocket_enabled=no disable_advanced_gui=no disable_3d=yes optimize=size use_lto=yes
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=android target=template_release arch=arm32 --jobs=$(sysctl -n hw.logicalcpu) module_bmp_enabled=no module_bullet_enabled=no module_csg_enabled=no module_dds_enabled=no module_enet_enabled=no module_etc_enabled=no module_gdnative_enabled=no module_gridmap_enabled=no module_hdr_enabled=no module_mbedtls_enabled=yes module_mobile_vr_enabled=no module_opus_enabled=no module_pvr_enabled=no module_recast_enabled=no module_regex_enabled=no module_squish_enabled=no module_tga_enabled=no module_thekla_unwrap_enabled=no module_theora_enabled=no module_tinyexr_enabled=no module_vorbis_enabled=no module_webm_enabled=no module_websocket_enabled=no disable_advanced_gui=no disable_3d=yes optimize=size use_lto=yes
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=android target=template_release arch=arm64 --jobs=$(sysctl -n hw.logicalcpu) module_bmp_enabled=no module_bullet_enabled=no module_csg_enabled=no module_dds_enabled=no module_enet_enabled=no module_etc_enabled=no module_gdnative_enabled=no module_gridmap_enabled=no module_hdr_enabled=no module_mbedtls_enabled=yes module_mobile_vr_enabled=no module_opus_enabled=no module_pvr_enabled=no module_recast_enabled=no module_regex_enabled=no module_squish_enabled=no module_tga_enabled=no module_thekla_unwrap_enabled=no module_theora_enabled=no module_tinyexr_enabled=no module_vorbis_enabled=no module_webm_enabled=no module_websocket_enabled=no disable_advanced_gui=no disable_3d=yes optimize=size use_lto=yes
    cd {{GODOT_SUBMODULE_PATH}}/platform/android/java && ./gradlew generateGodotTemplates
    echo "Moving templates...."
    mv {{GODOT_SUBMODULE_PATH}}/bin/android_debug.apk templates/android_debug.apk
    mv {{GODOT_SUBMODULE_PATH}}/bin/android_release.apk templates/android_release.apk
    mv {{GODOT_SUBMODULE_PATH}}/bin/android_source.zip templates/android_source.zip
install-android-template:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "installing android gradle for custom builds"
    rm -rf project/android
    mkdir project/android
    unzip -o templates/android_source.zip -d project/android/build
    chmod +x project/android
    md5=$(md5sum templates/android_source.zip | awk NF=1)
    rp=$(realpath templates/android_source.zip)
    echo "$rp [$md5]"  >> project/android/.build_version
    touch project/android/.gdignore
    echo "Done installing android template in "

build-android: pre-build
    @echo "Building and exporting for Android..."
    echo $ANDROID_KEYSTORE | base64 -d > android.keystore
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --export-debug "Android" ../export/android/{{GAME_NAME}}_debug.apk --headless
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --export-release "Android" ../export/android/{{GAME_NAME}}.apk --headless

# Build and export for iOS
build-ios: pre-build
    @echo "Building and exporting for iOS..."
    echo $IOS_PROVISIONING_PROFILE | base64 -d > profile.mobileprovision
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --export-debug "iOS" export/ios/{{GAME_NAME}}.ipa

# Save iOS PCK file
save-ios: pre-build
    @echo "Saving iOS PCK file..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --no-window --export-pack ios ../export/ios/{{GAME_NAME}}.pck

# Save iOS PCK file directly to app
save-ios-to-app: pre-build
    @echo "Saving iOS PCK file directly to app..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --no-window --export-pack ios ../export/ios/build/products/Debug-iphoneos/{{GAME_NAME}}.app/{{GAME_NAME}}.pck

# Save Android APK
save-android: pre-build
    @echo "Saving Android APK..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --verbose --headless --export-debug "Android" ../export/android/{{GAME_NAME}}.apk

# Lint GDScript files
lint:
    @echo "Linting GDScript files..."
    gdlint {{PROJECT_PATH}}

# Format GDScript files
format:
    @echo "Formatting GDScript files..."
    gdformat {{PROJECT_PATH}}

# Update version
update-version:
    @echo "Updating version..."
    sed -i '' 's/^version_code .*/version_code {{timestamp}}/' {{PROJECT_PATH}}/export_presets.cfg
    sed -i '' 's/^application\/version .*/application\/version "1.0.{{timestamp}}"/' {{PROJECT_PATH}}/export_presets.cfg

# Deploy to App Store
deploy-ios: build-ios
    @echo "Deploying to App Store..."
    cd export/ios && fastlane beta

# Deploy to Play Store
deploy-android: build-android
    @echo "Deploying to Play Store..."
    cd export/android && fastlane internal

# Generate GitLab CI configuration
generate-gitlab-ci:
    @echo "Generating GitLab CI configuration..."
    echo "stages:" > .gitlab-ci.yml
    echo "  - validate" >> .gitlab-ci.yml
    echo "  - build" >> .gitlab-ci.yml
    echo "  - test" >> .gitlab-ci.yml
    echo "  - deploy" >> .gitlab-ci.yml
    echo "" >> .gitlab-ci.yml
    echo "variables:" >> .gitlab-ci.yml
    echo "  GIT_SUBMODULE_STRATEGY: recursive" >> .gitlab-ci.yml
    echo "" >> .gitlab-ci.yml
    echo "validate:" >> .gitlab-ci.yml
    echo "  stage: validate" >> .gitlab-ci.yml
    echo "  script:" >> .gitlab-ci.yml
    echo "    - just validate-env" >> .gitlab-ci.yml
    echo "" >> .gitlab-ci.yml
    echo "build:" >> .gitlab-ci.yml
    echo "  stage: build" >> .gitlab-ci.yml
    echo "  script:" >> .gitlab-ci.yml
    echo "    - just install-deps" >> .gitlab-ci.yml
    echo "    - just build-editor" >> .gitlab-ci.yml
    echo "    - just build-templates" >> .gitlab-ci.yml
    echo "    - just build-android" >> .gitlab-ci.yml
    echo "    - just build-ios" >> .gitlab-ci.yml
    echo "  artifacts:" >> .gitlab-ci.yml
    echo "    paths:" >> .gitlab-ci.yml
    echo "      - editor/" >> .gitlab-ci.yml
    echo "      - export/" >> .gitlab-ci.yml
    echo "      - templates/" >> .gitlab-ci.yml
    echo "" >> .gitlab-ci.yml
    echo "test:" >> .gitlab-ci.yml
    echo "  stage: test" >> .gitlab-ci.yml
    echo "  script:" >> .gitlab-ci.yml
    echo "    - just lint" >> .gitlab-ci.yml
    echo "" >> .gitlab-ci.yml
    echo "deploy:" >> .gitlab-ci.yml
    echo "  stage: deploy" >> .gitlab-ci.yml
    echo "  only:" >> .gitlab-ci.yml
    echo "    - master" >> .gitlab-ci.yml
    echo "  script:" >> .gitlab-ci.yml
    echo "    - just update-version" >> .gitlab-ci.yml
    echo "    - just deploy-ios" >> .gitlab-ci.yml
    echo "    - just deploy-android" >> .gitlab-ci.yml


# Install pre-commit hook
install-hooks:
    @echo "Installing pre-commit hook..."
    echo "#!/bin/sh" > .git/hooks/pre-commit
    echo "just generate-gitlab-ci" >> .git/hooks/pre-commit
    echo "git add .gitlab-ci.yml" >> .git/hooks/pre-commit
    chmod +x .git/hooks/pre-commit
    @echo "Pre-commit hook installed successfully."

# Update export presets
update-export-presets:
    @echo "Updating export presets..."
    sed -i '' 's#keystore/path=".*"#keystore/path="{{KEYSTORE_PATH}}"#g' {{PROJECT_PATH}}/export_presets.cfg
    sed -i '' 's#keystore/password=".*"#keystore/password="{{KEYSTORE_PASSWORD}}"#g' {{PROJECT_PATH}}/export_presets.cfg
    sed -i '' 's#keystore/alias=".*"#keystore/alias="{{GAME_NAME}}"#g' {{PROJECT_PATH}}/export_presets.cfg
    sed -i '' 's#keystore/alias_password=".*"#keystore/alias_password="{{KEY_PASSWORD}}"#g' {{PROJECT_PATH}}/export_presets.cfg
    sed -i '' 's#application/identifier=".*"#application/identifier="{{IOS_BUNDLE_IDENTIFIER}}"#g' {{PROJECT_PATH}}/export_presets.cfg
    sed -i '' 's#application/signature=".*"#application/signature="{{APPLE_TEAM_ID}}"#g' {{PROJECT_PATH}}/export_presets.cfg
    sed -i '' 's#provisioning_profile/uuid=".*"#provisioning_profile/uuid="{{IOS_PROVISIONING_PROFILE_UUID}}"#g' {{PROJECT_PATH}}/export_presets.cfg

# Update project settings
update-project-settings:
    @echo "Updating project settings..."
    
    
    # Full build and deploy process
full-process: validate-env
    @echo "Running full build and deploy process..."
    just install-deps
    just build-editor
    just build-templates
    just update-version
    just format
    just build-android
    just build-ios
#   just deploy-android
#   just deploy-ios

# CI/CD process
ci-cd: validate-env
    @echo "Running CI/CD process..."
    just generate-gitlab-ci
    just full-process

# Run project on different targets
run target:
    @echo "Running project on {{target}}..."
    just _run_{{target}}

# Run on desktop
_run_desktop:
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}}

# Run on Android
_run_android: pre-build
    #!/usr/bin/env bash
    set -euo pipefail
    IP="{{ANDROID_DEVICE_IP}}"
    PORT="5555"
    echo "Connecting to Android device at ${IP}:${PORT}"
    ping ${IP} -c 3
    adb kill-server
    adb start-server
    adb tcpip ${PORT}
    adb connect ${IP}:${PORT}
    adb -s ${IP}:${PORT} uninstall {{ANDROID_PACKAGE_NAME}}
    adb -s ${IP}:${PORT} install export/android/{{GAME_NAME}}.apk
    adb -s ${IP}:${PORT} shell am start -a android.intent.action.MAIN -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp



# Run on iOS (requires additional setup with Xcode)
_run_ios device="iPhone": pre-build
    @echo "Running on iOS {{device}}..."
    # Add commands to build and run on iOS device using Xcode CLI tools
    # Example (adjust as needed):
    # xcodebuild -project export/ios/{{GAME_NAME}}.xcodeproj -scheme {{GAME_NAME}} -destination 'platform=iOS,name={{device}}' build run

# Run on iPad
_run_ipad: pre-build
    just _run_ios "iPad"

# Run on iPhone
_run_iphone: pre-build
    just _run_ios "iPhone"

# Clean build artifacts
clean:
    @echo "Cleaning build artifacts..."
    rm -rf editor/* templates/* export/*
    cd {{GODOT_SUBMODULE_PATH}} && scons --clean

# Update all submodules
update-all-submodules:
    @echo "Updating all submodules..."
    git submodule update --init --recursive
    just update-godot-submodule
    just update-env-submodule

# Update environment submodule
update-env-submodule:
    @echo "Updating environment submodule..."
    cd env && git pull origin main
    git add env
    git commit -m "Update environment submodule"

# Show project status
status:
    @echo "Project Status:"
    @echo "Godot submodule:"
    cd {{GODOT_SUBMODULE_PATH}} && git status -s
    @echo "Environment submodule:"
    cd env && git status -s
    @echo "Main project:"
    git status -s

# Run tests (placeholder, adjust based on your testing framework)
test:
    @echo "Running tests..."
    # Add your test commands here
    # Example: ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --test

# Generate documentation (placeholder, adjust based on your documentation tool)
generate-docs:
    @echo "Generating documentation..."
    # Add your documentation generation commands here
    # Example: doxygen Doxyfile

# Create a new release
create-release version:
    @echo "Creating release {{version}}..."
    just update-version
    git add {{PROJECT_PATH}}/export_presets.cfg
    git commit -m "Bump version to {{version}}"
    git tag -a v{{version}} -m "Release {{version}}"
    git push origin main --tags

