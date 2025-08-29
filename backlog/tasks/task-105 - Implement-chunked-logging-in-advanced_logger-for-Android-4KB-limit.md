---
id: task-105
title: Implement chunked logging in advanced_logger for Android 4KB limit
status: To Do
assignee: []
created_date: '2025-08-28 20:14'
updated_date: '2025-08-28 20:14'
labels:
  - android
  - logging
  - debug
dependencies: []
priority: high
---

## Description

Implement automatic chunking of large log entries in the advanced_logger addon to handle Android's ~4KB kernel log entry limit, preventing truncation of gamestate captures and other large debug logs

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] Log entries >3.5KB are automatically split into multiple chunks
- [ ] Chunks preserve original message structure with continuation markers
- [ ] JSON strings are split at appropriate boundaries (not mid-object)
- [ ] Backward compatibility maintained with existing logging calls
- [ ] Android capture-gamestate command can reassemble chunked logs
- [ ] Chunked logs are properly formatted and identifiable in logcat
<!-- AC:END -->

## Technical Context

**Problem**: Android kernel imposes ~4KB limit on log entries (LOGGER_ENTRY_MAX_PAYLOAD), causing large gamestate captures and debug logs to be truncated in logcat output.

**Root Cause**: The advanced_logger addon currently sends entire log messages as single entries, which get silently truncated by Android's logging system when they exceed the kernel buffer limit.

**Solution**: Implement intelligent chunking within the logger that automatically splits large entries while preserving message integrity and reassembly capability.

## Implementation Requirements

**Core Files to Modify:**
- `project/addons/advanced_logger/core/logger.gd` - Main chunking logic
- `project/addons/advanced_logger/core/log_formatter.gd` - Chunk formatting
- Update justfile Android log commands to handle multi-part reassembly

**Chunking Strategy:**
- Detect log entries approaching 3.5KB threshold (safety margin below 4KB limit)
- Split preferentially at natural JSON boundaries (after complete objects/arrays)
- Add chunk headers: `[CHUNK 1/3] [MSG_ID: abc123]` for reassembly
- Maintain original timestamp and log level for each chunk
- Preserve indentation and formatting where possible

**Backward Compatibility:**
- Existing logger.debug(), logger.info(), etc. calls work unchanged
- Small log entries (<3.5KB) are sent as single messages (no performance impact)
- Only large entries trigger chunking behavior

**Android Integration:**
- Update `just capture-gamestate` command to reassemble chunks based on MSG_ID
- Ensure chunk detection works reliably in justfile log parsing
- Test with actual Android logcat buffer behavior
