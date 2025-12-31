---
id: task-374
title: Review and consolidate potentially redundant Android recipes
status: Done
assignee: []
created_date: '2025-12-23 23:01'
updated_date: '2025-12-29 00:07'
labels:
  - cleanup
  - android
  - documentation
  - infrastructure
dependencies: []
priority: medium
ordinal: 264000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

Android has the most recipes of any platform, and some may be redundant or overlapping.

**Potential redundancies to review:**

### Run/Launch
- `run-android` vs `launch-android` - What's the difference? Both run the app.

### Test variants
- `test-android-enhanced` vs `test-android-target` - Are these different?
- `test-android-trace` vs `test-android-verbose` - Distinct purposes?

### Export
- `export-apk-android` vs `export-all-android` - Overlapping?
- `export-install-android-debug` / `export-install-android-launch-debug` - Needed?

## Investigation Needed

1. Document the purpose of each potentially redundant recipe
2. Identify which can be consolidated
3. Identify which serve distinct purposes (keep)
4. Create deprecation plan for redundant recipes

## Expected Outcome

- Clear documentation of each recipe's purpose
- Removal of truly redundant recipes
- Simplified command surface for Android

## Reference

Part of platform parity analysis - Infrastructure/Cleanup.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Purpose of run-android vs launch-android documented
- [x] #2 Purpose of test-android-enhanced vs test-android-target documented
- [x] #3 Purpose of test-android-trace vs test-android-verbose documented
- [x] #4 Redundant recipes identified and removal plan created
- [x] #5 Validation: Any removed recipes no longer appear in just --list
- [x] #6 Validation: Remaining recipes still work correctly
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Order: Wave 0 (Second)

Do this BEFORE adding new recipes - understand current architecture first.

## Chunked Validation

### Chunk 1: Audit Run/Launch
```bash
# Document difference
just --list | grep -E "^(run|launch)-android"
# Read implementations
rg "^run-android|^launch-android" justfiles/ -A5
```
Decision: Keep both or consolidate?

### Chunk 2: Audit Test Variants
```bash
just --list | grep "test-android"
# Compare implementations
diff <(just --show test-android-enhanced) <(just --show test-android-target)
```
Decision: Document distinct purposes or consolidate?

### Chunk 3: Audit Export Recipes
```bash
just --list | grep "export-.*android"
```
Decision: Which are truly needed?

### Chunk 4: Document Findings
Update task-376 parity doc with findings.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Investigation Results

### run-android vs launch-android: KEEP BOTH

- run-android: LEVEL 1 (1-2 sec) with state cleanup - for dev iteration

- launch-android: Simple app launch via adb only

### test-android-enhanced vs test-android-target: KEEP BOTH

- enhanced: Smart dispatcher (test list vs config detection)

- target: Automated test runner with checksum validation + error analysis

### test-android-trace vs test-android-verbose: KEEP

- trace: Basic test wrapper

- verbose: VERBOSE_TESTING=true for ObjectDB/memory leak debugging

### Export Recipes: KEEP ALL

- Workflow chain: export-apk-android -> export-all-android -> export-install-android-debug -> export-install-android-launch-debug

- Each adds functionality: export -> export+install -> export+install+launch

### Conclusion

No redundancies found. All recipes serve distinct purposes in the development workflow.
<!-- SECTION:NOTES:END -->
