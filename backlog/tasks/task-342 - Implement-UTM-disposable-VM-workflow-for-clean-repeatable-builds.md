---
id: task-342
title: 'Implement UTM disposable VM workflow for clean, repeatable builds'
status: Consider
assignee: []
created_date: '2025-12-15 08:25'
updated_date: '2025-12-29 00:07'
labels:
  - infrastructure
  - ci-cd
  - automation
  - utm
dependencies:
  - task-336
priority: medium
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Use UTM's disposable flag to ensure every CI/CD build starts from a pristine VM state, guaranteeing clean and repeatable builds.

## Goals
- Configure UTM VM with disposable mode enabled
- Create golden snapshot with all tooling pre-installed
- Implement workflow that resets VM to snapshot after each build
- Ensure build environment is identical for every job

## How UTM Disposable Works
- VM starts from a saved snapshot state
- All changes during runtime are discarded on shutdown
- Next boot returns to exact snapshot state
- Perfect for CI/CD reproducibility

## Benefits
- **Reproducibility**: Every build starts from identical state
- **No state pollution**: Failed builds can't corrupt environment
- **No dependency drift**: Tooling versions locked to snapshot
- **Easy debugging**: Can reproduce exact build environment
- **Clean artifacts**: No leftover files from previous builds

## Implementation
1. Set up macOS VM with all required tools (Godot, Android SDK, Xcode, etc.)
2. Verify everything works correctly
3. Create snapshot of working state
4. Enable disposable flag in UTM
5. Configure GitLab Runner to use disposable VM
6. Test build reproducibility across multiple runs

## Snapshot Contents
- macOS with development tools
- Godot 4.3 custom engine
- Android SDK and NDK
- Xcode and iOS toolchain
- GitLab Runner configured
- Project dependencies cached
<!-- SECTION:DESCRIPTION:END -->
