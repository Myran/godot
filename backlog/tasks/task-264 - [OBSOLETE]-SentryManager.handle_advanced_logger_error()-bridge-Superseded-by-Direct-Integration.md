---
id: task-264
title: >-
  [OBSOLETE] SentryManager.handle_advanced_logger_error() bridge - Superseded by
  Direct Integration
status: Done
assignee: []
created_date: '2025-11-10 09:51'
updated_date: '2025-11-10 23:12'
labels:
  - sentry
  - advanced-logger
  - integration
  - error-tracking
  - obsolete
dependencies: []
priority: high
---

## Description

## Status: Won't Implement

**Reason:** Superseded by simplified direct integration approach in task-263.

**Expert Panel Decision (2025-11-10):**
- Virtual expert panel unanimously rejected SentryManager wrapper pattern
- Recommended direct SentrySDK integration in Advanced Logger
- This task is no longer needed - functionality implemented directly in Advanced Logger

**See:** `/tmp/task-263-expert-panel-evaluation.md` for complete analysis

---

## Original Description (OBSOLETE)

~~Implement **`handle_advanced_logger_error()`** method in SentryManager to capture errors from GameTwo's Advanced Logger system and forward them to Sentry's error tracking backend.~~

## Replacement Implementation

**Instead of creating a bridge method, Advanced Logger now calls SentrySDK directly:**

```gdscript
# In addons/advanced_logger/core/logger.gd

func error(message: String, context: Dictionary = {}, tags: Array = []) -> void:
	_log(LogLevel.ERROR, message, context, tags)

	# Direct SentrySDK integration - no bridge needed
	if Engine.has_singleton("SentrySDK"):
		var sentry = Engine.get_singleton("SentrySDK")
		if sentry and sentry.has_method("capture_message"):
			sentry.capture_message(message, "error")
			if context.size() > 0:
				sentry.set_context("log_context", context)
```

**Benefits of Direct Integration:**
- ✅ No additional method/layer needed
- ✅ Zero wrapper overhead
- ✅ Consistent with GameTwo's direct-access pattern
- ✅ Simpler to maintain and test
- ✅ Implementation time: 1-2 hours vs 8-12 hours for bridge

## Migration Notes

All functionality originally planned for this task is now implemented in:
- **task-263**: Direct SentrySDK Integration in Advanced Logger

No separate bridge method needed - Advanced Logger owns its own error forwarding logic.

---

## Original Context (ARCHIVED)

**Integration Point:** Advanced Logger (Log autoload)
**Test Location:** `project/debug/actions/sentry/sentry_integration_bridges_action.gd:83-107`

**Original Behavior:**
- GameTwo uses `Log.error()` throughout codebase for comprehensive error logging
- Errors logged with rich metadata (tags, context dictionaries)
- Currently only logged locally, not tracked in Sentry

**New Behavior (Direct Integration):**
- All `Log.error()` calls automatically forward to SentrySDK
- No intermediate bridge layer
- No code changes required in existing error logging

## Why This Approach Was Rejected

**From Expert Panel Analysis:**

1. **Senior Systems Architect:**
   - Wrapper anti-pattern: Adds unnecessary layer
   - User feedback form already uses direct pattern as proof of concept

2. **Platform Integration Specialist:**
   - No platform compatibility benefit
   - Increases build complexity without value

3. **Test Infrastructure Lead:**
   - Harder to test two layers vs direct integration
   - Test can validate SentrySDK directly

4. **Technical Debt Reviewer:**
   - Creates maintenance burden
   - Architectural inconsistency (only Sentry wrapped, not Firebase/Log/etc)

5. **Performance Engineer:**
   - Additional method call overhead per error (~5-10μs)
   - No performance benefit

## Related Tasks

- **Superseded by:** task-263 - Direct SentrySDK Integration in Advanced Logger
- **Independent:** task-265 - Add Firebase user context to Sentry
- **Independent:** task-266 - Create Sentry debug actions
