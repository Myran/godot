---
id: task-387
title: >-
  Update ship-android recipe with fastlane production upload and auto-deploy git
  hook
status: To Do
assignee: []
created_date: '2025-12-26 11:58'
labels:
  - ci-cd
  - fastlane
  - android
  - git-hooks
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Current State:**
- `ship-android` recipe runs `fastlane internal` (internal testing track only)
- No fastlane configuration exists in `export/android/fastlane/`
- No git hook for automatic deployment when committing to master

**Required Changes:**

1. **Fastlane Setup for Google Play Store Production**
   - Create `export/android/fastlane/Fastfile` with production lane
   - Configure `supply` or `upload_to_play_store` action for production track
   - Set up service account JSON authentication
   - Add version management and release notes handling

2. **Update justfile-cicd.justfile**
   - Modify `ship-android` recipe to use production fastlane lane
   - Add new `ship-android-internal` for testing track (if needed)

3. **Git Hook for Auto-Deploy**
   - Create `post-merge` or `post-commit` hook in `.git/hooks/`
   - Hook should detect commits to master branch
   - Trigger `just ship-android` automatically
   - Add safety checks (e.g., opt-in via commit message tag like [ship])
   - Log deployment attempts for audit trail

4. **Hook Management Recipe**
   - Add `install-ship-hook` recipe to justfile-cicd.justfile
   - Add `uninstall-ship-hook` recipe to remove hook
   - Document hook behavior and safety mechanisms

**Safety Considerations:**
- Hook should require explicit opt-in (commit message tag like `[ship]` or `[deploy]`)
- Should validate CI passed before attempting upload
- Should only trigger on actual master commits, not merges
- Add dry-run mode for testing

**Files to Modify:**
- `justfiles/justfile-cicd.justfile` - Update ship recipes, add hook management
- `.git/hooks/post-merge` - New file (created via install recipe)
- `export/android/fastlane/Fastfile` - New file
- `export/android/fastlane/Appfile` - New file
<!-- SECTION:DESCRIPTION:END -->
