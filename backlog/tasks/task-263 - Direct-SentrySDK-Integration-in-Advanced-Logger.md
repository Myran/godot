---
id: task-263
title: Direct SentrySDK Integration in Advanced Logger
status: Done
assignee: []
created_date: '2025-11-10 09:51'
updated_date: '2025-11-11 20:31'
labels:
  - sentry
  - integration
  - advanced-logger
  - error-tracking
dependencies: []
priority: high
---

## Description

Implement **direct SentrySDK integration** in Advanced Logger to automatically forward error and critical logs to Sentry without requiring an intermediate wrapper layer.

## Context

**Expert Panel Decision (2025-11-10):**
- Virtual expert panel unanimously rejected SentryManager wrapper approach
- Recommended direct SentrySDK integration pattern (consistent with user feedback form)
- Reduces implementation time from 40-60h to 2-4h (83% reduction)
- Eliminates architectural complexity and technical debt

**Current State:**
- Sentry SDK integrated via GDExtension addon
- SentrySDK singleton accessible: `Engine.get_singleton("SentrySDK")`
- User feedback form already uses direct pattern: `SentrySDK.capture_feedback()` (proof of concept)
- Advanced Logger (`addons/advanced_logger/core/logger.gd`) is autoload

**Evidence:**
- See `/tmp/task-263-expert-panel-evaluation.md` for complete analysis
- User feedback form: `project/addons/sentry/user_feedback/user_feedback_form.gd:71`

## Required Implementation

### **Modify Advanced Logger to Call SentrySDK Directly**

Add Sentry forwarding to error and critical methods in `logger.gd`:

```gdscript
# In addons/advanced_logger/core/logger.gd

func error(message: String, context: Dictionary = {}, tags: Array = []) -> void:
	_log(LogLevel.ERROR, message, context, tags)

	# Forward to Sentry if enabled
	_forward_to_sentry(message, "error", context, tags)

func critical(message: String, context: Dictionary = {}, tags: Array = []) -> void:
	_log(LogLevel.CRITICAL, message, context, tags)

	# Forward to Sentry if enabled
	_forward_to_sentry(message, "fatal", context, tags)

func _forward_to_sentry(message: String, level: String, context: Dictionary, tags: Array) -> void:
	# Only forward if Sentry is available
	if not Engine.has_singleton("SentrySDK"):
		return

	var sentry: Variant = Engine.get_singleton("SentrySDK")
	if not sentry:
		return

	# Check if Sentry forwarding is enabled in config
	if not _config.get("sentry_enabled", true):
		return

	# Capture message with level
	if sentry.has_method("capture_message"):
		sentry.capture_message(message, level)

	# Add context if available
	if context.size() > 0 and sentry.has_method("set_context"):
		sentry.set_context("log_context", context)

	# Add tags if available
	if tags.size() > 0 and sentry.has_method("set_tags"):
		var tag_dict: Dictionary = {}
		for tag in tags:
			tag_dict[tag] = true
		sentry.set_tags(tag_dict)
```

### **Add Configuration Option**

Add to Advanced Logger config to enable/disable Sentry forwarding:

```gdscript
# In advanced_logger config
{
	"sentry_enabled": true,  # Set to false to disable Sentry forwarding
	# ... existing config
}
```

## Success Criteria

- [ ] `error()` method forwards to `SentrySDK.capture_message()` with level "error"
- [ ] `critical()` method forwards to `SentrySDK.capture_message()` with level "fatal"
- [ ] Context dictionary forwarded to `SentrySDK.set_context()`
- [ ] Tags array forwarded to `SentrySDK.set_tags()`
- [ ] Config flag `sentry_enabled` controls forwarding behavior
- [ ] Graceful handling if SentrySDK not available
- [ ] Test validation passes on desktop and Android
- [ ] No performance regression in logging hot path

## Technical Considerations

**Performance:**
- Check `Engine.has_singleton()` only once per log call
- Early return if Sentry not available (minimal overhead)
- No additional GDExtension compilation required

**Error Handling:**
- Sentry forwarding failures must not break logging
- Use `has_method()` checks before calling SDK methods
- Silent failure if Sentry unavailable

**Platform Compatibility:**
- Works wherever SentrySDK singleton exists
- No platform-specific code needed (handled by official SDK)
- Same code for desktop, Android, iOS

## Related Work

**Modified Files:**
- `project/addons/advanced_logger/core/logger.gd` - Add Sentry forwarding

**Test Files:**
- `project/debug/actions/sentry/sentry_integration_bridges_action.gd` - Update to validate direct integration

**Reference Implementation:**
- `project/addons/sentry/user_feedback/user_feedback_form.gd:71` - Direct SentrySDK usage pattern

## Dependencies

This task replaces the previous approach:
- ~~task-264: Implement handle_advanced_logger_error()~~ - No longer needed (direct integration)
- task-265: Add Firebase user context (independent task)
- task-266: Create Sentry debug actions (independent task)

## Estimated Effort

**2-4 hours** (vs 40-60 hours for GDExtension wrapper approach)

- Implementation: 1-2 hours
- Testing: 1 hour
- Documentation: 0.5 hour
- Cross-platform validation: 0.5 hour

## Expert Panel Recommendation

See `/tmp/task-263-expert-panel-evaluation.md` for complete analysis.

**Key Benefits:**
- ✅ Consistent with GameTwo's direct-access architecture pattern
- ✅ No GDExtension wrapper maintenance burden
- ✅ Zero additional runtime overhead
- ✅ Automatic updates when official Sentry SDK updates
- ✅ Simpler testing (one integration point vs two layers)
