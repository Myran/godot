# Windows Platform Support
# Windows desktop export template building and management for GameTwo
# Cross-compilation from macOS to Windows using MinGW-w64

# ================================
# WINDOWS TEMPLATE BUILDING
# ================================

# Build Windows export templates (complete chain)
build-windows-templates:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔧 Building Windows export templates..."
    cd {{GODOT_SUBMODULE_PATH}}

    echo "📦 Building Windows debug template (x86_64)..."
    scons platform=windows target=template_debug arch=x86_64 --jobs={{jobs}}

    echo "📦 Building Windows release template (x86_64)..."
    scons platform=windows target=template_release arch=x86_64 production=yes optimize=size lto=none --jobs={{jobs}}

    echo "📁 Copying Windows templates to templates/ directory..."
    mkdir -p ../templates
    cp bin/godot.windows.template_debug.x86_64.exe ../templates/
    cp bin/godot.windows.template_release.x86_64.exe ../templates/

    # Create Windows template zip package
    echo "📦 Packaging Windows templates into zip file..."
    cd ../templates
    rm -f windows_debug.zip windows_release.zip windows_templates.zip

    # Debug template
    zip -9 windows_debug.zip godot.windows.template_debug.x86_64.exe

    # Release template
    zip -9 windows_release.zip godot.windows.template_release.x86_64.exe

    # Combined package for convenience
    zip -9 windows_templates.zip godot.windows.template_debug.x86_64.exe godot.windows.template_release.x86_64.exe

    echo "✅ Windows export templates built successfully!"
    echo "   📄 templates/windows_debug.zip"
    echo "   📄 templates/windows_release.zip"
    echo "   📄 templates/windows_templates.zip (combined)"

# Build minimal Windows templates (debug only) - for faster iteration
build-windows-templates-minimal:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔧 Building minimal Windows debug template (x86_64)..."
    cd {{GODOT_SUBMODULE_PATH}}

    scons platform=windows target=template_debug arch=x86_64 --jobs={{jobs}}

    echo "📁 Copying Windows debug template to templates/ directory..."
    mkdir -p ../templates
    cp bin/godot.windows.template_debug.x86_64.exe ../templates/

    echo "📦 Packaging Windows debug template..."
    cd ../templates
    rm -f windows_debug.zip
    zip -9 windows_debug.zip godot.windows.template_debug.x86_64.exe

    echo "✅ Minimal Windows debug template built successfully!"
    echo "   📄 templates/windows_debug.zip"

# Clean Windows template artifacts
clean-windows-templates:
    @echo "🧹 Cleaning Windows template artifacts..."
    rm -f templates/windows_*.zip
    rm -f templates/godot.windows.template_*.exe
    rm -f {{GODOT_SUBMODULE_PATH}}/bin/godot.windows.template_*.exe
    echo "✅ Windows templates cleaned"

# Check if Windows templates need to be rebuilt
check-windows-templates:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔍 Checking Windows template status..."
    if [ -f "templates/windows_debug.zip" ] && [ -f "templates/windows_release.zip" ]; then
        echo "✅ Windows templates already built:"
        echo "   📄 templates/windows_debug.zip"
        echo "   📄 templates/windows_release.zip"
        echo ""
        echo "Rebuild? Run: just build-windows-templates"
    else
        echo "❌ Windows templates missing or incomplete"
        echo ""
        echo "Build Windows templates with: just build-windows-templates"
        echo "For quick debug-only build: just build-windows-templates-minimal"
    fi

# ================================
# WINDOWS EXPORT TESTING
# ================================

# Test Windows export from project
test-windows-export:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧪 Testing Windows export functionality..."

    # Check if Windows templates exist
    if [ ! -f "templates/windows_debug.zip" ]; then
        echo "❌ Windows debug template missing"
        echo "Build with: just build-windows-templates"
        exit 1
    fi

    if [ ! -f "templates/windows_release.zip" ]; then
        echo "❌ Windows release template missing"
        echo "Build with: just build-windows-templates"
        exit 1
    fi

    echo "✅ Windows export templates found"
    echo "🎮 Use Godot Editor to test Windows export:"
    echo "   1. Open project/project.godot"
    echo "   2. Go to Project > Export"
    echo "   3. Add Windows Desktop preset"
    echo "   4. Set custom template paths to:"
    echo "      Debug: templates/windows_debug.zip"
    echo "      Release: templates/windows_release.zip"

# Validate Windows template integrity
validate-windows-templates:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔍 Validating Windows template integrity..."
    if [ -f "templates/windows_debug.zip" ]; then
        echo "✅ Windows debug template: $(unzip -l templates/windows_debug.zip | wc -l) files"
    else
        echo "❌ Windows debug template missing"
    fi

    if [ -f "templates/windows_release.zip" ]; then
        echo "✅ Windows release template: $(unzip -l templates/windows_release.zip | wc -l) files"
    else
        echo "❌ Windows release template missing"
    fi