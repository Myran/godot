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
const BackendIsolatedPushOnlyTestActionClass = preload(
	"res://debug/actions/firebase_backend/isolated_push_only_test_action.gd"
)
const BackendIsolatedGetOnlyTestActionClass = preload(
	"res://debug/actions/firebase_backend/isolated_get_only_test_action.gd"
)
const BackendIsolatedSetValueTestActionClass = preload(
	"res://debug/actions/firebase_backend/isolated_set_value_test_action.gd"
)


static func register_all(registry: DebugActionRegistry) -> void:
	var helper: RegistrationHelper = RegistrationHelper.new(registry, "Backend Firebase")

	helper.register(BackendAsyncPatternTestActionClass.new())
	helper.register(BackendTimerManagerTestActionClass.new())
	helper.register(BackendMethodMappingTestActionClass.new())
	helper.register(BackendLifecycleTestActionClass.new())
	helper.register(BackendErrorHandlingTestActionClass.new())
	helper.register(BackendPerformanceTestActionClass.new())
	helper.register(BackendRequestTrackingTestActionClass.new())
	helper.register(BackendIsolatedPushOnlyTestActionClass.new())
	helper.register(BackendIsolatedGetOnlyTestActionClass.new())
	helper.register(BackendIsolatedSetValueTestActionClass.new())

	helper.complete()
