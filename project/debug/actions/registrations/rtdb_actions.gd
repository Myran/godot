# project/debug/actions/registrations/rtdb_actions.gd
class_name RTDBDebugActions
extends RefCounted


static func register_all(registry: DebugActionRegistry) -> void:
	# Register all RTDB actions using their existing implementations
	# This preserves the complex Firebase logic while enabling programmatic registration

	# Basic Operations
	_register_basic_operations(registry)

	# Listener Operations
	_register_listener_operations(registry)

	# Advanced Operations
	_register_advanced_operations(registry)

	# Legacy Operations
	_register_legacy_operations(registry)


static func _register_basic_operations(registry: DebugActionRegistry) -> void:
	# Set Simple Value
	var set_action: RTDBSetSimpleValueAction = RTDBSetSimpleValueAction.new()
	registry.register_action(set_action)

	# Get Simple Value
	var get_action: RTDBGetSimpleValueAction = RTDBGetSimpleValueAction.new()
	registry.register_action(get_action)

	# Delete Value
	var delete_action: RTDBDeleteValueAction = RTDBDeleteValueAction.new()
	registry.register_action(delete_action)

	# Update Value
	var update_action: RTDBUpdateValueAction = RTDBUpdateValueAction.new()
	registry.register_action(update_action)

	# Set Nested Path
	var nested_set_action: RTDBSetNestedPathAction = RTDBSetNestedPathAction.new()
	registry.register_action(nested_set_action)

	# Get Nested Path
	var nested_get_action: RTDBGetNestedPathAction = RTDBGetNestedPathAction.new()
	registry.register_action(nested_get_action)


static func _register_listener_operations(registry: DebugActionRegistry) -> void:
	# Child Added Listener
	var child_added_action := RTDBChildAddedListenerAction.new()
	registry.register_action(child_added_action)

	# Child Changed Listener
	var child_changed_action := RTDBChildChangedListenerAction.new()
	registry.register_action(child_changed_action)

	# Child Removed Listener
	var child_removed_action := RTDBChildRemovedListenerAction.new()
	registry.register_action(child_removed_action)

	# Single Value Listener
	var single_value_action := RTDBSingleValueListenerAction.new()
	registry.register_action(single_value_action)

	# Remove All Listeners
	var remove_listeners_action := RTDBRemoveAllListenersAction.new()
	registry.register_action(remove_listeners_action)


static func _register_advanced_operations(registry: DebugActionRegistry) -> void:
	# Batch Operations
	var batch_action := RTDBBatchOperationsAction.new()
	registry.register_action(batch_action)

	# Concurrent Operations
	var concurrent_action := RTDBConcurrentOperationsAction.new()
	registry.register_action(concurrent_action)

	# Transaction Test
	var transaction_action := RTDBTransactionTestAction.new()
	registry.register_action(transaction_action)

	# Large Data Test
	var large_data_action := RTDBLargeDataTestAction.new()
	registry.register_action(large_data_action)

	# List Children
	var list_children_action := RTDBListChildrenAction.new()
	registry.register_action(list_children_action)

	# Path Validation
	var path_validation_action := RTDBPathValidationAction.new()
	registry.register_action(path_validation_action)

	# Error Handling Test
	var error_handling_action := RTDBErrorHandlingTestAction.new()
	registry.register_action(error_handling_action)


static func _register_legacy_operations(registry: DebugActionRegistry) -> void:
	# Legacy actions now use programmatic approach instead of resource-based classes
	registry.register_action(
		(
			DebugAction
			. create("Basic Set Simple Value (Legacy)", _legacy_set_simple_value)
			. set_category("RTDB")
			. set_group("Legacy Tests")
			. set_description("Legacy test for setting a simple value in RTDB")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("Basic Get Simple Value (Legacy)", _legacy_get_simple_value)
			. set_category("RTDB")
			. set_group("Legacy Tests")
			. set_description("Legacy test for getting a simple value from RTDB")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create("Basic Push Item (Legacy)", _legacy_push_item)
			. set_category("RTDB")
			. set_group("Legacy Tests")
			. set_description("Legacy test for pushing an item to RTDB")
		)
	)


# Legacy action implementations
static func _legacy_set_simple_value() -> void:
	Log.info("RTDB Legacy: Setting simple value", {}, ["debug", "rtdb"])
	# Basic Firebase RTDB set operation would go here


static func _legacy_get_simple_value() -> void:
	Log.info("RTDB Legacy: Getting simple value", {}, ["debug", "rtdb"])
	# Basic Firebase RTDB get operation would go here


static func _legacy_push_item() -> void:
	Log.info("RTDB Legacy: Pushing item", {}, ["debug", "rtdb"])
	# Basic Firebase RTDB push operation would go here
