---
id: task-254
title: Fix folder expansion syntax in test system for auto-discovery of configs
status: Done
assignee: []
created_date: '2025-10-30 14:42'
updated_date: '2025-12-18 10:37'
labels:
  - test-framework
  - bug-fix
  - critical
dependencies: []
priority: high
ordinal: 69000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The test list comprehensive-with-replays.json uses folder expansion syntax '/archive/generated-replays/' which should auto-discover configs in tests/debug_configs/archive/generated-replays/, but the test system incorrectly looks for configs directly in tests/debug_configs/ instead, causing 8+ test configurations to fail with 'Neither test list nor config found' errors.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Folder expansion syntax '/folder/' correctly discovers configs in tests/debug_configs/archive/generated-replays/ subdirectory
- [x] #2 Test system properly handles nested directory discovery for folder expansion patterns
- [x] #3 All 25+ battle replay configurations in comprehensive-with-replays.json execute successfully without manual file copying
- [x] #4 Error messages clearly indicate correct config paths when folder expansion fails
- [x] #5 Folder expansion syntax documentation is updated with correct usage examples
- [x] #6 Platform validation works correctly for archive configs
- [x] #7 Single canonical config lookup path maintained across all test components
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Investigate folder expansion syntax issue in test system

## Root Cause Analysis
1. **Current Behavior**: Test system looks for configs in tests/debug_configs/ instead of tests/debug_configs/archive/generated-replays/
2. **Expected Behavior**: Folder expansion '/folder/' should auto-discover configs in the corresponding subdirectory
3. **Impact**: 8+ battle replay configurations fail with 'Neither test list nor config found' errors

## Proposed Solutions
**Option 1: Fix Path Resolution Logic**
- Update test system to properly handle nested directory discovery
- Ensure '/folder/' patterns map to correct subdirectory paths

**Option 2: Update Folder Expansion Syntax**
- Modify syntax to be more explicit about nested discovery
- Maintain backward compatibility with existing test lists

## Implementation Approach
1. Investigate current folder expansion implementation
2. Identify where path resolution fails for nested directories  
3. Fix the path resolution logic
4. Test with comprehensive-with-replays.json configurations
5. Update documentation with correct usage examples

## Root Cause Analysis and Solution

**Deep Investigation Results:**

1. **CONFIG_PATH Issue Discovery**: The root cause was not just config discovery, but that `CONFIG_PATH` wasn't being updated to point to the actual found location when recursive configs were discovered.

2. **Architecture Analysis**:
   - Folder expansion syntax `/folder/` correctly discovered configs in subdirectories
   - However, validation-enhanced-testing.justfile wasn't updating `CONFIG_PATH` to the recursive location
   - This caused downstream test components to receive incorrect path information

3. **Shared Config Lookup Enhancement**: Fixed the `_validate-config-exists` function in justfile-core-config.justfile to include recursive search, ensuring single canonical config lookup path across all test components.

**Solution Implemented:**

```bash
# Enhanced recursive search in justfile-core-config.justfile
RECURSIVE_FOUND=$(find "{{DEBUG_CONFIG_DIR}}" -name "{{CONFIG}}.json" -type f 2>/dev/null | head -1)
if [ -f "$RECURSIVE_FOUND" ]; then
    exit 0
fi
```

```bash
# CONFIG_PATH updating fix in justfile-validation-enhanced-testing.justfile
RECURSIVE_FOUND=$(find "{{DEBUG_CONFIG_DIR}}" -name "${CONFIG_NAME}.json" -type f 2>/dev/null | head -1)
if [[ -n "$RECURSIVE_FOUND" ]]; then
    echo "✅ Found config in subdirectory: $(basename "$(dirname "$RECURSIVE_FOUND")")/${CONFIG_NAME}.json"
    CONFIG_PATH="$RECURSIVE_FOUND"
```

**Validation Results:**
- ✅ Archive configs discovered correctly in subdirectories
- ✅ CONFIG_PATH properly updated to recursive locations
- ✅ Platform validation works correctly for archive configs
- ✅ Single canonical config lookup path maintained
- ✅ All 25+ battle replay configurations execute successfully

## Success Metrics
- All 8+ battle replay configs execute without manual file copying
- Folder expansion works reliably for nested directory structures
- Clear error messages for path resolution failures
- CONFIG_PATH correctly points to recursive config locations
- Shared config lookup architecture maintained across all test components
<!-- SECTION:PLAN:END -->
