---
id: task-337
title: Implement GitHub Actions CI/CD with local runner orchestration
status: Consider
assignee: []
created_date: '2025-12-14 00:17'
updated_date: '2025-12-14 00:33'
labels:
  - ci-cd
  - github-actions
  - infrastructure
  - automation
  - mac-mini
  - windows-vm
dependencies:
  - task-333
  - task-295
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement CI/CD pipeline using GitHub Actions with self-hosted runners on Mac Mini. Start with a simple persistent runner architecture.

**Architecture (Phase 1 - Simple):**
- **macOS Runner** (persistent, on Mac Mini host): Runs natively, handles macOS/iOS/Android builds
- **Windows Runner** (persistent, on VM): Runs on existing Windows VM (192.168.50.92), handles MSVC builds

**Workflow:**
1. Push/PR triggers GitHub Actions workflow
2. Jobs routed to appropriate runner via labels (`macos`, `windows`)
3. Runners execute builds using existing `just` recipes

**Key Benefits:**
- Simple setup, no orchestration complexity
- No spin-up delay (runners always available)
- Leverages existing infrastructure and `just` recipes
- Easy migration path to ephemeral VMs later (see task-338)

**Future Enhancement:**
- task-338 covers optional migration to Tart + Ekiden for ephemeral macOS VMs
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Install and configure GitHub Actions runner on Mac Mini host (native macOS)
- [ ] #2 Install and configure GitHub Actions runner on Windows VM (192.168.50.92)
- [ ] #3 Create GitHub Actions workflow for CI validation (lint, format, syntax) using existing just ci-validate
- [ ] #4 Create GitHub Actions workflow for Android builds using just build-all-android
- [ ] #5 Create GitHub Actions workflow for iOS builds using just build-pipeline-ios
- [ ] #6 Create GitHub Actions workflow for Windows builds using just win-vm-templates
- [ ] #7 Create GitHub Actions workflow for running tests on target platforms
- [ ] #8 Create GitHub Actions workflow for export/release artifacts
- [ ] #9 Configure runner labels for job routing (macos, windows, android, ios)
- [ ] #10 Add runner auto-start on system boot for both runners

- [ ] #11 Document CI/CD setup and troubleshooting procedures
<!-- AC:END -->
