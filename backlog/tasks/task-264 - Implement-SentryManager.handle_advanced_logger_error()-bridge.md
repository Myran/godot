---
id: task-264
title: Implement SentryManager.handle_advanced_logger_error() bridge
status: Open
assignee: []
created_date: '2025-11-10 09:51'
updated_date: '2025-11-10 09:52'
labels:
  - sentry
  - advanced-logger
  - integration
  - error-tracking
dependencies:
  - task-263
priority: high
---

## Description

Implement **`handle_advanced_logger_error()`** method in SentryManager to capture errors from GameTwo's Advanced Logger system and forward them to Sentry's error tracking backend.

## Context

**Integration Point:** Advanced Logger (Log autoload)
**Test Location:** `project/debug/actions/sentry/sentry_integration_bridges_action.gd:83-107`

**Current Behavior:**
- GameTwo uses `Log.error()` throughout codebase for comprehensive error logging
- Errors logged with rich metadata (tags, context dictionaries)
- Currently only logged locally, not tracked in Sentry

**Target Behavior:**
- All `Log.error()` calls automatically forwarded to Sentry
- Preserve GameTwo's rich logging context (tags, metadata)
- No code changes required in existing error logging

## Method Signature

```gdscript
func handle_advanced_logger_error(
    message: String,
    metadata: Dictionary,
    tags: Array[String]
) -> void
```

**Parameters:**
- `message` - The error message from Log.error()
- `metadata` - Context dictionary passed to Log.error()
- `tags` - Array of string tags for categorization

## Implementation Requirements

1. **Error Capture:**
   - Convert Advanced Logger error to Sentry event format
   - Preserve error message exactly as logged
   - Map metadata dictionary to Sentry extras
   - Map tags array to Sentry tags

2. **Context Preservation:**
   - Include all metadata fields as Sentry "extras"
   - Include all tags as Sentry tags
   - Maintain original timestamp
   - Preserve log level (ERROR)

3. **Sentry Integration:**
   - Use Sentry SDK's error capture API
   - Format event according to Sentry protocol
   - Handle async capture if needed
   - Gracefully handle Sentry SDK failures (don't crash game)

4. **Hook into Advanced Logger:**
   - Register as error callback/listener with Log system
   - Trigger automatically on all Log.error() calls
   - Non-blocking (don't slow down error logging)

## Test Validation

**Test Method:** `_test_advanced_logger_bridge()` in `sentry_integration_bridges_action.gd`

**Test Flow:**
1. Validates Log autoload exists and is valid
2. Calls `Log.error("Test error for Sentry bridge validation", {...}, ["sentry", "test"])`
3. Checks SentryManager has `handle_advanced_logger_error()` method
4. Expects return: `true` (bridge structure validated)

**Test Scenario:**
```gdscript
Log.error(
    "Test error for Sentry bridge validation",
    {"test": true, "bridge_test": true},
    ["sentry", "test"]
)
```

## Success Criteria

- [ ] Method `handle_advanced_logger_error()` exists in SentryManager
- [ ] Method accepts 3 parameters: message (String), metadata (Dictionary), tags (Array)
- [ ] Errors captured by Advanced Logger forwarded to Sentry
- [ ] All metadata preserved in Sentry extras
- [ ] All tags preserved in Sentry tags
- [ ] Test `_test_advanced_logger_bridge()` returns true
- [ ] Integration test shows 1/3 bridges working
- [ ] No performance impact on error logging
- [ ] Works on both desktop and Android platforms

## Technical Considerations

**Advanced Logger Integration:**
- May need to extend/modify Advanced Logger to support error callbacks
- Alternative: Hook into Log.error() at initialization
- Consider using signals for loose coupling

**Sentry SDK API:**
- Use SentrySDK.capture_message() or capture_event()
- Set level to ERROR
- Add extras via set_extra() or event modification
- Add tags via set_tag() or event modification

**Error Handling:**
- If Sentry SDK unavailable, silently fail (don't crash)
- If capture fails, log warning but continue
- Don't create infinite loop (error in error handler)

## Example Implementation (Pseudocode)

```gdscript
func handle_advanced_logger_error(
    message: String,
    metadata: Dictionary,
    tags: Array[String]
) -> void:
    if not sentry_sdk or not sentry_sdk.is_enabled():
        return  # Silently fail if Sentry not available

    # Create Sentry event
    var event = sentry_sdk.create_event()
    event.set_message(message)
    event.set_level("error")

    # Add metadata as extras
    for key in metadata:
        event.set_extra(key, metadata[key])

    # Add tags
    for tag in tags:
        event.set_tag(tag, true)  # or appropriate value

    # Capture event
    sentry_sdk.capture_event(event)
```

## Related Tasks

- **Parent:** task-263 - Implement SentryManager Engine singleton
- **Related:** task-265 - Firebase context integration
- **Related:** task-266 - Debug Coordinator compatibility

## Related Files

**Test:** `project/debug/actions/sentry/sentry_integration_bridges_action.gd:83-107`
**Advanced Logger:** `autoloads/advanced_logger/`
**Sentry SDK:** `addons/sentry/`
