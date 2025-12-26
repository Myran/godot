---
id: task-383
title: Sentry Test Coverage Gap Analysis and Enhancement Plan
status: To Do
assignee: []
created_date: '2025-12-26 09:12'
labels:
  - sentry
  - testing
  - coverage-analysis
  - documentation
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Overview

Comprehensive analysis of Sentry integration capabilities vs current test coverage in GameTwo.

---

## Current Sentry Capabilities

### SentryHelper API (project/utils/sentry_helper.gd)

| Method | Purpose | Parameters |
|--------|---------|------------|
| `is_available()` | Check SDK availability | - |
| `get_sdk()` | Get SDK singleton | - |
| `capture_message(msg, level)` | Send message | level: debug/info/warning/error/fatal |
| `set_user(user_dict)` | Set user context | id, email, username |
| `set_tag(key, value)` | Set single tag | key, value strings |
| `set_tags(tags_dict)` | Set multiple tags | Dictionary |
| `set_context(name, data)` | Set structured context | name, Dictionary |

### Platform-Specific Features

| Feature | Android | iOS | Windows | Desktop |
|---------|---------|-----|---------|---------|
| Crash Reporting | ✅ | ✅ | ✅ (crashpad) | ✅ |
| Message Capture | ✅ | ✅ | ✅ | ✅ |
| User Context | ✅ | ✅ | ✅ | ✅ |
| Tagging | ✅ | ✅ | ✅ | ✅ |
| Contextual Data | ✅ | ✅ | ✅ | ✅ |
| Auto-init | ✅ (AAR) | ❌ | ❌ | ❌ |
| Breadcrumbs | ✅ | ✅ | ✅ | ✅ |
| Screenshot Capture | ✅ | ✅ | ✅ | ✅ |
| Session Replay | ✅ (100%/10%) | ✅ | ❓ | ✅ |
| Performance Monitor | ✅ | ✅ | ✅ | ✅ |
| UI Profiling | ✅ | ❓ | ❓ | ✅ |

### Integration Points

1. **Advanced Logger Bridge** - Log.error() → SentryHelper.capture_message()
2. **Firebase Auth Integration** - Login → SentryHelper.set_user()
3. **Debug Coordinator** - All Sentry debug actions registered

---

## Current Test Coverage

### Debug Actions (5 total)

| Action | What It Tests | Status |
|--------|---------------|--------|
| `sentry.validate_gdextension_loading` | GDExtension files, native binaries present | ✅ Solid |
| `sentry.test_sdk_functionality` | ClassDB, singleton, init(), capture_message() | ✅ Solid |
| `sentry.test_crash_scenarios` | 4 crash scenarios (null ref, bounds, resource, type) | ⚠️ Simulated only |
| `sentry.test_integration_bridges` | Logger, Firebase, Debug Coordinator bridges | ✅ Basic |
| Real crash test | Actual crash generation | ⚠️ Manual only |

### Test Configs (10 total)

- sentry-addon-validation, sentry-android-file-validation
- sentry-integration-test, sentry-android-integration-test
- sentry-crash-scenarios, sentry-real-crash-test
- sentry-integration-bridges
- TDD configs: sentry.test_sdk_functionality, sentry.test_integration_bridges

### Test Lists (4 total)

- sentry-core-validation (3 configs, 2-3 min)
- sentry-android, sentry-desktop (platform-specific)
- sentry-all (6 configs, 5-10 min) - **Now in main test suite**

---

## GAP ANALYSIS

### 🔴 Critical Gaps

**1. SentryHelper API Methods Not Tested**
- `set_user()` - User context setting never validated
- `set_tag()` / `set_tags()` - Tag functionality untested
- `set_context()` - Context setting untested
- Message levels - Only "error" level tested, not debug/info/warning/fatal

**2. Crash Testing is Simulated (TDD Placeholders)**
- Current `sentry.test_crash_scenarios` uses safe checks that DON'T crash
- No verification crashes reach Sentry dashboard
- No actual GDScript exception capture testing

**3. No End-to-End Verification**
- Tests don't verify events appear in Sentry dashboard
- No API check for received events
- Integration tests assume success without confirmation

### 🟡 Medium Gaps

**4. Platform-Specific Features Untested**
- iOS: Native SDK specifics not covered
- Windows: Crashpad backend functionality not tested
- Android: AAR features (breadcrumbs, replays, profiling) not tested

**5. Edge Case Handling**
- Sentry unavailable scenario (defensive patterns)
- Network failure during event capture
- Rate limiting behavior

**6. Performance Monitoring**
- No tests for performance transaction capture
- No span/trace testing

### 🟢 Minor Gaps

**7. Firebase → Sentry User Flow**
- Integration bridge tests availability, not actual flow
- No test for user context appearing in Sentry events

**8. Breadcrumb Recording**
- Automatic breadcrumbs enabled but not tested
- No verification breadcrumbs appear with crashes

---

## Recommended New Tests

### Priority 1: SentryHelper API Tests

```
sentry.test_helper_api
├── test_is_available()
├── test_capture_message_all_levels (debug, info, warning, error, fatal)
├── test_set_user() with valid user dict
├── test_set_user() with empty dict (clear)
├── test_set_tag()
├── test_set_tags()
└── test_set_context()
```

### Priority 2: Actual Crash Capture Tests

```
sentry.test_real_crash_capture
├── Generate actual GDScript exception
├── Verify exception captured by Sentry
├── Check stack trace present
└── Verify metadata attached
```

### Priority 3: Defensive Pattern Tests

```
sentry.test_unavailable_handling
├── Test all methods return false when Sentry unavailable
├── Verify no crashes when Sentry disabled
└── Test graceful degradation
```

### Priority 4: Platform-Specific Tests

```
sentry.test_windows_crashpad (windows-physical only)
├── Verify crashpad_handler.exe present
├── Test out-of-process crash handling

sentry.test_android_aar (android only)
├── Verify auto-initialization
├── Test breadcrumb recording
└── Test screenshot on crash
```

---

## Implementation Approach

1. **Phase 1**: Create `sentry_helper_api_test_action.gd` for SentryHelper coverage
2. **Phase 2**: Enhance crash testing with actual exception generation
3. **Phase 3**: Add platform-specific test actions
4. **Phase 4**: Create Sentry dashboard verification (optional, requires API key)

---

## Evidence

Analysis performed on 2025-12-26 examining:
- `/project/utils/sentry_helper.gd` - 219 lines, 7 public methods
- `/project/debug/actions/sentry/*.gd` - 5 debug actions
- `/tests/debug_configs/sentry-*.json` - 10 configs
- `/tests/test-lists/sentry-*.json` - 4 test lists
- `/justfiles/justfile-*sentry*.justfile` - 5 justfiles, 40+ recipes
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 SentryHelper API test action created covering all 7 methods
- [ ] #2 All 5 message levels tested (debug, info, warning, error, fatal)
- [ ] #3 set_user, set_tag, set_tags, set_context methods have dedicated tests
- [ ] #4 Crash testing enhanced beyond TDD placeholders
- [ ] #5 Platform-specific tests added for Windows crashpad
- [ ] #6 Defensive pattern tests verify graceful handling when Sentry unavailable
- [ ] #7 Test coverage documented in tests/CLAUDE.md Sentry section
<!-- AC:END -->
