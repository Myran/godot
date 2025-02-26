# Supportive commands for Godot 4 Projects

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
# Format GDScript files
format:
    @echo "Formatting GDScript files..."
    cd {{PROJECT_PATH}} && find . -name "*.gd" -type f -not -path "./addons/*" -exec gdformat {} +

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

# Update export presets
update-export-presets:
    @echo "Updating export presets..."
#    sed -i '' 's#keystore/path=".*"#keystore/path="{{KEYSTORE_PATH}}"#g' {{PROJECT_PATH}}/export_presets.cfg
#    sed -i '' 's#keystore/password=".*"#keystore/password="{{KEYSTORE_PASSWORD}}"#g' {{PROJECT_PATH}}/export_presets.cfg
#    sed -i '' 's#keystore/alias=".*"#keystore/alias="{{GAME_NAME}}"#g' {{PROJECT_PATH}}/export_presets.cfg
#    sed -i '' 's#keystore/alias_password=".*"#keystore/alias_password="{{KEY_PASSWORD}}"#g' {{PROJECT_PATH}}/export_presets.cfg
#    sed -i '' 's#application/identifier=".*"#application/identifier="{{IOS_BUNDLE_IDENTIFIER}}"#g' {{PROJECT_PATH}}/export_presets.cfg
#    sed -i '' 's#application/signature=".*"#application/signature="{{APPLE_TEAM_ID}}"#g' {{PROJECT_PATH}}/export_presets.cfg
#    sed -i '' 's#provisioning_profile/uuid=".*"#provisioning_profile/uuid="{{IOS_PROVISIONING_PROFILE_UUID}}"#g' {{PROJECT_PATH}}/export_presets.cfg

# Update project settings
update-project-settings:
    @echo "Updating project settings..."
    # Add any project-specific settings updates here

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

# Update MoltenVK ios
update-moltenvk:
    @echo "./fetchdepencies --ios needed on fresh build, not included...."
    cd extras/moltenVK && ./fetchDependencies --ios
    cd extras/MoltenVK && make ios
    cp -R extras/MoltenVK/Package/Release/MoltenVK/static/MoltenVK.xcframework export/ios
