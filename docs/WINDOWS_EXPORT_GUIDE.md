# Windows Export Pipeline Guide

Complete guide for building, exporting, and testing GameTwo on Windows with Firebase and Sentry integration.

## Overview

GameTwo supports Windows desktop exports through a **two-machine architecture**:
- **Windows VM (192.168.50.92)** - Native MSVC template building
- **Windows Physical (192.168.50.80)** - GUI testing with Wake-on-LAN

**Key Features:**
- Firebase C++ SDK integration (shared code architecture)
- Sentry GDExtension with crashpad backend (out-of-process crash handling)
- Native MSVC builds (ARM64→x64 cross-compilation on VM)
- Full automated and manual testing infrastructure

## Quick Start

```bash
# 1. Build Windows templates and Sentry on VM
just build-all-windows

# 2. Export Windows build
just export-windows-debug

# 3. Deploy to physical machine
just win-physical-deploy

# 4. Run automated test
just test-windows-physical-target firebase-cpp-layer
```

## Machine Architecture

### Windows VM (Building)
- **Host**: 192.168.50.92
- **Purpose**: Template compilation with native MSVC
- **Environment**: Windows 11 ARM64 + Visual Studio 2022 Build Tools
- **Cross-compilation**: ARM64→x64 via cmake toolchain file
- **Commands**: `win-vm-*` prefixed recipes

### Windows Physical (Testing)
- **Host**: 192.168.50.80
- **Purpose**: GUI testing (Windows doesn't support headless Godot)
- **Features**: Wake-on-LAN, automated test execution, log retrieval
- **Commands**: `win-physical-*` prefixed recipes

## Build Commands

### Complete Build Pipeline
```bash
just build-all-windows           # Full pipeline: sync → templates → sentry → package
just build-windows-templates     # Build templates only
```

### Export Commands
```bash
just export-windows-debug        # Export debug build
just export-windows-release      # Export release build
just export-windows-all          # Export both debug and release
just validate-windows-export     # Validate Firebase/Sentry integration
```

### Windows Export Pipeline
```bash
just windows-export-pipeline     # Complete: export → validate → deploy
```

## Testing Commands

### Physical Machine Management
```bash
just win-physical-status         # Check machine status (awake/sleeping)
just win-physical-wake           # Send Wake-on-LAN packet
just win-physical-wake-wait      # Wake and wait for SSH availability
just win-physical-verify         # Full connectivity verification
just win-physical-deploy         # Deploy Windows export to machine
```

### Automated Testing (GUI Mode)
```bash
just test-windows-physical-target CONFIG  # Run test with auto-quit
just test-windows-physical-manual CONFIG  # Run test, stays open for inspection
```

### Log Retrieval
```bash
just logs-windows-physical TEST_ID        # Retrieve test logs
just logs-windows-physical-errors TEST_ID # Error-focused analysis
```

### Checksum Baseline Management
```bash
just test-windows-update CONFIG   # Update checksum baseline
just test-windows-reset CONFIG    # Reset checksum baseline
```

## VM Build Commands

### Template Building
```bash
just win-vm-verify               # Verify VM connectivity and environment
just win-vm-sync                 # Sync repository to VM
just win-vm-template-debug       # Build debug template (~14 min)
just win-vm-template-release     # Build release template (~18 min)
just win-vm-templates            # Build both templates
just win-vm-templates-package    # Copy templates from VM to macOS
just win-vm-status               # Check build status on VM
```

### Sentry Building
```bash
just sentry-windows-vm-build-all   # Build Sentry DLLs on VM
just sentry-windows-vm-package     # Copy Sentry files from VM
just sentry-windows-vm-complete    # Full workflow: verify → build → package
```

### Status & Validation
```bash
just sentry-windows-status       # Check Sentry build status
just sentry-windows-validate     # Validate DLL integration
```

## Integration Status

### Firebase C++ SDK
- **Status**: Fully integrated and tested
- **Architecture**: Shared code (firebase_common.cpp) + Windows-specific (firebase_windows.cpp)
- **Libraries**: Statically linked MSVC libraries
- **Tests**: 8/8 cpp-layer tests pass on Windows

### Sentry GDExtension
- **Status**: Fully integrated with crashpad backend
- **Backend**: crashpad (out-of-process crash handling)
- **Files**:
  - `libsentry.windows.release.x86_64.dll` (340KB)
  - `libsentry.windows.debug.x86_64.dll` (1.9MB)
  - `crashpad_handler.exe` (682KB)
- **Build**: Native MSVC on Windows VM

## Build Times

| Command | Time | Description |
|---------|------|-------------|
| `win-vm-template-debug` | ~14 min | Debug template |
| `win-vm-template-release` | ~18 min | Release template |
| `build-all-windows` | 25-40 min | Full pipeline |
| `export-windows-debug` | ~2 min | Export debug build |
| `win-physical-deploy` | ~30 sec | Deploy to physical machine |

## Workflow Examples

### Development Workflow
```bash
# After code changes, rebuild and test
just export-windows-debug
just win-physical-deploy
just test-windows-physical-target firebase-cpp-layer
just logs-windows-physical-errors TEST_ID
```

### Full Validation
```bash
# Complete Windows validation
just build-all-windows
just export-windows-all
just validate-windows-export
just win-physical-deploy
just test-windows-physical-target production-ready
```

### Quick Iteration
```bash
# For GDScript changes only (no template rebuild needed)
just export-windows-debug
just win-physical-deploy
just test-windows-physical-target CONFIG
```

## Troubleshooting

### VM Connection Issues
```bash
# Verify VM is running and accessible
just win-vm-verify

# Check SSH connectivity
ssh gametwo@192.168.50.92 "echo Connected"
```

### Physical Machine Not Responding
```bash
# Check status
just win-physical-status

# Wake machine
just win-physical-wake-wait

# Verify connectivity
just win-physical-verify
```

### Missing Sentry DLLs
```bash
# Check Sentry status
just sentry-windows-status

# Rebuild if missing
just sentry-windows-vm-complete
```

### Export Validation Failures
```bash
# Run validation
just validate-windows-export

# Check specific components:
# - Executables exist
# - PCK files present
# - Firebase config found
# - Sentry DLLs present
```

## File Locations

### Templates (macOS)
```
templates/
├── godot.windows.template_debug.x86_64.exe
└── godot.windows.template_release.x86_64.exe
```

### Exports (macOS)
```
export/windows/
├── gametwo_debug.exe
├── gametwo_debug.pck
├── gametwo.exe
└── gametwo.pck
```

### Sentry DLLs (macOS)
```
project/addons/sentry/bin/windows/x86_64/
├── libsentry.windows.release.x86_64.dll
├── libsentry.windows.debug.x86_64.dll
├── crashpad_handler.exe
└── crashpad_wer.dll (optional)
```

### Physical Machine
```
C:\GameTwoTests\
├── builds/           # Deployed exports
├── logs/             # Test logs
└── configs/          # Debug configurations
```

## Related Documentation

- **Quick Reference**: `just help-windows`
- **Justfile Architecture**: `justfiles/ARCHITECTURE.md`
- **Build System**: `backlog doc view doc-002`
- **Main CLAUDE.md**: Windows section
