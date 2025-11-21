---
id: task-276
title: Add Windows DLL files for Sentry GDExtension to support Windows exports
status: Done
assignee: []
created_date: '2025-11-12 11:02'
updated_date: '2025-11-21 13:24'
labels: []
dependencies: []
---

## Description

Windows Sentry GDExtension DLL files have been successfully integrated into the build system.

**Completed Implementation:**
- Windows Sentry DLL builds (debug and release) for x86_64 architecture
- Cross-compilation from macOS using MinGW-w64
- Integration into unified `build-sentry-all` command
- Automatic inclusion in `build-toolchain` pipeline

**Build Commands:**
- `just build-sentry-native-windows-release` - Build release DLL
- `just build-sentry-native-windows-debug` - Build debug DLL
- `just build-sentry-all` - Build all Sentry components (includes Windows)

**Output Files:**
- `project/addons/sentry/bin/windows/x86_64/libsentry.windows.release.x86_64.dll`
- `project/addons/sentry/bin/windows/x86_64/libsentry.windows.debug.x86_64.dll`

**Integration:**
Windows Sentry builds are now part of Tier 1 (build-toolchain) in the three-tier build system, ensuring Sentry SDK is ready before editor and templates are built.

## Related Commits
- Commit f9b3560f: feat(build): integrate Sentry into build pipeline and add iOS debug/release variants
- Windows DLL builds included in unified Sentry build system
