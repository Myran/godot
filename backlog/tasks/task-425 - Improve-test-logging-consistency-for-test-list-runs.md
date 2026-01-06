---
id: task-425
title: Improve test logging consistency for test list runs
status: To Do
assignee: []
created_date: '2026-01-06 00:10'
updated_date: '2026-01-06 00:32'
labels:
  - testing
  - logging
  - debug
  - test-framework
  - developer-experience
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem Statement

During test list execution, log retrieval is inconsistent and confusing:

1. **Test ID Format Inconsistency**: Tests run individually vs as part of a test list generate different test ID formats, making it hard to correlate failures
2. **logs-* Commands Can't Find List Run IDs**: `just logs-errors TEST_ID` works for individual runs but fails for test list run IDs
3. **No Test List Summary Log**: Each config creates its own log file with different timestamps, no unified view of the entire test list run
4. **@ Symbol Inconsistency**: `@firebase-auth-all` works in some contexts but not in `test-android-target`

## Current State

- Individual test: `test-android-target backend.firebase.auth.id_token` → Creates log with predictable ID
- Test list: `test-android-target firebase-auth-all` → Creates 9 separate logs with different timestamps
- No way to run `just logs-errors <test-list-run-id>` to see all failures from that run
- Developers must manually search through multiple log files to find failures

## Potential Solutions (from Expert Panel Analysis)

### Approach 1: Centralized Test Session Log (Session-based) ⭐ RECOMMENDED

Create a single master log file per test list run that aggregates all results.

**Structure:**
```
logs/test-lists/
  └── firebase-auth-all_20250106_120530.json
      ├── metadata: { test_list, platform, timestamp, duration, total_configs, passed, failed }
      ├── configs: [
        { name: "backend.firebase.auth.id_token", test_id: "...", status: "passed", duration_ms: 1006, log_file: "..." },
        { name: "backend.firebase.auth.cycle", test_id: "...", status: "failed", duration_ms: 1052, log_file: "..." }
      ]
      └── logs: "path/to/combined/android/log"
```

**Implementation:**
- Test list runner creates session ID at start: `{test_list}_{timestamp}`
- Write session metadata to JSON file before running any configs
- Append each config result to session file as it completes
- Just commands `just logs-list SESSION_ID` read this file

**Pros:**
- Single source of truth for test list runs
- Fast lookup (no parsing multiple files)
- Enables historical analysis of test runs over time
- Easy to implement (minimal changes to test framework)

**Cons:**
- Another file to manage
- Need to ensure cleanup of old session files

---

### Approach 2: Unified Test ID Namespace (ID-based)

Standardize test ID generation so list runs use predictable, queryable IDs.

**Changes:**
- Test list runs use format: `{test_list_name}_android_{timestamp}` instead of per-config timestamps
- Individual config logs named: `{test_list_name}_android_{timestamp}_{config_name}.log`
- All `logs-*` commands accept either full test ID or test list session ID
- When test list ID is provided, commands aggregate results from all member configs

**Implementation:**
```gdscript
# Test list generates session ID once
var session_id: String = "{test_list}_{platform}_{Time.get_datetime_string_from_system()}"

# Each config uses: session_id + "_" + config_name
var config_test_id: String = "{session_id}_{config_name}"

# logs-errors handles both formats:
# - Individual: logs-errors config_test_id  
# - List: logs-errors session_id (shows all failures from that run)
```

**Pros:**
- Predictable, queryable IDs
- Works with existing log retrieval commands
- No new file formats
- Backward compatible

**Cons:**
- Requires changes to ID generation in multiple places
- Test list runs still create multiple log files

---

### Approach 3: Enhanced Test List Index (Index-based)

Create a lightweight JSON index file alongside test list runs that maps configs to their logs.

**Structure:**
```json
{
  "run_id": "firebase-auth-all-android-1767656994",
  "test_list": "firebase-auth-all",
  "platform": "android",
  "timestamp": "2025-01-06T12:05:30Z",
  "duration_ms": 45000,
  "summary": { "total": 9, "passed": 7, "failed": 2 },
  "configs": [
    { "name": "backend.firebase.auth.id_token", "test_id": "...", "status": "passed", "log_file": "android_...log" },
    { "name": "backend.firebase.auth.cycle", "test_id": "...", "status": "passed", "log_file": "android_...log" }
  ]
}
```

**Just commands:**
- `just logs-list-index RUN_ID` - Shows index contents
- `just logs-failures RUN_ID` - Shows only failed configs from that run
- `just logs-test-list-run RUN_ID` - Opens aggregated logs for all configs

**Pros:**
- Minimal changes to test framework
- Index files are small and fast to parse
- Enables powerful queries (show failures, show slow tests, etc.)
- Can store additional metadata (tags, commit hash, branch)

**Cons:**
- Another file format to maintain
- Index could get out of sync with actual log files
- Still need to search for individual log files when drilling down

---

## Expert Panel Recommendation

**Approach 1 (Centralized Test Session Log)** is recommended because:

1. **Single source of truth** - One file per test list run with everything
2. **Fastest to query** - No need to parse multiple index + log files
3. **Enables analytics** - Easy to track test flakiness over time
4. **Better debugging** - Complete context in one place

Approach 2 can be implemented alongside for better ID consistency.

---

## Acceptance Criteria
<!-- AC:BEGIN -->
1. Test list runs create a session log file with metadata and all config results
2. `just logs-errors SESSION_ID` works for test list runs, showing all failures
3. Individual config logs still accessible via their specific test IDs
4. Session logs include: test list name, platform, timestamp, duration, per-config results
5. `just logs-list-recent` shows recent test list runs with their session IDs
<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 Test list runs create a session log file with metadata and all config results
- [ ] #2 just logs-errors SESSION_ID works for test list runs showing all failures
- [ ] #3 Individual config logs still accessible via their specific test IDs
- [ ] #4 Session logs include test list name platform timestamp duration per-config results
- [ ] #5 just logs-list-recent shows recent test list runs with their session IDs
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Approach 2 Deep Dive: Unified Test ID Namespace

### Current ID Generation (from codebase analysis)

**Core ID Function** (justfile-testing-core.justfile:122-143):
```bash
_shared-generate-test-id CONFIG_NAME TEST_TYPE PLATFORM="":
    TIMESTAMP=$(date +%s)
    if [[ -n "$PLATFORM" ]]; then
        TEST_ID="${CONFIG_NAME}_${PLATFORM}_${TEST_TYPE}_${TIMESTAMP}"
    else
        TEST_ID="${CONFIG_NAME}_${TEST_TYPE}_${TIMESTAMP}"
    fi
    echo "$TEST_ID"
```

**Current Formats:**
- Individual: `battle-animated_android_test_1733254472`
- Test List: `testlist-firebase-auth-all_android_1756924010`
- Each config in list gets its own timestamp (no shared session)

### Proposed Unified Format

All tests in a run share session prefix:
{SESSION}-{CONFIG}_{PLATFORM}_{TYPE}_{TIMESTAMP}

Example from firebase-auth-all test list:
```
1756924010-backend.firebase.auth.id_token_android_test_1733254472
1756924010-backend.firebase.auth.cycle_android_test_1733254473
1756924010-backend.firebase.auth.anonymous_check_android_test_1733254474
           └────────────────────────────────────────────────────┘
           Same session prefix groups all configs
```

### Implementation Changes

| File | Change |
|------|--------|
| justfile-testing-core.justfile:122-143 | Add session prefix from MULTI_PLATFORM_SESSION |
| justfile-logs.justfile:141-161 | Support session prefix pattern matching |
| justfile-cross-platform-testing.justfile:2286 | Use session prefix instead of testlist- prefix |

### Key Benefits

1. Session grouping - Filter all tests from run: just logs-errors "1756924010-*"
2. Cross-platform - Same session ID works across Android/iOS/Desktop
3. Backward compatible - Can detect old vs new format
4. No new files - Just changes to ID generation logic
<!-- SECTION:NOTES:END -->
