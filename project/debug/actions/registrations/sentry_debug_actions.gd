class_name SentryDebugActions
extends RefCounted

const SentryAddonValidationActionClass = preload(
	"res://debug/actions/sentry/sentry_addon_validation_action.gd"
)

const SentryCrashTestingActionClass = preload(
	"res://debug/actions/sentry/sentry_crash_testing_action.gd"
)

const SentryIntegrationBridgesActionClass = preload(
	"res://debug/actions/sentry/sentry_integration_bridges_action.gd"
)

const SentryIntegrationTestActionClass = preload(
	"res://debug/actions/sentry/sentry_integration_test_action.gd"
)


static func register_all(registry: DebugActionRegistry) -> void:
	Log.info("Registering Sentry Debug actions...", {}, ["debug", "sentry_debug", "registration"])

	var counters: Array[int] = [0, 0]  # [registered, failed]

	_register_with_count(
		registry, SentryAddonValidationActionClass.new(), "SentryAddonValidationAction", counters
	)

	_register_with_count(
		registry, SentryCrashTestingActionClass.new(), "SentryCrashTestingAction", counters
	)

	_register_with_count(
		registry,
		SentryIntegrationBridgesActionClass.new(),
		"SentryIntegrationBridgesAction",
		counters
	)

	_register_with_count(
		registry, SentryIntegrationTestActionClass.new(), "SentryIntegrationTestAction", counters
	)

	Log.info(
		"Sentry Debug actions registration completed",
		{"total_actions": counters[0], "failed_actions": counters[1]},
		["debug", "sentry_debug", "registration"]
	)


static func _register_with_count(
	registry: DebugActionRegistry, action: DebugAction, name: String, counters: Array[int]
) -> void:
	if registry.register_action(action):
		counters[0] += 1
	else:
		counters[1] += 1
		Log.error(
			"Failed to register Sentry Debug action: " + name,
			{},
			["debug", "sentry_debug", "registration"]
		)
