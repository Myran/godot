# project/debug/actions/registrations/cpp_firebase_actions.gd
class_name CPPFirebaseActions
extends RefCounted

# Preload the action classes
const CPPSetValueTestAction = preload("res://debug/actions/firebase_cpp/cpp_set_value_test_action.gd")
const CPPGetValueTestAction = preload("res://debug/actions/firebase_cpp/cpp_get_value_test_action.gd")
const CPPRemoveValueTestAction = preload("res://debug/actions/firebase_cpp/cpp_remove_value_test_action.gd")
const CPPSignalIntegrityTestAction = preload("res://debug/actions/firebase_cpp/cpp_signal_integrity_test_action.gd")
const CPPErrorHandlingTestAction = preload("res://debug/actions/firebase_cpp/cpp_error_handling_test_action.gd")
const CPPConcurrentOperationsTestAction = preload("res://debug/actions/firebase_cpp/cpp_concurrent_operations_test_action.gd")
const CPPLargeDataTestAction = preload("res://debug/actions/firebase_cpp/cpp_large_data_test_action.gd")
const CPPTimeoutBehaviorTestAction = preload("res://debug/actions/firebase_cpp/cpp_timeout_behavior_test_action.gd")

static func register_all(registry: DebugActionRegistry) -> void:
	Log.info("Registering C++ Firebase debug actions...", {}, ["debug", "cpp_firebase", "registration"])
	
	var counters: Array[int] = [0, 0]  # [registered, failed]
	
	# Core C++ Firebase operations
	_register_with_count(registry, CPPSetValueTestAction.new(), "CPPSetValueTestAction", counters)
	_register_with_count(registry, CPPGetValueTestAction.new(), "CPPGetValueTestAction", counters)
	_register_with_count(registry, CPPRemoveValueTestAction.new(), "CPPRemoveValueTestAction", counters)
	_register_with_count(registry, CPPSignalIntegrityTestAction.new(), "CPPSignalIntegrityTestAction", counters)
	
	# Advanced C++ Firebase operations
	_register_with_count(registry, CPPErrorHandlingTestAction.new(), "CPPErrorHandlingTestAction", counters)
	_register_with_count(registry, CPPConcurrentOperationsTestAction.new(), "CPPConcurrentOperationsTestAction", counters)
	_register_with_count(registry, CPPLargeDataTestAction.new(), "CPPLargeDataTestAction", counters)
	_register_with_count(registry, CPPTimeoutBehaviorTestAction.new(), "CPPTimeoutBehaviorTestAction", counters)
	
	Log.info("C++ Firebase debug actions registration completed", 
		{"total_actions": counters[0], "failed_actions": counters[1]}, 
		["debug", "cpp_firebase", "registration"])

static func _register_with_count(registry: DebugActionRegistry, action: DebugAction, name: String, counters: Array[int]) -> void:
	if registry.register_action(action):
		counters[0] += 1
	else:
		counters[1] += 1
		Log.error("Failed to register C++ Firebase action: " + name, {}, ["debug", "cpp_firebase", "registration"])
