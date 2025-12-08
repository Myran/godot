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


static func register_all(registry: DebugActionRegistry) -> void:
	var helper := RegistrationHelper.new(registry, "C++ Firebase")

	helper.register(CPPSetValueTestActionClass.new())
	helper.register(CPPGetValueTestActionClass.new())
	helper.register(CPPRemoveValueTestActionClass.new())
	helper.register(CPPSignalIntegrityTestActionClass.new())
	helper.register(CPPErrorHandlingTestActionClass.new())
	helper.register(CPPConcurrentOperationsTestActionClass.new())
	helper.register(CPPLargeDataTestActionClass.new())
	helper.register(CPPTimeoutBehaviorTestActionClass.new())
	helper.register(CPPDatabaseAvailabilityActionClass.new())

	helper.complete()
