# project/debug/actions/registrations/backend_firebase_actions.gd
class_name BackendFirebaseActions
extends RefCounted

# Preload the action classes
const BackendAsyncPatternTestAction = preload(
	"res://debug/actions/firebase_backend/backend_async_pattern_test_action.gd"
)
const BackendTimerManagerTestAction = preload(
	"res://debug/actions/firebase_backend/backend_timer_manager_test_action.gd"
)
const BackendMethodMappingTestAction = preload(
	"res://debug/actions/firebase_backend/backend_method_mapping_test_action.gd"
)
const BackendErrorHandlingTestAction = preload(
	"res://debug/actions/firebase_backend/backend_error_handling_test_action.gd"
)
const BackendPerformanceTestAction = preload(
	"res://debug/actions/firebase_backend/backend_performance_test_action.gd"
)
const BackendLifecycleTestAction = preload(
	"res://debug/actions/firebase_backend/backend_lifecycle_test_action.gd"
)
const BackendRequestTrackingTestAction = preload(
	"res://debug/actions/firebase_backend/backend_request_tracking_test_action.gd"
)


static func register_all(registry: DebugActionRegistry) -> void:
	Log.info(
		"Registering Backend Firebase debug actions...",
		{},
		["debug", "backend_firebase", "registration"]
	)

	var counters: Array[int] = [0, 0]  # [registered, failed]

	# Core Backend Firebase operations
	_register_with_count(
		registry, BackendAsyncPatternTestAction.new(), "BackendAsyncPatternTestAction", counters
	)
	_register_with_count(
		registry, BackendTimerManagerTestAction.new(), "BackendTimerManagerTestAction", counters
	)
	_register_with_count(
		registry, BackendMethodMappingTestAction.new(), "BackendMethodMappingTestAction", counters
	)
	_register_with_count(
		registry, BackendLifecycleTestAction.new(), "BackendLifecycleTestAction", counters
	)

	# Advanced Backend Firebase operations
	_register_with_count(
		registry, BackendErrorHandlingTestAction.new(), "BackendErrorHandlingTestAction", counters
	)
	_register_with_count(
		registry, BackendPerformanceTestAction.new(), "BackendPerformanceTestAction", counters
	)
	_register_with_count(
		registry,
		BackendRequestTrackingTestAction.new(),
		"BackendRequestTrackingTestAction",
		counters
	)

	Log.info(
		"Backend Firebase debug actions registration completed",
		{"total_actions": counters[0], "failed_actions": counters[1]},
		["debug", "backend_firebase", "registration"]
	)


static func _register_with_count(
	registry: DebugActionRegistry, action: DebugAction, name: String, counters: Array[int]
) -> void:
	if registry.register_action(action):
		counters[0] += 1
	else:
		counters[1] += 1
		Log.error(
			"Failed to register Backend Firebase action: " + name,
			{},
			["debug", "backend_firebase", "registration"]
		)
