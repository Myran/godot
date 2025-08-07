# project/debug/actions/registrations/rtdb_actions.gd
class_name RTDBDebugActions
extends RefCounted

# Preload all RTDB action classes
const RTDBGetSimpleValueActionClass = preload(
	"res://debug/actions/rtdb/rtdb_get_simple_value_action.gd"
)
const RTDBSetSimpleValueActionClass = preload(
	"res://debug/actions/rtdb/rtdb_set_simple_value_action.gd"
)
const RTDBDeleteValueActionClass = preload("res://debug/actions/rtdb/rtdb_delete_value_action.gd")
const RTDBUpdateValueActionClass = preload("res://debug/actions/rtdb/rtdb_update_value_action.gd")
const RTDBGetNestedPathActionClass = preload(
	"res://debug/actions/rtdb/rtdb_get_nested_path_action.gd"
)
const RTDBSetNestedPathActionClass = preload(
	"res://debug/actions/rtdb/rtdb_set_nested_path_action.gd"
)
const RTDBListChildrenActionClass = preload("res://debug/actions/rtdb/rtdb_list_children_action.gd")
const RTDBPushItemActionClass = preload("res://debug/actions/rtdb/rtdb_push_item_action.gd")
const RTDBSingleValueListenerActionClass = preload(
	"res://debug/actions/rtdb/rtdb_single_value_listener_action.gd"
)
const RTDBChildAddedListenerActionClass = preload(
	"res://debug/actions/rtdb/rtdb_child_added_listener_action.gd"
)
const RTDBChildChangedListenerActionClass = preload(
	"res://debug/actions/rtdb/rtdb_child_changed_listener_action.gd"
)
const RTDBChildRemovedListenerActionClass = preload(
	"res://debug/actions/rtdb/rtdb_child_removed_listener_action.gd"
)
const RTDBRemoveAllListenersActionClass = preload(
	"res://debug/actions/rtdb/rtdb_remove_all_listeners_action.gd"
)
const RTDBTransactionTestActionClass = preload(
	"res://debug/actions/rtdb/rtdb_transaction_test_action.gd"
)
const RTDBConcurrentOperationsActionClass = preload(
	"res://debug/actions/rtdb/rtdb_concurrent_operations_action.gd"
)
const RTDBBatchOperationsActionClass = preload(
	"res://debug/actions/rtdb/rtdb_batch_operations_action.gd"
)
const RTDBPathValidationActionClass = preload(
	"res://debug/actions/rtdb/rtdb_path_validation_action.gd"
)
const RTDBErrorHandlingTestActionClass = preload(
	"res://debug/actions/rtdb/rtdb_error_handling_test_action.gd"
)
const RTDBLargeDataTestActionClass = preload(
	"res://debug/actions/rtdb/rtdb_large_data_test_action.gd"
)


static func register_all(registry: DebugActionRegistry) -> void:
	# Register all RTDB debug actions
	Log.info("Registering RTDB debug actions...", {}, ["debug", "rtdb", "registration"])

	var counters: Array[int] = [0, 0]  # [registered, failed]

	# Basic RTDB Operations
	_register_with_count(
		registry, RTDBGetSimpleValueActionClass.new(), "RTDBGetSimpleValueAction", counters
	)
	_register_with_count(
		registry, RTDBSetSimpleValueActionClass.new(), "RTDBSetSimpleValueAction", counters
	)
	_register_with_count(
		registry, RTDBDeleteValueActionClass.new(), "RTDBDeleteValueAction", counters
	)
	_register_with_count(
		registry, RTDBUpdateValueActionClass.new(), "RTDBUpdateValueAction", counters
	)
	_register_with_count(
		registry, RTDBGetNestedPathActionClass.new(), "RTDBGetNestedPathAction", counters
	)
	_register_with_count(
		registry, RTDBSetNestedPathActionClass.new(), "RTDBSetNestedPathAction", counters
	)
	_register_with_count(
		registry, RTDBListChildrenActionClass.new(), "RTDBListChildrenAction", counters
	)
	_register_with_count(registry, RTDBPushItemActionClass.new(), "RTDBPushItemAction", counters)

	# Listener Operations
	_register_with_count(
		registry,
		RTDBSingleValueListenerActionClass.new(),
		"RTDBSingleValueListenerAction",
		counters
	)
	_register_with_count(
		registry, RTDBChildAddedListenerActionClass.new(), "RTDBChildAddedListenerAction", counters
	)
	_register_with_count(
		registry,
		RTDBChildChangedListenerActionClass.new(),
		"RTDBChildChangedListenerAction",
		counters
	)
	_register_with_count(
		registry,
		RTDBChildRemovedListenerActionClass.new(),
		"RTDBChildRemovedListenerAction",
		counters
	)
	_register_with_count(
		registry, RTDBRemoveAllListenersActionClass.new(), "RTDBRemoveAllListenersAction", counters
	)

	# Advanced Operations
	_register_with_count(
		registry, RTDBTransactionTestActionClass.new(), "RTDBTransactionTestAction", counters
	)
	_register_with_count(
		registry,
		RTDBConcurrentOperationsActionClass.new(),
		"RTDBConcurrentOperationsAction",
		counters
	)
	_register_with_count(
		registry, RTDBBatchOperationsActionClass.new(), "RTDBBatchOperationsAction", counters
	)

	# Utility & Testing Operations
	_register_with_count(
		registry, RTDBPathValidationActionClass.new(), "RTDBPathValidationAction", counters
	)
	_register_with_count(
		registry, RTDBErrorHandlingTestActionClass.new(), "RTDBErrorHandlingTestAction", counters
	)
	_register_with_count(
		registry, RTDBLargeDataTestActionClass.new(), "RTDBLargeDataTestAction", counters
	)

	Log.info(
		"RTDB debug actions registration completed",
		{"total_actions": counters[0], "failed_actions": counters[1]},
		["debug", "rtdb", "registration"]
	)


static func _register_with_count(
	registry: DebugActionRegistry, action: DebugAction, name: String, counters: Array[int]
) -> void:
	# Helper function to register with error checking and count tracking
	if registry.register_action(action):
		counters[0] += 1  # registered count
	else:
		counters[1] += 1  # failed count
		var action_name: String = name if name else (action.action_name if action else "Unknown")
		Log.error(
			"Failed to register RTDB action: " + action_name, {}, ["debug", "rtdb", "registration"]
		)
