---
id: task-426
title: Consolidate just logs-* commands into unified interface
status: Done
assignee: []
created_date: '2026-01-06 00:33'
updated_date: '2026-01-07 10:06'
labels:
  - justfile
  - logging
  - cli
  - developer-experience
  - documentation
dependencies: []
priority: medium
ordinal: 15000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem Statement

The justfile has 15+ log retrieval commands creating cognitive overhead:
- `just logs-errors`, `just logs-search`, `just logs-pattern`
- `just logs-android`, `just logs-desktop`, `just logs-ios`, `just logs-macos`
- `just logs-android-errors`, `just logs-desktop-errors`, `just logs-ios-errors`, `just logs-macos-errors`
- `just logs-android-device`, `just logs-android-clear`, etc.

Users struggle to remember which command to use. This creates unnecessary mental load.

## Expert Panel Consensus: Hybrid Approach ⭐

**Unified primary command:**
```bash
just logs TEST_ID                   # Smart defaults: errors + auto-platform
```

**Escape flags for advanced use:**
```bash
just logs TEST_ID --raw             # No filtering (for piping to jq/rg)
just logs TEST_ID --full            # Full content (not just errors)
just logs TEST_ID --all-platforms   # All platforms, not auto-detected
just logs TEST_ID --platform android # Explicit platform override
just logs TEST_ID --search "term"   # Search instead of errors
```

## Commands to Deprecate

Replaced by flags:
- ~~logs-android-errors~~ → `just logs TEST_ID --platform android`
- ~~logs-desktop-errors~~ → `just logs TEST_ID --platform desktop`
- ~~logs-ios-errors~~ → `just logs TEST_ID --platform ios`
- ~~logs-macos-errors~~ → `just logs TEST_ID --platform macos`

## Commands to Keep (Different Functionality)

- `logs-android-device "term"` - Live device logs (different data source)
- `logs-android-clear` - System operation, not log retrieval
- `logs-android-health` - Diagnostics, not log retrieval

## Implementation Priority

1. **Phase 1**: Add `just logs` consolidated entry point in justfile-logs.justfile
2. **Phase 2**: Add flag parsing (--raw, --full, --all-platforms, --platform, --search)
3. **Phase 3**: Deprecate platform-specific error variants (keep working, add deprecation notice)
4. **Phase 4**: Update CLAUDE.md documentation to primary `just logs` command

## Benefits

- **Fewer commands to remember** - One primary command vs 15+
- **Preserves token savings** - Smart defaults keep 98% efficiency
- **Backward compatible** - Old commands still work during transition
- **Power user escape** - --raw flag enables external tool integration
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Unified `just logs TEST_ID` command with smart defaults (errors + auto-platform)
- [x] #2 Flag parsing: --raw, --full, --all-platforms, --platform, --search
- [x] #3 Platform-specific commands work with deprecation warnings
- [x] #4 Live device commands unchanged (logs-android-device, logs-android-clear, logs-android-health)
- [x] #5 Documentation updated to primary `just logs` command
<!-- AC:END -->
