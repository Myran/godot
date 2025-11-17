# Legacy quick-build-all removed - use platform-specific commands instead:
#   just build-all-android   # Android smart rebuild (3-25 min)
#   just quick-build-ios     # iOS quick build (2-3 min)

# Build status check
build-status:
    @echo "📊 BUILD STATUS CHECK"
    @echo "===================="
    @echo ""
    @echo "EDITOR:"
    @if [ -f "editor/{{GODOT_EXECUTABLE}}" ]; then \
        echo "  ✅ Built"; \
    else \
        echo "  ❌ Not built"; \
    fi
    @echo ""
    @echo "TEMPLATES:"
    @if [ -f "templates/android_debug.apk" ]; then \
        echo "  ✅ Android: Built"; \
    else \
        echo "  ❌ Android: Not built"; \
    fi
    @if [ -f "templates/ios.zip" ]; then \
        echo "  ✅ iOS: Built"; \
    else \
        echo "  ❌ iOS: Not built"; \
    fi
    @if [ -f "templates/windows_debug.zip" ] && [ -f "templates/windows_release.zip" ]; then \
        echo "  ✅ Windows: Built"; \
    else \
        echo "  ❌ Windows: Not built"; \
    fi
    @echo ""
    @echo "ANDROID EXPORTS:"
    @if [ -f "export/android/{{GAME_NAME}}.apk" ]; then \
        echo "  ✅ APK: export/android/{{GAME_NAME}}.apk"; \
    else \
        echo "  ❌ APK: Not exported"; \
    fi
    @if [ -f "export/android/{{GAME_NAME}}.aab" ]; then \
        echo "  ✅ AAB: export/android/{{GAME_NAME}}.aab"; \
    else \
        echo "  ❌ AAB: Not exported"; \
    fi
    @echo ""
    @echo "iOS EXPORTS:"
    @if [ -d "export/ios/{{GAME_NAME}}.xcworkspace" ]; then \
        echo "  ✅ Xcode project: Exported"; \
    else \
        echo "  ❌ Xcode project: Not exported"; \
    fi
    @if [ -d "export/ios/build/products/debug-iphoneos/{{GAME_NAME}}.app" ]; then \
        echo "  ✅ iOS app: Built"; \
    else \
        echo "  ❌ iOS app: Not built"; \
    fi

# ================================
# INTERNAL BUILD HELPERS (DRY)
# ================================

# Common build steps
_build-common force="no":
    @echo "📦 [1/3] Installing dependencies..."
    just install-deps
    @echo "🔨 [2/3] Checking Godot editor..."
    just build-editor {{force}}
    @echo "📝 [3/3] Updating version..."
    just update-version


# Android full build steps
# REMOVED: _build-android-full - moved to justfile-platform-android.justfile

# iOS full build steps
_build-ios-full:
    @echo ""
    @echo "🍎 iOS BUILD STEPS"
    @echo "================="
    @echo "📦 [1/3] Building iOS templates..."
    just templates-ios
    @echo "📱 [2/3] Exporting iOS project..."
    just export-pck-ios
    @echo "🔨 [3/3] Building with Xcode..."
    just build-ios-app

# ================================
# OLD BUILD-ALL BUGFIX
# ================================

replace TARGET_FILE PATTERN REPLACEMENT_FILE:
    #!/usr/bin/env bash
    set -euo pipefail
    python3 tools/replace_content.py "{{TARGET_FILE}}" "{{PATTERN}}" "{{REPLACEMENT_FILE}}"

# 🔥🛡️ Inject Android SDKs (Firebase + Sentry)
# REQUIRED STEP: After installing Android templates, you MUST inject SDKs before building
android-inject-sdks:
    @echo "📦 Injecting Android SDKs (Firebase + Sentry) into templates..."

    # Generate Sentry configuration from project settings first
    @echo "🛡️ Generating Sentry configuration from project settings..."
    python3 extras/sentry-godot/scripts/extract_sentry_config.py

    @echo "Inserting Firebase + Sentry configurations..."

    # Firebase: Copy configuration file
    @echo "🔥 Firebase: Copying google-services.json..."
    cp firebase/google-services.json project/android/build/

    # Firebase: Insert buildscript
    @echo "🔥 Firebase: Inserting buildscript..."
    just replace project/android/build/build.gradle //ADD_FIREBASE_BUILDSCRIPT_HERE_ inject/firebase_buildscript.gradle

    # Firebase: Insert dependencies
    @echo "🔥 Firebase: Inserting dependencies..."
    just replace project/android/build/build.gradle //ADD_FIREBASE_DEPENDENCIES_HERE_ inject/firebase_dependencies.gradle

    # Firebase: Insert plugin
    @echo "🔥 Firebase: Inserting plugin..."
    just replace project/android/build/build.gradle //ADD_FIREBASE_PLUGINS_HERE_ inject/firebase_apply_plugin.gradle

    # Sentry: Insert buildscript
    @echo "🛡️ Sentry: Inserting buildscript..."
    just replace project/android/build/build.gradle //ADD_SENTRY_BUILDSCRIPT_HERE_ inject/sentry_buildscript.gradle

    # Sentry: Apply plugin (after plugins block)
    @echo "🛡️ Sentry: Applying plugin..."
    just replace project/android/build/build.gradle //ADD_SENTRY_PLUGINS_HERE_ inject/remove_placeholder.gradle
    just replace project/android/build/build.gradle //ADD_SENTRY_PLUGIN_APPLY_HERE_ inject/sentry_apply_plugin.gradle

    # Sentry: Insert manifest metadata
    @echo "🛡️ Sentry: Inserting manifest metadata..."
    just replace project/android/build/AndroidManifest.xml "<!--ADD_SENTRY_METADATA_HERE_-->" inject/sentry_metadata.xml

    @echo ""
    @echo "✅ Android SDKs injected successfully!"
    @echo "   🔥 Firebase: Auth, Database, Messaging, Analytics, Config"
    @echo "   🛡️ Sentry: Error tracking, Performance, Session replay, Crash reporting"
    @echo ""
    @echo "📱 Templates now ready for building:"
    @echo "   just export-apk-debug"
    @echo "   just export-apk-release"

# 🔥 Firebase Android SDK integration (legacy - kept for compatibility)
android-insert-firebase-dependencies:
    @echo "🔥 Preparing Firebase Android SDK dependencies..."

    @echo "Preparing Firebase dependencies..."
    cp firebase/google-services.json project/android/build/

    @echo "Inserting Firebase configurations..."

    # Insert Firebase buildscript into buildscript
    just replace project/android/build/build.gradle //ADD_FIREBASE_BUILDSCRIPT_HERE_ inject/firebase_buildscript.gradle

    # Insert Firebase dependencies
    just replace project/android/build/build.gradle //ADD_FIREBASE_DEPENDENCIES_HERE_ inject/firebase_dependencies.gradle

    # Insert Firebase plugin application
    just replace project/android/build/build.gradle //ADD_FIREBASE_PLUGINS_HERE_ inject/firebase_apply_plugin.gradle

    @echo "✅ Firebase Android SDK dependencies inserted successfully."

# 🛡️ Sentry Android SDK integration (legacy - kept for compatibility)
android-insert-sentry-dependencies:
    @echo "🛡️ Preparing Sentry Android SDK dependencies..."

    # Generate Sentry configuration from project settings first
    @echo "🔧 Generating Sentry Android configuration from project settings..."
    python3 extras/sentry-godot/scripts/extract_sentry_config.py

    @echo "Inserting Sentry configurations..."

    # Insert Sentry classpath into buildscript
    just replace project/android/build/build.gradle //ADD_SENTRY_BUILDSCRIPT_HERE_ inject/sentry_buildscript.gradle

    # Remove old placeholder and apply Sentry plugin after plugins block
    just replace project/android/build/build.gradle //ADD_SENTRY_PLUGINS_HERE_ inject/remove_placeholder.gradle
    just replace project/android/build/build.gradle //ADD_SENTRY_PLUGIN_APPLY_HERE_ inject/sentry_apply_plugin.gradle

    # Insert manifest metadata
    just replace project/android/build/AndroidManifest.xml "<!--ADD_SENTRY_METADATA_HERE_-->" inject/sentry_metadata.xml

    @echo "✅ Sentry Android SDK dependencies inserted successfully."

# 🔥🛡️ Complete Android Setup (Templates + SDKs + Config Update)
# ONE-STOP SHOP: Clean install with everything needed
android-setup-templates:
    @echo "🚀 COMPLETE ANDROID SETUP (Templates + SDKs + Configuration)"

    # Step 1: Install clean Android templates
    @echo "📦 Step 1: Installing clean Android templates..."
    just install-android-template

    # Step 2: Inject all required SDKs
    @echo "📦 Step 2: Injecting Android SDKs (Firebase + Sentry)..."
    just android-inject-sdks

    @echo ""
    @echo "🎉 COMPLETE ANDROID SETUP FINISHED!"
    @echo "   📦 ✅ Android templates installed"
    @echo "   🔥 ✅ Firebase SDK injected (Auth, Database, Messaging, Analytics, Config)"
    @echo "   🛡️ ✅ Sentry SDK injected (Error tracking, Performance, Session replay)"
    @echo ""
    @echo "📱 Ready to build APKs:"
    @echo "   just export-apk-debug"
    @echo "   just export-apk-release"

# 🔄 Update Android SDK Configuration (when project.godot settings change)
# Use this when you change SDK settings - faster than full reinstall
android-update-sdk-config:
    @echo "🔄 Updating Android SDK configuration from project settings..."

    # Update Sentry configuration
    @echo "🛡️ Updating Sentry configuration..."
    python3 extras/sentry-godot/scripts/extract_sentry_config.py
    just replace project/android/build/AndroidManifest.xml "<!--ADD_SENTRY_METADATA_HERE_-->" inject/sentry_metadata.xml

    # Update Firebase configuration (copy google-services.json)
    @echo "🔥 Updating Firebase configuration..."
    cp firebase/google-services.json project/android/build/

    @echo ""
    @echo "✅ Android SDK configuration updated successfully!"
    @echo "   🛡️ Sentry: DSN and settings updated from project.godot"
    @echo "   🔥 Firebase: google-services.json updated"

# Wildcard patterns and development cycles guide
