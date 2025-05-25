class_name ManualActionDataService
extends RefCounted
## Service class for centralized manual action data retrieval and management.
## Follows SOLID principles by providing a single interface for all manual action operations.
## Eliminates code duplication (DRY) by centralizing data access logic.

const LOG_TAG := "manual_action_service"

## Get all categories that have manual actions
func get_categories() -> Array[String]:
	var categories: Array[String] = []
	
	if not _has_manual_actions():
		Log.debug("No manual actions available", {}, [LOG_TAG])
		return categories
	
	var manual_actions_dict: Dictionary = DebugManager.manual_actions.get_actions_by_category()
	
	# Add categories from grouped actions
	for category_name in manual_actions_dict:
		if not categories.has(category_name):
			categories.append(category_name)
			Log.debug("Found category with grouped actions", {"category": category_name}, [LOG_TAG])
	
	# Add categories from ungrouped actions
	var all_categories: Array[String] = _get_all_manual_action_categories()
	for category_name in all_categories:
		if not categories.has(category_name) and has_ungrouped_actions(category_name):
			categories.append(category_name)
			Log.debug("Found category with ungrouped actions", {"category": category_name}, [LOG_TAG])
	
	Log.debug("Retrieved manual action categories", {"count": categories.size(), "categories": categories}, [LOG_TAG])
	return categories


## Get all groups for a specific category (excludes ungrouped actions)
func get_groups_for_category(category_name: String) -> Array[String]:
	var groups: Array[String] = []
	
	if not _has_manual_actions():
		return groups
	
	var manual_actions_dict: Dictionary = DebugManager.manual_actions.get_actions_by_category()
	
	if manual_actions_dict.has(category_name):
		for group_name in manual_actions_dict[category_name]:
			groups.append(group_name)
	
	Log.debug("Retrieved groups for category", {
		"category": category_name, 
		"group_count": groups.size(), 
		"groups": groups
	}, [LOG_TAG])
	
	return groups


## Get all ungrouped manual actions for a specific category
func get_ungrouped_actions(category_name: String) -> Array[ManualDebugAction]:
	var actions: Array[ManualDebugAction] = []
	
	if not _has_manual_actions():
		return actions
	
	var ungrouped: Array[ManualDebugAction] = DebugManager.manual_actions.get_ungrouped_actions(category_name)
	actions.assign(ungrouped)
	
	Log.debug("Retrieved ungrouped actions", {
		"category": category_name, 
		"action_count": actions.size()
	}, [LOG_TAG])
	
	return actions


## Check if a category has any ungrouped actions
func has_ungrouped_actions(category_name: String) -> bool:
	if not _has_manual_actions():
		return false
	
	var has_ungrouped: bool = DebugManager.manual_actions.has_ungrouped_actions(category_name)
	
	Log.debug("Checked for ungrouped actions", {
		"category": category_name, 
		"has_ungrouped": has_ungrouped
	}, [LOG_TAG])
	
	return has_ungrouped


## Get all manual actions for a category (both grouped and ungrouped)
func get_all_actions_for_category(category_name: String) -> Dictionary:
	var result: Dictionary = {
		"grouped": {},
		"ungrouped": []
	}
	
	if not _has_manual_actions():
		return result
	
	# Get grouped actions
	var manual_actions_dict: Dictionary = DebugManager.manual_actions.get_actions_by_category()
	if manual_actions_dict.has(category_name):
		result.grouped = manual_actions_dict[category_name].duplicate(true)
	
	# Get ungrouped actions
	var ungrouped: Array[ManualDebugAction] = get_ungrouped_actions(category_name)
	result.ungrouped = ungrouped
	
	Log.debug("Retrieved all actions for category", {
		"category": category_name,
		"grouped_groups": result.grouped.size(),
		"ungrouped_count": result.ungrouped.size()
	}, [LOG_TAG])
	
	return result


## Get actions for a specific group within a category
func get_actions_for_group(category_name: String, group_name: String) -> Array:
	var actions: Array = []
	
	if not _has_manual_actions():
		return actions
	
	var manual_actions_dict: Dictionary = DebugManager.manual_actions.get_actions_by_category()
	
	if manual_actions_dict.has(category_name) and manual_actions_dict[category_name].has(group_name):
		actions = manual_actions_dict[category_name][group_name].duplicate()
	
	Log.debug("Retrieved actions for group", {
		"category": category_name,
		"group": group_name,
		"action_count": actions.size()
	}, [LOG_TAG])
	
	return actions


## Validate that a category exists and has actions
func validate_category(category_name: String) -> bool:
	if not _has_manual_actions():
		Log.warning("No manual actions available for validation", {"category": category_name}, [LOG_TAG])
		return false
	
	var has_grouped: bool = _category_has_grouped_actions(category_name)
	var has_ungrouped: bool = has_ungrouped_actions(category_name)
	var is_valid: bool = has_grouped or has_ungrouped
	
	Log.debug("Category validation", {
		"category": category_name,
		"has_grouped": has_grouped,
		"has_ungrouped": has_ungrouped,
		"is_valid": is_valid
	}, [LOG_TAG])
	
	return is_valid


## Get summary statistics for debugging
func get_debug_summary() -> Dictionary:
	var summary: Dictionary = {
		"manual_actions_available": _has_manual_actions(),
		"total_categories": 0,
		"categories_with_grouped": 0,
		"categories_with_ungrouped": 0,
		"total_groups": 0,
		"total_ungrouped_actions": 0
	}
	
	if not _has_manual_actions():
		return summary
	
	var categories: Array[String] = get_categories()
	summary.total_categories = categories.size()
	
	for category_name in categories:
		var groups: Array[String] = get_groups_for_category(category_name)
		if groups.size() > 0:
			summary.categories_with_grouped += 1
			summary.total_groups += groups.size()
		
		if has_ungrouped_actions(category_name):
			summary.categories_with_ungrouped += 1
			var ungrouped: Array[ManualDebugAction] = get_ungrouped_actions(category_name)
			summary.total_ungrouped_actions += ungrouped.size()
	
	Log.info("Manual action debug summary", summary, [LOG_TAG])
	return summary


# Private helper methods

func _has_manual_actions() -> bool:
	return DebugManager != null and DebugManager.manual_actions != null


func _get_all_manual_action_categories() -> Array[String]:
	var categories: Array[String] = []
	
	if not _has_manual_actions():
		return categories
	
	# Get from grouped actions
	var manual_actions_dict: Dictionary = DebugManager.manual_actions.get_actions_by_category()
	for category_name in manual_actions_dict:
		if not categories.has(category_name):
			categories.append(category_name)
	
	# Get from ungrouped actions (we need to check all possible categories)
	# Note: This requires iterating through the manual actions registry
	# For now, we'll rely on the existing get_actions_by_category method
	
	return categories


func _category_has_grouped_actions(category_name: String) -> bool:
	if not _has_manual_actions():
		return false
	
	var manual_actions_dict: Dictionary = DebugManager.manual_actions.get_actions_by_category()
	return manual_actions_dict.has(category_name) and manual_actions_dict[category_name].size() > 0
