---
id: task-355
title: Remove Windows prebuilt Sentry binaries after switching to source builds
status: Done
assignee: []
created_date: '2025-12-20 10:47'
updated_date: '2025-12-29 00:07'
labels:
  - sentry
  - cleanup
  - windows
  - prebuilt-binaries
dependencies: []
priority: low
ordinal: 282000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Now that we're building Sentry Windows GDExtension from source using the Windows VM (task-354 completed), we should remove the prebuilt Windows binaries from extras/sentry-godot-gdextension-1.2.0+241f16b/addons/sentry/bin/windows/x86_64/

## Background
- Previously used prebuilt binaries for all platforms
- Windows is now built from source using SCons + MSVC on Windows VM
- Other platforms (iOS, Android, macOS, Linux) still use prebuilt
- Prebuilt Windows binaries are no longer needed

## Files to Remove
- extras/sentry-godot-gdextension-1.2.0+241f16b/addons/sentry/bin/windows/x86_64/* (all files)

## Benefits
- Reduce repository size (~40MB of Windows binaries)
- Ensure only source-built Windows binaries are used
- Clear separation between prebuilt and source-built platforms

## Risks
- Lose fallback if Windows VM build fails
- Need to rebuild from source if binaries deleted accidentally
<!-- SECTION:DESCRIPTION:END -->
