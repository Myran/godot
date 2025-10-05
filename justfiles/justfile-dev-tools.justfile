# Development Tools & Utilities
# Developer workflow utilities, editor access, and debugging tools
# Essential tools for daily development workflow

# Note: Variables inherited from imported modules

# Open Godot editor for development
edit:
    @echo "Running Godot editor..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --editor # --verbose --debug

# Show the implementation of a specific command
show COMMAND:
    @just --show {{COMMAND}}

# Run Godot in headless mode without GUI
headless:
    @echo "Running Godot in headless mode..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless
    
# Run Godot in headless mode with additional arguments
headless-run *ARGS:
    @echo "Running Godot in headless mode with args: {{ARGS}}"
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless {{ARGS}}

# Quick shortcuts for common operations
c:
    @just --choose

l:
    @just -l

# Note: validate-env is provided by justfile-support.justfile

# Format GDScript files using gdformat
format:
    echo "Formatting GDScript files..."
    cd {{PROJECT_PATH}} && find . -name "*.gd" -type f -not -path "./addons/*" -exec /Users/mattiasmyhrman/.local/bin/gdformat {} +

# Note: validate function is provided by justfile-validation.justfile

# Update export presets (iOS/Android)
update-export-presets:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📱 Updating export presets..."
    
    cd {{PROJECT_PATH}}
    
    # Generate export_presets.cfg if it doesn't exist
    if [ ! -f "export_presets.cfg" ]; then
        echo "Creating default export presets..."
        cp ../export_presets.cfg.template export_presets.cfg 2>/dev/null || echo "No template found"
    fi
    
    echo "✅ Export presets updated"

# Update project settings 
update-project-settings:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "⚙️ Updating project settings..."
    
    cd {{PROJECT_PATH}}
    
    # Validate project.godot exists
    if [ ! -f "project.godot" ]; then
        echo "❌ project.godot not found"
        exit 1
    fi
    
    echo "✅ Project settings validated"

# Development workflow: fastbuild-android + ci-validate + log-run test
development:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🚀 Running complete development workflow..."
    echo ""

    # Step 1: Fast build Android
    echo "1️⃣ Running fastbuild-android..."
    if ! just fastbuild-android; then
        echo "❌ Fast build Android failed"
        exit 1
    fi
    echo "✅ Fast build Android completed"
    echo ""

    # Step 2: CI validation
    echo "2️⃣ Running ci-validate..."
    if ! just ci-validate; then
        echo "❌ CI validation failed"
        exit 1
    fi
    echo "✅ CI validation completed"
    echo ""

    # Step 3: Run tests with logging
    echo "3️⃣ Running tests with logging..."
    if ! just log-run test; then
        echo "❌ Tests failed"
        exit 1
    fi
    echo "✅ Tests completed"
    echo ""

    echo "🎉 Development workflow completed successfully!"