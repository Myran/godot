#!/usr/bin/env just --justfile

# Main build Justfile for Godot 4 Projects
# Import other Justfiles
import "justfile-run.justfile"
import "justfile-cicd.justfile"
import "justfile-support.justfile"
#import "justfile-test.justfile"
# Set default shell
set shell := ["bash", "-c"]

# Environment variables
export GAME_NAME := env_var_or_default("CI_PROJECT_NAME", "gametwo")
export GODOT_VERSION := "4.0"
export GODOT_BUILD_VERSION := "4.3.rc"
export GODOT_EXECUTABLE := "godot.macos.editor.arm64"  # For Apple Silicon Macs
export PROJECT_PATH := justfile_directory() + "/project"
export ANDROID_SDK_PATH := env_var_or_default("ANDROID_SDK_PATH", "~/Library/Android/sdk")
export ANDROID_NDK_PATH := env_var_or_default("ANDROID_NDK_PATH", ANDROID_SDK_PATH + "/ndk/25.1.8937393")
export ANDROID_PACKAGE_NAME := env_var_or_default("ANDROID_PACKAGE_NAME", "com.primaryhive." + GAME_NAME)
export IOS_BUNDLE_IDENTIFIER := env_var_or_default("IOS_BUNDLE_IDENTIFIER", "com.godotengine." + GAME_NAME)
export KEYSTORE_PATH := env_var_or_default("KEYSTORE_PATH", "./keys/" + GAME_NAME + ".keystore")
export KEYSTORE_PASSWORD := env_var_or_default("KEYSTORE_PASSWORD", "lovegametwo")
export KEY_PASSWORD := env_var_or_default("KEY_PASSWORD", "lovegametwo")
export APPLE_TEAM_ID := env_var_or_default("APPLE_TEAM_ID", "123")
export APPLE_ID := env_var_or_default("APPLE_ID", "123")
export APP_STORE_CONNECT_API_KEY_PATH := env_var_or_default("APP_STORE_CONNECT_API_KEY_PATH", "123")
export IOS_PROVISIONING_PROFILE_UUID := env_var_or_default("IOS_PROVISIONING_PROFILE_UUID", "123")
export ANDROID_DEVICE_IP := env_var_or_default("ANDROID_DEVICE_IP", "192.168.1.100")
export ANDROID_GRADLE_DIR := "build/gradle"

# Godot submodule settings
GODOT_REPO := "https://github.com/godotengine/godot.git"
GODOT_BRANCH := "gametwo"  # Replace with your custom branch name
GODOT_SUBMODULE_PATH := "godot"

# Utility functions
timestamp := `date +%Y%m%d%H%M%S`
jobs := `sysctl -n hw.logicalcpu`
    
default:
    @just --list

# Gruvbox Material colors
_gruvbox-colors:
    # Base colors
    @export BG_H="#1d2021"
    @export BG="#282828"
    @export BG_S="#32302f"
    @export FG="#d4be98"
    
    # Regular colors
    @export RED="#ea6962"
    @export GREEN="#a9b665"
    @export YELLOW="#d8a657"
    @export BLUE="#7daea3"
    @export PURPLE="#d3869b"
    @export AQUA="#89b482"
    @export ORANGE="#e78a4e"
    @export GRAY="#928374"

# Build Godot editor
build-editor: validate-env
    @echo "Building Godot editor..."
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=macos target=editor use_lto=yes --jobs={{jobs}} # vulkan_sdk_path=
    mv {{GODOT_SUBMODULE_PATH}}/bin/godot.macos.editor.* editor/

# Build export templates
build-templates:
    just build-and-package-ios-templates
    just build-android-templates minimal=no
    just install-android-template

# build macos
build-macos-templates: validate-env
    @echo "Building export templates..."
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=macos target=template_debug --jobs={{jobs}}
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=macos target=template_release --jobs={{jobs}}
    mkdir -p templates
    cp {{GODOT_SUBMODULE_PATH}}/bin/godot.macos.template_debug.* templates/
    cp {{GODOT_SUBMODULE_PATH}}/bin/godot.macos.template_release.* templates/

# Run Godot editor
edit:
    @echo "Running Godot editor..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --editor --verbose --debug

# Run Godot in headless mode without GUI
headless:
    @echo "Running Godot in headless mode..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless
    
# Run Godot in headless mode with additional arguments
headless-run *ARGS:
    @echo "Running Godot in headless mode with args: {{ARGS}}"
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless {{ARGS}}

# Validate GDScript code by checking for errors
validate:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Validating GDScript code..."
    
    # Start the Godot process and save its PID
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless --check-only --verbose --debug &
    VALIDATION_PID=$!
    
    echo "Started validation process with PID: $VALIDATION_PID"
    
    # Wait for up to 90 seconds for the process to complete naturally
    TIMEOUT=90
    for ((i=1; i<=TIMEOUT; i++)); do
        if ! ps -p $VALIDATION_PID > /dev/null 2>&1; then
            echo "Validation process completed after $i seconds"
            echo "Validation complete. Any errors will be shown above."
            exit 0
        fi
        
        # Print a progress message every 15 seconds
        if [ $((i % 15)) -eq 0 ]; then
            echo "Validation still running after $i seconds..."
        fi
        
        sleep 1
    done
    
    # If we get here, the process is still running after the timeout
    if ps -p $VALIDATION_PID > /dev/null 2>&1; then
        echo "Validation process (PID: $VALIDATION_PID) timed out after $TIMEOUT seconds. Terminating..."
        kill $VALIDATION_PID 2>/dev/null || true
        
        # Give it a moment to terminate gracefully
        sleep 2
        
        # Force kill if still running
        if ps -p $VALIDATION_PID > /dev/null 2>&1; then
            echo "Process didn't terminate gracefully. Forcing termination..."
            kill -9 $VALIDATION_PID 2>/dev/null || true
        fi
        echo "Validation process terminated due to timeout."
        exit 1
    fi

# Export validation errors to a log file
validate-log:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Validating GDScript code and saving errors to log file..."
    
    # Remove previous log file to avoid confusion with old errors
    rm -f validation_errors.log
    
    # Start the Godot process and save its PID
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless --close --check-only --debug --verbose > validation_errors.log 2>&1 &
    VALIDATION_PID=$!
    
    echo "Started validation process with PID: $VALIDATION_PID"
    
    # Wait for up to 90 seconds for the process to complete naturally
    TIMEOUT=90
    for ((i=1; i<=TIMEOUT; i++)); do
        if ! ps -p $VALIDATION_PID > /dev/null 2>&1; then
            echo "Validation process completed after $i seconds"
            exit 0
        fi
        
        # Print a progress message every 15 seconds
        if [ $((i % 15)) -eq 0 ]; then
            echo "Validation still running after $i seconds..."
        fi
        
        sleep 1
    done
    
    # If we get here, the process is still running after the timeout
    if ps -p $VALIDATION_PID > /dev/null 2>&1; then
        echo "Validation process (PID: $VALIDATION_PID) timed out after $TIMEOUT seconds. Terminating..."
        kill $VALIDATION_PID 2>/dev/null || true
        
        # Give it a moment to terminate gracefully
        sleep 2
        
        # Force kill if still running
        if ps -p $VALIDATION_PID > /dev/null 2>&1; then
            echo "Process didn't terminate gracefully. Forcing termination..."
            kill -9 $VALIDATION_PID 2>/dev/null || true
        fi
    fi
    
    echo "Validation complete. Errors saved to validation_errors.log"

# Pre-build hook
pre-build:
    @echo "Running pre-build tasks..."
    just update-export-presets
    just update-project-settings

# Build and package iOS templates
build-and-package-ios-templates: validate-env
    just build-ios-template
    just package-ios-template

# build ios template
build-ios-template:
    @echo "============================="
    @echo "BUILDING IOS EXECUTABLES"
    @echo "============================="
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=ios target=template_debug arch=arm64 --jobs={{jobs}}
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=ios target=template_release arch=arm64 --jobs={{jobs}}

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

# Package ios template
package-ios-template:
    @echo "=========================="
    @echo "PACKAGING IOS TEMPLATES"
    @echo "=========================="
    rm -f templates/ios.zip
    mkdir -p templates
    cd {{GODOT_SUBMODULE_PATH}}/misc/dist/ios_xcode && zip -9 -r ../../../../templates/ios.zip *

    @echo "iOS templates built and packaged successfully."

# Build Android templates
build-android-templates minimal="yes":
    #!/usr/bin/env bash
    set -e
    
    # Define the module flags based on the minimal argument
    MODULE_FLAGS=""
    if [ "{{minimal}}" = "yes" ]; then
        MODULE_FLAGS="module_bmp_enabled=no module_bullet_enabled=no module_csg_enabled=no module_dds_enabled=no module_enet_enabled=no module_etc_enabled=no module_gdnative_enabled=no module_gridmap_enabled=no module_hdr_enabled=no module_mbedtls_enabled=yes module_mobile_vr_enabled=no module_opus_enabled=no module_pvr_enabled=no module_recast_enabled=no module_regex_enabled=no module_squish_enabled=no module_tga_enabled=no module_thekla_unwrap_enabled=no module_theora_enabled=no module_tinyexr_enabled=no module_vorbis_enabled=no module_webm_enabled=no module_websocket_enabled=no disable_advanced_gui=no disable_3d=yes"
    fi
    
    # Build for all targets and architectures in a single working directory context
    GODOT_PATH="{{GODOT_SUBMODULE_PATH}}"
    
    # Debug arm32
    (cd "$GODOT_PATH" && scons platform=android target=template_debug arch=arm32 --jobs={{jobs}} $MODULE_FLAGS optimize=size use_lto=yes)
    
    # Debug arm64
    (cd "$GODOT_PATH" && scons platform=android target=template_debug arch=arm64 --jobs={{jobs}} $MODULE_FLAGS optimize=size use_lto=yes)
    
    # Release arm32
    (cd "$GODOT_PATH" && scons platform=android target=template_release arch=arm32 --jobs={{jobs}} $MODULE_FLAGS optimize=size use_lto=yes)
    
    # Release arm64
    (cd "$GODOT_PATH" && scons platform=android target=template_release arch=arm64 --jobs={{jobs}} $MODULE_FLAGS optimize=size use_lto=yes)
    
    # Generate templates
    (cd "$GODOT_PATH/platform/android/java" && ./gradlew generateGodotTemplates)
    
    # Make sure the templates directory exists
    mkdir -p templates
    
    # Move templates
    echo "Moving templates...."
    mv "$GODOT_PATH/bin/android_debug.apk" templates/android_debug.apk
    mv "$GODOT_PATH/bin/android_release.apk" templates/android_release.apk
    mv "$GODOT_PATH/bin/android_source.zip" templates/android_source.zip


clean-android-templates:
    #!/usr/bin/env bash
    set -e
    # Build for all targets and architectures in a single working directory context
    GODOT_PATH="{{GODOT_SUBMODULE_PATH}}"
    # clean templates
    (cd "$GODOT_PATH/platform/android/java" && ./gradlew clean)

# Install Android template
install-android-template:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Installing Android gradle for custom builds"
    rm -rf project/android
    mkdir project/android
    unzip -o templates/android_source.zip -d project/android/build
    chmod +x project/android
    md5=$(md5sum templates/android_source.zip | awk NF=1)
    rp=$(realpath templates/android_source.zip)
    echo "$rp [$md5]"  >> project/android/.build_version
    touch project/android/.gdignore
    echo "Done installing Android template"

# Build and export for Android
build-android BUILD_TYPE="apk": pre-build
    @echo "Building and exporting for Android ({{BUILD_TYPE}})..."
    echo $ANDROID_KEYSTORE | base64 -d > android.keystore
    
    # Debug build
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} \
        --export-debug "Android {{BUILD_TYPE}}" \
        ../export/android/{{GAME_NAME}}_debug.{{BUILD_TYPE}} --headless
    
    # Release build
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} \
        --export-release "Android {{BUILD_TYPE}}" \
        ../export/android/{{GAME_NAME}}.{{BUILD_TYPE}} --headless

# Alias commands for easier use
build-android-apk: (build-android "apk")
build-android-aab: (build-android "aab")

# Build, install and run Android app using Gradle (matches Godot's remote deploy)
install-and-run-android-gradle:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # First insert Firebase dependencies
    just insert-firebase-dependencies
    
    echo "Building with package name: {{ANDROID_PACKAGE_NAME}}"
    
    # Create timestamp for unique filename
    TIMESTAMP=$(date +%s)
    TEMP_DIR="/tmp/android_deploy"
    
    # Create temp directory if it doesn't exist
    mkdir -p "$TEMP_DIR"
    
    # Run Gradle build using the same command as Godot remote deploy
    cd {{PROJECT_PATH}}/android/build && \
    ./gradlew validateJavaVersion clean assembleStandardDebug \
      -Paddons_directory={{PROJECT_PATH}}/addons \
      -Pexport_package_name={{ANDROID_PACKAGE_NAME}} \
      -Pexport_version_code=$(date +%Y%m%d%H%M%S) \
      -Pexport_version_name=1.0.$(date +%Y%m%d%H%M%S) \
      -Pexport_version_min_sdk=24 \
      -Pexport_version_target_sdk=34 \
      -Pexport_enabled_abis=arm64-v8a \
      -Pplugins_local_binaries= \
      -Pplugins_remote_binaries= \
      -Pplugins_maven_repos= \
      -Pperform_zipalign=true \
      -Pperform_signing=true \
      -Pcompress_native_libraries=false
    
    # Copy and rename binary (just like Godot does)
    echo "Copying and renaming APK..."
    EXPORT_FILENAME="tmpexport.$TIMESTAMP.apk"
    cd {{PROJECT_PATH}}/android/build && \
    ./gradlew copyAndRenameBinary \
      -Pexport_edition=standard \
      -Pexport_build_type=debug \
      -Pexport_format=apk \
      -Pexport_path=file:$TEMP_DIR \
      -Pexport_filename=$EXPORT_FILENAME
    
    # Check if package exists, uninstall if it does, then install
    echo "Checking if package {{ANDROID_PACKAGE_NAME}} exists..."
    if adb -s 246d2c533a037ece shell pm list packages | grep -q "{{ANDROID_PACKAGE_NAME}}"; then
        echo "Package exists. Uninstalling..."
        adb -s 246d2c533a037ece uninstall {{ANDROID_PACKAGE_NAME}}
    else
        echo "Package does not exist."
    fi
    
    # Install the new APK
    echo "Installing APK to device..."
    adb -s 246d2c533a037ece install "$TEMP_DIR/$EXPORT_FILENAME"
    
    # Launch the app
    echo "Launching the app..."
    adb -s 246d2c533a037ece shell am start -a android.intent.action.MAIN -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp
    
    echo "APK file is available at: $TEMP_DIR/$EXPORT_FILENAME"
    
    echo "Deployment completed successfully!"
    echo "APK file is available at: $TEMP_DIR/$EXPORT_FILENAME"

# Build and export for iOS
build-ios: pre-build
    @echo "Building and exporting for iOS..."
    cd export/ios && xcodebuild -workspace {{GAME_NAME}}.xcworkspace -scheme {{GAME_NAME}} -configuration Debug -destination "generic/platform=iOS" -allowProvisioningUpdates

# Save iOS PCK file
save-ios: pre-build
    @echo "Saving iOS PCK file..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless --export-pack ios ../export/ios/{{GAME_NAME}}.pck

# Save iOS PCK file directly to app
save-ios-to-app: pre-build
    @echo "Saving iOS PCK file directly to app..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless --export-pack ios ../export/ios/build/products/Debug-iphoneos/{{GAME_NAME}}.app/{{GAME_NAME}}.pck

# Full build and deploy process
build-all: validate-env
    @echo "Running full build and deploy process..."
    just install-deps
    just build-editor
    just build-templates
    just update-version
    #just format
    just insert-firebase-dependencies
    just build-android apk
    just build-android aab
    just build-ios

replace TARGET_FILE PATTERN REPLACEMENT_FILE:
    #!/usr/bin/env bash
    set -euo pipefail
    python3 tools/replace_content.py "{{TARGET_FILE}}" "{{PATTERN}}" "{{REPLACEMENT_FILE}}"

insert-firebase-dependencies:
    cp firebase/google-services.json project/android/build/

    @echo "Preparing Firebase dependencies..."

    echo 'implementation platform ("com.google.firebase:firebase-bom:33.1.2")' > temp_dependencies.txt
    echo 'implementation "com.google.firebase:firebase-auth"' >> temp_dependencies.txt
    echo 'implementation "com.google.firebase:firebase-messaging"' >> temp_dependencies.txt
    echo 'implementation "com.google.firebase:firebase-database"' >> temp_dependencies.txt
    echo 'implementation "com.google.firebase:firebase-config"' >> temp_dependencies.txt
    echo 'implementation "com.google.firebase:firebase-analytics"' >> temp_dependencies.txt
    
    @echo "Preparing Firebase plugin..."

    echo 'apply plugin: "com.google.gms.google-services"' > temp_plugin.txt
    
    @echo "Preparing Firebase buildscript..."
    echo 'buildscript {' > temp_buildscript.txt
    echo '    repositories {' >> temp_buildscript.txt
    echo '        google()' >> temp_buildscript.txt
    echo '        mavenCentral()' >> temp_buildscript.txt
    echo '    }' >> temp_buildscript.txt
    echo '    dependencies {' >> temp_buildscript.txt
    echo '        classpath "com.google.gms:google-services:4.4.2"' >> temp_buildscript.txt
    echo '    }' >> temp_buildscript.txt
    echo '}' >> temp_buildscript.txt
    
    @echo "Inserting Firebase configurations..."

    just replace project/android/build/build.gradle  //ADD_FIREBASE_BUILDSCRIPT_HERE_ temp_buildscript.txt    
    just replace project/android/build/build.gradle  //ADD_FIREBASE_DEPENDENCIES_HERE_ temp_dependencies.txt
    just replace project/android/build/build.gradle  //ADD_FIREBASE_PLUGINS_HERE_ temp_plugin.txt

    @echo "Cleaning up temporary files..."

    rm temp_dependencies.txt temp_plugin.txt temp_buildscript.txt   

    @echo "Firebase dependencies inserted successfully."
