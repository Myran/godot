---
id: task-332
title: Fix gamestate checksum validation failures on macOS
status: Open
assignee: []
created_date: '2025-12-11 11:02'
labels:
  - macos
  - testing
  - gamestate
  - checksum
  - validation
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

Two gamestate test configurations are failing on macOS with checksum validation errors:
1. `gamestate-complete-save-load-cycle-test`
2. `gamestate-save-load-test`

## Symptoms

```
❌ CRITICAL: Checksum validation FAILED
Test result: FAILED (checksum validation is mandatory)
```

Both tests execute successfully but fail during checksum validation, indicating that saved/loaded game states are not matching expected checksums.

## Context

- Platform: macOS only (Android/iOS may have different behavior)
- Test Type: Automated save/load cycle validation
- Validation Type: Checksum-based state integrity verification
- Test List: `main` (part of daily development workflow)

## Impact

- Blocks daily development workflow on macOS
- 2 out of 19 test configs failing (11% failure rate in main test suite)
- Prevents verification of gamestate save/load consistency

## Investigation Needed

1. Check if checksums are platform-specific (macOS vs Android/iOS differences)
2. Verify if baseline checksums need to be updated for macOS
3. Determine if this is a legitimate code change requiring baseline update or actual bug
4. Check if timing/async issues affect state capture on macOS

## Suggested Commands

```bash
# Update baseline if changes are legitimate
just test-macos-update gamestate-complete-save-load-cycle-test
just test-macos-update gamestate-save-load-test

# Or reset if starting fresh
just test-macos-reset gamestate-complete-save-load-cycle-test
just test-macos-reset gamestate-save-load-test

# Re-test after update
just test-macos-target gamestate-complete-save-load-cycle-test
```

## Related

- See `justfiles/CLAUDE.md` for checksum baseline management guidance
- Test configurations: `tests/debug_configs/gamestate-*.json`
<!-- SECTION:DESCRIPTION:END -->
