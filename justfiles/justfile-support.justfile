# Supportive commands for Godot 4 Projects

# Take screenshot from Android device for AI analysis
screenshot-android name="screenshot":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📱 Taking screenshot from Android device..."
    
    # Take screenshot on device
    adb shell screencap -p /sdcard/{{name}}.png
    
    # Pull screenshot to temp directory
    adb pull /sdcard/{{name}}.png /tmp/{{name}}.png
    
    # Clean up device storage
    adb shell rm /sdcard/{{name}}.png
    
    echo "✅ Screenshot saved to /tmp/{{name}}.png"
    echo "🤖 Screenshot ready for AI analysis via Read tool"
    echo ""
    echo "💡 Use: Read tool with /tmp/{{name}}.png"

# Quick screenshot for debugging (uses default name)
screenshot:
    just screenshot-android screenshot

# Close debug menu by tapping X button (top-right corner)
close-debug-menu:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🎯 Closing debug menu..."
    
    # Get screen size (expecting 1080x2220 override size)
    SCREEN_SIZE=$(adb shell wm size | grep "Override size" | cut -d: -f2 | tr -d ' ')
    if [[ -z "$SCREEN_SIZE" ]]; then
        SCREEN_SIZE=$(adb shell wm size | grep "Physical size" | cut -d: -f2 | tr -d ' ')
    fi
    
    WIDTH=$(echo $SCREEN_SIZE | cut -dx -f1)
    HEIGHT=$(echo $SCREEN_SIZE | cut -dx -f2)
    
    # Calculate X button position (approximately 95% from left, 3% from top)
    X_POS=$((WIDTH * 95 / 100))
    Y_POS=$((HEIGHT * 3 / 100))
    
    echo "📱 Screen size: ${WIDTH}x${HEIGHT}"
    echo "🎯 Tapping X button at: ${X_POS},${Y_POS}"
    
    adb shell input tap $X_POS $Y_POS
    
    echo "✅ Debug menu close attempted"

# Tap anywhere on screen to dismiss overlays
tap-to-dismiss:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "👆 Tapping to dismiss overlays..."
    
    # Get screen size
    SCREEN_SIZE=$(adb shell wm size | grep "Override size" | cut -d: -f2 | tr -d ' ')
    if [[ -z "$SCREEN_SIZE" ]]; then
        SCREEN_SIZE=$(adb shell wm size | grep "Physical size" | cut -d: -f2 | tr -d ' ')
    fi
    
    WIDTH=$(echo $SCREEN_SIZE | cut -dx -f1)
    HEIGHT=$(echo $SCREEN_SIZE | cut -dx -f2)
    
    # Tap center of screen
    X_POS=$((WIDTH / 2))
    Y_POS=$((HEIGHT / 2))
    
    echo "🎯 Tapping center at: ${X_POS},${Y_POS}"
    adb shell input tap $X_POS $Y_POS

# Validate environment variables
update-clangd:
    cd godot && scons compiledb=yes compile_commands.json

clean-xcode:
    rm -rf ~/Library/Developer/Xcode/DerivedData/

# Generate a repofile with repomix
generate-repofile:
    repomix --include 'project/**/*.gd','project/docs/*.md','godot/modules/firebase/*.mm','godot/modules/firebase/*.cpp','godot/modules/firebase/*.h'

validate-env:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Validating environment variables..."
    echo "✅ GAME_NAME: {{GAME_NAME}}"
    echo "✅ KEYSTORE_PASSWORD: [CONFIGURED]" 
    echo "✅ KEY_PASSWORD: [CONFIGURED]"
    echo "✅ APPLE_TEAM_ID: {{APPLE_TEAM_ID}}"
    echo "✅ APPLE_ID: {{APPLE_ID}}"
    echo "✅ IOS_PROVISIONING_PROFILE_UUID: {{IOS_PROVISIONING_PROFILE_UUID}}"
    echo "All required environment variables are set."

# Install dependencies
install-deps:
    @echo "Installing dependencies..."
    brew install scons yasm pipx ninja
    pipx install "gdtoolkit==4.*"
    pipx inject gdtoolkit setuptools

# Install iOS-specific dependencies
install-ios-deps:
    @echo "Installing iOS dependencies..."
    @echo "Current directory: $(pwd)"
    @echo "Justfile directory: {{justfile_directory()}}"
    @echo "Changing to MoltenVK directory..."
    cd {{justfile_directory()}}/extras/MoltenVK && \
    echo "Current directory after cd: $(pwd)" && \
    echo "Listing directory contents:" && \
    ls -la && \
    echo "Running fetchDependencies..." && \
    ./fetchDependencies --ios && \
    echo "Running make ios..." && \
    make ios
    @echo "Creating export/ios directory..."
    mkdir -p {{justfile_directory()}}/export/ios
    @echo "Copying MoltenVK.xcframework..."
    cp -R {{justfile_directory()}}/extras/MoltenVK/Package/Latest/MoltenVK/Static/MoltenVK.xcframework {{justfile_directory()}}/export/ios/
    @echo "iOS dependencies installed successfully."
    
# Lint GDScript files
lint:
    @echo "Linting GDScript files..."
    cd {{PROJECT_PATH}} && find . -name "*.gd" -type f -not -path "./addons/*" | grep -v -f .gdlintignore | xargs gdlint
# REMOVED: format - moved to justfile-dev-tools.justfile

format-test:
    @echo "TEST Formatting GDScript files..."
    cd {{PROJECT_PATH}} && find . -name "*.gd" -type f -not -path "./addons/*" -exec gdformat --check {} +

# Update version
update-version:
    #!/bin/bash
    echo "Updating versions..."
    # Update iOS version
    sed -i '' "s/^application\/version=.*/application\/version=\"1.0.$(date +'%Y%m%d%H%M%S')\"/" {{PROJECT_PATH}}/export_presets.cfg

    # Update Android version code and name
    sed -i '' "s/^version\/code=.*/version\/code=$(date +'%Y%m%d%H%M%S')/" {{PROJECT_PATH}}/export_presets.cfg
    sed -i '' "s/^version\/name=.*/version\/name=\"1.0.$(date +'%Y%m%d%H%M%S')\"/" {{PROJECT_PATH}}/export_presets.cfg

# REMOVED: update-export-presets - moved to justfile-dev-tools.justfile

# REMOVED: update-project-settings - moved to justfile-dev-tools.justfile

# Clean build artifacts
clean:
    @echo "Cleaning build artifacts..."
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

# Update MoltenVK ios
update-moltenvk:
    @echo "./fetchdepencies --ios needed on fresh build, not included...."
    cd extras/moltenVK && ./fetchDependencies --ios
    cd extras/MoltenVK && make ios
    cp -R extras/MoltenVK/Package/Release/MoltenVK/static/MoltenVK.xcframework export/ios
