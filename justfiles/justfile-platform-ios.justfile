# iOS Platform Development Commands
# Complete iOS build, deploy, test, and device management workflow
# Handles iOS-specific development tasks and workflows

# Note: Variables and build functions inherited from imported modules

# Check if iOS executable exists or build it
_check-or-build-ios-executable force="no":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{force}}" = "yes" ]; then
        echo "🔥 Force rebuild enabled - rebuilding iOS executable..."
        just build-ios-executable
    elif [ -f "export/ios/{{GAME_NAME}}.xcframework/ios-arm64/libgodot.a" ]; then
        echo "✅ iOS executable already built: export/ios/{{GAME_NAME}}.xcframework/ios-arm64/libgodot.a"
        echo "⏭️  Skipping iOS executable rebuild (saves 20+ minutes)"
    else
        echo "❌ iOS executable not found, building..."
        just build-ios-executable
    fi

# Build iOS executable with optimized settings
build-ios-executable:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔨 Building iOS executable..."

    cd {{GODOT_SUBMODULE_PATH}}
    echo "📦 Building iOS template for arm64 (Sentry SDK always included)..."
    scons platform=ios target=template_release arch=arm64 --jobs={{jobs}} optimize=size use_lto=yes
    
    # Move to export directory - update existing XCFramework
    echo "📁 Moving executable to export directory..."
    cp misc/dist/ios_xcode/libgodot.ios.template_release.xcframework/ios-arm64/libgodot.a ../export/ios/{{GAME_NAME}}.xcframework/ios-arm64/libgodot.a

    echo "✅ iOS executable built successfully and XCFramework updated"

# iOS help information
help-ios:
    #!/usr/bin/env bash
    echo "🍎 iOS Development Commands"
    echo "=========================="
    echo ""
    echo "Build Commands:"
    echo "  just build-ios-executable       # Build iOS executable"
    echo "  just build-ios-app              # Build iOS .app with Xcode"
    echo "  just save-ios-to-app            # Save PCK file to .app"
    echo "  just build-pipeline-ios         # Complete pipeline: source to device ready"
    echo "  just ios-build                  # iOS build pipeline"
    echo "  just build-install-ios          # Full iOS rebuild & install (smart rebuild)"
    echo "  just build-all-ios              # Build all iOS components (smart rebuild)"
    echo "  just rebuild-all-ios            # Force rebuild all iOS components"
    echo ""
    echo "Export & Deploy:"
    echo "  just ios-export-pck              # Export iOS PCK file"
    echo "  just ios-update-pck              # Update iOS PCK file"
    echo ""
    echo "Device Management:"
    echo "  just ios-launch-help             # iOS launch help"
    echo "  just ios-restart-help            # iOS restart help"
    echo ""
    echo "Quick Commands:"
    echo "  just quick-build-ios             # Quick iOS build"

# Export iOS PCK file
ios-export-pck: pre-build
    @echo "📦 Exporting iOS PCK file..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --export-pack "ios" ../export/ios/{{GAME_NAME}}.pck --headless

# Build iOS app with Xcode (creates .app file)
build-ios-app: pre-build
    @echo "🔨 Building iOS app with Xcode..."
    cd export/ios && xcodebuild -workspace {{GAME_NAME}}.xcworkspace \
                                -scheme {{GAME_NAME}} \
                                -configuration Debug \
                                -destination "generic/platform=iOS" \
                                -allowProvisioningUpdates

# Save iOS PCK file directly to app
save-ios-to-app: pre-build
    @echo "💾 Saving iOS PCK file directly to app..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless --export-pack ios ../export/ios/build/products/Debug-iphoneos/{{GAME_NAME}}.app/{{GAME_NAME}}.pck

# iOS build pipeline
ios-build: pre-build
    @echo "🍎 iOS build pipeline..."
    just ios-export-pck

# iOS launch help
ios-launch-help:
    #!/usr/bin/env bash
    echo "🚀 iOS Launch Instructions"
    echo "========================="
    echo ""
    echo "To launch on iOS device/simulator:"
    echo "1. Open Xcode project in export/ios/"
    echo "2. Select target device/simulator"
    echo "3. Build and run (Cmd+R)"
    echo ""
    echo "For command line deployment:"
    echo "- ios-deploy --bundle export/ios/{{GAME_NAME}}.app"

# iOS restart help
ios-restart-help:
    #!/usr/bin/env bash
    echo "🔄 iOS Restart Instructions"
    echo "=========================="
    echo ""
    echo "To restart iOS app:"
    echo "1. Background the app (home button/gesture)"
    echo "2. Open app switcher"
    echo "3. Swipe up on app to close"
    echo "4. Relaunch from home screen"
    echo ""
    echo "For development:"
    echo "- Xcode: Stop and restart debug session"

# Update iOS PCK file
ios-update-pck: pre-build
    @echo "🔄 Updating iOS PCK file..."
    just ios-export-pck
    @echo "✅ iOS PCK updated"

# Full iOS rebuild & install (2-5 min, complete project rebuild)
build-install-ios:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔨 Full iOS rebuild & install..."
    
    # Clean previous builds
    echo "🧹 Cleaning previous builds..."
    rm -rf export/ios/{{GAME_NAME}}.pck
    
    # Smart check for iOS executable
    just _check-or-build-ios-executable
    
    # Export PCK
    echo "📦 Exporting iOS PCK..."
    just ios-export-pck
    
    echo "✅ iOS build & install complete"
    echo "💡 Open Xcode project in export/ios/ to deploy"

# Build all iOS components
build-all-ios force="no": validate-env
    @echo "🍎 Building all iOS components..."
    just _check-or-build-ios-executable {{force}}
    just ios-export-pck
    @echo "✅ All iOS builds complete"

# Quick iOS build for development iteration
quick-build-ios:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "⚡ Quick iOS build..."
    
    # Only export PCK for faster iteration
    just ios-export-pck
    
    echo "✅ Quick iOS build complete"
    echo "💡 Use build-ios-executable for full rebuild"

# Force rebuild all iOS components (ignores existing builds)
rebuild-all-ios:
    @echo "🔥 Force rebuilding all iOS components..."
    just build-all-ios force=yes
    @echo "✅ All iOS rebuilds complete"

# Complete iOS pipeline - from source to device deployment
build-pipeline-ios:
    @echo "🚀 Complete iOS pipeline - source to device..."
    just _check-or-build-ios-executable
    just build-ios-app
    just save-ios-to-app
    @echo "✅ iOS pipeline complete - ready for device deployment"
    @echo "💡 Use 'just launch-ios-iphone' to deploy to iPhone"
    @echo "💡 Use 'just launch-ios-ipad' to deploy to iPad"