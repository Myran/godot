# project/debug/actions/registrations/rtdb_actions.gd
class_name RTDBDebugActions
extends RefCounted


static func register_all(registry: DebugActionRegistry) -> void:
	# Register all RTDB debug actions
	Log.info("Registering RTDB debug actions...", {}, ["debug", "rtdb", "registration"])

	var actions_registered: int = 0
	var actions_failed: int = 0

	# Helper function to register with error checking
	var register_with_check = func(action: DebugAction, name: String = "") -> void:
		if registry.register_action(action):
			actions_registered += 1
		else:
			actions_failed += 1
			var action_name: String = (
				name if name else (action.action_name if action else "Unknown")
			)
			Log.error(
				"Failed to register RTDB action: " + action_name,
				{},
				["debug", "rtdb", "registration"]
			)

	# Basic RTDB Operations
	register_with_check.call(RTDBGetSimpleValueAction.new(), "RTDBGetSimpleValueAction")
	register_with_check.call(RTDBSetSimpleValueAction.new(), "RTDBSetSimpleValueAction")
	register_with_check.call(RTDBDeleteValueAction.new(), "RTDBDeleteValueAction")
	register_with_check.call(RTDBUpdateValueAction.new(), "RTDBUpdateValueAction")
	register_with_check.call(RTDBGetNestedPathAction.new(), "RTDBGetNestedPathAction")
	register_with_check.call(RTDBSetNestedPathAction.new(), "RTDBSetNestedPathAction")
	register_with_check.call(RTDBListChildrenAction.new(), "RTDBListChildrenAction")

	# Legacy Basic Operations (for compatibility testing) - loaded via script path
	var legacy_get_script = preload(
		"res://debug/actions/rtdb/rtdb_legacy_basic_get_simple_value_action.gd"
	)
	register_with_check.call(legacy_get_script.new(), "RTDBLegacyGetSimpleValueAction")

	var legacy_set_script = preload(
		"res://debug/actions/rtdb/rtdb_legacy_basic_set_simple_value_action.gd"
	)
	register_with_check.call(legacy_set_script.new(), "RTDBLegacySetSimpleValueAction")

	var legacy_push_script = preload(
		"res://debug/actions/rtdb/rtdb_legacy_basic_push_item_action.gd"
	)
	register_with_check.call(legacy_push_script.new(), "RTDBLegacyPushItemAction")

	# Listener Operations
	register_with_check.call(RTDBSingleValueListenerAction.new(), "RTDBSingleValueListenerAction")
	register_with_check.call(RTDBChildAddedListenerAction.new(), "RTDBChildAddedListenerAction")
	register_with_check.call(RTDBChildChangedListenerAction.new(), "RTDBChildChangedListenerAction")
	register_with_check.call(RTDBChildRemovedListenerAction.new(), "RTDBChildRemovedListenerAction")
	register_with_check.call(RTDBRemoveAllListenersAction.new(), "RTDBRemoveAllListenersAction")

	# Advanced Operations
	register_with_check.call(RTDBTransactionTestAction.new(), "RTDBTransactionTestAction")
	register_with_check.call(RTDBConcurrentOperationsAction.new(), "RTDBConcurrentOperationsAction")
	register_with_check.call(RTDBBatchOperationsAction.new(), "RTDBBatchOperationsAction")

	# Utility & Testing Operations
	register_with_check.call(RTDBPathValidationAction.new(), "RTDBPathValidationAction")
	register_with_check.call(RTDBErrorHandlingTestAction.new(), "RTDBErrorHandlingTestAction")
	register_with_check.call(RTDBLargeDataTestAction.new(), "RTDBLargeDataTestAction")

	Log.info(
		"RTDB debug actions registration completed",
		{"total_actions": actions_registered, "failed_actions": actions_failed},
		["debug", "rtdb", "registration"]
	)
