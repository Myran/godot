---
id: task-372
title: 'Investigate fastbuild equivalents for iOS, macOS, and Windows'
status: Consider
assignee: []
created_date: '2025-12-23 23:00'
updated_date: '2025-12-29 00:07'
labels:
  - build
  - performance
  - investigation
  - phase-3
dependencies: []
priority: low
ordinal: 7000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

Only Android has a fast iteration build command (`fastbuild-android`, 30-60s). Other platforms require full rebuilds.

**Current state:**
- `fastbuild-android` ✅ (30-60 seconds)
- `fastbuild-ios` ❌ MISSING
- `fastbuild-macos` ❌ MISSING
- `fastbuild-windows` ❌ MISSING

## Impact

- iOS/macOS/Windows iteration is 10-50x slower than Android
- Developers avoid testing on these platforms during rapid iteration
- Reduced test coverage on non-Android platforms

## Investigation Needed

### iOS
- Can Xcode incremental builds be leveraged?
- Can we skip PCK re-export if only GDScript changed?
- What's the minimum rebuild for GDScript changes?

### macOS
- Editor-based testing (`test-editor-target`) is already fast
- For exported app testing: can we do incremental builds?
- Template rebuilds are slow - can we cache better?

### Windows
- VM-based builds add network overhead
- Can MSVC incremental linking help?
- Is local Windows build possible for faster iteration?

## Expected Outcomes

1. Document current build times for each platform
2. Identify bottlenecks in each build pipeline
3. Prototype fastbuild recipes where feasible
4. Document limitations where fastbuild isn't practical

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 #1 Benchmark current build times documented for all platforms
- [ ] #2 #2 Bottlenecks identified for iOS, macOS, and Windows builds
- [ ] #3 #3 Feasibility assessment completed for each platform
- [ ] #4 #4 Prototype fastbuild-* implemented where feasible (target: <2 min)

## Reference

Part of platform parity analysis - Phase 3 Feature Parity.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Order: Wave 6 (Investigation)

Low priority - only pursue if iteration speed becomes a pain point.

## Investigation Steps

### Chunk 1: Benchmark Current Times
```bash
# Time each platform's build
time just build-all-ios
time just build-all-macos  
time just build-all-windows
time just fastbuild-android  # Baseline: 30-60s
```

### Chunk 2: Identify Bottlenecks
For each platform, profile:
- Template rebuild time
- PCK export time
- Native compilation time
- Network transfer time (Windows VM)

### Chunk 3: Prototype iOS Fastbuild
```bash
# Can we skip PCK export if only GDScript changed?
# Can Xcode incremental build help?

# Prototype:
fastbuild-ios:
    @# Only re-export PCK
    @just export-pck-ios
    @# Skip template rebuild
    @# Incremental Xcode build
    @xcodebuild -incremental ...
```

### Chunk 4: Document Findings
Create findings doc with:
- Current times per platform
- Feasibility assessment
- Recommended optimizations
- "Not feasible" explanations where applicable
<!-- SECTION:PLAN:END -->

<!-- AC:END -->

- [ ] #5 Validation: Any new fastbuild-* recipe tested with GDScript-only changes
- [ ] #6 Limitations documented in CLAUDE.md or platform-specific docs
<!-- AC:END -->
