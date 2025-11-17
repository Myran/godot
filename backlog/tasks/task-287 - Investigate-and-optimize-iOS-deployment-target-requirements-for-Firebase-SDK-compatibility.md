---
id: task-287
title: >-
  Investigate and optimize iOS deployment target requirements for Firebase SDK
  compatibility
status: To Do
assignee: []
created_date: '2025-11-16 22:20'
labels: []
dependencies: []
---

## Description

Investigate why iOS deployment target is set to 16.6 and optimize for broader device compatibility. Current requirement prevents testing on iPad running iOS 15.6.1.

**Current Issue:**
- iOS deployment target: 16.6 (too restrictive)
- iPad test device: iOS 15.6.1 (incompatible)
- Recommended by Xcode: 15.0 (much more reasonable)
- Firebase SDKs likely causing high requirement

## Investigation Tasks

### 1. Dependency Analysis
- Identify which Firebase SDK requires iOS 16.6+
- Check each Firebase pod's minimum iOS version requirements
- Determine if all features require high iOS version or if lower version SDKs available

### 2. Build System Investigation
- Check Godot export preset settings for iOS deployment target
- Verify if Xcode project template (templates/ios.zip) has hardcoded requirements
- Investigate if build system automatically sets highest dependency requirement

### 3. Compatibility Testing
- Test with reduced deployment target (15.0)
- Identify which Firebase features break at lower iOS versions
- Determine minimal iOS version that maintains all required functionality

### 4. Optimization Strategies
- Evaluate older Firebase SDK versions with lower iOS requirements
- Consider conditional Firebase feature loading based on iOS version
- Investigate alternative libraries or native implementations

## Success Criteria
- [ ] iOS deployment target reduced to 15.0 or lower
- [ ] All Firebase core features work on iPad iOS 15.6.1
- [ ] Sentry crash reporting works on reduced deployment target
- [ ] Build system maintains compatibility across iOS versions
- [ ] Documentation updated with minimum iOS requirements

## Technical Notes
- Current Xcode project file: `export/ios/gametwo.xcodeproj/project.pbxproj`
- Firebase Podfile: `export/ios/Podfile`
- Godot export preset: `project/export_presets.cfg`
- Template source: `templates/ios.zip` (if exists)
