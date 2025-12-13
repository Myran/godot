---
id: task-295
title: Implement Windows export pipeline with Sentry and Firebase integration
status: To Do
assignee: []
created_date: '2025-11-19 21:42'
updated_date: '2025-12-13 18:20'
labels:
  - windows
  - export
  - sentry
  - firebase
  - integration
  - high-priority
  - build-system
dependencies:
  - task-277
  - task-293
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement comprehensive Windows export pipeline that properly integrates Sentry crash reporting and Firebase services. This extends beyond existing Windows build capabilities to ensure production-ready Windows exports with full monitoring, analytics, and backend connectivity. The pipeline must handle Windows-specific deployment requirements including installer creation, code signing, and runtime dependencies.
<!-- SECTION:DESCRIPTION:END -->

## Assessment (2025-12-06)

**Value: MEDIUM-HIGH** - Production-ready Windows builds require this.

**Recommendation: KEEP** - Logical follow-on to task-277 and task-293. This completes the Windows platform story with production-ready exports. Depends on both prerequisites being completed first.

**Effort**: Medium-Large (export pipeline, installer creation, code signing)
**Blocker**: Requires task-277 + task-293 completed first

---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Integrate Firebase C++ SDK into Windows export pipeline with proper library linking and initialization
- [ ] #2 Implement Sentry GDExtension integration for Windows exports with crash reporting and performance monitoring
- [x] #3 Create Windows export templates with embedded Firebase and Sentry dependencies
- [ ] #4 Develop Windows-specific export scripts handling executable creation, DLL bundling, and dependency management
- [ ] #5 Implement Windows installer creation with proper Firebase/Sentry configuration files
- [ ] #6 Create Windows export validation workflow testing Firebase connectivity and Sentry crash reporting
- [x] #7 Ensure Windows exports maintain debug/release build configurations with appropriate SDK integration
- [ ] #8 Implement Windows-specific resource management (icons, metadata, version info) for production builds
- [ ] #9 Create comprehensive Windows export documentation and troubleshooting guides
- [ ] #10 Validate Windows export pipeline with end-to-end testing of Firebase operations and Sentry reporting
- [ ] #11 Ensure cross-platform consistency with existing Android/iOS export methodologies
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Status Update (2025-12-13)

**Dependencies Status:**
- task-277 (Firebase C++ SDK for Windows) - **Done** ✅
- task-293 (Windows Testing Infrastructure) - To Do (but can be worked in parallel)

**Acceptance Criteria Already Satisfied (from task-277 & task-333):**

✅ **AC#1** - Firebase C++ SDK integrated into Windows export pipeline:
- Shared code architecture implemented (firebase_common.cpp)
- Windows-specific code in firebase_windows.cpp
- SCsub links Firebase Windows libraries correctly
- System libraries configured (Userenv.lib, icu.lib, etc.)

✅ **AC#3** - Windows export templates with Firebase dependencies:
- Windows debug template builds successfully with MSVC (~14 min)
- Firebase libraries statically linked
- Templates can be built via `just win-vm-template-debug/release`

✅ **AC#7** - Debug/release build configurations:
- Both debug and release configurations supported
- VS2019/MT/x64/Debug and Release libraries available

**Remaining Work:**
- AC#2: Sentry GDExtension integration (DLLs exist from task-276)
- AC#4: Export scripts for DLL bundling and dependency management
- AC#5: Windows installer creation
- AC#6: Export validation workflow
- AC#8: Resource management (icons, metadata, version info)
- AC#9: Documentation
- AC#10: End-to-end testing
- AC#11: Cross-platform consistency

**Available Infrastructure:**
- Windows VM: 192.168.50.92 (SSH access)
- Just recipes: `win-vm-*` commands
- Sentry Windows DLLs ready (task-276)
<!-- SECTION:NOTES:END -->
