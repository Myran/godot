---
id: task-336
title: Setup UTM macOS VM with GitLab Runner for automated CI/CD on master merges
status: Consider
assignee: []
created_date: '2025-12-13 23:51'
updated_date: '2025-12-14 23:02'
labels:
  - infrastructure
  - ci-cd
  - automation
  - gitlab
dependencies:
  - task-335
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a UTM macOS VM on the Mac Mini with a GitLab Runner that automatically picks up and executes test, build, and export jobs when changes are merged to master.

## Goals
- Set up UTM macOS VM on Mac Mini with GitLab Runner
- Configure runner to trigger on master branch merges
- Automate test execution (Android, desktop, macOS)
- Automate build pipelines (templates, APK, AAB, iOS, macOS exports)
- Handle export jobs for release artifacts

## Why macOS VM
- Required for Xcode/iOS builds
- Required for macOS .app/.dmg exports
- Native Apple toolchain access
- Consistent with host Mac Mini environment

## Pipeline Jobs
- **Test jobs**: Run `just test-android-target`, `just test-desktop-target`, `just test-macos-target`
- **Build jobs**: Run `just build-all-android`, `just build-pipeline-ios`, macOS exports
- **Export jobs**: Generate APK, AAB, IPA, DMG artifacts
- **Validation**: Run `just ci-validate` checks

## Requirements
- UTM with macOS guest VM
- GitLab Runner installation and registration
- Android SDK, Xcode, Godot toolchain installed in VM
- Artifact storage for build outputs
- Notification on build success/failure
<!-- SECTION:DESCRIPTION:END -->
