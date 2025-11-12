# Windows Export Template Guide

This guide covers building and using Windows export templates for GameTwo, enabling cross-platform game exports from macOS to Windows.

## Overview

GameTwo now supports Windows desktop exports through custom export templates built with MinGW-w64 cross-compilation. This allows development on macOS while targeting Windows as a deployment platform.

## Prerequisites

### Cross-Compilation Environment
- **MinGW-w64**: Cross-compiler for Windows builds on macOS
- **Rosetta 2**: Required for Intel-based tools on Apple Silicon
- **SCons**: Build system (already configured for GameTwo)
- **Custom Godot 4.3**: GameTwo's custom engine with all modules

### Installation (if needed)
```bash
# Install MinGW-w64 cross-compiler
brew install mingw-w64

# Install Rosetta 2 (Apple Silicon only)
softwareupdate --install-rosetta --agree-to-license
```

## Available Commands

### Template Building Commands

#### Complete Windows Templates
```bash
just build-windows-templates
```
- Builds both debug and release Windows templates
- Targets x86_64 architecture
- Creates packaged zip files in `templates/`
- **Time**: 15-30 minutes

#### Minimal Debug Template (Fast)
```bash
just build-windows-templates-minimal
```
- Builds only debug template
- Faster iteration for testing
- **Time**: 10-15 minutes

### Template Management Commands

#### Check Template Status
```bash
just check-windows-templates
```
Shows current Windows template build status and file locations.

#### Validate Template Integrity
```bash
just validate-windows-templates
```
Verifies Windows template zip files are properly formed and contain expected files.

#### Clean Template Artifacts
```bash
just clean-windows-templates
```
Removes all Windows template build artifacts and zip files.

### Testing Commands

#### Test Export Configuration
```bash
just test-windows-export
```
Validates Windows export template setup and provides instructions for testing in Godot Editor.

### Build System Integration

#### Build All Platform Templates
```bash
just templates-all
```
Builds templates for all platforms: iOS, Android, and Windows.

#### Build Status Check
```bash
just build-status
```
Shows build status for editor and all platform templates including Windows.

## Template Files

After successful build, Windows templates are created in the `templates/` directory:

```
templates/
├── windows_debug.zip          # Debug template (development builds)
├── windows_release.zip        # Release template (production builds)
└── windows_templates.zip      # Combined debug + release (convenience)
```

### Template Contents
Each zip file contains:
- `godot.windows.template_debug.x86_64.exe` - Debug executable
- `godot.windows.template_release.x86_64.exe` - Release executable

## Export Configuration

### Project Settings
The `project/export_presets.cfg` has been updated with Windows template paths:

```ini
[preset.3.options]
custom_template/debug="/Users/mattiasmyhrman/repos/gametwo/templates/windows_debug.zip"
custom_template/release="/Users/mattiasmyhrman/repos/gametwo/templates/windows_release.zip"
```

### Export Settings
- **Platform**: Windows Desktop
- **Architecture**: x86_64
- **Target**: Debug and Release templates
- **Texture Format**: S3TC/BPTC (Windows native compression)

## Export Workflow

### 1. Build Templates
```bash
# First time or after C++ changes
just build-windows-templates

# For quick debug testing
just build-windows-templates-minimal
```

### 2. Test Export in Godot Editor
1. Open `project/project.godot` in Godot Editor
2. Navigate to **Project > Export**
3. Select **Windows Desktop** preset
4. Verify custom template paths are set correctly
5. Test export with **Export** button

### 3. Validate Exported Executable
Run the exported Windows executable on a Windows machine to verify:
- Game launches correctly
- Core functionality works (Firebase/Sentry integration optional)
- Performance is acceptable

## Technical Details

### Cross-Compilation Process
1. **SCons Build**: Uses MinGW-w64 to compile Godot for Windows
2. **Module Integration**: All GameTwo custom modules included
3. **Packaging**: Creates zip files for easy template management

### Architecture Support
- **Target**: Windows x86_64 (64-bit)
- **Compiler**: MinGW-w64 GCC 15.2.0
- **Platform APIs**: Windows-specific implementations used

### Custom Modules Included
- Firebase integration (ready for future implementation)
- Sentry error reporting (ready for future implementation)
- All GameTwo-specific systems and utilities

## Build Times (Estimates)

| Command | Time | Description |
|---------|------|-------------|
| `build-windows-templates-minimal` | 10-15 min | Debug template only |
| `build-windows-templates` | 15-30 min | Debug + Release templates |
| `templates-all` | 45-60 min | All platform templates |

## Troubleshooting

### Common Issues

#### Build Fails with Missing Tools
```bash
# Verify MinGW-w64 installation
x86_64-w64-mingw32-gcc --version

# Should output: x86_64-w64-mingw32-gcc (GCC) 15.2.0
```

#### Export Templates Not Found
```bash
# Check template status
just check-windows-templates

# Rebuild if missing
just build-windows-templates
```

#### Export Fails in Godot Editor
1. Verify template paths in `export_presets.cfg`
2. Check zip files exist and are not corrupted
3. Ensure Godot Editor can access the templates directory

### Verification Steps

#### Template Integrity
```bash
just validate-windows-templates
```

#### Build System Integration
```bash
just build-status
```

#### Cross-Compilation Test
```bash
# Test MinGW-w64 with simple program
echo 'int main() { return 0; }' > test.c
x86_64-w64-mingw32-gcc -o test.exe test.c
file test.exe  # Should show "PE32+ executable (console) x86-64, for MS Windows"
rm test.c test.exe
```

## Integration with Existing Workflows

### Development Pipeline
Windows template building integrates with existing GameTwo workflows:

```bash
# Complete development workflow
just development
```

### CI/CD Integration
Windows templates are included in:
- `just build-toolchain` - Foundation: editor + all templates
- `just build-pipeline` - Complete: source to deployment

### Maintenance
- Template rebuilding required after C++ module changes
- GDScript changes don't require template rebuilds
- Template files should be committed to version control

## Future Enhancements

### Planned Features
- **Firebase Integration**: Full Windows Firebase support
- **Sentry Integration**: Windows error reporting
- **Code Signing**: Windows executable signing
- **Installer Creation**: Windows installer generation

### Wine Integration (Optional)
For Windows-specific testing tools:
```bash
# Install Wine (requires password)
brew install --cask wine-stable
```

## Support

For issues with Windows export templates:
1. Check this guide for common solutions
2. Verify build environment setup
3. Test with minimal debug template first
4. Review build logs for specific error messages
5. Use `just check-windows-templates` for diagnostic information

## Related Documentation

- **Main Build Guide**: See `just help-build` for complete build system
- **Android Export**: See platform-specific Android documentation
- **iOS Export**: See platform-specific iOS documentation
- **Development Workflow**: See `just help-workflows` for daily patterns