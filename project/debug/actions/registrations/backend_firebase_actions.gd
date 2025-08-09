class_name BackendFirebaseActions
extends RefCounted

const BackendAsyncPatternTestActionClass = preload(
	"res://debug/actions/firebase_backend/backend_async_pattern_test_action.gd"
)
const BackendTimerManagerTestActionClass = preload(
	"res://debug/actions/firebase_backend/backend_timer_manager_test_action.gd"
)
const BackendMethodMappingTestActionClass = preload(
	"res://debug/actions/firebase_backend/backend_method_mapping_test_action.gd"
)
const BackendErrorHandlingTestActionClass = preload(
	"res://debug/actions/firebase_backend/backend_error_handling_test_action.gd"
)
const BackendPerformanceTestActionClass = preload(
	"res://debug/actions/firebase_backend/backend_performance_test_action.gd"
)
const BackendLifecycleTestActionClass = preload(
	"res://debug/actions/firebase_backend/backend_lifecycle_test_action.gd"
)
const BackendRequestTrackingTestActionClass = preload(
	"res://debug/actions/firebase_backend/backend_request_tracking_test_action.gd"
)


static func register_all(registry: DebugActionRegistry) -> void:
	Log.info(
		"Registering Backend Firebase debug actions...",
		{},
		["debug", "backend_firebase", "registration"]
	)

	var counters: Array[int] = [0, 0]  # [registered, failed]

	_register_with_count(
		registry,
		BackendAsyncPatternTestActionClass.new(),
		"BackendAsyncPatternTestAction",
		counters
	)
	_register_with_count(
		registry,
		BackendTimerManagerTestActionClass.new(),
		"BackendTimerManagerTestAction",
		counters
	)
	_register_with_count(
		registry,
		BackendMethodMappingTestActionClass.new(),
		"BackendMethodMappingTestAction",
		counters
	)
	_register_with_count(
		registry, BackendLifecycleTestActionClass.new(), "BackendLifecycleTestAction", counters
	)

	_register_with_count(
		registry,
		BackendErrorHandlingTestActionClass.new(),
		"BackendErrorHandlingTestAction",
		counters
	)
	_register_with_count(
		registry, BackendPerformanceTestActionClass.new(), "BackendPerformanceTestAction", counters
	)
	_register_with_count(
		registry,
		BackendRequestTrackingTestActionClass.new(),
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
