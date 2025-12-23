---
id: task-359
title: Fix iOS checksum extraction in test framework
status: To Do
assignee: []
created_date: '2025-12-22 14:01'
labels:
  - test-framework
  - ios
  - checksum
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

The `_extract-checksums-unified` recipe fails during iOS test runs with "No checksums found in test logs".

## Evidence

From `20251222_104921_full-pipeline.log`:
```
📸 Checksum Validation:
======================
⚠️  Checksum extraction failed from iOS test log:
  error: Recipe `_extract-checksums-unified` failed with exit code 1
⚠️  No checksums found in test logs
This could indicate:
  • Test completed too quickly for checksum capture
  • SessionManager not logging checksums properly
  • Debug actions not being executed
```

## Impact

- iOS tests marked as failed due to checksum extraction issues
- `backend.firebase.async_pattern` on iOS affected
- Test framework reliability reduced

## Investigation Areas

1. Check if iOS logs are being captured correctly
2. Verify SessionManager checksum logging on iOS platform
3. Compare iOS log format with Android/desktop formats
4. Check timing of checksum capture vs test completion
<!-- SECTION:DESCRIPTION:END -->
