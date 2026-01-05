---
id: task-422
title: Fix @ reference expansion in build-export-test-all
status: Done
assignee: []
created_date: '2026-01-05 12:07'
updated_date: '2026-01-05 12:12'
labels:
  - bugfix
  - justfile
  - testing
  - infrastructure
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The build-export-test-all command doesn't properly expand @ test list references (e.g., @firebase-auth-all). Individual test-*-target commands handle @ expansion correctly, but build-export-test-all passes the @ literal through which causes "Neither test list nor config found" errors.

Investigate how test-*-target handles @ expansion and apply the same logic to build-export-test-all.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 build-export-test-all @test-list expands correctly
- [x] #2 All configs in test list are executed on all platforms
- [x] #3 @ references work identically in test-*-target and build-export-test-all
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Root Cause Analysis (2025-01-05)

**Finding**: `_test-list-generic` in `justfile-validation-enhanced-testing.justfile` calls `just _expand_at_references` to expand @ references.

**Problem**: `build-export-test-all` in `justfile-build-export-test.justfile` passes CONFIG directly to `_all-platforms-impl` without @ reference expansion.

**Code Path Difference**:

- `test-android-target CONFIG` → `_execute-test-with-analysis` → `_test-list-generic` → `_expand_at_references` ✅

- `build-export-test-all CONFIG` → `_all-platforms-impl` → `build-export-test-*` → NO EXPANSION ❌

**Solution**: Add @ reference detection and expansion to `build-export-test-all` before calling `_all-platforms-impl`.
<!-- SECTION:NOTES:END -->
