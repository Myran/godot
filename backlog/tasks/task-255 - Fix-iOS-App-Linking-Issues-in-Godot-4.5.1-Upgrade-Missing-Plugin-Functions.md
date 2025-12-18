---
id: task-255
title: Fix iOS App Linking Issues in Godot 4.5.1 Upgrade - Missing Plugin Functions
status: Done
assignee: []
created_date: '2025-10-30 16:29'
updated_date: '2025-12-18 10:37'
labels:
  - ios
  - godot-upgrade
  - critical
  - linking
  - apple-embedded
dependencies: []
ordinal: 68000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
iOS app builds successfully at template stage but fails at final app linking with missing Apple embedded plugin symbols. This is a critical blocker for iOS deployment in the Godot 4.5.1 upgrade.

**Specific Errors:**
1. **SwiftUICore Framework Warning:**
```
ld: warning: Could not parse or use implicit file '/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks/SwiftUICore.framework/SwiftUICore.tbd': cannot link directly with 'SwiftUICore' because product being built is not an allowed client of it
```

2. **Missing Apple Embedded Plugin Symbols:**
```
Undefined symbols for architecture arm64:
  "godot_apple_embedded_plugins_initialize()", referenced from:
      register_ios_api() in libgodot.a[1063](api.ios.template_release.arm64.o)
  "godot_apple_embedded_plugins_deinitialize()", referenced from:
      unregister_ios_api() in libgodot.a[1063](api.ios.template_release.arm64.o)
ld: symbol(s) not found for architecture arm64
```

**Root Cause Analysis:**
- Functions `godot_apple_embedded_plugins_initialize()` and `godot_apple_embedded_plugins_deinitialize()` are declared in `godot/platform/ios/api/api.h`
- They're called from `godot/platform/ios/api/api.cpp` in `register_ios_api()` and `unregister_ios_api()`
- These functions should be **auto-generated during export** by the plugin system (found in `godot/editor/export/editor_export_platform_apple_embedded.cpp`)
- The plugin system generates these functions based on enabled plugins in the export configuration
- **Something changed in Godot 4.5** that broke this generation or linking process

**Expected Behavior:**
The export system should generate a `.cpp` file containing the plugin initialization/deinitialization functions and compile it into the iOS app.

**Current State:**
Functions are declared and called but never defined/compiled, causing linker errors.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 iOS app builds and links successfully without missing symbol errors
- [ ] #2 Export system generates required plugin initialization functions automatically
- [ ] #3 Plugin system investigation identifies root cause in Godot 4.5 changes
- [ ] #4 Fix preserves existing plugin functionality
- [ ] #5 iOS app runs successfully on device/simulator after fix
- [ ] #6 SwiftUICore framework warnings are resolved
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
### Phase 1: Investigation and Root Cause Analysis
1. **Examine Godot 4.5 Changes**
   - Research changes in Apple embedded plugin system between 4.3 and 4.5
   - Check Git history for `editor_export_platform_apple_embedded.cpp`
   - Compare plugin generation logic between versions

2. **Current System Analysis**
   - Examine `godot/platform/ios/api/api.h` and `api.cpp` to understand function declarations and calls
   - Study `godot/editor/export/editor_export_platform_apple_embedded.cpp` to understand generation process
   - Identify where plugin configuration is read and how functions should be generated

3. **Export Configuration Review**
   - Check current export preset configuration for iOS
   - Verify which plugins are enabled and their configuration
   - Examine if plugin system properly detects enabled plugins

### Phase 2: Solution Investigation
1. **Export Config Fix Approach**
   - Test different plugin configurations in export preset
   - Verify if specific plugin combinations trigger proper generation
   - Check if export template generation needs adjustment

2. **Plugin System Debugging**
   - Add logging to plugin generation process to trace what's happening
   - Verify if generation code is being called during export
   - Check if generated files are being created but not compiled

3. **Manual Workaround Investigation**
   - Research if manual implementation of these functions is viable
   - Determine minimal implementation needed to satisfy linker
   - Assess if this approach is sustainable long-term

### Phase 3: Implementation and Testing
1. **Apply Chosen Solution**
   - Implement fix based on investigation findings
   - Ensure solution is compatible with Godot 4.5.1 architecture
   - Test that fix doesn't break other platforms

2. **Comprehensive Testing**
   - Build iOS app with fix applied
   - Verify all linking errors are resolved
   - Test app functionality on device/simulator
   - Validate existing plugins still work correctly

3. **Documentation and Validation**
   - Document the root cause and solution
   - Update any relevant build/configuration documentation
   - Ensure fix is reproducible and maintainable
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
This task requires deep understanding of Godot's export system and Apple embedded plugin architecture. The issue appears to be a regression in Godot 4.5 where the auto-generation of plugin initialization functions is not working properly.

The fix must ensure that:
- Plugin initialization functions are properly generated during export
- Generated functions are compiled and linked into the final iOS app
- Existing plugin functionality is preserved
- The solution is compatible with the upgraded Godot 4.5.1 architecture

Priority: Critical - This completely blocks iOS deployment and must be resolved before the Godot 4.5.1 upgrade can be considered complete.
<!-- SECTION:NOTES:END -->
