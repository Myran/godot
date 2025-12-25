# Platform Parity Matrix

**Status**: Active Tracking Document
**Last Updated**: 2024-12-24
**Purpose**: Track testing and debugging capability parity across all platforms

## Platform Overview

| Platform | Code Name | Device Type | Status |
|----------|-----------|-------------|--------|
| Android | `android` | Physical devices | ✅ Complete |
| Desktop (Editor) | `editor` / `desktop` | Godot Editor | ✅ Complete |
| iOS | `ios` | iPad/iPhone devices | 🟡 Partial |
| macOS | `macos` | Exported .app bundle | ✅ Complete |
| Windows (VM) | `windows` | VM via SSH | ✅ Complete |
| Windows-Physical | `windows-physical` | Physical machine | 🟡 Partial |

## Capability Matrix

| Capability | Android | Editor | iOS | macOS | Windows | Win-Physical |
|------------|---------|--------|-----|-------|---------|--------------|
| **Automated Testing** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Manual Testing** | ✅ | ✅ | ⚠️ | ✅ | ✅ | ✅ |
| **Checksum Update** | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ |
| **Checksum Reset** | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ |
| **Error Analysis** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Device Monitoring** | ✅ | N/A | ⚠️ | N/A | N/A | ❌ |
| **Fast Build** | ✅ | N/A | ❌ | ❌ | ❌ | N/A |
| **Log Retrieval** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Run/Launch** | ✅ | ✅ | ✅ | ✅ | ✅ | N/A |

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
| `test-{platform}` | fzf selector for manual config | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `test-{platform}-target CONFIG` | Automated testing with validation | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `test-{platform}-manual CONFIG` | Manual mode (stays open) | ✅ | ✅ | ⚠️ | ✅ | ✅ | ✅ |
| `test-{platform}-update CONFIG` | Update checksum baseline | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ |
| `test-{platform}-reset CONFIG` | Reset checksum baseline | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ |

**Note**: `editor` is sometimes aliased as `desktop`. This is being consolidated to `desktop` (task-375).

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

**iOS:**
- Missing `test-ios-update` / `test-ios-reset` (checksum management)
- `test-ios-manual` not fully implemented
- Device monitoring partial (needs consolidation)

**macOS:**
- Tests exported .app bundle (not editor)
- Complete parity with desktop for testing

**Windows (VM):**
- Remote execution via SSH/SCP
- Separate from Windows-Physical

**Windows-Physical:**
- GUI mode only (no headless testing)
- Missing checksum update/reset

## Parity Scores

**Calculation**: (Implemented Features) / (Total Applicable Features) × 100

| Platform | Score | Notes |
|----------|-------|-------|
| Android | 100% | Baseline for all features |
| Editor | 88% | Missing checksum reset |
| iOS | 62% | Missing checksum management, incomplete manual mode |
| macOS | 100% | Full feature parity |
| Windows | 100% | Full feature parity |
| Win-Physical | 75% | Missing checksum management |

## Outstanding Tasks

Reference to platform parity tasks (361-379):

| Wave | Focus | Tasks | Status |
|------|-------|-------|--------|
| 0 | Foundation | task-376, task-374 | In Progress |
| 1 | Consolidate | task-375 | Pending |
| 2 | Pure Additions | task-361, 364, 370, 373 | Pending |
| 3 | iOS Parity | task-379, 362, 369, 371 | Pending |
| 4 | Windows Parity | task-363 | Pending |
| 5 | Direct Renames | task-366, 365, 378, 367 | Pending |
| 6 | Optional | task-368, 377, 372 | Pending |

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
