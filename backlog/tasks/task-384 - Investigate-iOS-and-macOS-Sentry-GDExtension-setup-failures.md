---
id: task-384
title: Investigate iOS and macOS Sentry GDExtension setup failures
status: To Do
assignee: []
created_date: '2025-12-26 10:39'
labels:
  - sentry
  - ios
  - macos
  - gdextension
  - build
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

Sentry GDExtension validation is failing on iOS and macOS platforms during automated testing.

## Evidence (2025-12-26)

From `just test-all sentry-all` run:

```
sentry-addon-validation:
├── android: ✅ PASSED
├── ios: ❌ FAILED  
├── macos: ❌ FAILED
├── windows-physical: ✅ PASSED

Error message:
❌ Sentry GDExtension validation FAILED
```

The `sentry.validate_gdextension_loading` action is failing, indicating the Sentry GDExtension is not properly loaded on these platforms.

## What Works

- **Android**: Full Sentry integration via AAR plugin with auto-initialization
- **Windows Physical**: GDExtension loads correctly

## What's Failing

- **iOS**: GDExtension validation fails - native libraries may not be bundled correctly
- **macOS**: GDExtension validation fails - framework may not be included in export

## Investigation Areas

### iOS
1. Check if `libsentry.ios.debug.xcframework` / `libsentry.ios.release.xcframework` are included in export
2. Verify XCFramework is properly signed
3. Check `project/addons/sentry/sentry.gdextension` iOS library paths
4. Review `just build-sentry-gdscript-ios` output

### macOS
1. Check if `libsentry.macos.debug.framework` / `libsentry.macos.release.framework` are included
2. Verify `Sentry.framework` dependency is bundled
3. Check Gatekeeper/notarization issues
4. Review `just build-sentry-gdscript-desktop` output

## Related Files

- `project/addons/sentry/sentry.gdextension` - GDExtension configuration
- `project/debug/actions/sentry/sentry_addon_validation_action.gd` - Validation action
- `justfiles/justfile-gdscript-sentry.justfile` - Build recipes
- `extras/sentry-godot/` - Sentry GDExtension submodule

## Conversation Reference

Session ID: 2025-12-26 Sentry test coverage analysis
Key findings from this session:
- Unified Sentry integration test across all platforms
- Removed editor from Sentry test platforms (Sentry not available in editor)
- iOS and macOS have GDExtension loading issues
- Android and Windows work correctly
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 sentry.validate_gdextension_loading passes on iOS
- [ ] #2 sentry.validate_gdextension_loading passes on macOS
- [ ] #3 just test-all sentry-all passes on all platforms
- [ ] #4 Root cause documented
<!-- AC:END -->
