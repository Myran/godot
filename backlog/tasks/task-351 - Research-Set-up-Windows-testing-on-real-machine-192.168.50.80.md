---
id: task-351
title: 'Research: Set up Windows testing on real machine (192.168.50.80)'
status: To Do
assignee: []
created_date: '2025-12-19 09:30'
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
