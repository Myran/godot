---
id: task-338
title: Migrate CI/CD to ephemeral macOS VMs using Tart + Ekiden
status: Consider
assignee: []
created_date: '2025-12-14 00:33'
labels:
  - ci-cd
  - github-actions
  - infrastructure
  - tart
  - ekiden
  - macos
  - virtualization
dependencies:
  - task-337
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Migrate from persistent macOS runner to ephemeral VM-based runners using Tart and Ekiden. This provides clean-slate builds and better isolation.

**Why migrate:**
- Clean environment for every job (no state leakage between builds)
- Matches GitHub-hosted runner behavior (reproducible builds)
- Better isolation for multiple contributors
- Snapshot "golden images" with all tools pre-installed
- Easier to test different macOS/Xcode versions

**Technology stack:**
- **Tart**: Fast macOS VM management optimized for Apple Silicon CI/CD
- **Ekiden**: Mirego's runner orchestration framework for Tart VMs
- **Apple Virtualization Framework**: Native hypervisor (no emulation overhead)

**Migration approach:**
1. Document current Mac Mini runner environment (installed tools, versions)
2. Create Tart base image from clean macOS
3. Install toolchain: Xcode, Homebrew, Android SDK, just, etc.
4. Verify all `just` recipes work identically in VM
5. Snapshot as golden image
6. Configure Ekiden for ephemeral runner management
7. Update GitHub Actions workflows to use new runner
8. Decommission persistent runner

**Expected overhead:**
- VM boot time: ~30-60 seconds per job
- Image maintenance: Periodic updates for Xcode/tool upgrades

**Prerequisites:**
- task-337 must be working and proven stable first
- Understanding of what makes builds succeed/fail on bare metal
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Install and configure Tart on Mac Mini host
- [ ] #2 Create base macOS VM image with required toolchain (Xcode, Homebrew, Android SDK, just)
- [ ] #3 Verify all existing just recipes work correctly inside Tart VM
- [ ] #4 Configure Ekiden for ephemeral runner orchestration
- [ ] #5 Create golden image snapshot for CI builds
- [ ] #6 Update GitHub Actions workflows to use Tart-based runner
- [ ] #7 Implement image update workflow for toolchain upgrades
- [ ] #8 Document Tart/Ekiden setup and image maintenance procedures
- [ ] #9 Benchmark build times: bare metal vs Tart VM
- [ ] #10 Decommission persistent macOS runner after successful migration
<!-- AC:END -->
