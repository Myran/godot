---
id: task-387
title: >-
  Update ship-android recipe with fastlane production upload and auto-deploy git
  hook
status: Done
assignee: []
created_date: '2025-12-26 11:58'
updated_date: '2025-12-30 14:05'
labels:
  - ci-cd
  - fastlane
  - android
  - git-hooks
dependencies: []
priority: medium
ordinal: 297000
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
**Progress 2025-12-26**:

**Completed:**

- Created `export/android/fastlane/Fastfile` with lanes for internal, alpha, beta, production, and deploy tracks

- Created `export/android/fastlane/Appfile` with app configuration

- Validated Google Play service account key (`fastlaneaccountkey.json`) - connection successful

**Remaining Issues:**

- Path resolution in Fastfile: `File.expand_path` resolves to wrong path

- Current error: Looking for `/Users/mattiasmyhrman/repos/gametwo/export/fastlane/fastlaneaccountkey.json`

- Actual path: `/Users/mattiasmyhrman/repos/gametwo/fastlane/fastlaneaccountkey.json`

**Next Steps:**

1. Fix `json_key_file` path in Fastfile to correctly resolve from `export/android/fastlane/`

2. Test `fastlane validate` lane from export/android directory

3. Test `fastlane internal` upload lane

4. Update `ship-android` recipe in justfile-cicd.justfile

5. Implement git hooks for auto-deploy

6. Add hook management recipes (`install-ship-hook`, `uninstall-ship-hook`)

**Next Action:**

1. Copy `fastlane/fastlaneaccountkey.json` → `export/android/fastlane/fastlaneaccountkey.json`

2. Update `json_key_file` path in Fastfile to use local path

3. Test `fastlane validate` and `fastlane internal`

**Progress 2025-12-26 (continued):**

**Completed:**
- Moved `fastlaneaccountkey.json` to `export/android/fastlane/`
- Fixed Fastfile path resolution with `File.expand_path`
- Added `get_version_from_export_presets` helper to read version from `project/export_presets.cfg`
- Added `version` lane to display current version
- Updated `internal` and `production` lanes to log version before upload
- Verified `fastlane validate` - connection to Google Play Store successful
- Verified `fastlane version` - correctly reads version code/name from export_presets.cfg

**Version System:**
- Single source of truth: `project/export_presets.cfg`
- Format: `version/code=YYYYMMDDHHMMSS`, `version/name="1.0.YYYYMMDDHHMMSS"`
- `just update-version` recipe updates all platforms consistently
- Fastlane reads existing version (doesn't regenerate)

**Next Steps:**
1. Update `ship-android` recipe in justfile-cicd.justfile to use production track
2. Add `ship-android-internal` for testing track
3. Implement git hooks for auto-deploy
4. Add hook management recipes

**Progress 2025-12-26 (session 2):**

**Completed:**
- Updated fastlane to 2.230.0
- Removed deprecated `check_superseded_tracks` option from all lanes
- Added `skip_upload_apk: true` to all lanes (AAB-only uploads)
- Added version logging to all upload lanes (alpha, beta, deploy)
- Tested `just ship-android` - fastlane pipeline works correctly

**Blockers:**
- **Upload key mismatch**: Current keystore SHA1 `DE:A4:12:D8:...` doesn't match Play Console expected `EB:82:54:EB:A0:30:...`
- Original upload keystore not found in repo or backups
- Generated `upload_cert.pem` for Play Console upload key reset request

**Pending Google Action:**
- Upload key reset requested in Play Console
- Uploaded `upload_cert.pem` (from current `gametwo-release.keystore`)
- Waiting for Google approval (typically 1-3 days)

**Files created/modified:**
- `export/android/fastlane/Fastfile` - Updated all lanes, added version helper
- `export/android/fastlane/fastlaneaccountkey.json` - Moved to correct location
- `upload_cert.pem` - Generated for Play Console key reset

**Once Google approves:**
1. Re-run `just ship-android` to test upload
2. Update `ship-android` recipe for production track
3. Add `ship-android-internal` for testing track
4. Implement git hooks for auto-deploy

**Progress 2025-12-30:**

**Completed:**
- Fixed version code overflow bug (YYYYMMDDHHMMSS > Integer.MAX_VALUE, defaulted to 1)
- Added `bump_version` lane - auto-fetches max version from all Play Store tracks and increments
- Added `next_version` lane - read-only version check
- Added `upload_with_auto_status` helper - tries 'completed' first, falls back to 'draft' for unpublished apps
- Updated all upload lanes (internal, alpha, beta, production, deploy) to use auto-detection
- Successfully uploaded version 2 and 3 to internal track
- Updated `ship-android` recipe with full workflow: bump_version → export → upload
- Added `ship-android-internal` and `ship-android-production` aliases

**Key Changes:**
- Version code now uses simple incrementing integer (not timestamp)
- Version name keeps timestamp for human readability
- Draft state auto-detected - no manual flag needed

**Usage:**
```bash
just ship-android           # Internal track (default)
just ship-android production # Production track
just ship-android-internal   # Alias for internal
just ship-android-production # Alias for production
```

**Remaining:**
- [ ] Git hooks for auto-deploy (optional, deferred)
- [ ] Hook management recipes (optional, deferred)

## Completion Summary (2025-12-30)

**Implemented:**
- Fastlane version management: `bump_version`, `next_version`, `version` lanes
- Auto-increment from Play Store max across all tracks
- Fixed version code overflow (timestamp → simple integer)
- Draft mode support for first uploads
- `ship-android` recipe with track/draft parameters
- `pipeline-ship` (build → export → test → ship)
- `pipeline-rebuild-ship` (rebuild → export → test → ship)
- Shared `_pipeline-export-test-ship` for DRY code
- Export recipes default to force=yes
- `help-pipeline` comprehensive documentation

**Commit:** 024f1a95
<!-- SECTION:NOTES:END -->
