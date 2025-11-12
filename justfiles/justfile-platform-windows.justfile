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

# ================================
# WINDOWS DESKTOP EXPORTS
# ================================

# Export Windows Desktop - Debug only
export-windows-debug:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📦 Exporting Windows Desktop (debug only)..."

    # Ensure export directory exists
    mkdir -p export/windows

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
    echo "🔨 Building Windows debug export..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} \
        --export-debug "Windows Desktop" \
        ../export/windows/{{GAME_NAME}}_debug.exe --headless

    echo "✅ Windows debug export completed successfully"
    echo "📁 Debug: export/windows/{{GAME_NAME}}_debug.exe"

# Export Windows Desktop - Release only
export-windows-release:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📦 Exporting Windows Desktop (release only)..."

    # Ensure export directory exists
    mkdir -p export/windows

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
    echo "🔨 Building Windows release export..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} \
        --export-release "Windows Desktop" \
        ../export/windows/{{GAME_NAME}}.exe --headless

    echo "✅ Windows release export completed successfully"
    echo "📁 Release: export/windows/{{GAME_NAME}}.exe"

# Export Windows Desktop - Both debug and release
export-windows-all: export-windows-debug export-windows-release
    @echo "✅ All Windows exports completed successfully"
    @echo "📁 Debug: export/windows/{{GAME_NAME}}_debug.exe"
    @echo "📁 Release: export/windows/{{GAME_NAME}}.exe"

# Validate Windows export CLI functionality
validate-windows-exports:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧪 Validating Windows export CLI functionality..."

    # Check if Windows templates exist (extracted .exe files)
    if [ ! -f "templates/godot.windows.template_debug.x86_64.exe" ]; then
        echo "❌ Windows debug template missing"
        echo "Build with: just build-windows-templates"
        exit 1
    fi

    if [ ! -f "templates/godot.windows.template_release.x86_64.exe" ]; then
        echo "❌ Windows release template missing"
        echo "Build with: just build-windows-templates"
        exit 1
    fi

    # Check if Sentry Windows DLLs exist
    if [ ! -f "project/addons/sentry/bin/windows/x86_64/libsentry.windows.release.x86_64.dll" ]; then
        echo "❌ Sentry Windows release DLL missing"
        echo "Build with: just sentry-windows-build"
        exit 1
    fi

    if [ ! -f "project/addons/sentry/bin/windows/x86_64/libsentry.windows.debug.x86_64.dll" ]; then
        echo "❌ Sentry Windows debug DLL missing"
        echo "Build with: just sentry-windows-build-debug"
        exit 1
    fi

    echo "✅ Windows export templates and Sentry DLLs found"
    echo "🎮 Windows export CLI commands ready:"
    echo "   1. just export-windows-debug     # Export debug build"
    echo "   2. just export-windows-release   # Export release build"
    echo "   3. just export-windows-all       # Export both builds"

# ================================
# BUILD MACHINE SETUP
# ================================

# Install all dependencies needed for Windows export build machine
dependencies-build-windows:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔧 Setting up Windows export build machine dependencies..."

    # Update Homebrew first
    echo "📦 Updating Homebrew..."
    brew update

    # Install MinGW-w64 cross-compilers for Windows builds
    echo "🪟 Installing MinGW-w64 cross-compilers..."
    brew install mingw-w64

    # Install SCons build system (Godot's build system)
    echo "🔨 Installing SCons build system..."
    brew install scons

    # Install CMake for Sentry SDK builds
    echo "🔧 Installing CMake..."
    brew install cmake

    # Install jq for JSON processing (justfile variables)
    echo "📄 Installing jq for JSON processing..."
    brew install jq

    # Install zip/unzip for template packaging
    echo "📦 Installing zip/unzip utilities..."
    brew install zip unzip

    # Install coreutils for GNU compatibility (if needed)
    echo "🛠️ Installing coreutils..."
    brew install coreutils

    # Install Python 3 and pip (SCons requires Python)
    echo "🐍 Installing Python 3 and pip..."
    brew install python3 python3-pip

    # Install yq for YAML processing (if needed for future configs)
    echo "📝 Installing yq for YAML processing..."
    brew install yq

    # Install tree for directory structure inspection (useful for debugging)
    echo "🌳 Installing tree for directory inspection..."
    brew install tree

    # Install ripgrep for fast code searching (GameTwo standard)
    echo "🔍 Installing ripgrep for fast code searching..."
    brew install ripgrep

    # Install fd for fast file finding (GameTwo standard)
    echo "📁 Installing fd for fast file finding..."
    brew install fd

    # Install bat for syntax-highlighted file preview (GameTwo standard)
    echo "🦇 Installing bat for file preview..."
    brew install bat

    # Verify installations
    echo "✅ Verifying installations..."
    echo "   MinGW-w64 x86_64: $(x86_64-w64-mingw32-gcc --version | head -1 || echo '❌ Not found')"
    echo "   MinGW-w32 x86_32: $(i686-w64-mingw32-gcc --version | head -1 || echo '❌ Not found')"
    echo "   SCons: $(scons --version | head -1 || echo '❌ Not found')"
    echo "   CMake: $(cmake --version | head -1 || echo '❌ Not found')"
    echo "   jq: $(jq --version || echo '❌ Not found')"
    echo "   Python3: $(python3 --version || echo '❌ Not found')"
    echo "   ripgrep: $(rg --version | head -1 || echo '❌ Not found')"
    echo "   fd: $(fd --version | head -1 || echo '❌ Not found')"
    echo "   bat: $(bat --version | head -1 || echo '❌ Not found')"

    echo "✅ Windows export build machine setup completed!"
    echo ""
    echo "🎯 Ready for Windows development:"
    echo "   1. just build-windows-templates     # Build Windows export templates"
    echo "   2. just sentry-windows-build        # Build Sentry Windows DLLs"
    echo "   3. just export-windows-all          # Export Windows builds"
    echo "   4. just validate-windows-exports    # Validate setup"

# Verify all Windows build dependencies are installed
verify-windows-build-machine:
    @echo "🔍 Verifying Windows build machine setup..."
    @echo ""
    @echo "🔧 Compilers and Build Tools:"
    @if command -v x86_64-w64-mingw32-gcc &> /dev/null; then echo "   ✅ MinGW-w64 x86_64: $(x86_64-w64-mingw32-gcc --version | head -1)"; else echo "   ❌ MinGW-w64 x86_64: Not found (brew install mingw-w64)"; fi
    @if command -v i686-w64-mingw32-gcc &> /dev/null; then echo "   ✅ MinGW-w32 x86_32: $(i686-w64-mingw32-gcc --version | head -1)"; else echo "   ❌ MinGW-w32 x86_32: Not found (brew install mingw-w64)"; fi
    @if command -v scons &> /dev/null; then echo "   ✅ SCons: $(scons --version | head -1)"; else echo "   ❌ SCons: Not found (brew install scons)"; fi
    @if command -v cmake &> /dev/null; then echo "   ✅ CMake: $(cmake --version | head -1)"; else echo "   ❌ CMake: Not found (brew install cmake)"; fi
    @if command -v make &> /dev/null; then echo "   ✅ Make: $(make --version | head -1)"; else echo "   ❌ Make: Not found (brew install make)"; fi
    @echo ""
    @echo "📄 Utilities and Tools:"
    @if command -v jq &> /dev/null; then echo "   ✅ jq: $(jq --version)"; else echo "   ❌ jq: Not found (brew install jq)"; fi
    @if command -v python3 &> /dev/null; then echo "   ✅ Python3: $(python3 --version)"; else echo "   ❌ Python3: Not found (brew install python3)"; fi
    @if command -v zip &> /dev/null; then echo "   ✅ zip: $(zip --version | head -1)"; else echo "   ❌ zip: Not found (brew install zip)"; fi
    @if command -v unzip &> /dev/null; then echo "   ✅ unzip: $(unzip -v | head -1)"; else echo "   ❌ unzip: Not found (brew install unzip)"; fi
    @echo ""
    @echo "🚀 GameTwo Development Tools:"
    @if command -v rg &> /dev/null; then echo "   ✅ ripgrep: $(rg --version | head -1)"; else echo "   ❌ ripgrep: Not found (brew install ripgrep)"; fi
    @if command -v fd &> /dev/null; then echo "   ✅ fd: $(fd --version | head -1)"; else echo "   ❌ fd: Not found (brew install fd)"; fi
    @if command -v bat &> /dev/null; then echo "   ✅ bat: $(bat --version | head -1)"; else echo "   ❌ bat: Not found (brew install bat)"; fi
    @if command -v tree &> /dev/null; then echo "   ✅ tree: $(tree --version | head -1)"; else echo "   ❌ tree: Not found (brew install tree)"; fi
    @if command -v yq &> /dev/null; then echo "   ✅ yq: $(yq --version | head -1)"; else echo "   ❌ yq: Not found (brew install yq)"; fi
    @echo ""
    @echo "📋 Build Machine Status:"
    @echo "   🍎 macOS: $(sw_vers -productName) $(sw_vers -productVersion)"
    @echo "   💻 Architecture: $(uname -m)"
    @echo "   📦 Homebrew: $(brew --version | head -1)"
    @echo ""
    @echo "🎯 Next Steps:"
    @echo "   1. just dependencies-build-windows    # Install missing dependencies"
    @echo "   2. just build-windows-templates       # Build Windows export templates"
    @echo "   3. just sentry-windows-build          # Build Sentry Windows DLLs"
    @echo "   4. just export-windows-all            # Export complete Windows builds"