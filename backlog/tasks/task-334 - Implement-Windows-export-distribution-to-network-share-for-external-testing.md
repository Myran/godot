---
id: task-334
title: Implement Windows export distribution to network share for external testing
status: Done
assignee: []
created_date: '2025-12-13 20:20'
updated_date: '2025-12-29 00:07'
labels:
  - windows
  - testing
  - infrastructure
  - network
  - distribution
dependencies:
  - task-295
priority: medium
ordinal: 31.25
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a workflow to copy exported Windows builds from the VM to a network-shared folder on the Mac Mini, enabling testing on physical Windows machines outside the VM environment.

## Background

**Current State:**
- Windows builds are compiled in the UTM VM (192.168.50.92)
- Exported builds remain on the VM or are copied via SSH/SCP to macOS
- No easy way to test on external Windows hardware on the network

**Goal:**
- Exported Windows builds available on a network share from Mac Mini
- External Windows machines can access and run builds directly
- Version tracking via commit hash in folder names for easy comparison

## Proposed Workflow

```
VM Build → Export → Copy to Mac Mini → Network Share → Windows Test Machine
```

**Folder Structure:**
```
/Volumes/SharedBuilds/gametwo/windows/
├── gametwo_abc123_debug/
│   ├── gametwo.exe
│   ├── *.dll
│   └── ...
├── gametwo_def456_release/
│   └── ...
└── latest_debug -> gametwo_abc123_debug/
```

## Components

1. **Mac Mini Network Share Setup**
   - Create shared folder (e.g., `/Users/Shared/GameTwoBuilds`)
   - Enable SMB sharing in System Preferences
   - Configure appropriate permissions for network access

2. **Export Copy Workflow**
   - Just recipe to copy export from VM to shared folder
   - Automatic naming with git commit short hash
   - Include build type (debug/release) in folder name
   - Create/update `latest_debug` and `latest_release` symlinks

3. **Cleanup Management**
   - Optional: Keep last N builds
   - Optional: Prune builds older than X days
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Mac Mini has a shared folder configured and accessible via SMB from Windows machines on the network
- [ ] #2 Just recipe `win-export-distribute` copies exported build from VM to network share with commit-based naming
- [ ] #3 Folder naming includes short commit hash and build type (e.g., `gametwo_abc123f_debug`)
- [ ] #4 Symlinks `latest_debug` and `latest_release` point to most recent builds
- [ ] #5 External Windows machine can access and run exported builds from network share
- [ ] #6 Documentation for network share setup and usage workflow
- [ ] #7 Optional cleanup recipe to manage old builds
<!-- AC:END -->
