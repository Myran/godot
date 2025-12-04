---
id: task-327
title: >-
  Reduce logging command complexity: 47→13 commands (72% reduction) with
  dependency safety
status: To Do
assignee: []
created_date: '2025-12-04 08:23'
updated_date: '2025-12-04 08:47'
labels:
  - refactoring
  - justfile
  - high-priority
  - breaking-changes
dependencies: []
priority: high
---

## Description

**CRITICAL FINDINGS**: Dependency analysis revealed 5 commands with hard dependencies that WILL BREAK other recipes if removed without updates first.

Comprehensive validation shows 47 logging commands is too many. Reduce to 8 core + 5 legacy (13 total) commands with explicit platform parameters instead of auto-detection. Two-tier naming: `logs-*` for test results, `logs-android-*` for device logs.

**Must update dependencies BEFORE removal to prevent breaking changes.**

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Dependency analysis complete - 5 hard dependencies identified
- [ ] #2 Update 5 dependent recipes (semantic-replay, gamestate-testing, gamestate-capture, validation)
- [ ] #3 Add 8 new consolidated commands with platform parameters
- [ ] #4 Test all updated recipes with new commands
- [ ] #5 Add deprecation warnings to 34 safe-to-remove commands
- [ ] #6 Create migration guide showing old → new command mapping
- [ ] #7 2-week grace period for feedback
- [ ] #8 Remove deprecated commands after grace period
- [ ] #9 Update documentation (CLAUDE.md, ARCHITECTURE.md, justfile help)
<!-- AC:END -->

---

# 🚨 CRITICAL: Dependency Analysis Results

**Date**: 2025-12-04
**Analysis**: Searched all justfiles for recipe logic dependencies
**Tool**: `rg "just (logs-|android-logs-)" justfiles/*.justfile`

---

## ⚠️ BREAKING CHANGES: 5 Commands with Hard Dependencies

These commands are used in recipe logic and WILL BREAK other recipes if removed:

| Command | Dependencies | Files Affected | Risk |
|---------|--------------|----------------|------|
| `logs-last` | **5 uses** | semantic-replay (3), cross-validation (2) | 🔴 CRITICAL |
| `logs-text` | **2 uses** | gamestate-testing (2) | 🔴 CRITICAL |
| `logs-desktop-last` | **4 uses** | gamestate-capture (4) | 🟡 HIGH |
| `android-logs-health-check` | **3 uses** | android-device-logs (2), validation (1) | 🟡 HIGH |
| `android-logs-clear-lightweight` | **1 use** | validation-enhanced-testing (1) | 🟡 MEDIUM |

### **What Breaks If Removed Without Updates:**

**1. Replay System** - Uses `logs-last` for session extraction:
```bash
# justfile-semantic-replay-commands.justfile (3 uses)
just logs-last | grep "SEMANTIC_ACTION" | head -3
SESSION_ID=$(just logs-last | grep "SESSION_START" | tail -1)
SEMANTIC_COUNT=$(just logs-last | grep -c "SEMANTIC_ACTION")
```

**2. Gamestate Validation** - Uses `logs-text` for automated testing:
```bash
# justfile-gamestate-testing.justfile (2 uses)
RESTORATION_LOGS=$(just logs-text "$LATEST_TEST_ID" "gamestate_restore")
LOADED_SESSION_LOGS=$(just logs-text "$LATEST_TEST_ID" "loaded_state_recording")
```

**3. Gamestate Capture** - Uses `logs-desktop-last` for state extraction:
```bash
# justfile-gamestate-capture.justfile (4 uses)
just logs-desktop-last 2>/dev/null || echo ""
CAPTURE_OUTPUT=$(just logs-desktop-last | grep "DEBUG_GAMESTATE_CAPTURE")
```

**4. Buffer Safety** - Uses `android-logs-health-check` (Task-242 lessons):
```bash
# Multiple files (3 uses)
BUFFER_HEALTH_OUTPUT=$(just android-logs-health-check)
```

---

## ✅ SAFE TO REMOVE: 34 Commands (Zero Dependencies)

All other commands have **NO recipe dependencies** - only used in:
- Documentation (CLAUDE.md, ARCHITECTURE.md)
- Help text (echo statements)
- Comments

Can be safely removed after deprecation warnings and grace period.

---

# 🎯 Revised Strategy: 8 Core + 5 Legacy = 13 Commands

## Two-Tier Naming Convention

### **Tier 1: Test Results** → `logs-*` prefix
For analyzing saved test log files:
```bash
logs-latest [PLATFORM]                    # Latest test
logs-errors TEST_ID [PLATFORM]            # Error extraction
logs-search TEST_ID "term" [PLATFORM]     # Text search (replaces logs-text)
logs-pattern TEST_ID PATTERN [PLATFORM]   # Pattern matching
```

### **Tier 2: Android Device** → `logs-android-*` prefix
For live device logs (adb logcat):
```bash
logs-android-device "search_term"         # Device log search (consolidates 6 commands)
logs-android-clear                        # Buffer management
logs-android-health                       # Buffer health check
logs-android-status                       # Device status
```

**Rationale**: Clear distinction between saved test results vs live device logs prevents confusion.

---

## 📋 8 New Core Commands

**Test Result Analysis (4 commands)**:
1. `logs-latest [PLATFORM]` - Get latest test (NEW, replaces logs-last-*)
2. `logs-errors TEST_ID [PLATFORM]` - Error extraction (ENHANCED with platform param)
3. `logs-search TEST_ID "term" [PLATFORM]` - Text search (NEW, replaces logs-text)
4. `logs-pattern TEST_ID PATTERN [PLATFORM]` - Pattern matching (ENHANCED)

**Android Device Monitoring (4 commands)**:
5. `logs-android-device "term"` - Device search (NEW, consolidates 6 commands)
6. `logs-android-clear` - Buffer management (KEEP - has 1 dependency)
7. `logs-android-health` - Buffer health (RENAME from android-logs-health-check)
8. `logs-android-status` - Device status (KEEP or integrate)

---

## 🔄 5 Legacy Commands (Backwards Compatibility)

Keep during transition to prevent breaking existing recipes:

1. `logs-last` → Alias to `logs-latest` (preserve 5 dependencies)
2. `logs-text` → Alias to `logs-search` (preserve 2 dependencies)
3. `logs-desktop-last` → Alias to `logs-latest desktop` (preserve 4 dependencies)
4. `android-logs-health-check` → Alias to `logs-android-health` (preserve 3 dependencies)
5. `android-logs-clear-lightweight` → Alias to `logs-android-clear` (preserve 1 dependency)

**Note**: These aliases will be removed AFTER dependent recipes are updated.

---

## 🗑️ 34 Commands to Remove

**Platform-Specific Variants (8)**:
- `logs-last-android`, `logs-last-desktop`, `logs-last-ios`
- `logs-last-ios-ipad`, `logs-last-ios-iphone`
- `logs-android TEST_ID`, `logs-desktop TEST_ID`
- `logs-android-errors`, `logs-desktop-errors`

**Advanced Analysis (5)**:
- `logs-performance` → Use `logs-search TEST_ID "duration_ms"`
- `logs-checksum-detail` → Use `logs-search TEST_ID "checksum"`
- `logs-lifecycle` → Use `logs-search TEST_ID "lifecycle"`
- `logs-list-tags` → Not needed
- `logs-tags` → Replaced by logs-search with grep

**Wildcard Advanced (5)**:
- `logs-multi` → Use `logs-search` with grep OR
- `logs-exclude` → Use `logs-pattern | grep -v`
- `logs-suggest` → Broken, not critical
- `logs-tree` → Broken, not critical
- `logs-discover` → Use `logs-pattern "prefix.*"`

**Android Device Advanced (6)**:
- `android-logs-errors` → Use `logs-android-device "error"`
- `android-logs-live` → Use `logs-android-device` + watch
- `android-logs-tagged` → Use `logs-android-device "TAG"`
- `android-logs-recent` → Use `logs-android-device "" | head`
- `android-logs-search` → Replaced by `logs-android-device`
- `android-logs-performance` → Use `logs-search`

**Monitoring Infrastructure (6)**:
- `android-logs-monitor-restart`
- `android-logs-monitor-background`
- `android-logs-monitor-stop`
- `android-logs-cross-validate`
- Plus 2 others

**Other (4)**:
- `logs-summary` → Use `logs-errors | head -50`
- `logs-benchmark` → Not essential
- `logs-test-pattern` → Not essential
- Others as identified

---

# 🚀 Safe Implementation Plan

## Phase 1: Add New Commands (Week 1)

**1.1 Implement new commands with platform parameters:**
```bash
logs-latest [PLATFORM]                    # New
logs-search TEST_ID "term" [PLATFORM]     # New (replaces logs-text)
logs-android-device "term"                # New (consolidates 6 commands)
logs-android-health                       # Rename from android-logs-health-check
```

**1.2 Add platform parameter to existing:**
```bash
logs-errors TEST_ID [PLATFORM]            # Add parameter
logs-pattern TEST_ID PATTERN [PLATFORM]   # Add parameter
```

**1.3 Test new commands:**
```bash
just logs-latest
just logs-latest android
just logs-search TEST_ID "firebase"
just logs-android-device "error"
```

---

## Phase 2: Update Dependencies (Week 1)

**2.1 Update justfile-semantic-replay-commands.justfile** (5 uses):
```bash
# OLD
just logs-last | grep "SEMANTIC_ACTION"

# NEW
just logs-latest | grep "SEMANTIC_ACTION"
```

**2.2 Update justfile-gamestate-testing.justfile** (2 uses):
```bash
# OLD
RESTORATION_LOGS=$(just logs-text "$LATEST_TEST_ID" "gamestate_restore")

# NEW
RESTORATION_LOGS=$(just logs-search "$LATEST_TEST_ID" "gamestate_restore")
```

**2.3 Update justfile-gamestate-capture.justfile** (4 uses):
```bash
# OLD
just logs-desktop-last 2>/dev/null

# NEW
just logs-latest desktop 2>/dev/null
```

**2.4 Update android-logs-health-check references** (3 uses):
```bash
# OLD
BUFFER_HEALTH_OUTPUT=$(just android-logs-health-check)

# NEW
BUFFER_HEALTH_OUTPUT=$(just logs-android-health)
```

**2.5 Update validation-enhanced-testing.justfile** (1 use):
```bash
# OLD
just android-logs-clear-lightweight

# NEW
just logs-android-clear
```

---

## Phase 3: Test Updated Recipes (Week 1)

**3.1 Test gamestate system:**
```bash
just test-gamestate-cycle            # Verify logs-search works
just capture-gamestate-desktop test  # Verify logs-latest desktop works
```

**3.2 Test replay system:**
```bash
# Generate replay and verify logs-latest works
just replay-generate-desktop SESSION_ID test
```

**3.3 Test validation:**
```bash
just test-android-target CONFIG      # Verify logs-android-clear works
```

---

## Phase 4: Deprecation Warnings (Week 2)

**4.1 Add warnings to 34 safe-to-remove commands:**
```bash
logs-last-android:
    @echo "⚠️  DEPRECATED: Use 'just logs-latest android' instead"
    @echo "This command will be removed after 2025-12-18"
    @just logs-latest android

logs-text TEST_ID SEARCH_TERM:
    @echo "⚠️  DEPRECATED: Use 'just logs-search {{TEST_ID}} \"{{SEARCH_TERM}}\"' instead"
    @echo "This command will be removed after 2025-12-18"
    @just logs-search "{{TEST_ID}}" "{{SEARCH_TERM}}"
```

**4.2 Create migration guide:**
```markdown
# Logging Command Migration Guide

| Old Command | New Command |
|-------------|-------------|
| logs-last-android | logs-latest android |
| logs-text TEST_ID "term" | logs-search TEST_ID "term" |
| android-logs-search "term" | logs-android-device "term" |
...
```

---

## Phase 5: Grace Period (2 weeks)

**5.1 Monitor for usage:**
- Check if any deprecated commands are called
- Gather user feedback
- Allow time for external scripts to update

**5.2 Update documentation:**
- CLAUDE.md - Focus on 13 commands
- ARCHITECTURE.md - Update command reference
- justfile help text - Remove deprecated commands

---

## Phase 6: Remove Deprecated Commands (Week 4)

**6.1 Remove old commands:**
- Delete 34 command recipes
- Remove from justfile modules
- Clean up internal helpers

**6.2 Remove legacy aliases:**
- Remove `logs-last` alias (after recipes updated)
- Remove `logs-text` alias (after recipes updated)
- Remove `logs-desktop-last` alias (after recipes updated)

**6.3 Final verification:**
```bash
# Verify no broken recipes
just test-all
just test-gamestate-cycle
just validate
```

---

# 📊 Impact Summary

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| **Total Commands** | 47 | 13 | -34 (-72%) |
| **Working Rate** | 23/47 (49%) | 13/13 (100%) | +51% quality |
| **Hard Dependencies** | Unknown | 5 identified | Risk mitigated |
| **Maintenance Burden** | HIGH | LOW | Significant reduction |
| **User Confusion** | HIGH (47 choices) | LOW (13 clear) | Better UX |

---

# ✅ Success Criteria

**Technical**:
- [ ] All 5 dependent recipes updated and tested
- [ ] Zero broken recipes after command removal
- [ ] All new commands have platform parameter support
- [ ] Buffer safety preserved (android-logs-health)

**User Experience**:
- [ ] Clear migration guide provided
- [ ] Deprecation warnings show alternatives
- [ ] Documentation updated with new commands
- [ ] Simpler mental model (13 vs 47)

**Process**:
- [ ] 2-week grace period completed
- [ ] User feedback incorporated
- [ ] No complaints about broken workflows
- [ ] Successful rollout without incidents

---

# 🎯 Key Decisions

**1. Platform Parameter vs Auto-Detection**
- ✅ Explicit platform parameter (better for CI/CD)
- ❌ Auto-detection (magic behavior, less predictable)

**2. Two-Tier Naming**
- ✅ `logs-*` for test results, `logs-android-*` for device logs
- ❌ Single prefix (would cause confusion)

**3. Update Dependencies First**
- ✅ Update 5 recipes BEFORE removal (prevents breaking changes)
- ❌ Remove first, fix later (would break production workflows)

**4. Legacy Aliases During Transition**
- ✅ Keep aliases during grace period (smooth migration)
- ❌ Hard cutover (would break external scripts)

---

# 📁 Related Documents

- `/tmp/logging-command-dependencies.md` - Complete dependency analysis
- `justfiles/CLAUDE.md` - Will be updated with new commands
- `justfiles/ARCHITECTURE.md` - Command reference update needed
- `task-326` - Validation findings that led to this task

---

**Next Steps**:
1. Get approval for this revised plan
2. Start Phase 1: Implement 8 new commands
3. Start Phase 2: Update 5 dependent recipes
4. Test thoroughly before deprecation warnings
