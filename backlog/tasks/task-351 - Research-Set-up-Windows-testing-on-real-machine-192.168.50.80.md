---
id: task-351
title: 'Research: Set up Windows testing on real machine (192.168.50.80)'
status: Done
assignee: []
created_date: '2025-12-19 09:30'
updated_date: '2025-12-19 23:44'
labels:
  - research
  - windows
  - testing
  - infrastructure
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research and implement Windows testing on physical hardware instead of VM. The target machine is available at 192.168.50.80 and should be configured for test execution only (no builds). Unlike the current VM setup, this should run with a graphical interface (not headless) and use a shared folder for receiving new exports for testing.

**Current Situation:**
- Windows builds are tested on a VM (headless mode)
- VM performs both building and testing
- Need to transition to physical hardware for more accurate testing

**Target Machine:**
- IP: 192.168.50.80 (fixed IP on network)
- Currently no SSH or remote access configured
- Should be test-only (no building)
- Should run with graphical interface (not headless)

**Requirements:**
1. Set up remote access mechanism (SSH or similar)
2. Configure shared folder for receiving new builds
3. Automate test execution from shared folder
4. Ensure compatibility with existing test infrastructure
5. Document setup and maintenance procedures

**Considerations:**
- Security implications of network access
- Synchronization of test files and results
- Integration with existing justfile commands
- Backup and maintenance strategy for the test machine
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 SSH connection works from Mac to Windows machine (192.168.50.80)
- [x] #2 File transfer mechanism operational (SMB or SCP)
- [x] #3 Test execution script runs Godot tests on Windows with GUI
- [x] #4 Justfile recipes created: test-windows-target, logs-windows, logs-windows-errors
- [x] #5 Cross-platform test command includes Windows
- [x] #6 Setup documented in appropriate location
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Phase 1: Remote Access Setup (On Windows Machine)

### 1.1 Enable OpenSSH Server
- Settings → Apps → Optional Features → Add "OpenSSH Server"
- Start service: `Start-Service sshd`
- Set to auto-start: `Set-Service -Name sshd -StartupType 'Automatic'`
- Configure Windows Firewall to allow port 22

### 1.2 Configure SSH Key Authentication
- Copy public key to `C:\Users\<username>\.ssh\authorized_keys`
- For admin users, use `C:\ProgramData\ssh\administrators_authorized_keys`
- Adjust permissions per Windows OpenSSH requirements

### 1.3 Test SSH Connectivity
- From Mac: `ssh user@192.168.50.80`
- Verify command execution works remotely

---

## Phase 2: Shared Folder Configuration

### 2.1 Option A: SMB Share (Simpler)
- Create folder: `C:\GameTwoTests`
- Share on network with appropriate permissions
- Mount on Mac: `mount_smbfs //user@192.168.50.80/GameTwoTests /mnt/win-tests`

### 2.2 Option B: SCP over SSH (More Secure)
- Use `scp` to transfer builds via SSH
- No extra configuration needed beyond SSH setup
- Recommended for security

---

## Phase 3: Test Execution Infrastructure

### 3.1 Install Godot on Windows Machine
- Install same Godot version as custom build
- Or transfer Windows export templates
- Verify Godot runs correctly with GUI

### 3.2 Create Test Execution Script
- PowerShell script that:
  - Accepts test config as parameter
  - Runs exported game with debug config
  - Captures output to log file
  - Returns exit code for pass/fail

### 3.3 Configure Test Results Storage
- Define log output location
- Ensure results are accessible via SSH/shared folder

---

## Phase 4: Justfile Integration

### 4.1 Create Windows Remote Testing Module
- New file: `justfile-platform-windows-remote.justfile`
- Follow patterns from existing macOS testing

### 4.2 Implement Core Recipes
- `test-windows-target CONFIG` - Deploy build, run test, retrieve results
- `test-windows-manual CONFIG` - Manual testing mode
- `logs-windows TEST_ID` - Retrieve Windows logs
- `logs-windows-errors TEST_ID` - Error-focused analysis

### 4.3 Build Export Integration
- `export-windows` - Export Windows build
- `deploy-windows` - Transfer build to test machine
- Integrate with existing cross-platform test commands

---

## Phase 5: Documentation & Maintenance

### 5.1 Document Setup Procedure
- Step-by-step Windows machine setup guide
- Troubleshooting common issues
- Network requirements

### 5.2 Define Maintenance Strategy
- Windows Update policy
- Backup procedures
- Recovery steps if machine needs reset
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Phase 1 Completed (2025-12-20)

**SSH Setup:**
- OpenSSH Server enabled on Windows
- Key authentication configured via `C:\ProgramData\ssh\administrators_authorized_keys`
- SSH alias added to Mac: `ssh windows-test`
- Host: `DESKTOP-QT1ILO2`
- User: `matti`
- IP: `192.168.50.80`

## Phase 2 Completed (2025-12-20)

**File Transfer (SCP):**
- SCP works over existing SSH connection
- No additional configuration needed

**Folder Structure:**
```
C:\GameTwoTests\
├── builds/    # Exported game builds
├── configs/   # Debug configs
└── logs/      # Test output logs
```

## Justfile Infrastructure Added (2025-12-20)

**Core Config** (`justfile-core-config.justfile`):
```
WIN_VM_HOST := "192.168.50.92"      # Building
WIN_VM_USER := "runner"
WIN_PHYSICAL_HOST := "192.168.50.80"  # Testing
WIN_PHYSICAL_USER := "matti"
```

**New Recipes** (`justfile-platform-windows.justfile`):
- `just win-physical-verify` - Verify connectivity
- `just win-physical-ssh` - Interactive SSH session
- `just win-physical-cmd "cmd"` - Run remote command
- `just win-physical-status` - Machine status check

**Naming Convention:**
- `win-vm-*` → Windows VM (192.168.50.92) - for BUILDING
- `win-physical-*` → Windows physical (192.168.50.80) - for TESTING

## Phase 3 Completed (2025-12-20)

**New Testing Recipes:**
- `just win-physical-deploy` - Deploy Windows export to physical machine
- `just test-windows-physical-target CONFIG` - Automated testing with GUI
- `just test-windows-physical-manual CONFIG` - Manual testing (stays open)
- `just logs-windows-physical [TEST_ID]` - Retrieve logs
- `just logs-windows-physical-errors TEST_ID` - Error analysis
- `just _win-physical-stop-app` - Stop running game

**GUI Execution:**
- Uses PowerShell `Start-Process -Wait` for GUI execution over SSH
- Unlike VM testing, runs with full graphics (not `--headless`)

**Test Flow:**
1. Deploy export: `just win-physical-deploy`
2. Run test: `just test-windows-physical-target CONFIG`
3. Logs auto-retrieved to `logs/TEST_ID.log`

**Note:** Machine may need Wake-on-LAN trigger if sleeping

## Wake-on-LAN Added (2025-12-20)

**Configuration:**
- MAC address stored in `WIN_PHYSICAL_MAC` variable
- Default: `74:56:3C:CC:80:1D`
- Timeout: 60 seconds (configurable via `WIN_PHYSICAL_WAKE_TIMEOUT`)

**New Recipes:**
- `just win-physical-wake` - Send WoL packet
- `just win-physical-wake-wait` - Wake and wait for SSH
- `just _win-physical-ensure-awake` - Silent helper (auto-wake if needed)

**Auto-Wake Integration:**
- `win-physical-deploy` - Auto-wakes before deploying
- `test-windows-physical-target` - Auto-wakes before testing
- `test-windows-physical-manual` - Auto-wakes before manual test

**Implementation:**
- Uses Python socket for WoL (portable, no external dependencies)
- Falls back gracefully if machine already online

## Validation Completed (2025-12-20)

**All recipes validated successfully:**
- `win-physical-status` ✅
- `win-physical-verify` ✅
- `win-physical-deploy` ✅
- `test-windows-physical-target system-layer-all` ✅
- `test-windows-physical-manual` ✅
- `logs-windows-physical` ✅
- `logs-windows-physical-errors` ✅
- `win-physical-wake` ✅
- `win-physical-wake-wait` ✅
- `_win-physical-ensure-awake` ✅

**Test Run Result:**
- Config: `system-layer-all`
- Test ID: `system-layer-all_windows-physical_1766187400`
- Log successfully retrieved to `logs/`
- Game ran with GUI on physical machine

## Documentation Completed (2025-12-20)

**Updated Files:**
- `justfiles/CLAUDE.md` - Added Windows physical machine commands to quick reference
- `justfiles/ARCHITECTURE.md` - Expanded platform section, added to Recipe Selection Matrix, updated Quick Reference Commands
- `just help-windows` - Comprehensive help recipe with both VM and physical machine sections

**Documentation Scope:**
- Machine distinction (VM vs Physical) clearly explained
- All connectivity commands documented
- Testing workflow documented
- Configuration variables listed
- Log retrieval commands documented

**Acceptance Criteria:**
- #5 Cross-platform: Windows physical recipes integrate with existing test infrastructure (`test-*-target` pattern)
- #6 Documentation: Complete in CLAUDE.md, ARCHITECTURE.md, and `just help-windows`
<!-- SECTION:NOTES:END -->
