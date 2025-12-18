---
id: task-260
title: Add Swappy Frame Pacing to Godot Android Build for Performance Optimization
status: Done
assignee: []
created_date: '2025-11-06 12:01'
updated_date: '2025-12-18 10:37'
labels:
  - android
  - performance
  - critical
  - build-optimization
dependencies: []
ordinal: 64000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add Google Swappy Frame Pacing library to Godot Android build to eliminate stutter and achieve consistent 30/60/90/120 FPS on Android devices. This is **critical for game performance** as without Swappy, Godot apps will inevitably suffer stutter even on the best phones and the most simple scenes.

## Current Issue

During `just build-android-templates`, Godot displays the following warning:

```
WARNING: Swappy Frame Pacing not detected! It is strongly recommended you download it from https://github.com/godotengine/godot-swappy/releases and extract it so that the following files can be found:
 thirdparty/swappy-frame-pacing/arm64-v8a/libswappy_static.a
 thirdparty/swappy-frame-pacing/armeabi-v7a/libswappy_static.a
 thirdparty/swappy-frame-pacing/x86/libswappy_static.a
 thirdparty/swappy-frame-pacing/x86_64/libswappy_static.a
Without Swappy, Godot apps on Android will inevitable suffer stutter and struggle to keep consistent 30/60/90/120 fps. Though Swappy cannot guarantee your app will be stutter-free, not having Swappy will guarantee there will be stutter even on the best phones and the most simple of scenes.
```

## Required Actions

### **Step 1: Download Swappy Frame Pacing**
- **Source**: https://github.com/godotengine/godot-swappy/releases
- **Required Files**: All architecture-specific static libraries (.a files)
- **Target Directory**: `godot/thirdparty/swappy-frame-pacing/`

### **Step 2: Extract Required Libraries**
Download and extract Swappy so that the following files are found:
```
godot/thirdparty/swappy-frame-pacing/arm64-v8a/libswappy_static.a
godot/thirdparty/swappy-frame-pacing/armeabi-v7a/libswappy_static.a
godot/thirdparty/swappy-frame-pacing/x86/libswappy_static.a
godot/thirdparty/swappy-frame-pacing/x86_64/libswappy_static.a
```

### **Step 3: Verify Integration**
- Run `just build-android-templates` to confirm no Swappy warnings
- Ensure Swappy is detected and integrated into Android build
- Test performance improvements on actual Android devices
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
### **Option 1: Manual Download (Recommended)**
1. Visit https://github.com/godotengine/godot-swappy/releases
2. Download the latest release (compatible with Godot 4.3)
3. Extract to `godot/thirdparty/swappy-frame-pacing/`
4. Verify file structure matches required paths

### **Option 2: Automated Download via Just Recipe**
Create a just recipe to automate Swappy download and integration:
```bash
install-swappy:
    # Download latest Swappy release
    # Extract to correct directory structure
    # Verify all required .a files are present
    # Test integration with build-android-templates
```

### **Option 3: Git Submodule Integration**
Add Swappy as a Git submodule for version control:
```bash
# Add Swappy as submodule
git submodule add https://github.com/godotengine/godot-swappy.git godot/thirdparty/swappy-frame-pacing
```

## Success Criteria

- [ ] Swappy Frame Pacing library downloaded and integrated
- [ ] All four required static libraries present:
  - `arm64-v8a/libswappy_static.a`
  - `armeabi-v7a/libswappy_static.a`
  - `x86/libswappy_static.a`
  - `x86_64/libswappy_static.a`
- [ ] Build process runs without Swappy warnings
- [ ] Android games show improved frame consistency
- [ ] Performance testing shows reduced stutter

## Performance Impact

### **Without Swappy (Current State)**
- Inevitable stutter on Android devices
- Inconsistent frame rates (30/60/90/120 FPS)
- Poor user experience on basic scenes
- Negative impact on game quality perception

### **With Swappy (Target State)**
- Smooth frame pacing and timing
- Consistent target frame rates
- Improved user experience
- Professional-quality Android performance
- Better competitive viability for GameTwo

## Dependencies

- Godot 4.3 Android build system
- Internet access for Swappy download
- File extraction tools (unzip/tar)
- SCons build system compatibility

## Risk Assessment

### **Low Risk Items**
- Swappy is official Google library
- Well-documented integration process
- No breaking changes to existing code
- Proven solution used by many Godot games

### **Medium Risk Items**
- Version compatibility with Godot 4.3
- Architecture-specific file management
- Build system integration complexity

### **High Risk Items**
- None identified (Swappy is low-risk addition)

## Testing Strategy

1. **Build Validation**: Confirm no Swappy warnings in build output
2. **Performance Testing**: Test frame consistency on target devices
3. **Compatibility Testing**: Verify across different Android devices
4. **Regression Testing**: Ensure no impact on existing functionality

## Timeline Estimate

- **Download & Setup**: 30 minutes
- **Integration & Testing**: 1-2 hours
- **Performance Validation**: 2-3 hours on actual devices
- **Total**: 3-6 hours for complete integration

## Related Tasks

- **task-259**: Sentry Android SDK integration (also uses build-android-templates)
- **task-258**: Android build system investigation
- Android performance optimization initiatives
<!-- SECTION:PLAN:END -->
