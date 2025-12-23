---
id: task-368
title: Clarify Windows VM vs Windows Physical naming in documentation
status: To Do
assignee: []
created_date: '2025-12-23 22:59'
updated_date: '2025-12-23 23:43'
labels:
  - documentation
  - windows
  - naming
  - phase-2
dependencies:
  - task-376
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

The naming distinction between Windows VM and Windows Physical can be confusing:

**Current:**
- `test-windows-target` → VM/local Windows testing
- `test-windows-physical-target` → Physical machine (192.168.50.80) GUI testing

The `test-windows-*` commands suggest general Windows testing, but they're actually for the VM.

## Impact

- Users may not realize there are two different Windows test environments
- Confusion about which commands to use

## Solution

**Option A (Documentation only):**
- Add clear documentation explaining the two-machine architecture
- Update help commands to clarify VM vs Physical distinction

**Option B (Recipe rename - more disruptive):**
- Rename `test-windows-*` → `test-windows-vm-*`
- Keep `test-windows-physical-*` as-is
- Add deprecation aliases

**Recommendation:** Start with Option A (documentation), consider Option B if confusion persists.

## Reference

Part of platform parity analysis - Phase 2 Naming Standardization.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Order: Wave 6 (Documentation)

## Chunked Validation

### Chunk 1: Update CLAUDE.md Windows Section
Add clear explanation:
```markdown
## 🪟 Windows Development

**Windows uses a two-machine architecture:**
- **Windows VM (192.168.50.92)** - `win-vm-*` recipes - Template building with native MSVC
- **Windows Physical (192.168.50.80)** - `win-physical-*` / `test-windows-physical-*` - GUI testing

**Recipe Naming:**
- `test-windows-*` - Tests on VM (headless capable)
- `test-windows-physical-*` - Tests on physical machine (GUI mode)
```

Validate: Read CLAUDE.md, confirm clarity

### Chunk 2: Update help-windows
```bash
# Add explanation to just help-windows output
# Validate
just help-windows | grep -A5 "two-machine"
```

### Chunk 3: Update ARCHITECTURE.md
Add Windows section explaining the split architecture.

Validate: `rg "VM.*Physical|Physical.*VM" justfiles/ARCHITECTURE.md`
<!-- SECTION:PLAN:END -->
