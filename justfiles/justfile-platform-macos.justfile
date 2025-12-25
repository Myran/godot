# macOS Platform Support
# macOS desktop export template building and management for GameTwo
# Builds ARM64 (Apple Silicon) and Universal 2 (ARM64 + Intel) templates

# ================================
# macOS TEMPLATE BUILDING
# ================================

# Build macOS export templates (complete chain) - Universal 2 (ARM64 + x86_64)
templates-macos force="no":
    just macos-build-template {{force}}
    just package-macos-template {{force}}

# Complete macOS build with templates and all dependencies (consistency with build-all-android/windows)
build-all-macos force="no":
    @echo "Building all macOS components..."
    @just templates-macos {{force}}
    @echo "✅ macOS build complete"

# Build macOS export templates - ARM64 only (faster, smaller)
templates-macos-arm64 force="no":
    just macos-build-template-arm64 {{force}}
    just package-macos-template {{force}}

# Build Universal 2 macOS templates (ARM64 + x86_64)
macos-build-template force="no":
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if macOS templates already exist
    if [ "{{force}}" != "yes" ] && [ "{{force}}" != "force=yes" ] && \
       [ -f "{{GODOT_SUBMODULE_PATH}}/bin/godot.macos.template_release.universal" ] && \
       [ -f "{{GODOT_SUBMODULE_PATH}}/bin/godot.macos.template_debug.universal" ]; then
        echo "✅ macOS Universal 2 templates already built"
        echo "   Use 'just macos-build-template force=yes' to rebuild"
        exit 0
    fi

    if [ "{{force}}" = "yes" ] || [ "{{force}}" = "force=yes" ]; then
        echo "🔥 Force rebuild enabled - rebuilding macOS Universal 2 templates..."
    else
        echo "❌ macOS Universal 2 templates not found, building..."
    fi

    echo "🔨 Building macOS Universal 2 templates..."
    echo "============================="
    echo "BUILDING macOS EXECUTABLES (ARM64 + x86_64)"
    echo "============================="

    cd {{GODOT_SUBMODULE_PATH}}

    echo "📦 Building macOS debug template (ARM64)..."
    scons platform=macos target=template_debug arch=arm64 --jobs={{jobs}}

    echo "📦 Building macOS release template (ARM64)..."
    scons platform=macos target=template_release arch=arm64 --jobs={{jobs}}

    echo "📦 Building macOS debug template (x86_64)..."
    scons platform=macos target=template_debug arch=x86_64 --jobs={{jobs}}

    echo "📦 Building macOS release template (x86_64 + generate bundle)..."
    # generate_bundle=yes on final build auto-combines architectures via lipo
    scons platform=macos target=template_release arch=x86_64 production=yes optimize=size generate_bundle=yes --jobs={{jobs}}

    echo "✅ macOS Universal 2 templates built successfully"
    echo "   📁 Templates in: {{GODOT_SUBMODULE_PATH}}/bin/"

# Build ARM64-only macOS templates (faster build, Apple Silicon only)
macos-build-template-arm64 force="no":
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if ARM64 templates already exist
    if [ "{{force}}" != "yes" ] && [ "{{force}}" != "force=yes" ] && \
       [ -f "{{GODOT_SUBMODULE_PATH}}/bin/godot.macos.template_release.arm64" ] && \
       [ -f "{{GODOT_SUBMODULE_PATH}}/bin/godot.macos.template_debug.arm64" ]; then
        echo "✅ macOS ARM64 templates already built"
        echo "   Use 'just macos-build-template-arm64 force=yes' to rebuild"
        exit 0
    fi

    if [ "{{force}}" = "yes" ] || [ "{{force}}" = "force=yes" ]; then
        echo "🔥 Force rebuild enabled - rebuilding macOS ARM64 templates..."
    else
        echo "❌ macOS ARM64 templates not found, building..."
    fi

    echo "🔨 Building macOS ARM64-only templates..."
    echo "============================="
    echo "BUILDING macOS EXECUTABLES (ARM64 only)"
    echo "============================="

    cd {{GODOT_SUBMODULE_PATH}}

    echo "📦 Building macOS debug template (ARM64)..."
    scons platform=macos target=template_debug arch=arm64 --jobs={{jobs}}

    echo "📦 Building macOS release template (ARM64 + generate bundle)..."
    # generate_bundle=yes creates the .app bundle
    scons platform=macos target=template_release arch=arm64 production=yes optimize=size generate_bundle=yes --jobs={{jobs}}

    echo "✅ macOS ARM64 templates built successfully"
    echo "   📁 Templates in: {{GODOT_SUBMODULE_PATH}}/bin/"

# Package macOS templates into zip file
package-macos-template force="no":
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if macOS template package already exists
    if [ "{{force}}" != "yes" ] && [ "{{force}}" != "force=yes" ] && [ -f "templates/macos.zip" ]; then
        echo "✅ macOS template package already built"
        echo "   Use 'just package-macos-template force=yes' to rebuild"
        exit 0
    fi

    if [ "{{force}}" = "yes" ] || [ "{{force}}" = "force=yes" ]; then
        echo "🔥 Force rebuild enabled - repackaging macOS templates..."
    else
        echo "❌ macOS template package not found, building..."
    fi

    echo "📦 Packaging macOS templates..."
    echo "=========================="
    echo "PACKAGING macOS TEMPLATES"
    echo "=========================="

    # Ensure templates directory exists
    mkdir -p templates

    # Check for pre-built zip (scons with generate_bundle=yes creates this directly)
    PREBUILT_ZIP="{{GODOT_SUBMODULE_PATH}}/bin/godot_macos.zip"
    TEMPLATE_BUNDLE="{{GODOT_SUBMODULE_PATH}}/bin/macos_template.app"

    if [ -f "$PREBUILT_ZIP" ]; then
        echo "📦 Found pre-built template zip: $PREBUILT_ZIP"
        # Remove old package if exists
        rm -f templates/macos.zip
        # Copy the pre-built zip
        cp "$PREBUILT_ZIP" templates/macos.zip
        echo "✅ macOS templates packaged successfully!"
        echo "   📄 templates/macos.zip (copied from scons output)"
    elif [ -d "$TEMPLATE_BUNDLE" ]; then
        echo "📦 Found template bundle: $TEMPLATE_BUNDLE"
        # Remove old package if exists
        rm -f templates/macos.zip
        # Create the zip from the template app bundle
        cd {{GODOT_SUBMODULE_PATH}}/bin
        zip -r9 ../../templates/macos.zip macos_template.app
        echo "✅ macOS templates packaged successfully!"
        echo "   📄 templates/macos.zip (zipped from bundle)"
    else
        echo "❌ macOS templates not found!"
        echo "   Checked: $PREBUILT_ZIP"
        echo "   Checked: $TEMPLATE_BUNDLE"
        echo "💡 Run 'just macos-build-template' first to build templates"
        exit 1
    fi

# Build minimal macOS templates (ARM64 debug only) - fastest iteration
build-macos-templates-minimal:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔧 Building minimal macOS debug template (ARM64)..."
    cd {{GODOT_SUBMODULE_PATH}}

    scons platform=macos target=template_debug arch=arm64 --jobs={{jobs}}

    echo "📁 Copying macOS debug template to templates/ directory..."
    mkdir -p ../templates
    cp bin/godot.macos.template_debug.arm64 ../templates/

    echo "✅ Minimal macOS debug template built successfully!"
    echo "   📄 templates/godot.macos.template_debug.arm64"

# Clean macOS template artifacts
clean-macos-templates:
    @echo "🧹 Cleaning macOS template artifacts..."
    rm -f templates/macos.zip
    rm -f templates/godot.macos.template_*.arm64
    rm -f templates/godot.macos.template_*.x86_64
    rm -f templates/godot.macos.template_*.universal
    rm -rf {{GODOT_SUBMODULE_PATH}}/bin/macos_template.app
    rm -f {{GODOT_SUBMODULE_PATH}}/bin/godot.macos.template_*
    echo "✅ macOS templates cleaned"

# Check if macOS templates need to be rebuilt
check-macos-templates:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔍 Checking macOS template status..."

    MISSING=false
    CAN_PACKAGE=false

    if [ -f "templates/macos.zip" ]; then
        echo "✅ macOS template package: templates/macos.zip"
        echo "   $(ls -lh templates/macos.zip | awk '{print $5}')"
    else
        echo "❌ macOS template package missing: templates/macos.zip"
        MISSING=true
    fi

    echo ""
    echo "📁 Template sources in {{GODOT_SUBMODULE_PATH}}/bin/:"

    # Check for pre-built zip from scons
    if [ -f "{{GODOT_SUBMODULE_PATH}}/bin/godot_macos.zip" ]; then
        echo "✅ godot_macos.zip (scons output) - ready to package"
        CAN_PACKAGE=true
    fi

    # Check for app bundle
    if [ -d "{{GODOT_SUBMODULE_PATH}}/bin/macos_template.app" ]; then
        echo "✅ macos_template.app bundle exists"
        CAN_PACKAGE=true
    fi

    # Check for individual binaries
    for arch in arm64 x86_64 universal fat; do
        for target in debug release; do
            FILE="{{GODOT_SUBMODULE_PATH}}/bin/godot.macos.template_${target}.${arch}"
            if [ -f "$FILE" ]; then
                SIZE=$(ls -lh "$FILE" | awk '{print $5}')
                echo "   ✅ godot.macos.template_${target}.${arch} ($SIZE)"
            fi
        done
    done

    echo ""
    if [ "$MISSING" = true ] && [ "$CAN_PACKAGE" = true ]; then
        echo "💡 Templates built but not packaged. Run:"
        echo "   just package-macos-template"
    elif [ "$MISSING" = true ]; then
        echo "💡 Build commands:"
        echo "   just templates-macos           # Universal 2 (ARM64 + x86_64)"
        echo "   just templates-macos-arm64     # ARM64 only (faster)"
        echo "   just build-macos-templates-minimal  # Debug only (fastest)"
    else
        echo "✅ macOS templates ready for export"
    fi

# Validate macOS template integrity
validate-macos-templates:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔍 Validating macOS template integrity..."

    ERRORS=0

    if [ -f "templates/macos.zip" ]; then
        echo "✅ macOS template package exists"

        # Check zip contents
        CONTENTS=$(unzip -l templates/macos.zip 2>/dev/null || echo "ERROR")
        if echo "$CONTENTS" | grep -q "macos_template.app"; then
            echo "   ✅ Contains macos_template.app bundle"
        else
            echo "   ❌ Missing macos_template.app in zip"
            ERRORS=$((ERRORS + 1))
        fi

        # Check for executables in bundle
        if echo "$CONTENTS" | grep -q "MacOS/godot"; then
            echo "   ✅ Contains executable in bundle"
        else
            echo "   ⚠️  May be missing executable (check manually)"
        fi

        # Show zip stats
        FILE_COUNT=$(unzip -l templates/macos.zip 2>/dev/null | tail -1 | awk '{print $2}')
        ZIP_SIZE=$(ls -lh templates/macos.zip | awk '{print $5}')
        echo "   📊 Package stats: $FILE_COUNT files, $ZIP_SIZE"
    else
        echo "❌ macOS template package missing"
        ERRORS=$((ERRORS + 1))
    fi

    echo ""
    if [ $ERRORS -eq 0 ]; then
        echo "✅ macOS templates validated successfully"
    else
        echo "❌ macOS template validation failed with $ERRORS errors"
        echo "💡 Run 'just templates-macos' to rebuild"
        exit 1
    fi

# ================================
# macOS FIREBASE CONFIG
# ================================

# Generate Firebase desktop config from iOS plist
generate-firebase-macos-config:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔥 Generating Firebase desktop config for macOS..."

    PLIST_FILE="firebase/GoogleService-Info.plist"
    GENERATOR="firebase/firebase_cpp_sdk/generate_xml_from_google_services_json.py"
    OUTPUT_FILE="firebase/google-services-desktop.json"

    if [ ! -f "$PLIST_FILE" ]; then
        echo "❌ iOS plist not found: $PLIST_FILE"
        echo "💡 Download GoogleService-Info.plist from Firebase Console"
        exit 1
    fi

    if [ ! -f "$GENERATOR" ]; then
        echo "❌ Generator script not found: $GENERATOR"
        echo "💡 Ensure Firebase C++ SDK is installed"
        exit 1
    fi

    echo "📄 Converting: $PLIST_FILE → $OUTPUT_FILE"
    python3 "$GENERATOR" --plist -i "$PLIST_FILE" -o "$OUTPUT_FILE"

    if [ -f "$OUTPUT_FILE" ]; then
        echo "✅ Firebase desktop config generated successfully"
        echo "   📁 Output: $OUTPUT_FILE"
    else
        echo "❌ Failed to generate config"
        exit 1
    fi

# Copy Firebase config to macOS app bundle (internal helper)
_copy-firebase-config-to-macos-bundle app_path:
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_FILE="firebase/google-services-desktop.json"
    DEST_DIR="{{app_path}}/Contents/Resources"

    # Generate config if it doesn't exist
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "📦 Firebase config not found, generating..."
        just generate-firebase-macos-config
    fi

    if [ -d "$DEST_DIR" ]; then
        cp "$CONFIG_FILE" "$DEST_DIR/"
        echo "✅ Firebase config copied to app bundle"
        echo "   📁 $DEST_DIR/google-services-desktop.json"
    else
        echo "⚠️  App bundle Resources not found: $DEST_DIR"
    fi

# ================================
# macOS DESKTOP EXPORTS
# ================================

# Export macOS Desktop - Debug only
export-macos-debug force="yes": _validate-godot-editor (_ensure-directory-exists "export/macos")
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📦 Exporting macOS Desktop (debug only)..."

    # Check if .app bundle already exists (DIRECTORY check, not file)
    DEBUG_APP="export/macos/{{GAME_NAME}}_debug.app"

    if [ "{{force}}" != "yes" ] && [ "{{force}}" != "force=yes" ] && [ -d "$DEBUG_APP" ]; then
        echo "✅ macOS debug export already exists:"
        echo "   📁 Debug: $DEBUG_APP"
        echo "   Use 'just export-macos-debug force=yes' to re-export"
        exit 0
    fi

    if [ "{{force}}" = "yes" ] || [ "{{force}}" = "force=yes" ]; then
        echo "🔥 Force re-export enabled - removing existing debug export..."
        rm -rf "$DEBUG_APP"
    fi

    # Source environment variables for Godot context
    if [ -f ".env" ]; then
        set -a
        source .env
        set +a
        echo "✅ Environment variables loaded for Godot export"
    else
        echo "❌ .env file not found"
        exit 1
    fi

    # Debug export
    echo "🔨 Building macOS debug export..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} \
        --export-debug "macOS" \
        ../export/macos/{{GAME_NAME}}_debug.app --headless

    # Copy Firebase config to app bundle
    just _copy-firebase-config-to-macos-bundle "export/macos/{{GAME_NAME}}_debug.app"

    echo "✅ macOS debug export completed successfully"
    echo "📁 Debug: export/macos/{{GAME_NAME}}_debug.app"

# Export macOS Desktop - Release only
export-macos-release force="yes": _validate-godot-editor (_ensure-directory-exists "export/macos")
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📦 Exporting macOS Desktop (release only)..."

    # Check if .app bundle already exists (DIRECTORY check)
    RELEASE_APP="export/macos/{{GAME_NAME}}.app"

    if [ "{{force}}" != "yes" ] && [ "{{force}}" != "force=yes" ] && [ -d "$RELEASE_APP" ]; then
        echo "✅ macOS release export already exists:"
        echo "   📁 Release: $RELEASE_APP"
        echo "   Use 'just export-macos-release force=yes' to re-export"
        exit 0
    fi

    if [ "{{force}}" = "yes" ] || [ "{{force}}" = "force=yes" ]; then
        echo "🔥 Force re-export enabled - removing existing release export..."
        rm -rf "$RELEASE_APP"
    fi

    # Source environment variables for Godot context
    if [ -f ".env" ]; then
        set -a
        source .env
        set +a
        echo "✅ Environment variables loaded for Godot export"
    else
        echo "❌ .env file not found"
        exit 1
    fi

    # Release export
    echo "🔨 Building macOS release export..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} \
        --export-release "macOS" \
        ../export/macos/{{GAME_NAME}}.app --headless

    # Copy Firebase config to app bundle
    just _copy-firebase-config-to-macos-bundle "export/macos/{{GAME_NAME}}.app"

    echo "✅ macOS release export completed successfully"
    echo "📁 Release: export/macos/{{GAME_NAME}}.app"

# Export macOS Desktop - Both debug and release
export-macos-all force="yes":
    @echo "📦 Exporting all macOS formats (Debug + Release)..."
    just export-macos-debug {{force}}
    just export-macos-release {{force}}
    @echo "✅ All macOS exports completed successfully"
    @echo "📁 Debug: export/macos/{{GAME_NAME}}_debug.app"
    @echo "📁 Release: export/macos/{{GAME_NAME}}.app"

# Validate macOS export CLI functionality
validate-macos-exports:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧪 Validating macOS export CLI functionality..."

    # Check if macOS templates exist
    if [ ! -f "templates/macos.zip" ]; then
        echo "❌ macOS template package missing"
        echo "Build with: just templates-macos"
        exit 1
    fi

    echo "✅ macOS export templates found"
    echo "🎮 macOS export CLI commands ready:"
    echo "   1. just export-macos-debug     # Export debug build"
    echo "   2. just export-macos-release   # Export release build"
    echo "   3. just export-macos-all       # Export both builds"

# ================================
# macOS RUN COMMANDS
# ================================

# Run macOS debug build (launches .app with console output)
run-macos:
    #!/usr/bin/env bash
    set -euo pipefail

    APP_PATH="export/macos/{{GAME_NAME}}_debug.app"

    if [ ! -d "$APP_PATH" ]; then
        echo "❌ macOS app not found: $APP_PATH"
        echo "💡 Export first: just export-macos-debug"
        exit 1
    fi

    echo "🍎 Running macOS debug build..."
    echo "📁 App: $APP_PATH"
    echo ""

    # Run directly to get console output
    "$APP_PATH/Contents/MacOS/{{GAME_NAME}}"

# Run macOS debug build in background (opens app normally, no console)
run-macos-background:
    #!/usr/bin/env bash
    set -euo pipefail

    APP_PATH="export/macos/{{GAME_NAME}}_debug.app"

    if [ ! -d "$APP_PATH" ]; then
        echo "❌ macOS app not found: $APP_PATH"
        echo "💡 Export first: just export-macos-debug"
        exit 1
    fi

    echo "🍎 Opening macOS debug build..."
    open "$APP_PATH"
    echo "✅ App launched in background"

# Run macOS release build
run-macos-release:
    #!/usr/bin/env bash
    set -euo pipefail

    APP_PATH="export/macos/{{GAME_NAME}}.app"

    if [ ! -d "$APP_PATH" ]; then
        echo "❌ macOS release app not found: $APP_PATH"
        echo "💡 Export first: just export-macos-release"
        exit 1
    fi

    echo "🍎 Running macOS release build..."
    "$APP_PATH/Contents/MacOS/{{GAME_NAME}}"

# ================================
# macOS TEST CACHE MANAGEMENT
# ================================

# Clear macOS test config to allow normal run-macos without debug actions
# This removes stale debug_startup_actions.json that exported apps auto-run
clear-test-macos:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧹 Clearing macOS test configuration..."

    CONFIG_PATH="$HOME/Library/Application Support/Godot/app_userdata/gametwo/debug_startup_actions.json"

    if [ -f "$CONFIG_PATH" ]; then
        rm -f "$CONFIG_PATH"
        echo "✅ macOS test config cleared"
        echo "   Removed: debug_startup_actions.json"
        echo "💡 run-macos will now start without debug actions"
    else
        echo "ℹ️  No macOS test config found - already clean"
    fi

# Clear macOS test cache (alias for consistency with other platforms)
clear-macos-test-cache: clear-test-macos

# ================================
# macOS HELP
# ================================

# macOS help information
help-macos:
    #!/usr/bin/env bash
    echo "🍎 macOS Development Commands"
    echo "=============================="
    echo ""
    echo "Template Building:"
    echo "  just templates-macos               # Build Universal 2 templates (ARM64 + x86_64)"
    echo "  just templates-macos-arm64         # Build ARM64-only templates (faster)"
    echo "  just macos-build-template          # Build Universal 2 template binaries"
    echo "  just macos-build-template-arm64    # Build ARM64-only template binaries"
    echo "  just package-macos-template        # Package templates into macos.zip"
    echo "  just build-macos-templates-minimal # Build debug-only (fastest iteration)"
    echo ""
    echo "Template Management:"
    echo "  just check-macos-templates         # Check template status"
    echo "  just validate-macos-templates      # Validate template integrity"
    echo "  just clean-macos-templates         # Clean template artifacts"
    echo ""
    echo "Export Commands:"
    echo "  just export-macos-debug            # Export debug build"
    echo "  just export-macos-release          # Export release build"
    echo "  just export-macos-all              # Export both debug and release"
    echo "  just validate-macos-exports        # Validate export setup"
    echo ""
    echo "Run Commands:"
    echo "  just run-macos                     # Run debug build (with console output)"
    echo "  just run-macos-background          # Run debug build (no console, background)"
    echo "  just run-macos-release             # Run release build (with console output)"
    echo ""
    echo "Testing Commands:"
    echo "  just test-macos-target CONFIG      # Automated testing with validation"
    echo "  just test-macos-manual CONFIG      # Manual testing (app stays open)"
    echo "  just test-macos-update CONFIG      # Update checksum baseline"
    echo "  just test-macos-reset CONFIG       # Reset checksum baseline"
    echo ""
    echo "Test Cache Management:"
    echo "  just clear-test-macos              # Clear debug_startup_actions.json"
    echo "  just clear-macos-test-cache        # Alias for clear-test-macos"
    echo ""
    echo "Template Types:"
    echo "  Universal 2: Supports both Apple Silicon (ARM64) and Intel (x86_64) Macs"
    echo "  ARM64-only:  Supports only Apple Silicon Macs (smaller, faster build)"
    echo ""
    echo "Build Times (approximate):"
    echo "  Universal 2 templates: 15-25 minutes"
    echo "  ARM64-only templates:  8-12 minutes"
    echo "  Debug-only (minimal):  4-6 minutes"
    echo ""
    echo "Output:"
    echo "  templates/macos.zip - Template package for Godot export"
    echo "  export/macos/       - Exported .app bundles"
