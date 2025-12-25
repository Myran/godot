---
id: doc-003
title: Platform Parity Matrix
type: other
created_date: '2025-12-24 00:03'
---
# Platform Parity Matrix

**Status**: Active Tracking Document
**Last Updated**: 2025-12-25
**Purpose**: Track testing and debugging capability parity across all platforms

## Platform Overview

| Platform | Code Name | Device Type | Status |
|----------|-----------|-------------|--------|
| Android | `android` | Physical devices | ✅ Complete |
| Desktop (Editor) | `editor` / `desktop` | Godot Editor | ✅ Complete |
| iOS | `ios` | iPad/iPhone devices | ✅ Complete |
| macOS | `macos` | Exported .app bundle | ✅ Complete |
| Windows (VM) | `windows` | VM via SSH | ✅ Complete |
| Windows-Physical | `windows-physical` | Physical machine | 🟡 Partial |

## Capability Matrix

| Capability | Android | Editor | iOS | macOS | Windows | Win-Physical |
|------------|---------|--------|-----|-------|---------|--------------|
| **Automated Testing** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Manual Testing** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Checksum Update** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Checksum Reset** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Error Analysis** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Device Monitoring** | ✅ | N/A | ✅ | N/A | N/A | ❌ |
| **Fast Build** | ✅ | N/A | ❌ | ❌ | ❌ | N/A |
| **Log Retrieval** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Run/Launch** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **fzf Selector** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |

### Legend
- ✅ **Implemented** - Feature available and working
- ⚠️ **Partial** - Feature exists but incomplete
- ❌ **Missing** - Feature not implemented
- N/A **Not Applicable** - Platform doesn't support this capability

## Standard Recipe Patterns

### Testing Recipes

All platforms should follow this pattern:

| Pattern | Purpose | Android | Editor | iOS | macOS | Windows | Win-Physical |
|---------|---------|---------|--------|-----|-------|---------|--------------|
| `test-{platform}` | fzf selector for manual config | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| `test-{platform}-target CONFIG` | Automated testing with validation | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `test-{platform}-manual CONFIG` | Manual mode (stays open) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `test-{platform}-update CONFIG` | Update checksum baseline | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| `test-{platform}-reset CONFIG` | Reset checksum baseline | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |

**Note**: `editor` is sometimes aliased as `desktop`. Both names work for all recipes.

### Log Analysis Recipes

| Pattern | Purpose |
|---------|---------|
| `logs-{platform} TEST_ID [TAGS]` | Platform-specific log retrieval |
| `logs-{platform}-errors TEST_ID [TAGS]` | Platform-specific error analysis |
| `logs-errors TEST_ID [PLATFORM]` | Cross-platform error analysis |
| `logs-search TEST_ID "TERM" [PLATFORM]` | Cross-platform text search |
| `logs-pattern TEST_ID "PATTERN" [PLATFORM]` | Wildcard pattern matching |

### Platform-Specific Notes

**Android:**
- Most complete implementation
- `run-android` (1-2 sec, no install) vs `launch-android` (install first)
- `fastbuild-android` for rapid iteration
- Device monitoring: `logs-android-health`, `logs-android-status`, `logs-android-device`

**iOS:**
- ✅ Checksum management complete: `test-ios-update`, `test-ios-reset`
- ✅ Manual mode: `test-ios-manual` (use with `test-ios-iphone-manual` or `test-ios-ipad-manual`)
- ✅ Device monitoring: `logs-ios-health`, `logs-ios-status`, `logs-ios-device`
- Unified log naming: `logs-ios-*` commands (Task-366)
- Auto-detects iPhone vs iPad for diagnostic commands

**macOS:**
- Tests exported .app bundle (not editor)
- Complete parity with desktop for testing
- Build recipe: `build-all-macos` for consistency

**Windows (VM):**
- Remote execution via SSH/SCP
- Separate from Windows-Physical
- Run recipe: `run-windows` (wake + deploy + launch)

**Windows-Physical:**
- GUI mode only (no headless testing)
- Missing checksum update/reset (different architecture)

## Parity Scores

**Calculation**: (Implemented Features) / (Total Applicable Features) × 100

| Platform | Score | Notes |
|----------|-------|-------|
| Android | 100% | Baseline for all features |
| Editor | 100% | ✅ Full feature parity (test-editor-reset added) |
| iOS | 95% | ✅ Checksum management, manual mode, device monitoring complete |
| macOS | 100% | Full feature parity |
| Windows | 100% | Full feature parity |
| Win-Physical | 75% | Missing checksum management (GUI-only architecture) |

## Outstanding Tasks

Reference to platform parity tasks (361-379):

| Wave | Focus | Tasks | Status |
|------|-------|-------|--------|
| 0 | Foundation | task-376, task-374 | Done |
| 1 | Consolidate | task-375 | Done |
| 2 | Pure Additions | task-361, 364, 370, 373 | ✅ Done |
| 3 | iOS Parity | task-379, 362, 369, 371 | ✅ Done |
| 4 | Windows Parity | task-363 | Done |
| 5 | Direct Renames | task-366, 365, 378, 367 | ✅ Done |
| 6 | Optional | task-368, 377, 372 | Done |

## Completion Summary (2025-12-25)

**Platform Parity Achievement**: 5 of 6 platforms now have complete feature parity.

### Implemented Features (Tasks 361-379)

| Task | Feature | Status |
|------|---------|--------|
| 361 | `test-editor-reset` | ✅ Checksum baseline reset for editor |
| 362 | `test-ios-manual` | ✅ Manual inspection mode for iOS |
| 364 | `test-macos`, `test-windows` | ✅ fzf selector recipes added |
| 365 | `build-all-ios` rename | ✅ Consistent naming with other platforms |
| 366 | iOS log command renaming | ✅ Unified `logs-ios-*` naming pattern |
| 369 | `logs-ios-health/status/device` | ✅ iOS diagnostic commands |
| 370 | `build-all-macos` | ✅ Consistent build recipe |
| 371 | iOS export commands | ✅ `export-ios-debug/release/all` |
| 373 | `run-windows` | ✅ Quick Windows launch (wake + deploy + launch) |
| 375 | Android log naming | ✅ Documented `logs-android-*` vs `android-logs-*` distinction |
| 376 | Platform parity tracking | ✅ This document created |
| 379 | `test-ios-update/reset` | ✅ iOS checksum baseline management |

### Remaining Gaps

| Platform | Missing Feature | Priority |
|----------|-----------------|----------|
| Windows-Physical | Checksum update/reset | Low (GUI-only architecture) |
| All platforms | Fast build (iOS/macOS/Windows) | Low (Android-only optimization) |

## Validation Commands

To verify current state:

```bash
# Test recipes
just --list | grep "test-"
just --list | grep "test-android"
just --list | grep "test-ios"
just --list | grep "test-macos"
just --list | grep "test-windows"

# Log recipes
just --list | grep "logs-"

# Platform-specific
just --list | grep "win-"
just --list | grep "android-"
just --list | grep "ios-"
```

---

**Related Documents**:
- `justfiles/ARCHITECTURE.md` - Complete justfile architecture
- `CLAUDE.md` - Daily development reference
- Task 361-379 - Platform parity implementation tasks
