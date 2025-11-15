---
id: task-280
title: Rename Sentry Build Recipes for Clear and Consistent Naming Convention
status: Done
assignee: []
created_date: '2025-11-15 10:00'
updated_date: '2025-11-15 10:22'
labels: []
dependencies: []
---

## Description

Rename all Sentry build recipes to follow a clear, consistent naming convention that reflects:
- **Type**: `native` (C++ GDExtension) vs `gdscript` (Pure GDScript + downloaded binaries)
- **Platform**: `ios`, `android`, `windows`, `macos`, `desktop` (collective term for macOS+Linux+Windows)
- **Build Type**: `development` vs `release` for native builds
- **Architecture**: `x86_64`, `arm64` where applicable

**Current naming issues:**
- "editor" → should be "development" (not Godot Editor, but development builds)
- "template" → should be "release" (production builds)
- Inconsistent patterns across platforms
- Unclear what crash types each recipe covers

## Proposed Naming Convention

```
build-{native|gdscript}-{platform|desktop}-{build_type|architecture}
```

### Native Builds (C++ GDExtension)
- `build-native-ios-development` (current: sentry-native-ios-editor)
- `build-native-ios-release` (current: sentry-native-ios-template)
- `build-native-windows-x86_64` (current: sentry-windows-build-x86_64)

### GDScript Builds (Pure GDScript + downloaded binaries)
- `build-gdscript-desktop` (current: sentry-gdscript-build-desktop - covers macOS+Linux+Windows)
- `build-gdscript-android` (current: sentry-gdscript-build-android)
- `build-gdscript-ios` (current: sentry-gdscript-build-ios)

### Meta Commands
- `build-native-all` (all native platforms)
- `build-gdscript-all` (all GDScript platforms)
- `build-sentry-all` (complete build pipeline - already exists and correct)

## Acceptance Criteria

1. **All recipes renamed** to follow consistent `build-{type}-{platform}-{variant}` pattern
2. **Help documentation updated** to reflect new names
3. **All recipe references updated** (build-sentry-all, help commands, etc.)
4. **Force parameter functionality preserved** for all renamed recipes
5. **Build pipeline validation passes** with new names
6. **No broken references** left in any justfile

## Implementation Plan

### Phase 1: Inventory and Mapping
- [ ] Document all current recipe names and their new equivalents
- [ ] Identify all cross-references between recipes
- [ ] List all help text that needs updating

### Phase 2: Rename Native Build Recipes
- [ ] Rename `sentry-native-ios-editor` → `build-native-ios-development`
- [ ] Rename `sentry-native-ios-template` → `build-native-ios-release`
- [ ] Rename `sentry-windows-build-x86_64` → `build-native-windows-x86_64`
- [ ] Update all references in help commands and build pipelines

### Phase 3: Rename GDScript Build Recipes
- [ ] Rename `sentry-gdscript-build-desktop` → `build-gdscript-desktop`
- [ ] Rename `sentry-gdscript-build-android` → `build-gdscript-android`
- [ ] Rename `sentry-gdscript-build-ios` → `build-gdscript-ios`
- [ ] Rename `sentry-gdscript-build` → `build-gdscript-all`
- [ ] Update all references and dependencies

### Phase 4: Update Help and Documentation
- [ ] Update help command outputs to reflect new names
- [ ] Update recipe descriptions and comments
- [ ] Verify all `just help` commands show correct new names

### Phase 5: Validation and Testing
- [ ] Test all renamed recipes with force parameter
- [ ] Run `build-sentry-all` to verify pipeline integrity
- [ ] Validate all help commands work correctly
- [ ] Test force=yes functionality on all recipes
- [ ] Confirm no broken references remain

### Phase 6: Cleanup
- [ ] Remove any obsolete references or comments
- [ ] Ensure consistent naming throughout all justfiles
- [ ] Final validation of complete build system

## Success Metrics

- **Consistency**: All recipes follow same naming pattern
- **Clarity**: Recipe names immediately indicate purpose and scope
- **Functionality**: All force parameters and build features work correctly
- **Documentation**: Help commands accurately reflect new naming
- **Integration**: Complete build pipeline works without issues

## Related Files

- `justfiles/justfile-sentry.justfile` (main integration)
- `justfiles/justfile-native-ios-sentry.justfile`
- `justfiles/justfile-native-windows-sentry.justfile`
- `justfiles/justfile-gdscript-sentry.justfile`
- `justfiles/justfile-build-system.justfile` (references)
- `CLAUDE.md` (documentation updates)

## Testing Commands for Validation

```bash
# Test native builds
just build-native-ios-development
just build-native-ios-release
just build-native-windows-x86_64 force=yes

# Test GDScript builds
just build-gdscript-desktop
just build-gdscript-android
just build-gdscript-ios
just build-gdscript-all force=yes

# Test complete pipeline
just build-sentry-all

# Test help commands
just help-sentry
just help-sentry-native-ios
just help-sentry-windows
just help-sentry-gdscript
```
