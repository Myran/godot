---
id: task-390
title: Add Sentry dSYM upload to build pipeline
status: To Do
assignee: []
created_date: '2025-12-27 12:39'
labels:
  - sentry
  - build-system
  - ios
  - macos
  - crash-reporting
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Summary
Crash symbolication requires dSYM files to be uploaded to Sentry. Currently dSYMs are built but not uploaded, causing crash reports to show raw memory addresses instead of function names.

## Current State
- dSYMs exist locally (147 MB total):
  - `project/addons/sentry/bin/macos/dSYMs/` (102 MB)
  - `project/addons/sentry/bin/ios/dSYMs/` (45 MB)
- dSYMs are NOT shipped in app bundles (correct)
- dSYMs are NOT uploaded to Sentry (missing)

## Implementation
Add `sentry-cli` upload step to build pipeline:

```bash
# Install sentry-cli (one-time)
brew install getsentry/tools/sentry-cli

# Upload dSYMs after build
sentry-cli upload-dif --org ORG --project PROJECT path/to/dSYMs/
```

## Integration Points
- `just build-sentry-gdscript-desktop` → upload macOS dSYMs
- `just build-sentry-gdscript-template-ios` → upload iOS dSYMs
- Fastlane lanes (`ship-ios`, `ship-android`) → upload at release time

## Requirements
- Sentry auth token (environment variable `SENTRY_AUTH_TOKEN`)
- Sentry org/project configuration
- Decide: upload at build time vs release time
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 sentry-cli installed and configured with auth token
- [ ] #2 macOS dSYMs uploaded after desktop Sentry build
- [ ] #3 iOS dSYMs uploaded after iOS Sentry build
- [ ] #4 Upload integrated into fastlane ship lanes
- [ ] #5 Verify crash reports show symbolicated stack traces
<!-- AC:END -->
