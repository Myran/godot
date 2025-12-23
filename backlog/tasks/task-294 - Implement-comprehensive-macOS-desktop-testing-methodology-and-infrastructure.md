---
id: task-294
title: Implement comprehensive macOS desktop testing methodology and infrastructure
status: Done
assignee: []
created_date: '2025-11-19 20:19'
updated_date: '2025-12-22 23:44'
labels:
  - macos
  - testing
  - infrastructure
  - high-priority
  - foundation
  - desktop
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create macOS desktop testing infrastructure equivalent to iOS's test-ios-target and Android's test-android-target systems, including app bundle deployment, log capture, automated testing, and debug config compatibility. This is foundational work required for cross-platform validation and macOS Sentry crash reporting integration, leveraging existing macOS build capabilities.
<!-- SECTION:DESCRIPTION:END -->

## Assessment (2025-12-06)

**Value: MEDIUM** - Part of desktop platform expansion strategy.

**Recommendation: KEEP but DEFER** - macOS testing infrastructure is useful but you already have desktop testing working on the primary development machine. This becomes more valuable when macOS becomes a distribution target. Lower priority than Windows (task-293) since macOS development is already functional locally.

**Effort**: Medium
**Note**: Consider merging with task-296 (macOS export pipeline) for efficiency

---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Research macOS desktop deployment and testing workflows using app bundles and system logging tools (Console.app, log command)
- [x] #2 Create macOS app deployment scripts equivalent to iOS fastbuild workflows with proper bundle management and code signing
- [x] #3 Implement macOS log capture system with structured parsing and test result analysis using unified logging and Console utilities
- [x] #4 Develop macOS automated testing infrastructure (test-macos-target) with validation capabilities and error analysis
- [x] #5 Ensure macOS testing works with existing debug configs and actions without modification
- [x] #6 Create comprehensive macOS testing documentation and just command workflows
- [x] #7 Validate macOS testing infrastructure with comprehensive test suite covering all system layers
- [x] #8 Implement macOS-specific performance monitoring and crash detection capabilities (CrashReporter integration)
- [x] #9 Ensure cross-platform compatibility with existing Android/iOS testing methodologies
- [x] #10 Leverage existing macOS build system for seamless integration with current development workflows
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Completed (2025-12-23)

macOS testing infrastructure is fully operational:

**Results from 2025-12-22 full-pipeline:**
- macOS: 19/19 passed, 0 skipped, 0 failed

**Infrastructure Implemented:**
- `test-macos-target CONFIG` - Automated testing with exported .app
- `test-macos-manual CONFIG` - Manual testing (stays open)
- `test-macos-update CONFIG` - Update checksum baseline
- `test-macos-reset CONFIG` - Reset checksum baseline
- `logs-macos TEST_ID` - Log retrieval
- `logs-macos-errors TEST_ID` - Error analysis
- Editor preservation (never kills Godot editor)
- Gatekeeper quarantine handling with `xattr -cr`

**Key Features:**
- Tests exported `.app` bundle (not editor)
- Config deployment to `~/Library/Application Support/Godot/app_userdata/gametwo/`
- Cross-platform parity with Android/iOS testing

All acceptance criteria met through task-328 and task-357 implementations.
<!-- SECTION:NOTES:END -->
