# project/debug/actions/registrations/rtdb_actions.gd
class_name RTDBDebugActions
extends RefCounted


static func register_all(registry: DebugActionRegistry) -> void:
	# Register all RTDB debug actions
	Log.info("Registering RTDB debug actions...", {}, ["debug", "rtdb", "registration"])

	var counters: Array[int] = [0, 0]  # [registered, failed]

	# Basic RTDB Operations
	_register_with_count(
		registry, RTDBGetSimpleValueAction.new(), "RTDBGetSimpleValueAction", counters
	)
	_register_with_count(
		registry, RTDBSetSimpleValueAction.new(), "RTDBSetSimpleValueAction", counters
	)
	_register_with_count(registry, RTDBDeleteValueAction.new(), "RTDBDeleteValueAction", counters)
	_register_with_count(registry, RTDBUpdateValueAction.new(), "RTDBUpdateValueAction", counters)
	_register_with_count(
		registry, RTDBGetNestedPathAction.new(), "RTDBGetNestedPathAction", counters
	)
	_register_with_count(
		registry, RTDBSetNestedPathAction.new(), "RTDBSetNestedPathAction", counters
	)
	_register_with_count(registry, RTDBListChildrenAction.new(), "RTDBListChildrenAction", counters)

	# Legacy Basic Operations (for compatibility testing) - loaded via script path
	var legacy_get_script: GDScript = preload(
		"res://debug/actions/rtdb/rtdb_legacy_basic_get_simple_value_action.gd"
	)
	var legacy_get_action: DebugAction = legacy_get_script.new()  # Fail fast if not DebugAction
	_register_with_count(registry, legacy_get_action, "RTDBLegacyGetSimpleValueAction", counters)

	var legacy_set_script: GDScript = preload(
		"res://debug/actions/rtdb/rtdb_legacy_basic_set_simple_value_action.gd"
	)
	var legacy_set_action: DebugAction = legacy_set_script.new()  # Fail fast if not DebugAction
	_register_with_count(registry, legacy_set_action, "RTDBLegacySetSimpleValueAction", counters)

	var legacy_push_script: GDScript = preload(
		"res://debug/actions/rtdb/rtdb_legacy_basic_push_item_action.gd"
	)
	var legacy_push_action: DebugAction = legacy_push_script.new()  # Fail fast if not DebugAction
	_register_with_count(registry, legacy_push_action, "RTDBLegacyPushItemAction", counters)

	# Listener Operations
	_register_with_count(
		registry, RTDBSingleValueListenerAction.new(), "RTDBSingleValueListenerAction", counters
	)
	_register_with_count(
		registry, RTDBChildAddedListenerAction.new(), "RTDBChildAddedListenerAction", counters
	)
	_register_with_count(
		registry, RTDBChildChangedListenerAction.new(), "RTDBChildChangedListenerAction", counters
	)
	_register_with_count(
		registry, RTDBChildRemovedListenerAction.new(), "RTDBChildRemovedListenerAction", counters
	)
	_register_with_count(
		registry, RTDBRemoveAllListenersAction.new(), "RTDBRemoveAllListenersAction", counters
	)

	# Advanced Operations
	_register_with_count(
		registry, RTDBTransactionTestAction.new(), "RTDBTransactionTestAction", counters
	)
	_register_with_count(
		registry, RTDBConcurrentOperationsAction.new(), "RTDBConcurrentOperationsAction", counters
	)
	_register_with_count(
		registry, RTDBBatchOperationsAction.new(), "RTDBBatchOperationsAction", counters
	)

	# Utility & Testing Operations
	_register_with_count(
		registry, RTDBPathValidationAction.new(), "RTDBPathValidationAction", counters
	)
	_register_with_count(
		registry, RTDBErrorHandlingTestAction.new(), "RTDBErrorHandlingTestAction", counters
	)
	_register_with_count(
		registry, RTDBLargeDataTestAction.new(), "RTDBLargeDataTestAction", counters
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
