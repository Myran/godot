class_name RTDBDebugActions
extends RefCounted

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
	var helper: RegistrationHelper = RegistrationHelper.new(registry, "RTDB")

	helper.register(RTDBGetSimpleValueActionClass.new())
	helper.register(RTDBSetSimpleValueActionClass.new())
	helper.register(RTDBDeleteValueActionClass.new())
	helper.register(RTDBUpdateValueActionClass.new())
	helper.register(RTDBGetNestedPathActionClass.new())
	helper.register(RTDBSetNestedPathActionClass.new())
	helper.register(RTDBListChildrenActionClass.new())
	helper.register(RTDBPushItemActionClass.new())
	helper.register(RTDBSingleValueListenerActionClass.new())
	helper.register(RTDBChildAddedListenerActionClass.new())
	helper.register(RTDBChildChangedListenerActionClass.new())
	helper.register(RTDBChildRemovedListenerActionClass.new())
	helper.register(RTDBRemoveAllListenersActionClass.new())
	helper.register(RTDBTransactionTestActionClass.new())
	helper.register(RTDBConcurrentOperationsActionClass.new())
	helper.register(RTDBBatchOperationsActionClass.new())
	helper.register(RTDBPathValidationActionClass.new())
	helper.register(RTDBErrorHandlingTestActionClass.new())
	helper.register(RTDBLargeDataTestActionClass.new())

	helper.complete()
