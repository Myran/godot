quick-build-all:
    @echo "⚡ Quick build for all platforms (5-10 min)..."
    just quick-build-android
    just quick-build-ios
    @echo "✅ Quick build complete!"

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
_build-common:
    @echo "📦 [1/3] Installing dependencies..."
    just install-deps
    @echo "🔨 [2/3] Building Godot editor..."
    just build-editor
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
    just ios-export-pck
    @echo "🔨 [3/3] Building with Xcode..."
    just ios-build

# ================================
# OLD BUILD-ALL BUGFIX
# ================================

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

# Wildcard patterns and development cycles guide
