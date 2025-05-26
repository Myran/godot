class_name ManualDebugRegistry
extends Node
## Registry for manual debug actions that can be executed from the debug menu.
## Provides a flexible way to add custom debug functionality without modifying core files.

signal action_executed(action_name: String, success: bool)

## If true, ungrouped actions appear directly under their category
@export var show_ungrouped_in_category: bool = true

var _manual_actions: Dictionary = {}  # button_name -> ManualDebugAction
var _categories: Dictionary = {}  # category -> group -> Array[ManualDebugAction]
var _ungrouped_actions: Dictionary = {}  # category -> Array[ManualDebugAction] (for direct category actions)


func _ready() -> void:
	_register_default_actions()
	_scan_for_manual_actions()
	Log.info("ManualDebugRegistry initialized with %d actions" % _manual_actions.size())


## Register a manual debug action
func register_action(action: ManualDebugAction) -> void:
	if action.button_name == "":
		action.button_name = action.action_name.to_snake_case()

	_manual_actions[action.button_name] = action

	# Handle ungrouped vs grouped actions differently
	if action.group == "":
		# Ungrouped - store directly under category
		if not _ungrouped_actions.has(action.category):
			_ungrouped_actions[action.category] = []
		_ungrouped_actions[action.category].append(action)
		Log.debug(
			(
				"Registered ungrouped action: %s in category: %s"
				% [action.action_name, action.category]
			)
		)
	else:
		# Grouped - store in categories/groups hierarchy
		if not _categories.has(action.category):
			_categories[action.category] = {}
		if not _categories[action.category].has(action.group):
			_categories[action.category][action.group] = []
		_categories[action.category][action.group].append(action)
		Log.debug(
			(
				"Registered grouped action: %s in %s > %s"
				% [action.action_name, action.category, action.group]
			)
		)


## Register action using a callable
func register_callable(
	name: String,
	callable: Callable,
	category: String = "Manual",
	group: String = "",  # Optional - empty means no group
	description: String = "",
	requires_confirmation: bool = false
) -> void:
	var action := ManualDebugAction.new()
	action.action_name = name
	action.button_name = name.to_snake_case()
	action.category = category
	action.group = group
	action.description = description if description else "Execute " + name
	action.requires_confirmation = requires_confirmation
	action.action_callable = callable

	register_action(action)


## Execute action by button name
func execute_action(button_name: String) -> bool:
	if not _manual_actions.has(button_name):
		Log.warning("Manual action not found: " + button_name)
		return false

	var action: ManualDebugAction = _manual_actions[button_name]

	if action.requires_confirmation:
		# TODO: Show confirmation dialog
		Log.info("Action requires confirmation: " + action.confirmation_message)

	Log.info("Executing manual action: " + action.action_name)
	action.execute()
	action_executed.emit(action.action_name, true)
	return true


## Get all actions organized by category and group
func get_actions_by_category() -> Dictionary:
	return _categories.duplicate(true)


## Get ungrouped actions for a specific category
func get_ungrouped_actions(category: String) -> Array[ManualDebugAction]:
	var actions: Array[ManualDebugAction]
	if _ungrouped_actions.has(category):
		actions.assign(_ungrouped_actions[category].duplicate())
		return actions
	return actions


## Get all actions for a specific category (both grouped and ungrouped)
func get_actions_for_category(category: String) -> Array[ManualDebugAction]:
	var actions: Array[ManualDebugAction] = []

	# Add grouped actions
	if _categories.has(category):
		for group in _categories[category]:
			actions.append_array(_categories[category][group])

	# Add ungrouped actions
	if _ungrouped_actions.has(category):
		actions.append_array(_ungrouped_actions[category])

	return actions


## Check if category has any ungrouped actions
func has_ungrouped_actions(category: String) -> bool:
	return _ungrouped_actions.has(category) and _ungrouped_actions[category].size() > 0


## Register the default manual debug actions
func _register_default_actions() -> void:
	# Gameplay Actions - some with groups, some without
	register_callable(
		"Reset Match Level",
		func(): DebugManager.action(DebugManager.DebugEventType.EVENT_RESET_MATCH_LEVEL),
		"Gameplay",
		"",
		"Reset the current match level"  # No group
	)

	# Match Level Actions - grouped together
	for i in range(1, 6):
		register_callable(
			"Load Match Level %d" % i,
			func():
				DebugManager.action(
					DebugManager.DebugEventType.EVENT_FORCE_LOAD_MATCH_LEVEL, ["level_%02d" % i]
				),
			"Gameplay",
			"Match Levels",
			"Force load match level %d" % i
		)

	# Enemy/Debug Lineup Actions
	register_callable(
		"Populate Enemy Lineup",
		_populate_enemy_lineup,
		"Gameplay",
		"Preset Lineups",
		"Add test cards to enemy lineup"
	)

	# Database actions - mixed grouped and ungrouped
	register_callable(
		"Clear Card Cache",
		func():
			if data_source and data_source.has_method("clear_card_cache"):
				data_source.clear_card_cache()
			Log.info("Card cache cleared"),
		"Database",
		"Cache",
		"Clear the card data cache"
	)

	register_callable(
		"Toggle Local Battle DB",
		func():
			DebugManager.use_local_battle_db = not DebugManager.use_local_battle_db
			Log.info("Local battle DB: " + str(DebugManager.use_local_battle_db)),
		"Database",
		"",
		"Toggle between local and remote battle database"  # No group
	)

	# Quick Actions - all without groups (simpler organization)
	register_callable(
		"Cycle Asset Variant",
		func():
			DebugManager.asset_variant = (DebugManager.asset_variant % 3) + 1
			Log.info("Asset variant set to: " + str(DebugManager.asset_variant)),
		"Quick Actions",
		"",
		"Cycle through asset variants (1-3)"
	)

	register_callable(
		"Print Debug Info",
		func():
			Log.info("=== Debug Info ===")
			Log.info("Local DB: %s" % DebugManager.use_local_battle_db)
			Log.info("Asset Variant: %d" % DebugManager.asset_variant)
			Log.info("=================="),
		"Quick Actions",
		"",
		"Print current debug settings"
	)


## Scan for .tres files containing ManualDebugAction resources
func _scan_for_manual_actions() -> void:
	var dir_path := "res://debug/actions/manual/"
	var dir := DirAccess.open(dir_path)

	if not dir:
		Log.debug("No manual actions directory found at: " + dir_path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var resource_path := dir_path + file_name
			var resource = load(resource_path)

			if resource is ManualDebugAction:
				register_action(resource)
				Log.debug("Loaded manual action from: " + file_name)

		file_name = dir.get_next()


## Legacy function preserved from debug_manager.gd
func _populate_enemy_lineup() -> void:
	if not is_instance_valid(core) or not is_instance_valid(card_controller):
		Log.error("Cannot populate enemy lineup: core or card_controller missing")
		return

	# Create enemy cards
	for n in 3:
		var new_card = await card_controller.create_unit_from_id(str(n), 1)
		new_card.block_context = Cards.CONTEXT.LINEUP
		core.action(core.EnemyLineupAddCardEvent.new(new_card, n))

	# Create debug cards
	for n in 3:
		var new_card = await card_controller.create_unit_from_id(str(n), 1)
		new_card.block_context = Cards.CONTEXT.LINEUP
		core.action(core.DebugLineupAddCardEvent.new(new_card, n))

	Log.info("Enemy lineup populated with test cards")
