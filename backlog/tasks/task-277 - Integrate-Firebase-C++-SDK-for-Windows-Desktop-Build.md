---
id: task-277
title: Integrate Firebase C++ SDK for Windows Desktop Build
status: To Do
assignee: []
created_date: '2025-11-12 16:41'
updated_date: '2025-12-02 16:58'
labels:
  - firebase
  - windows
  - build-system
  - cross-platform
  - cpp
dependencies: []
priority: high
---

## Description

Integrate Firebase C++ SDK support for Windows desktop builds in the GameTwo Godot project. Currently, Firebase integration exists only for Android and iOS through a custom Godot module (`godot/modules/firebase/`). This task will extend the module to support Windows desktop using Firebase C++ SDK pre-built libraries with a unified fetch system via justfile commands, eliminating the need for cross-compilation.

## Context

**Current State:**
- Firebase module exists at `godot/modules/firebase/` with Android (.cpp) and iOS (.mm) implementations
- `config.py` only allows `android` and `ios` platforms
- Firebase C++ SDK 12.2.0 is available at `firebase/firebase_cpp_sdk/` with full platform support
- All Firebase libraries are present including Windows VS2019 libraries (MT/x64/Release confirmed)
- Windows build system exists using MinGW-w64 for cross-compilation (see Sentry Windows integration as reference)
- Current Android libraries are pre-built static files (.a) for armeabi-v7a and arm64-v8a architectures
- Total Firebase SDK size: 8.7GB (includes all platforms)
- Windows libraries were temporarily deleted but now restored

**Firebase C++ SDK Pre-built Libraries (New Approach):**
- **Official Distribution**: Pre-built libraries available from `https://dl.google.com/firebase/sdk/cpp/firebase_cpp_sdk_13.2.0.zip`
- **Platform Coverage**: Windows (x86/x64, Debug/Release, MT/MD), Android (existing), macOS, Linux
- **No Compilation Required**: Direct download and integration, eliminating cross-compilation complexity
- **Version Control**: Managed via justfile commands, not git (binaries in .gitignore)
- **Windows Library Variants**: Multiple configurations (x86/x64, Debug/Release, static/dynamic runtime)
- **Windows SDK Library Dependencies**: `advapi32, ws2_32, crypt32, rpcrt4, ole32, shell32, iphlpapi, psapi, userenv`

**Justfile Integration Strategy:**
- **Unified Fetch System**: Single command fetches all platform libraries
- **Platform-Specific Commands**: Separate commands for individual platforms when needed
- **Version Management**: Centralized version variable in justfile
- **No External Scripts**: All functionality embedded in justfile
- **Build Integration**: Automatic fetching before Windows builds

## Implementation Plan

### Phase 1: Optimize Current SDK & Setup Pre-built System

**1.1 Optimize Current Firebase SDK**
- [x] Firebase C++ SDK 12.2.0 libraries restored including Windows VS2019 libraries
- [ ] Remove unused platforms to reduce size: `rm -rf firebase/firebase_cpp_sdk/libs/linux firebase/firebase_cpp_sdk/libs/tvos`
- [ ] Verify Windows libraries are available: `firebase/firebase_cpp_sdk/libs/windows/VS2019/MT/x64/Release/`
- [ ] Document current SDK state: 8.7GB total, Firebase C++ SDK 12.2.0

**1.2 Update .gitignore**
- [ ] Add Firebase pre-built libraries to .gitignore: `firebase/firebase_cpp_sdk/`
- [ ] Keep directory structure with .gitkeep files

**1.3 Create Justfile Firebase Commands**
- [ ] Add Firebase version variable: `FIREBASE_VERSION := "13.2.0"`
- [ ] Create unified fetch command: `firebase-fetch-libraries` (fetches all platforms at once)
- [ ] Create management commands: `firebase-clean`, `firebase-status`, `firebase-update`
- [ ] Add version checking command: `firebase-version-check` (verifies current vs latest)
- [ ] Add selective module fetching: `firebase-fetch-modules database auth analytics`
- [ ] Add desktop configuration setup: `firebase-setup-desktop-config`
- [ ] Embed all functionality in justfile (no external scripts)
- [ ] Add robust error handling and validation

### Phase 2: Module Configuration & Windows Support

**2.1 Update Firebase Module Configuration**

**Current config.py Analysis:**
- Lines 1-6: `can_build()` function only returns `True` for "android" and "ios"
- Lines 8-11: `configure()` function only has Android configuration
- **Missing**: Windows platform support

**Updated config.py Plan:**

```python
def can_build(env, platform):
    if platform == "android":
        return True
    if platform == "ios":
        return True
    if platform == "windows":  # NEW - Enable Windows support
        return True
    return False

def configure(env):
    if env['platform'] == "android":
        pass
    elif env['platform'] == "windows":  # NEW - Windows configuration
        # Add Windows-specific preprocessor definitions
        env.Append(CPPDEFINES=['WINDOWS_ENABLED'])
        # Additional Windows configuration handled in SCsub
        pass
```

**Specific config.py Updates Required:**
- [ ] Add Windows platform check to `can_build()` function (after line 4)
- [ ] Add Windows configuration block in `configure()` function (after line 10)
- [ ] Add `WINDOWS_ENABLED` preprocessor definition for conditional compilation
- [ ] Ensure Windows configuration doesn't interfere with existing Android/iOS setup

**2.2 Update SCsub Build Script**

**Current SCsub Analysis:**
- Lines 1-9: Basic setup and include paths (already configured correctly)
- Lines 11-14: iPhone platform support (frameworks, not actively used)
- Lines 16-37: Android platform support with arm32/arm64 static libraries
- **Missing**: Windows platform support

**Windows Platform Addition Plan:**
Add new elif block for Windows platform (after line 37):

```python
elif env['platform'] == 'windows':
    print("windows")

    # Determine build configuration
    if env['target'] == 'debug':
        build_config = 'Debug'
    else:
        build_config = 'Release'

    # Determine architecture
    if env['arch'] == 'x86_64':
        arch = 'x64'
    elif env['arch'] == 'x86_32':
        arch = 'x86'
    else:
        print('WARN: Unsupported architecture for firebase module: '+str(env['arch']))
        return

    # Choose runtime library variant (can be made configurable)
    runtime_variant = 'MT'  # Static runtime (MD also available)

    # Construct library path using pre-built libraries
    lib_path = f"#/../firebase/firebase_cpp_sdk/libs/windows/{arch}/{build_config}/{runtime_variant}"

    # ROBUSTNESS: Verify library directory exists
    if not Dir(lib_path).exists():
        print(f"ERROR: Firebase Windows libraries not found at {lib_path}")
        print("Run 'just firebase-fetch-libraries' to download libraries")
        print("Skipping Firebase module compilation - build will continue without Firebase support")
        return  # Skip Firebase rather than fail entire build

    # Firebase Windows libraries to link
    firebase_libs = [
        "firebase_app",
        "firebase_analytics",
        "firebase_remote_config",
        "firebase_database",
        "firebase_auth",
        "firebase_functions",
        "firebase_messaging"
    ]

    # Link Firebase libraries with existence checking
    linked_libs = []
    for lib in firebase_libs:
        lib_file = File(f"{lib_path}/{lib}.lib")
        if lib_file.exists():
            env.Prepend(LIBS=[lib_file])
            linked_libs.append(lib)
            print(f"  Linking: {lib}.lib")
        else:
            print(f"  WARNING: Firebase library not found: {lib_file}")

    # Only proceed if we have essential libraries
    if "firebase_app" not in linked_libs:
        print("ERROR: Core Firebase library (firebase_app) missing - skipping Firebase integration")
        return

    # Link required Windows system libraries for Firebase
    windows_system_libs = [
        'advapi32',     # Common for auth, database, firestore, functions, storage
        'ws2_32',       # Windows Sockets API
        'crypt32',      # Cryptographic API
        'rpcrt4',       # RPC runtime (for Firestore, Functions, Remote Config)
        'ole32',        # OLE32 API (for Firestore, Functions, Remote Config)
        'shell32',      # Shell API (for Firestore)
        'iphlpapi',     # IP Helper API (for Realtime Database)
        'psapi',        # Process Status API (for Realtime Database)
        'userenv'       # User Environment API (for Realtime Database)
    ]

    env.Prepend(LIBS=windows_system_libs)

    # Add desktop configuration support
    config_path = "#/../firebase/firebase_cpp_sdk/desktop_config.json"
    if File(config_path).exists():
        env.Append(CPPDEFINES=[f'FIREBASE_DESKTOP_CONFIG_PATH="{config_path}"'])
        print(f"  Using desktop config: {config_path}")

    print(f"  Firebase Windows configured for {arch} {build_config} ({runtime_variant})")
    print(f"  Successfully linked {len(linked_libs)} Firebase libraries")
```

**Specific SCsub Updates Required:**
- [ ] Add Windows elif block after line 37 (Android section)
- [ ] Include Windows source files: add `*.cpp` files for Windows implementations
- [ ] Add conditional compilation support: `env.Append(CPPDEFINES=['WINDOWS_ENABLED'])`
- [ ] Handle missing libraries gracefully with existence checks
- [ ] Add Windows-specific include paths if needed
- [ ] Ensure library path resolution works with SCons File objects

**2.3 Create Windows Implementation Files**
- [ ] Create `godot/modules/firebase/database_windows.cpp` (Windows desktop implementation)
- [ ] Update existing files to support Windows compilation with `#ifdef WINDOWS_ENABLED`
- [ ] Ensure Firebase App initialization works on Windows desktop

### Phase 3: Build System Integration

**3.1 Integrate Firebase Fetch into Build Workflow**
- [ ] Add `firebase-fetch-libraries` dependency to build commands that need Firebase
- [ ] Ensure automatic library fetching before template builds when Firebase libraries missing
- [ ] Integrate with existing build commands (no need for separate Firebase-specific build commands)
- [ ] Add Firebase library validation to existing Windows build commands
- [ ] Create test integration: `test-firebase-windows` command that validates Firebase functionality

**Enhanced Build Integration Pattern:**
```bash
# Add to existing build commands (modification, not replacement)
build-windows-templates:
    #!/bin/bash
    # ADD: Firebase library check and fetch
    if [ ! -d "firebase/firebase_cpp_sdk/libs/windows" ]; then
        echo "Firebase libraries missing, fetching..."
        just firebase-fetch-libraries
    fi
    # Continue with existing build logic

test-firebase-windows:
    #!/bin/bash
    just build-windows-templates
    just test-android 'system.firebase.*'  # Use existing test patterns
```

**3.2 Justfile Command Integration**
- [ ] Follow existing just naming conventions (kebab-case, no aliases)
- [ ] Create essential management commands:
  - `firebase-fetch-libraries` - Fetch all platforms at once
  - `firebase-clean` - Remove all libraries
  - `firebase-status` - Show current state
  - `firebase-update` - Clean and re-fetch
- [ ] No platform-specific fetch commands needed since everything is fetched at once

**3.3 Desktop Configuration Setup**
- [ ] Ensure Firebase configuration file setup for Windows desktop
- [ ] Handle Windows-specific Firebase App initialization
- [ ] Verify desktop workflow requirements from Firebase documentation
- [ ] Create `firebase-setup-desktop-config` command that generates `desktop_config.json` from `google-services.json`
- [ ] Add configuration validation to ensure desktop config is properly formatted
- [ ] Test Firebase desktop configuration loading in Windows builds

**Desktop Configuration Requirements:**
- Firebase C++ SDK requires `desktop_config.json` for Windows desktop applications
- This file is generated from `google-services.json` (Android) or `GoogleService-Info.plist` (iOS)
- Configuration must be available at build time for proper Firebase initialization

### Phase 4: GDScript Integration & Testing

**4.1 Test Firebase Initialization on Windows**
- [ ] Verify `ClassDB.class_exists("FirebaseDatabase")` on Windows builds
- [ ] Test `project/firebase/firebase_service.gd` initialization
- [ ] Ensure `FirebaseDatabaseWrapper` works correctly

**4.2 Platform Detection & Configuration**
- [ ] Update `project/data/backends/firebase_service_backend.gd` if needed
- [ ] Handle Windows-specific Firebase configuration paths
- [ ] Test lazy initialization pattern on Windows

**4.3 Cross-Platform Validation**
- [ ] Run existing Firebase tests on Windows export
- [ ] Validate Realtime Database operations
- [ ] Test rate limiting and error handling

### Phase 5: Export & Deployment

**5.1 Windows Export Configuration**
- [ ] Ensure Firebase libraries are included in Windows exports (static linking)
- [ ] Update export templates to include Firebase dependencies
- [ ] Create Windows-specific Firebase configuration deployment
- [ ] Validate that Firebase libraries are properly bundled in Windows exports
- [ ] Test exported Windows application with Firebase functionality
- [ ] Ensure `desktop_config.json` is included in Windows exports

**Export Template Integration:**
- Firebase libraries are statically linked, so no DLLs need to be shipped separately
- Configuration files must be bundled with the exported application
- Test export process to ensure Firebase initialization works in deployed applications

**5.2 Documentation**
- [ ] Document Windows-specific setup requirements
- [ ] Add Windows build commands to CLAUDE.md
- [ ] Update build system documentation (doc-002)

## Technical Decisions

### Pre-built Libraries Approach (Chosen Strategy)
**Pros:**
- **No Cross-Compilation**: Eliminates MinGW-w64 complexity completely
- **Official Libraries**: Uses Google's pre-built Visual Studio libraries
- **Version Control**: Managed via justfile commands, not git bloat
- **Team Friendly**: Simple setup with `just firebase-fetch-libraries`
- **CI/CD Ready**: Automated fetching in build pipelines
- **Platform Coverage**: Single source for all platforms (Windows, Android, iOS, Linux, macOS)
- **Quick Setup**: No build time, just download and integrate

**Cons:**
- **Internet Required**: Need download during setup/build
- **Fixed Versions**: Limited to official pre-built library variants
- **Binary Size**: Includes all Firebase modules even if unused

**Decision:** Pre-built libraries approach is optimal because it eliminates cross-complication complexity while providing a unified, maintainable system for all platforms. Git provides version control and rollback capability, eliminating the need for complex version management in the justfile.

## Risks & Considerations

1. **Internet Dependency**
   - Build process requires downloading Firebase libraries
   - **Mitigation**: Libraries cached after first download; justfile checks for existing files; git provides offline capability after initial download

2. **Desktop Beta Status**
   - Firebase explicitly states desktop support is beta and for development only
   - **Mitigation**: Document this limitation; use for testing only, not production Windows releases

3. **Library Path Changes**
   - Firebase SDK structure could change in future versions
   - **Mitigation**: Robust error handling with existence checks; clear error messages guide users to run fetch command

4. **Library Size**
   - Firebase C++ SDK adds significant size to Windows templates
   - **Mitigation**: Accept size increase; pre-built approach eliminates build overhead; selective module fetching available

5. **Build System Integration**
   - Need to ensure just commands integrate with existing SCons build system
   - **Mitigation**: Follow existing Sentry integration patterns; add library validation to existing build commands

6. **Configuration Management**
   - Windows desktop requires proper `desktop_config.json` setup
   - **Mitigation**: Automated config generation from existing `google-services.json`; validation during build process

## Success Criteria

- [ ] Firebase submodule removed and replaced with pre-built library system
- [ ] `just firebase-fetch-libraries` successfully downloads all platform libraries (Windows, Android, iOS, Linux, macOS)
- [ ] `just firebase-status` shows available libraries for all platforms
- [ ] `just firebase-version-check` validates current version vs latest available
- [ ] `just firebase-fetch-modules database auth` downloads selective modules (size optimization)
- [ ] `just firebase-setup-desktop-config` generates Windows desktop configuration
- [ ] Windows Godot templates build successfully with Firebase module enabled
- [ ] `just build-windows-templates` completes without errors (with automatic Firebase fetch)
- [ ] `just test-firebase-windows` validates Firebase functionality using existing test framework
- [ ] `ClassDB.class_exists("FirebaseDatabase")` returns `true` on Windows builds
- [ ] Firebase initialization succeeds on Windows desktop export
- [ ] Realtime Database operations (read/write) work on Windows
- [ ] Firebase libraries are properly included in Windows exports (static linking)
- [ ] Windows desktop configuration (`desktop_config.json`) is included in exports
- [ ] Existing Android/iOS Firebase functionality remains unaffected
- [ ] Justfile Firebase commands follow project naming conventions (kebab-case)
- [ ] No external script dependencies - all functionality in justfile
- [ ] Firebase libraries properly excluded from git (.gitignore)
- [ ] Robust error handling prevents build failures when libraries missing
- [ ] At least one test configuration validates Firebase on Windows

## References

- **Firebase C++ SDK Pre-built Libraries**: https://dl.google.com/firebase/sdk/cpp/firebase_cpp_sdk_13.2.0.zip
- **Firebase C++ SDK Setup**: https://firebase.google.com/docs/cpp/setup
- **Firebase C++ SDK Release Notes**: https://firebase.google.com/support/release-notes/cpp-relnotes
- **Firebase C++ SDK GitHub**: https://github.com/firebase/firebase-cpp-sdk/releases
- **Project Justfile Conventions**: Existing justfile commands in repository
- **Project Windows Platform Support**: `justfiles/justfile-platform-windows.justfile`
- **Firebase Module Location**: `godot/modules/firebase/`
- **Firebase Libraries Location**: `firebase/firebase_cpp_sdk/`

## Related Tasks

- None currently (first Windows Firebase integration task)

## Notes

- **All-at-once Strategy**: Single command `firebase-fetch-libraries` downloads everything for all platforms (Windows, Android, iOS, Linux, macOS)
- **Selective Module Support**: `firebase-fetch-modules database auth` allows downloading only required Firebase modules
- **Enhanced Commands**: Additional commands for version checking, desktop config setup, and selective fetching
- **No Platform-Specific Commands**: Since we fetch everything at once, no need for `firebase-fetch-windows`, `firebase-fetch-android`, etc.
- **No Build Commands**: Integration happens through existing build commands (e.g., `build-windows-templates`) that check for Firebase libraries
- **No Aliases**: Follow just naming conventions strictly, avoid convenience aliases
- **No External Scripts**: All functionality embedded directly in justfile
- **Automatic Integration**: Build commands automatically trigger `firebase-fetch-libraries` if libraries missing
- **Robust Error Handling**: Build continues without Firebase if libraries missing, with clear error messages
- **Git Version Control**: Git handles version rollback and history, eliminating need for complex version management
- **Desktop Configuration**: Windows requires `desktop_config.json` generated from existing Firebase config files
- **Development Focus**: Windows build is for development/testing workflow validation only
- **Production Scope**: Production releases remain Android/iOS focused
