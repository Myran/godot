class_name CPPFirebaseActions
extends RefCounted

const CPPSetValueTestActionClass = preload(
	"res://debug/actions/firebase_cpp/cpp_set_value_test_action.gd"
)
const CPPGetValueTestActionClass = preload(
	"res://debug/actions/firebase_cpp/cpp_get_value_test_action.gd"
)
const CPPRemoveValueTestActionClass = preload(
	"res://debug/actions/firebase_cpp/cpp_remove_value_test_action.gd"
)
const CPPSignalIntegrityTestActionClass = preload(
	"res://debug/actions/firebase_cpp/cpp_signal_integrity_test_action.gd"
)
const CPPErrorHandlingTestActionClass = preload(
	"res://debug/actions/firebase_cpp/cpp_error_handling_test_action.gd"
)
const CPPConcurrentOperationsTestActionClass = preload(
	"res://debug/actions/firebase_cpp/cpp_concurrent_operations_test_action.gd"
)
const CPPLargeDataTestActionClass = preload(
	"res://debug/actions/firebase_cpp/cpp_large_data_test_action.gd"
)
const CPPTimeoutBehaviorTestActionClass = preload(
	"res://debug/actions/firebase_cpp/cpp_timeout_behavior_test_action.gd"
)
const CPPDatabaseAvailabilityActionClass = preload(
	"res://debug/actions/firebase_cpp/cpp_database_availability_action.gd"
)

# Analytics C++ test actions
const CPPAnalyticsLogEventActionClass = preload(
	"res://debug/actions/firebase_cpp/cpp_analytics_log_event_action.gd"
)
const CPPAnalyticsUserPropertiesActionClass = preload(
	"res://debug/actions/firebase_cpp/cpp_analytics_user_properties_action.gd"
)
const CPPAnalyticsConfigActionClass = preload(
	"res://debug/actions/firebase_cpp/cpp_analytics_config_action.gd"
)

# Remote Config C++ test actions
const CPPRemoteConfigFetchActionClass = preload(
	"res://debug/actions/firebase_cpp/cpp_remote_config_fetch_action.gd"
)
const CPPRemoteConfigGetValuesActionClass = preload(
	"res://debug/actions/firebase_cpp/cpp_remote_config_get_values_action.gd"
)

# Task-434: RTDB diagnostic tests
const CPPGetValueDiagnosticActionClass = preload(
	"res://debug/actions/firebase_rtdb/cpp_rtdb_get_value_diagnostic_action.gd"
)
const CPPSetValueDiagnosticActionClass = preload(
	"res://debug/actions/firebase_rtdb/cpp_rtdb_set_value_diagnostic_action.gd"
)
const CPPRTDBBlockingGetValueActionClass = preload(
	"res://debug/actions/firebase_rtdb/cpp_rtdb_blocking_get_value_action.gd"
)


static func register_all(registry: DebugActionRegistry) -> void:
	var helper: RegistrationHelper = RegistrationHelper.new(registry, "C++ Firebase")

	# Database tests
	helper.register(CPPSetValueTestActionClass.new())
	helper.register(CPPGetValueTestActionClass.new())
	helper.register(CPPRemoveValueTestActionClass.new())
	helper.register(CPPSignalIntegrityTestActionClass.new())
	helper.register(CPPErrorHandlingTestActionClass.new())
	helper.register(CPPConcurrentOperationsTestActionClass.new())
	helper.register(CPPLargeDataTestActionClass.new())
	helper.register(CPPTimeoutBehaviorTestActionClass.new())
	helper.register(CPPDatabaseAvailabilityActionClass.new())

	# Analytics tests
	helper.register(CPPAnalyticsLogEventActionClass.new())
	helper.register(CPPAnalyticsUserPropertiesActionClass.new())
	helper.register(CPPAnalyticsConfigActionClass.new())

	# Remote Config tests
	helper.register(CPPRemoteConfigFetchActionClass.new())
	helper.register(CPPRemoteConfigGetValuesActionClass.new())

	# Task-434: RTDB diagnostic tests
	helper.register(CPPGetValueDiagnosticActionClass.new())
	helper.register(CPPSetValueDiagnosticActionClass.new())
	helper.register(CPPRTDBBlockingGetValueActionClass.new())

	helper.complete()
