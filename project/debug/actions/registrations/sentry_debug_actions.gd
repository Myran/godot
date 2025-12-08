class_name SentryDebugActions
extends RefCounted

const SentryAddonValidationActionClass = preload(
	"res://debug/actions/sentry/sentry_addon_validation_action.gd"
)

const SentryCrashTestingActionClass = preload(
	"res://debug/actions/sentry/sentry_crash_testing_action.gd"
)

const SentryRealCrashTestActionClass = preload(
	"res://debug/actions/sentry/sentry_real_crash_test_action.gd"
)

const SentryIntegrationBridgesActionClass = preload(
	"res://debug/actions/sentry/sentry_integration_bridges_action.gd"
)

const SentryIntegrationTestActionClass = preload(
	"res://debug/actions/sentry/sentry_integration_test_action.gd"
)


static func register_all(registry: DebugActionRegistry) -> void:
	var helper: RegistrationHelper = RegistrationHelper.new(registry, "Sentry Debug")

	helper.register(SentryAddonValidationActionClass.new())
	helper.register(SentryCrashTestingActionClass.new())
	helper.register(SentryRealCrashTestActionClass.new())
	helper.register(SentryIntegrationBridgesActionClass.new())
	helper.register(SentryIntegrationTestActionClass.new())

	helper.complete()
