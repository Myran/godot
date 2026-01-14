---
id: task-435
title: Setup Windows Physical Machine for Building Templates
status: To Do
assignee: []
created_date: '2026-01-14 08:59'
updated_date: '2026-01-14 09:00'
labels:
  - windows
  - build-system
  - infrastructure
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Install VS2022 BuildTools, Python, SCons, Git, just, and clone repo to C:\gametwo on physical Windows machine (192.168.50.80). This enables the physical machine to build Windows templates as an alternative to the VM.

**Physical Machine:**
- Host: 192.168.50.80
- User: matti
- Repo path: C:\gametwo (same as VM)

**Prerequisites to Install:**
1. Visual Studio 2022 BuildTools with "Desktop development with C++" workload
2. Python 3.11+ with SCons (`pip install scons`)
3. Git for Windows
4. just command runner (`winget install Casey.Just`)

**After Installation:**
1. Clone repo to C:\gametwo
2. Run `just build-windows-physical-verify` to verify build environment
3. Run `just build-all-windows-physical` to test full build
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 VS2022 BuildTools installed with 'Desktop development with C++' workload
- [ ] #2 Python 3.11+ installed with SCons package
- [ ] #3 Git for Windows installed
- [ ] #4 just command runner installed
- [ ] #5 Repository cloned to C:\gametwo on physical machine
- [ ] #6 just build-windows-physical-verify passes
- [ ] #7 just build-all-windows-physical completes successfully
<!-- AC:END -->
