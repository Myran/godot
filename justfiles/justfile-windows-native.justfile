# Windows Native Build Support (MSVC)
# ====================================
# Native Windows builds using Visual Studio/MSVC compiler
# Run these recipes ONLY on Windows (in Developer Command Prompt or with vcvars64.bat)
#
# These recipes are designed for:
# - Building Godot Windows templates with Firebase C++ SDK integration
# - Building Sentry native SDK with MSVC
# - Exporting Windows builds with full Firebase + Sentry support
#
# Prerequisites:
# - Windows 11 (ARM64 VM via UTM or native x64)
# - Visual Studio 2022 with "Desktop development with C++" workload
# - Python 3.11+ with SCons (`pip install scons`)
# - Git for Windows
# - just command runner (`winget install Casey.Just`)
#
# IMPORTANT: Run from "Developer Command Prompt for VS 2022" or after running:
#   call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
#
# USAGE: Run this justfile directly (not via main justfile):
#   just --justfile justfiles/justfile-windows-native.justfile windows-native-verify

# Use cmd.exe as the shell for Windows compatibility
set shell := ["cmd.exe", "/c"]

# ================================
# CONFIGURATION
# ================================

# Windows-specific paths (relative, using backslashes for Windows)
# Using WIN_ prefix to avoid conflicts with main justfile variables
WIN_GODOT_PATH := "godot"
WIN_FIREBASE_SDK_PATH := "firebase\\firebase_cpp_sdk"
WIN_PROJECT_PATH := "project"
WIN_TEMPLATES_PATH := "templates"
WIN_EXPORT_PATH := "export\\windows"

# Build configuration
WIN_ARCH := "x86_64"
WIN_MSVC_RUNTIME := "MT"  # MT = static runtime, MD = dynamic runtime

# ================================
# ENVIRONMENT VERIFICATION
# ================================

# Verify Windows native build environment
windows-native-verify:
    echo Verifying Windows native build environment...
    echo.
    echo Checking Visual Studio/MSVC...
    where cl >nul 2>&1 && echo   [OK] MSVC compiler found || echo   [ERROR] MSVC compiler not found
    echo.
    echo Checking Python and SCons...
    where python >nul 2>&1 && echo   [OK] Python found || echo   [ERROR] Python not found
    where scons >nul 2>&1 && echo   [OK] SCons found || echo   [ERROR] SCons not found
    echo.
    echo Checking Git...
    where git >nul 2>&1 && echo   [OK] Git found || echo   [ERROR] Git not found
    echo.
    echo Checking Firebase SDK...
    if exist {{WIN_FIREBASE_SDK_PATH}}\libs\windows\VS2019\{{WIN_MSVC_RUNTIME}}\x64\Release\firebase_app.lib (echo   [OK] Firebase libraries found) else (echo   [ERROR] Firebase libraries not found)
    echo.
    echo Checking Godot source...
    if exist {{WIN_GODOT_PATH}}\SConstruct (echo   [OK] Godot source found) else (echo   [ERROR] Godot source not found)

# Show Windows native build help
windows-native-help:
    @echo "Windows Native Build Commands (MSVC)"
    @echo "====================================="
    @echo.
    @echo "ENVIRONMENT:"
    @echo "  just windows-native-verify      - Verify build environment"
    @echo "  just windows-native-help        - Show this help"
    @echo.
    @echo "TEMPLATE BUILDS (with Firebase):"
    @echo "  just windows-native-templates              - Build both debug and release templates"
    @echo "  just windows-native-template-release       - Build release template only"
    @echo "  just windows-native-template-debug         - Build debug template only"
    @echo "  just windows-native-templates-clean        - Clean template build artifacts"
    @echo.
    @echo "SENTRY BUILDS:"
    @echo "  just windows-native-sentry-release         - Build Sentry DLL (release)"
    @echo "  just windows-native-sentry-debug           - Build Sentry DLL (debug)"
    @echo "  just windows-native-sentry-all             - Build both Sentry variants"
    @echo.
    @echo "EXPORTS:"
    @echo "  just windows-native-export-debug           - Export Windows debug build"
    @echo "  just windows-native-export-release         - Export Windows release build"
    @echo "  just windows-native-export-all             - Export both builds"
    @echo.
    @echo "COMPLETE WORKFLOWS:"
    @echo "  just windows-native-full-pipeline          - Complete build pipeline (templates + sentry + export)"
    @echo "  just windows-native-dev-iteration          - Quick dev iteration (debug only)"
    @echo.
    @echo "PREREQUISITES:"
    @echo "  - Run from 'Developer Command Prompt for VS 2022'"
    @echo "  - Or run: call \"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat\""

# ================================
# GODOT TEMPLATE BUILDS (WITH FIREBASE)
# ================================

# Build Windows release template with Firebase integration
windows-native-template-release jobs="6":
    @echo "Building Windows release template with Firebase (MSVC)..."
    @echo "Architecture: {{WIN_ARCH}}"
    @echo "Runtime: {{WIN_MSVC_RUNTIME}}"
    @echo "Jobs: {{jobs}}"
    @echo.
    cd {{WIN_GODOT_PATH}} && scons platform=windows target=template_release arch={{WIN_ARCH}} production=yes optimize=size -j{{jobs}}
    @echo.
    @echo "[OK] Windows release template built successfully"
    @echo "Output: {{WIN_GODOT_PATH}}/bin/godot.windows.template_release.{{WIN_ARCH}}.exe"

# Build Windows debug template with Firebase integration
windows-native-template-debug jobs="6":
    @echo "Building Windows debug template with Firebase (MSVC)..."
    @echo "Architecture: {{WIN_ARCH}}"
    @echo "Runtime: {{WIN_MSVC_RUNTIME}}"
    @echo "Jobs: {{jobs}}"
    @echo.
    cd {{WIN_GODOT_PATH}} && scons platform=windows target=template_debug arch={{WIN_ARCH}} -j{{jobs}}
    @echo.
    @echo "[OK] Windows debug template built successfully"
    @echo "Output: {{WIN_GODOT_PATH}}/bin/godot.windows.template_debug.{{WIN_ARCH}}.exe"

# Build both Windows templates
windows-native-templates jobs="6": (windows-native-template-debug jobs) (windows-native-template-release jobs)
    @echo.
    @echo "[OK] Both Windows templates built successfully"
    @echo "Debug:   {{WIN_GODOT_PATH}}/bin/godot.windows.template_debug.{{WIN_ARCH}}.exe"
    @echo "Release: {{WIN_GODOT_PATH}}/bin/godot.windows.template_release.{{WIN_ARCH}}.exe"

# Copy templates to templates directory and package
windows-native-templates-package:
    @echo "Packaging Windows templates..."
    @if not exist "{{WIN_TEMPLATES_PATH}}" mkdir "{{WIN_TEMPLATES_PATH}}"
    @copy "{{WIN_GODOT_PATH}}\bin\godot.windows.template_debug.{{WIN_ARCH}}.exe" "{{WIN_TEMPLATES_PATH}}\" /Y
    @copy "{{WIN_GODOT_PATH}}\bin\godot.windows.template_release.{{WIN_ARCH}}.exe" "{{WIN_TEMPLATES_PATH}}\" /Y
    @echo [OK] Templates copied to {{WIN_TEMPLATES_PATH}}/

# Clean template build artifacts
windows-native-templates-clean:
    @echo "Cleaning Windows template build artifacts..."
    @if exist "{{WIN_GODOT_PATH}}\bin\godot.windows.template_*.exe" del /Q "{{WIN_GODOT_PATH}}\bin\godot.windows.template_*.exe"
    @if exist "{{WIN_TEMPLATES_PATH}}\godot.windows.template_*.exe" del /Q "{{WIN_TEMPLATES_PATH}}\godot.windows.template_*.exe"
    @echo [OK] Windows template artifacts cleaned

# ================================
# SENTRY NATIVE SDK BUILDS (MSVC)
# ================================

# Build Sentry native SDK for Windows (Release) using MSVC
windows-native-sentry-release:
    @echo "Building Sentry native SDK for Windows (Release, MSVC)..."
    @if not exist "sentry\build\windows-msvc-release" mkdir "sentry\build\windows-msvc-release"
    cd sentry\build\windows-msvc-release && cmake ..\..\modules\sentry-native -DCMAKE_BUILD_TYPE=Release -DSENTRY_BUILD_SHARED_LIBS=ON -DSENTRY_BUILD_TESTS=OFF -DSENTRY_BUILD_EXAMPLES=OFF -DSENTRY_BACKEND=crashpad -G "Visual Studio 17 2022" -A x64
    cd sentry\build\windows-msvc-release && cmake --build . --config Release --parallel
    @echo.
    @echo "Copying Sentry DLL to addon directory..."
    @if not exist "{{WIN_PROJECT_PATH}}\addons\sentry\bin\windows\x86_64" mkdir "{{WIN_PROJECT_PATH}}\addons\sentry\bin\windows\x86_64"
    @copy "sentry\build\windows-msvc-release\Release\sentry.dll" "{{WIN_PROJECT_PATH}}\addons\sentry\bin\windows\x86_64\libsentry.windows.release.x86_64.dll" /Y
    @if exist "sentry\build\windows-msvc-release\crashpad_build\handler\Release\crashpad_handler.exe" copy "sentry\build\windows-msvc-release\crashpad_build\handler\Release\crashpad_handler.exe" "{{WIN_PROJECT_PATH}}\addons\sentry\bin\windows\x86_64\" /Y
    @echo [OK] Sentry Release DLL built and installed

# Build Sentry native SDK for Windows (Debug) using MSVC
windows-native-sentry-debug:
    @echo "Building Sentry native SDK for Windows (Debug, MSVC)..."
    @if not exist "sentry\build\windows-msvc-debug" mkdir "sentry\build\windows-msvc-debug"
    cd sentry\build\windows-msvc-debug && cmake ..\..\modules\sentry-native -DCMAKE_BUILD_TYPE=Debug -DSENTRY_BUILD_SHARED_LIBS=ON -DSENTRY_BUILD_TESTS=OFF -DSENTRY_BUILD_EXAMPLES=OFF -DSENTRY_BACKEND=crashpad -G "Visual Studio 17 2022" -A x64
    cd sentry\build\windows-msvc-debug && cmake --build . --config Debug --parallel
    @echo.
    @echo "Copying Sentry Debug DLL to addon directory..."
    @if not exist "{{WIN_PROJECT_PATH}}\addons\sentry\bin\windows\x86_64" mkdir "{{WIN_PROJECT_PATH}}\addons\sentry\bin\windows\x86_64"
    @copy "sentry\build\windows-msvc-debug\Debug\sentry.dll" "{{WIN_PROJECT_PATH}}\addons\sentry\bin\windows\x86_64\libsentry.windows.debug.x86_64.dll" /Y
    @echo [OK] Sentry Debug DLL built and installed

# Build both Sentry variants
windows-native-sentry-all: windows-native-sentry-release windows-native-sentry-debug
    @echo [OK] Both Sentry DLL variants built successfully

# Clean Sentry build artifacts
windows-native-sentry-clean:
    @echo "Cleaning Sentry MSVC build artifacts..."
    @if exist "sentry\build\windows-msvc-release" rmdir /S /Q "sentry\build\windows-msvc-release"
    @if exist "sentry\build\windows-msvc-debug" rmdir /S /Q "sentry\build\windows-msvc-debug"
    @echo [OK] Sentry MSVC build artifacts cleaned

# ================================
# WINDOWS EXPORTS
# ================================

# Export Windows debug build
windows-native-export-debug:
    @echo "Exporting Windows debug build..."
    @if not exist "{{WIN_EXPORT_PATH}}" mkdir "{{WIN_EXPORT_PATH}}"
    editor\godot.windows.editor.x86_64.exe --path {{WIN_PROJECT_PATH}} --export-debug "Windows Desktop" ..\{{WIN_EXPORT_PATH}}\gametwo_debug.exe --headless
    @echo [OK] Windows debug export completed
    @echo Output: {{WIN_EXPORT_PATH}}\gametwo_debug.exe

# Export Windows release build
windows-native-export-release:
    @echo "Exporting Windows release build..."
    @if not exist "{{WIN_EXPORT_PATH}}" mkdir "{{WIN_EXPORT_PATH}}"
    editor\godot.windows.editor.x86_64.exe --path {{WIN_PROJECT_PATH}} --export-release "Windows Desktop" ..\{{WIN_EXPORT_PATH}}\gametwo.exe --headless
    @echo [OK] Windows release export completed
    @echo Output: {{WIN_EXPORT_PATH}}\gametwo.exe

# Export both debug and release
windows-native-export-all: windows-native-export-debug windows-native-export-release
    @echo [OK] All Windows exports completed
    @echo Debug:   {{WIN_EXPORT_PATH}}\gametwo_debug.exe
    @echo Release: {{WIN_EXPORT_PATH}}\gametwo.exe

# ================================
# COMPLETE WORKFLOWS
# ================================

# Full build pipeline: templates + sentry + exports
windows-native-full-pipeline jobs="6":
    @echo "=========================================="
    @echo "Windows Native Full Build Pipeline (MSVC)"
    @echo "=========================================="
    @echo.
    just windows-native-verify
    @echo.
    @echo "Step 1/4: Building Godot templates with Firebase..."
    just windows-native-templates {{jobs}}
    @echo.
    @echo "Step 2/4: Packaging templates..."
    just windows-native-templates-package
    @echo.
    @echo "Step 3/4: Building Sentry SDK..."
    just windows-native-sentry-all
    @echo.
    @echo "Step 4/4: Exporting Windows builds..."
    just windows-native-export-all
    @echo.
    @echo "=========================================="
    @echo "[OK] Full pipeline completed successfully!"
    @echo "=========================================="
    @echo.
    @echo "Outputs:"
    @echo "  Templates: {{WIN_TEMPLATES_PATH}}/"
    @echo "  Exports:   {{WIN_EXPORT_PATH}}/"

# Quick dev iteration (debug builds only)
windows-native-dev-iteration jobs="6":
    @echo "Quick Windows dev iteration (debug only)..."
    just windows-native-template-debug {{jobs}}
    just windows-native-sentry-debug
    just windows-native-export-debug
    @echo [OK] Dev iteration completed
    @echo Output: {{WIN_EXPORT_PATH}}\gametwo_debug.exe

# ================================
# FIREBASE SDK VERIFICATION
# ================================

# Verify Firebase SDK libraries are present
windows-native-firebase-verify:
    @echo "Verifying Firebase C++ SDK for Windows..."
    @echo.
    @echo "Checking library paths..."
    @set "FB_PATH={{WIN_FIREBASE_SDK_PATH}}\libs\windows\VS2019\{{WIN_MSVC_RUNTIME}}\x64\Release"
    @if exist "%FB_PATH%\firebase_app.lib" (echo "  [OK] firebase_app.lib") else (echo "  [MISSING] firebase_app.lib")
    @if exist "%FB_PATH%\firebase_auth.lib" (echo "  [OK] firebase_auth.lib") else (echo "  [MISSING] firebase_auth.lib")
    @if exist "%FB_PATH%\firebase_database.lib" (echo "  [OK] firebase_database.lib") else (echo "  [MISSING] firebase_database.lib")
    @if exist "%FB_PATH%\firebase_analytics.lib" (echo "  [OK] firebase_analytics.lib") else (echo "  [MISSING] firebase_analytics.lib")
    @if exist "%FB_PATH%\firebase_remote_config.lib" (echo "  [OK] firebase_remote_config.lib") else (echo "  [MISSING] firebase_remote_config.lib")
    @if exist "%FB_PATH%\firebase_functions.lib" (echo "  [OK] firebase_functions.lib") else (echo "  [MISSING] firebase_functions.lib")
    @if exist "%FB_PATH%\firebase_messaging.lib" (echo "  [OK] firebase_messaging.lib") else (echo "  [MISSING] firebase_messaging.lib")
    @echo.
    @echo "Firebase SDK include path: {{WIN_FIREBASE_SDK_PATH}}\include"
    @if exist "{{WIN_FIREBASE_SDK_PATH}}\include\firebase\app.h" (echo "  [OK] Headers found") else (echo "  [MISSING] Headers not found")

# ================================
# STATUS AND DIAGNOSTICS
# ================================

# Show complete build status
windows-native-status:
    @echo "Windows Native Build Status"
    @echo "============================"
    @echo.
    @echo "Templates:"
    @if exist "{{WIN_GODOT_PATH}}\bin\godot.windows.template_debug.{{WIN_ARCH}}.exe" (echo "  [OK] Debug template built") else (echo "  [--] Debug template not built")
    @if exist "{{WIN_GODOT_PATH}}\bin\godot.windows.template_release.{{WIN_ARCH}}.exe" (echo "  [OK] Release template built") else (echo "  [--] Release template not built")
    @echo.
    @echo "Sentry DLLs:"
    @if exist "{{WIN_PROJECT_PATH}}\addons\sentry\bin\windows\x86_64\libsentry.windows.release.x86_64.dll" (echo "  [OK] Release DLL") else (echo "  [--] Release DLL not built")
    @if exist "{{WIN_PROJECT_PATH}}\addons\sentry\bin\windows\x86_64\libsentry.windows.debug.x86_64.dll" (echo "  [OK] Debug DLL") else (echo "  [--] Debug DLL not built")
    @echo.
    @echo "Exports:"
    @if exist "{{WIN_EXPORT_PATH}}\gametwo.exe" (echo "  [OK] Release export") else (echo "  [--] Release not exported")
    @if exist "{{WIN_EXPORT_PATH}}\gametwo_debug.exe" (echo "  [OK] Debug export") else (echo "  [--] Debug not exported")
