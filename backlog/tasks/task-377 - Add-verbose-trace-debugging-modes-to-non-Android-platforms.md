---
id: task-377
title: Add verbose/trace debugging modes to non-Android platforms
status: Consider
assignee: []
created_date: '2025-12-23 23:01'
updated_date: '2025-12-29 00:07'
labels:
  - testing
  - debugging
  - parity
  - infrastructure
dependencies:
  - task-374
priority: low
ordinal: 8000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

Only Android has verbose and trace debugging modes for detailed analysis.

**Current state:**
- `test-android-verbose` ✅ (detailed memory/node debugging)
- `test-android-trace` ✅ (execution tracing)
- All other platforms: ❌ MISSING

## Impact

- Cannot get detailed debugging info on iOS/macOS/Windows
- Must rely on log analysis for non-Android platforms
- Harder to diagnose memory leaks, node issues on other platforms

## Solution

Add verbose modes where applicable:
1. `test-editor-verbose` - Editor already supports ObjectDB leak detection
2. `test-macos-verbose` - If exported app supports debug output
3. `test-ios-verbose` - If iOS supports detailed logging
4. `test-windows-physical-verbose` - If Windows supports detailed output

## Investigation Needed

- What debug flags does each platform support?
- What's the equivalent of Android's memory/node debugging?
- Can Godot's `--verbose` flag be used?

## Reference

Part of platform parity analysis - Infrastructure/Cleanup.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Investigation: What debug flags each platform supports
- [ ] #2 test-editor-verbose implemented (if applicable)
- [ ] #3 test-macos-verbose implemented (if applicable)
- [ ] #4 test-ios-verbose implemented (if applicable)
- [ ] #5 test-windows-physical-verbose implemented (if applicable)
- [ ] #6 Validation: Each new verbose recipe produces detailed debug output
- [ ] #7 Limitations documented for platforms where verbose mode isn't feasible
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Order: Wave 6 (Optional)

Depends on task-374 findings about test-android-verbose vs test-android-trace.

## Investigation First

### Chunk 1: Understand Android Verbose
```bash
rg "test-android-verbose" justfiles/ -A20
# What does it do? Memory debugging? Node counts?
```

### Chunk 2: Check Godot Flags
```bash
# What verbose flags does Godot support?
./editor/godot.macos.editor.arm64 --help | grep -i verbose
```

### Chunk 3: Implement Where Applicable
```just
# If Godot --verbose works for exported apps:
test-macos-verbose CONFIG:
    @just _execute-test-verbose macos {{CONFIG}}
```

### Chunk 4: Document Limitations
For platforms where verbose isn't feasible, document why:
- Editor: Already has ObjectDB leak detection
- iOS: Limited console access?
- Windows: Remote execution complicates verbose output?
<!-- SECTION:PLAN:END -->
