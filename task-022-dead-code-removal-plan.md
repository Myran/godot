# Task-022 Dead Code Removal Plan

## Proven Methodology from Task-021

Following the successful completion of task-021, we will use the same safety-first approach:

1. **Comprehensive baseline testing** before making any changes
2. **Incremental removal** with testing between each step
3. **Zero regression tolerance** - all active commands must work identically
4. **Safety measures** with rollback capability
5. **Testing framework** to verify impact of changes

## Phase 1: Analysis and Baseline (CURRENT PHASE)

### Dead Code Inventory Analysis

**CRITICAL DISCOVERY: Active vs Removed Function Duplication**

**Removed Functions (4 instances in justfile-config.justfile) - DEAD CODE:**
- `_removed_config_clear_android:` (lines ~68-83) - **REPLACED by active version in justfile-platform-android.justfile**
- `_removed_config_android_tags ACTIVE_TAGS IGNORED_TAGS:` (lines ~86-143) - **REPLACED by active version at config-android-tags:**  
- `_removed_config_android_level LEVEL:` (lines ~146-199) - **REPLACED by active version at config-android-level:**
- `_removed_config_android_reset:` (lines ~202-215) - **REPLACED by active version at config-android-reset:**

**Active Functions (confirmed working):**
- `config-clear-android:` in justfile-platform-android.justfile (ACTIVE, WORKING)
- `config-android-tags ACTIVE_TAGS IGNORED_TAGS:` in justfile-config.justfile (ACTIVE, WORKING)
- `config-android-level LEVEL:` in justfile-config.justfile (ACTIVE, WORKING)
- `config-android-reset:` in justfile-config.justfile (ACTIVE, WORKING)

**SAFETY CONFIRMATION**: All `_removed_*` functions are confirmed dead code with active replacements.

**Legacy Comments and Dead Code Paths:**
- `# Legacy approach (fallback):` sections in multiple files
- `# Legacy function (kept for compatibility)` sections
- `# REMOVED:` comment blocks with no actual removed functions
- `# Legacy non-interactive help (text-only fallback)` sections

**Legacy Compatibility Functions:**
- `_add-checksum-config-to-file` marked as legacy
- `_extract-logs-android` and `_extract-logs-desktop` legacy wrappers
- `build-all` alias marked as legacy
- `help-static` marked as legacy fallback

### Baseline Test Plan

```bash
# Core functionality verification
just help
just help-debug
just help-logs
just config-list
just config-push-android system-testing
just logs-last
just logs-errors $(just logs-last)
just test-android-target system-testing

# Build system verification
just build-status
just validate

# Legacy function verification (these should NOT exist as public commands)
just config-clear-android 2>&1 | grep -q "command not found" && echo "✅ Correctly removed" || echo "❌ Still exists"
just config-android-tags 2>&1 | grep -q "command not found" && echo "✅ Correctly removed" || echo "❌ Still exists"
just config-android-level 2>&1 | grep -q "command not found" && echo "✅ Correctly removed" || echo "❌ Still exists"
just config-android-reset 2>&1 | grep -q "command not found" && echo "✅ Correctly removed" || echo "❌ Still exists"
```

## Phase 2: Safe Incremental Removal

### Step 2.1: Remove _removed_* Functions (Safest First)
- Remove complete function bodies that are prefixed with `_removed_`
- These are already marked as removed and have no external dependencies

### Step 2.2: Remove Legacy Comment Blocks
- Remove `# REMOVED:` comment lines for functions already removed
- Remove dead comment blocks that reference non-existent functionality

### Step 2.3: Evaluate and Remove Legacy Fallback Code
- Analyze each `# Legacy approach (fallback):` section
- Determine if fallback code is actually reachable
- Remove only confirmed unreachable code paths

### Step 2.4: Handle Legacy Compatibility Functions
- Evaluate if legacy compatibility functions are actually used
- Consider if they can be safely removed or should be preserved

## Phase 3: Verification and Testing

### Regression Testing After Each Step
```bash
# After each removal step, run full verification
just validate                              # Complete validation pipeline
just help | head -20                       # Help system works
just config-list                           # Config commands work
just logs-last                             # Log commands work  
just build-status                          # Build system works
```

### Final Verification
- All active commands work identically to baseline
- No broken function calls or missing dependencies
- Help system shows correct available commands
- Documentation references are consistent

## Risk Assessment

### Low Risk (Remove Immediately):
- `_removed_*` functions - already marked as removed, no dependencies
- `# REMOVED:` comments for non-existent functions
- Dead comment blocks

### Medium Risk (Analyze First):
- Legacy fallback code paths - need to verify unreachability
- Legacy compatibility wrappers - need to check for usage

### High Risk (Preserve for Now):
- Any function that might be called from external scripts
- Functions that appear in CLAUDE.md or help documentation

## Safety Measures

1. **Git Branch**: Work on dedicated branch for safe rollback
2. **Incremental Commits**: Commit after each successful removal step  
3. **Testing Between Steps**: Full regression test after each change
4. **Documentation**: Update this plan with findings and decisions
5. **Rollback Plan**: `git reset --hard` to previous working state if needed

## Success Criteria

- [x] ~149 lines of confirmed dead code removed (conservative approach prioritized safety)
- [x] Zero regressions in active functionality
- [x] All existing commands work identically  
- [x] Help system shows only available commands
- [x] Improved maintainability and reduced cognitive load

## TASK COMPLETION SUMMARY

### Successfully Completed:
**Phase 1: Removed _removed_ Functions (138 lines)**
- `_removed_config_clear_android` (13 lines) - REPLACED by active version in platform-android 
- `_removed_config_android_tags` (57 lines) - REPLACED by active version in config.justfile
- `_removed_config_android_level` (54 lines) - REPLACED by active version in config.justfile  
- `_removed_config_android_reset` (14 lines) - REPLACED by active version in config.justfile

**Phase 2: Removed Dead Comments & Compatibility Functions (11 lines)**
- 3 "REMOVED:" comment blocks from build-utils and support files
- 2 unused legacy compatibility wrapper functions (_extract-logs-android/desktop)

### Conservative Decisions (Preserved for Safety):
- `build-all` alias - Still functional, users may depend on it
- `help-static` function - Manual fallback, users may invoke directly  
- `# Legacy approach (fallback):` code sections - May be needed when primary approach fails
- Large legacy functions - Avoided removing complex functions without thorough analysis

## Final Impact

- **Lines Removed**: 149 lines of confirmed dead code
- **Files Affected**: 4 justfiles (conservative scope)
- **Risk Level**: LOW (extremely conservative approach, only removed confirmed dead code)
- **Complexity**: LOW (focused on clearly marked _removed_ functions)
- **Safety**: MAXIMUM (all active commands verified working after each removal step)