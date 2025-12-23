---
id: task-296
title: Implement macOS export pipeline with Sentry and Firebase integration
status: Done
assignee: []
created_date: '2025-11-19 21:42'
updated_date: '2025-12-22 23:44'
labels:
  - macos
  - export
  - sentry
  - firebase
  - integration
  - high-priority
  - build-system
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement comprehensive macOS export pipeline that properly integrates Sentry crash reporting and Firebase services. This builds upon existing macOS build capabilities to ensure production-ready macOS exports with full monitoring, analytics, and backend connectivity. The pipeline must handle macOS-specific deployment requirements including app bundle creation, code signing, notarization, and App Store distribution support.
<!-- SECTION:DESCRIPTION:END -->

## Assessment (2025-12-06)

**Value: MEDIUM** - Production macOS distribution requires this.

**Recommendation: KEEP but DEFER** - Important for macOS App Store or notarized distribution, but lower priority than Windows/mobile platforms. Consider implementing when macOS becomes a distribution priority.

**Effort**: Medium-Large (notarization, code signing, App Store requirements)
**Note**: Could be combined with task-294 (macOS testing infrastructure)

---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Integrate Firebase SDK into macOS export pipeline with proper framework linking and initialization
- [x] #2 Implement Sentry GDExtension integration for macOS exports with crash reporting and performance monitoring
- [x] #3 Create macOS export templates with embedded Firebase and Sentry dependencies
- [x] #4 Develop macOS-specific export scripts handling app bundle creation, entitlements, and code signing
- [ ] #5 Implement macOS notarization workflow for distribution outside App Store with Firebase/Sentry integration
- [ ] #6 Create macOS App Store export pipeline with proper Firebase/Sentry configuration for sandboxed environment
- [x] #7 Implement macOS export validation workflow testing Firebase connectivity and Sentry crash reporting
- [x] #8 Ensure macOS exports maintain debug/release build configurations with appropriate SDK integration
- [ ] #9 Implement macOS-specific resource management (icons, metadata, version info, localization) for production builds
- [ ] #10 Create comprehensive macOS export documentation and troubleshooting guides
- [x] #11 Validate macOS export pipeline with end-to-end testing of Firebase operations and Sentry reporting
- [x] #12 Ensure cross-platform consistency with existing Android/iOS export methodologies
- [x] #13 Leverage existing macOS build system for seamless integration with current development workflows
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Completion Summary (2025-12-23)

**Core macOS export pipeline fully implemented and validated.**

### Results from 2025-12-22 full-pipeline:
- macOS: 19/19 passed, 0 skipped, 0 failed
- All Firebase tests passing
- All Sentry integration working

### Implemented Features:
- ✅ Firebase C++ SDK integration (task-330 completed)
- ✅ Sentry GDExtension integration
- ✅ macOS export templates with Firebase dependencies
- ✅ App bundle creation and Gatekeeper handling (`xattr -cr`)
- ✅ Export validation workflow (`test-macos-target`)
- ✅ Debug/release configurations
- ✅ End-to-end testing validated
- ✅ Cross-platform consistency with Android/iOS/Windows

### Key Infrastructure:
- `justfile-platform-macos.justfile` - macOS testing recipes
- Firebase libraries: `firebase/firebase_cpp_sdk/libs/darwin/`
- ARM64 and x86_64 architecture support

### Deferred (Not Currently Needed):
- Code signing and notarization workflow (AC#5)
- App Store distribution support (AC#6)
- macOS-specific resource management (AC#9)
- Comprehensive documentation (AC#10)

These production polish items can be implemented when preparing for macOS distribution.

### Related Completed Tasks:
- task-330: Firebase C++ module with macOS export (POC)
- task-328: macOS test system integration
- task-357: macOS checksum validation support
<!-- SECTION:NOTES:END -->
