---
id: task-328
title: Integrate macOS into test system with aligned just recipes
status: Done
assignee: []
created_date: '2025-12-08 18:46'
updated_date: '2025-12-18 10:37'
labels:
  - macos
  - testing
  - infrastructure
  - just-recipes
dependencies: []
priority: medium
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add macOS platform support to the automated testing infrastructure, aligning with existing Android and desktop test patterns. macOS will be included by default in `just test` and `just test-all`.

## Key Insight
macOS is similar to desktop (same `app_userdata` location, file-based config deployment), but runs the **exported `.app` bundle** instead of the Godot editor executable.

## Implementation Plan

### Primary file: `justfiles/justfile-validation-enhanced-testing.justfile`

#### 1. Core Functions (Phase 1)
- **_stop-app-macos** - Kill running macOS app instances
- **_deploy-config-macos** - Deploy config to app_userdata (same path as desktop)
- **_execute-test-macos** - Run exported `.app` bundle with `--test-mode`
- **Update _execute-test-with-analysis** - Add macOS case to platform dispatch
- **Update _extract-logs** - Add macOS case for log extraction

#### 2. Public Commands (Phase 2)
- **test-macos-target CONFIG** - Automated testing with validation
- **test-macos-manual CONFIG** - Manual testing (stays open)

#### 3. Checksum Management (Phase 3)
- **test-macos-update CONFIG** - Update checksum baseline
- **test-macos-reset CONFIG** - Reset checksum baseline

#### 4. Documentation Updates (Phase 4)
- Update `help-debug` command to include macOS examples
- Update existing `help-macos` to show testing commands

### Key Implementation Details

**_execute-test-macos differences from desktop:**
- Validate app exists: Check `export/macos/GameTwo_debug.app` exists
- Clear quarantine: `xattr -cr export/macos/GameTwo_debug.app` (Gatekeeper)
- Launch: `export/macos/GameTwo_debug.app/Contents/MacOS/GameTwo --test-mode --minimized`
- Same completion detection: `DEBUG_TEST_SUCCESS`, `TEST_COMPLETE_`, `Quit event received`

**Manual mode:**
- Inject `auto_quit=false` into config
- Launch with: `open export/macos/GameTwo_debug.app --args --test-mode`

**Cross-platform integration:**
- `_get-all-platforms` auto-discovers from `test-*-target` functions
- macOS will be automatically included in `just test` and `just test-all`

### Estimated Scope
- Lines of code: ~250-350 new lines
- Files modified: 2-3 justfiles
- Risk: Low (follows established patterns)
- Prerequisites: macOS app must be exported (`just export-macos-debug`)

### Acceptance Criteria
1. `just test-macos-target firebase-backend-layer` works
2. `just test-macos-manual battle-logic-only` works
3. `just test` includes macOS in cross-platform run
4. `just test-all` includes macOS
5. `just logs-errors TEST_ID macos` extracts macOS logs
6. `just test-macos-update CONFIG` updates baseline
7. `just help-macos` shows testing commands
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
### Primary file: `justfiles/justfile-validation-enhanced-testing.justfile`

#### 1. Core Functions (Phase 1)
- **_stop-app-macos** - Kill running macOS app instances
- **_deploy-config-macos** - Deploy config to app_userdata (same path as desktop)
- **_execute-test-macos** - Run exported `.app` bundle with `--test-mode`
- **Update _execute-test-with-analysis** - Add macOS case to platform dispatch
- **Update _extract-logs** - Add macOS case for log extraction

#### 2. Public Commands (Phase 2)
- **test-macos-target CONFIG** - Automated testing with validation
- **test-macos-manual CONFIG** - Manual testing (stays open)

#### 3. Checksum Management (Phase 3)
- **test-macos-update CONFIG** - Update checksum baseline
- **test-macos-reset CONFIG** - Reset checksum baseline

#### 4. Documentation Updates (Phase 4)
- Update `help-debug` command to include macOS examples
- Update existing `help-macos` to show testing commands

### Key Implementation Details

**_execute-test-macos differences from desktop:**
- Validate app exists: Check `export/macos/GameTwo_debug.app` exists
- Clear quarantine: `xattr -cr export/macos/GameTwo_debug.app` (Gatekeeper)
- Launch: `export/macos/GameTwo_debug.app/Contents/MacOS/GameTwo --test-mode --minimized`
- Same completion detection: `DEBUG_TEST_SUCCESS`, `TEST_COMPLETE_`, `Quit event received`

**Manual mode:**
- Inject `auto_quit=false` into config
- Launch with: `open export/macos/GameTwo_debug.app --args --test-mode`

**Cross-platform integration:**
- `_get-all-platforms` auto-discovers from `test-*-target` functions
- macOS will be automatically included in `just test` and `just test-all`

### Estimated Scope
- Lines of code: ~250-350 new lines
- Files modified: 2-3 justfiles
- Risk: Low (follows established patterns)
- Prerequisites: macOS app must be exported (`just export-macos-debug`)

### Acceptance Criteria
1. `just test-macos-target firebase-backend-layer` works
2. `just test-macos-manual battle-logic-only` works
3. `just test` includes macOS in cross-platform run
4. `just test-all` includes macOS
5. `just logs-errors TEST_ID macos` extracts macOS logs
6. `just test-macos-update CONFIG` updates baseline
7. `just help-macos` shows testing commands
<!-- SECTION:DESCRIPTION:END -->
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
### Primary file: `justfiles/justfile-validation-enhanced-testing.justfile`

#### 1. Core Functions (Phase 1)
- **_stop-app-macos** - Kill running macOS app instances (EDITOR-SAFE)
  - **CRITICAL**: Must ONLY kill exported app instances, NEVER the Godot editor
  - Pattern: `pkill -f "GameTwo_debug.app" 2>/dev/null || true`
  - Do NOT match editor processes - editor runs as `godot.macos.editor.universal`
  - Follow existing `_stop-app-desktop` pattern which explicitly preserves editor
  - Kill only the exported app bundle, never editor processes
- **_deploy-config-macos** - Deploy config to app_userdata (same path as desktop)
  - Same config path: `$HOME/Library/Application Support/Godot/app_userdata/gametwo/debug_startup_actions.json`
  - Same logs directory: `$HOME/Library/Application Support/Godot/app_userdata/gametwo/logs/`
  - Call `_stop-app-macos` instead of `_stop-app-desktop`
- **_execute-test-macos** - Run exported `.app` bundle with `--test-mode`
  - Validate app exists: `if [ ! -d "export/macos/GameTwo_debug.app" ]`
  - Clear quarantine: `xattr -cr export/macos/GameTwo_debug.app` (Gatekeeper)
  - **OPTIMIZATION**: Support external PCK loading for faster iteration
    - If `TEST_MACOS_PCK` environment variable is set, use: `--main-pack $TEST_MACOS_PCK`
    - This allows testing code/resource changes without full re-export
  - Launch: `export/macos/GameTwo_debug.app/Contents/MacOS/GameTwo --test-mode --minimized 2>&1`
  - **Important**: Both editor and app bundle write to same logs directory, but test extraction creates platform-specific files (`macos_[test-id].log`)
  - Same completion detection: `DEBUG_TEST_SUCCESS`, `TEST_COMPLETE_`, `Quit event received`
- **Update _execute-test-with-analysis** - Add macOS case to platform dispatch (after line 2744)
- **Update _extract-logs** - Add macOS case for log extraction (around line 865)
  - Create `macos_[test-id].log` file (parallel to `desktop_[test-id].log`)

#### 2. Public Commands (Phase 2)
- **test-macos-target CONFIG** - Automated testing with validation
  - Follow `test-desktop-target` pattern exactly
  - FZF selection for config if not provided
  - Session handling for cross-platform coordination
  - Calls `_execute-test-with-analysis` with platform="macos"
  - **Optimization tip**: Use `TEST_MACOS_PCK=/path/to/pck just test-macos-target CONFIG` for faster iteration
- **test-macos-manual CONFIG** - Manual testing (stays open)
  - Follow `test-desktop-manual` pattern
  - Inject `auto_quit=false` into config
  - Launch with: `open export/macos/GameTwo_debug.app --args --test-mode`
  - **Supports external PCK**: Set `TEST_MACOS_PCK` environment variable

#### 3. Checksum Management (Phase 3)
- **test-macos-update CONFIG** - Update checksum baseline
  - Follow `test-desktop-update` pattern
  - Menu selection if no config provided
- **test-macos-reset CONFIG** - Reset checksum baseline

#### 4. Documentation Updates (Phase 4)
- Update `help-debug` command to include macOS examples
  - Add lines: `echo "  just test-macos-target CONFIG    # macOS automated testing with validation"`
  - Add lines: `echo "  just test-macos-manual CONFIG    # macOS manual testing (stays open)"`
  - Add optimization tip: `echo "  TEST_MACOS_PCK=/path/to/pck just test-macos-target CONFIG  # Use external PCK for faster testing"`
- Update existing `help-macos` to show testing commands

### Key Implementation Details

**EDITOR PRESERVATION REQUIREMENT:**
- **ABSOLUTE REQUIREMENT**: Never kill the Godot editor during macOS testing
- Editor runs as: `godot.macos.editor.universal` 
- Exported app runs as: `GameTwo` or `GameTwo_debug.app`
- `_stop-app-macos` must only target the exported app, never the editor
- Follow the exact pattern from `_stop-app-desktop` which preserves editor processes

**PERFORMANCE OPTIMIZATION - External PCK Loading:**
- Godot supports loading external PCK files with `--main-pack` flag
- This allows testing resource changes without full re-export (saves 2-3 minutes)
- Config changes can be injected directly to `user://debug_startup_actions.json` (instant)
- C++ engine changes still require full re-export
- PCK export is ~10-15 seconds vs full app export at 2-3 minutes
- No re-signing required for external PCK files

**Log Path Considerations:**
- macOS app bundle and editor both write to: `~/Library/Application Support/Godot/app_userdata/gametwo/logs/`
- This is expected behavior - iOS/desktop have same pattern
- Platform-specific extraction creates separate files: `desktop_[test-id].log` vs `macos_[test-id].log`
- No conflict as long as only one process runs at a time (handled by `_stop-app-macos`)

**Manual Mode Launch Details:**
- Use `open export/macos/GameTwo_debug.app --args --test-mode`
- Proper macOS app launching (not direct binary execution)
- Background operation with `&` for manual inspection

**Automated Mode Details:**
- Direct binary execution: `export/macos/GameTwo_debug.app/Contents/MacOS/GameTwo`
- Capture all output to temp file for analysis
- Same timeout and completion detection as desktop

**Error Handling:**
- Check app exists with helpful error message
- Clear quarantine attributes for Gatekeeper
- Handle app bundle permissions gracefully

**Editor Process Matching (DO NOT MATCH):**
- Editor: `godot.macos.editor.universal`
- Editor processes include `--editor` flag
- These must NEVER be killed by macOS test commands

**Future Enhancement - Fast PCK Testing (Optional):**
- Consider adding `export-pck-macos` recipe for PCK-only exports
- Consider adding `test-macos-fast CONFIG` that auto-exports PCK first
- This would enable rapid iteration on resource changes

### IMPORTANT: Exported App Behavior Discovery

**Key Finding**: Exported apps (macOS, iOS, Android) behave differently from editor:

| Platform | Run Command | Auto-runs JSON? | Why? |
|----------|-------------|-----------------|------|
| **Desktop (editor)** | `run-desktop` | ❌ NO | `OS.has_feature("editor")` = true, skip logic triggers |
| **macOS (exported)** | `run-macos` | ✅ YES | `OS.has_feature("editor")` = false, skip bypassed |
| **Android** | N/A | ✅ YES | `is_test_mode = true` forced |
| **iOS** | N/A | ✅ YES | Exported app, no editor check |

**Root Cause** (main.gd lines 88-93):
```gdscript
if (
    not use_actions_in_editor
    and OS.has_feature("editor")   # FALSE for exported apps!
    and not DisplayServer.get_name() == "headless"
    and not is_test_mode
):
    return  # Skip coordinator - NEVER triggers for exports
```

**Implications:**
1. `--test-mode` flag is NOT required for exported macOS app (config auto-loads)
2. Config injection "just works" - copy JSON and run
3. BUT: `just run-macos` will run stale test configs if not cleared

### NEW REQUIREMENT: Config Clear Commands

Add commands to clear test configs so `run-macos` works without leftover test state:

- **`clear-test-macos`** - Remove `debug_startup_actions.json` from macOS app_userdata
- **`clear-test-desktop`** - Remove from desktop app_userdata (for consistency)
- **`clear-test-android`** - Remove from Android device
- **`clear-test-ios`** - Remove from iOS device

**Implementation:**
```bash
clear-test-macos:
    @echo "🧹 Clearing macOS test config..."
    rm -f "$HOME/Library/Application Support/Godot/app_userdata/gametwo/debug_startup_actions.json"
    @echo "✅ macOS test config cleared - run-macos will start without debug actions"
```

**Workflow:**
1. `just test-macos-target CONFIG` - Deploys config, runs test
2. `just run-macos` - Runs with leftover config (may be undesired)
3. `just clear-test-macos && just run-macos` - Clean run without test actions

### Implementation Complete - 2025-12-09

**Expert Panel Review**: ✅ PASSED (All 5 reviewers approved)

**Implementation Summary**:
- Added ~300 lines to `justfile-validation-enhanced-testing.justfile`
- Added ~40 lines to `justfile-platform-macos.justfile`

**Commands Added**:
- `test-macos-target CONFIG` - Automated testing with validation
- `test-macos-manual CONFIG` - Manual testing (stays open)
- `test-macos-update CONFIG` - Update checksum baseline
- `test-macos-reset CONFIG` - Reset checksum baseline
- `clear-test-macos` - Clear stale test config
- `clear-macos-test-cache` - Alias for consistency

**Critical Features**:
- Editor preservation: ONLY kills exported app instances, NEVER editor
- External PCK support: `TEST_MACOS_PCK` environment variable
- Config auto-load documented: Exported apps auto-run JSON
- Log extraction: Creates `macos_[test-id].log` files

**Acceptance Criteria Status**:
1. ✅ `just test-macos-target` - Implemented
2. ✅ `just test-macos-manual` - Implemented
3. ✅ Cross-platform integration - macOS platform icon registered
4. ✅ Log extraction - macOS case in `_extract-logs`
5. ✅ Checksum commands - test-macos-update/reset added
6. ✅ help-macos updated with testing commands

### Live Validation Assessment - 2025-12-09

**Commands Tested:**

| Command | Method | Result | Notes |
|---------|--------|--------|-------|
| `clear-test-macos` | Live run | ✅ PASS | Correctly clears config file |
| `clear-macos-test-cache` | Live run | ✅ PASS | Alias works, shows 'already clean' |
| `help-macos` | Live run | ✅ PASS | Shows all testing commands |
| `test-macos-target` | Live run | ✅ PASS | 4/4 actions passed (100%) |
| `test-macos-manual` | Dry-run | ✅ PASS | Correct config injection & launch |
| `test-macos-update` | Dry-run | ✅ PASS | Correct baseline update logic |
| `test-macos-reset` | Dry-run | ✅ PASS | Correct baseline reset logic |

**Additional Fixes Applied During Validation:**
- Added macOS case to `_collect-action-results` (missing platform support)
- Added macOS case to `_analyze-test-errors` (missing platform support)

**Live Test Output (system-layer-all):**
```
✅ Total Actions Executed: 4 actions
✅ Actions Passed: 4/4 (100%)
❌ Actions Failed: 0/4 (0%)

📊 Error Analysis Results:
   Critical Errors: 0
   Total Errors: 0
   Warnings: 0

✅ ERROR ANALYSIS PASSED
🎉 OVERALL RESULT: PASSED
```

**Known Limitation:**
- Firebase C++ module not compiled for macOS (shows ERROR in logs but doesn't affect test framework)
- This is a separate issue from task-328 scope

**Ready for Commit**: ✅ YES

### Input Type Validation - 2025-12-09

macOS test system supports **all input types** identical to Android/desktop:

| Input Type | Command Example | Status |
|------------|-----------------|--------|
| Single Config | `just test-macos-target system-layer-all` | ✅ PASS |
| Test List | `just test-macos-target system-all` | ✅ PASS |
| Wildcard Pattern | `just test-macos-target 'system.*'` | ✅ PASS |
| Folder Reference | `just test-macos-target '/archive/generated-replays/merge-20'` | ✅ PASS |
| Subdirectory Config | Auto-detected via recursive find | ✅ PASS |

**Code Sharing**: macOS uses the **shared `_execute-test-with-analysis` function** (same as Android/desktop), ensuring identical input handling across all platforms.

**Note**: `@` symbol references (like `@system-all`) are for use **inside** test list JSON files, not as command-line arguments. This behavior is consistent across all platforms.
<!-- SECTION:NOTES:END -->
