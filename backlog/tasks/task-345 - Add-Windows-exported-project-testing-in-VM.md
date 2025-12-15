---
id: task-345
title: Add Windows exported project testing in VM
status: To Do
assignee: []
created_date: '2025-12-15 09:55'
updated_date: '2025-12-15 16:38'
labels:
  - windows
  - testing
  - automation
  - vm
  - config-directory
  - clean-recipe
dependencies:
  - task-336
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement test-windows-target command following macOS/desktop pattern (Option B - Config Directory):

**Implementation Plan:**

1. **Update Windows Export Preset** (already noted - change embed_pck=false)

2. **Create test-windows-target command** (in justfile-validation-enhanced-testing.justfile):
   - Follow exact same pattern as test-desktop-target/test-macos-target
   - Accept config_name parameter (with fzf selection if not provided)
   - Use _execute-test-with-analysis function
   - Support MULTI_PLATFORM_SESSION coordination

3. **Windows Test Execution Flow** (Option B - Config Directory):
   ```bash
   test-windows-target CONFIG_NAME:
     # 1. Export Windows build (creates gametwo_debug.exe + gametwo.pck)
     # 2. Copy exported .exe to Windows VM
     # 3. Deploy test config to Windows user data directory
     # 4. Run executable with --test-mode flag
     # 5. Retrieve logs from VM to logs/ directory
     # 6. Run error analysis on logs
   ```

4. **Windows VM Integration**:
   - Use existing WIN_VM_HOST (192.168.50.92) connection
   - Create /C:/gametwo/test/ directory on VM
   - Copy only .exe (PCK stays bundled)
   - Deploy config to Windows user data: `/C:/Users/[USER]/AppData/Roaming/Godot/app_userdata/gametwo/`
   - Run tests via SSH with proper Windows path formatting

5. **Create test-windows-clean command**:
   - Clean Windows user data directory
   - Remove test artifacts from VM
   - Reset to pristine state

6. **Config Deployment** (same as macOS/desktop):
   - Use _deploy-config-windows function (to be created)
   - Copy config JSON to: `C:/Users/[USER]/AppData/Roaming/Godot/app_userdata/gametwo/debug_config.json`
   - Windows app auto-loads debug_config.json on startup

7. **Update _analyze-test-errors function**:
   - Add "windows" case in platform switch statement
   - Retrieve logs from: `/C:/Users/[USER]/AppData/Roaming/Godot/app_userdata/gametwo/logs/windows_${TEST_ID}.log`
   - Apply same error analysis as other platforms

8. **Test Summary Integration**:
   - Will automatically show same summary as other platforms:
     - 📊 Windows Test Execution Summary
     - Action count, failed count, critical errors
     - Status: ✅ PASSED or ❌ FAILED
     - Duration and performance metrics
<!-- SECTION:DESCRIPTION:END -->
