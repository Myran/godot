---
id: task-390
title: Add Sentry dSYM upload to build pipeline
status: Done
assignee: []
created_date: '2025-12-27 12:39'
updated_date: '2025-12-31 01:03'
labels:
  - sentry
  - build-system
  - ios
  - macos
  - crash-reporting
dependencies: []
priority: medium
ordinal: 299000
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
- DSN is configured in `project/project.godot`
- **sentry-cli is NOT installed**
- **SENTRY_ORG/SENTRY_PROJECT/SENTRY_AUTH_TOKEN NOT configured**

## Implementation Steps

### Step 1: Install sentry-cli
```bash
brew install getsentry/tools/sentry-cli
```

### Step 2: Configure Sentry CLI credentials
Create `.sentryclirc` in project root (gitignored):
```ini
[auth]
token=YOUR_AUTH_TOKEN

[defaults]
org=YOUR_ORG_SLUG
project=YOUR_PROJECT_SLUG
```

Or use environment variables:
- `SENTRY_AUTH_TOKEN` - Get from Sentry → Settings → Auth Tokens
- `SENTRY_ORG` - Organization slug (URL path, not numeric ID)
- `SENTRY_PROJECT` - Project slug (URL path, not numeric ID)

### Step 3: Add justfile recipes for dSYM upload
Add to `justfiles/justfile-sentry.justfile`:
```bash
# Upload iOS dSYMs to Sentry
sentry-upload-dsym-ios:
    sentry-cli debug-files upload --include-sources \
        project/addons/sentry/bin/ios/dSYMs/

# Upload macOS dSYMs to Sentry  
sentry-upload-dsym-macos:
    sentry-cli debug-files upload --include-sources \
        project/addons/sentry/bin/macos/dSYMs/

# Upload all dSYMs
sentry-upload-dsym-all:
    just sentry-upload-dsym-ios
    just sentry-upload-dsym-macos
```

### Step 4: Integrate with Fastlane ship lanes (optional)
Add `sentry_debug_files_upload` to iOS/Android Fastfiles for automatic upload during release.

## dSYM Locations
- **iOS**: `project/addons/sentry/bin/ios/dSYMs/` (6 dSYM bundles, 45 MB)
- **macOS**: `project/addons/sentry/bin/macos/dSYMs/` (3 dSYM bundles, 102 MB)

## Documentation
- https://docs.sentry.io/platforms/apple/guides/ios/configuration/options/debug-files/
- `sentry-cli debug-files upload --help`
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 sentry-cli installed via Homebrew
- [x] #2 Sentry auth token configured (env var or .sentryclirc)
- [x] #3 SENTRY_ORG and SENTRY_PROJECT configured
- [x] #4 Add .sentryclirc to .gitignore
- [x] #5 Create sentry-upload-dsym-ios recipe

- [x] #6 Create sentry-upload-dsym-macos recipe
- [x] #7 Create sentry-upload-dsym-all recipe
- [x] #8 Integrate upload into build-sentry-gdscript-* recipes (optional)
- [x] #9 Verify crash reports show symbolicated stack traces
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Pipeline Integration (2025-12-31)

Integrated dSYM upload into `ship-ios` recipe in `justfiles/justfile-cicd.justfile`.

Now when running `just ship-ios`, it will:
1. Export PCK for iOS
2. Run fastlane beta (App Store upload)
3. Upload iOS dSYMs to Sentry automatically

For macOS: Use `just sentry-upload-dsym-macos` manually (no ship-macos recipe exists yet).
<!-- SECTION:NOTES:END -->
