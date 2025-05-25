# Example of adding manual debug actions to a game
extends Node


# Called when the game needs to register custom debug actions
func register_custom_debug_actions() -> void:
	if not DebugManager.manual_actions:
		push_error("Manual actions registry not available")
		return

	var registry = DebugManager.manual_actions

	# Example 1: Simple action WITH a group
	registry.register_callable(
		"Print Hello World",
		func(): print("Hello, World!"),
		"Examples",
		"Simple",  # This creates a submenu
		"Prints a simple message to console"
	)

	# Example 2: Quick action WITHOUT a group
	registry.register_callable(
		"Print Time",
		func(): print("Current time: " + Time.get_time_string_from_system()),
		"Examples",
		"",  # Empty string = no group, appears directly under Examples
		"Prints current system time"
	)

	# Example 3: Cheats category - mixed grouped and ungrouped
	registry.register_callable(
		"Give 1000 Gold",
		func():
			#if has_node("/root/PlayerData"):
			#	PlayerData.gold += 1000
			Log.info("Added 1000 gold (simulated)"),
		"Cheats",
		"Currency",  # Grouped under Currency submenu
		"Adds 1000 gold to player inventory",
		true  # requires_confirmation
	)

	registry.register_callable(
		"Toggle God Mode",
		func(): Log.info("God mode toggled (simulated)"),
		"Cheats",
		"",  # No group - appears directly under Cheats for quick access
		"Toggle invincibility"
	)

	# Example 4: Settings - all ungrouped for easy access
	registry.register_callable(
		"Toggle Debug Mode",
		func():
			#GameSettings.debug_mode = not GameSettings.debug_mode
			Log.info("Debug mode toggled"),
		"Settings",
		"",  # No group
		"Toggle debug mode on/off"
	)

	registry.register_callable(
		"Show FPS",
		func():
			Engine.max_fps = 0 if Engine.max_fps == 60 else 60
			Log.info("FPS limit: %d" % Engine.max_fps),
		"Settings",
		"",  # No group
		"Toggle FPS limit"
	)

	# Example 5: Gameplay actions - organized by groups
	registry.register_callable(
		"Spawn Enemy Wave",
		_spawn_enemy_wave,
		"Gameplay",
		"Enemies",  # Grouped under Enemies
		"Spawns a wave of 5 enemies",
		true
	)

	registry.register_callable(
		"Skip Level",
		func(): Log.info("Level skipped (simulated)"),
		"Gameplay",
		"",  # No group - quick action
		"Skip current level"
	)

	# Example 6: Database actions
	registry.register_callable(
		"Clear All Caches",
		func():
			if data_source:
				data_source.clear_all_caches()
			Log.info("All caches cleared"),
		"Database",
		"Cache",  # Grouped under Cache
		"Clears all data caches"
	)

	registry.register_callable(
		"Print DB Stats",
		func(): Log.info("Database stats (simulated)"),
		"Database",
		"",  # No group - quick info
		"Show database statistics"
	)


func _spawn_enemy_wave() -> void:
	if not has_node("/root/EnemyManager"):
		Log.error("EnemyManager not found")
		return

	#for i in 5:
	#var enemy = EnemyManager.spawn_enemy("basic_enemy")
	#if enemy:
	#enemy.position = Vector2(100 + i * 50, 200)

	Log.info("Spawned 5 enemies")


# You can also create action resources programmatically
func create_action_resource_example() -> void:
	# Example with a group
	var grouped_action = ManualDebugAction.new()
	grouped_action.action_name = "Test Network Connection"
	grouped_action.category = "Network"
	grouped_action.group = "Testing"  # Will appear under Network > Testing
	grouped_action.description = "Tests connection to game server"
	grouped_action.requires_confirmation = false
	grouped_action.action_callable = func(): Log.info("Testing network...")
	# Your network test code here

	# Example without a group
	var ungrouped_action = ManualDebugAction.new()
	ungrouped_action.action_name = "Disconnect Network"
	ungrouped_action.category = "Network"
	ungrouped_action.group = ""  # Empty = appears directly under Network
	ungrouped_action.description = "Disconnect from server"
	ungrouped_action.requires_confirmation = true
	ungrouped_action.action_callable = func(): Log.info("Disconnecting...")
	# Your disconnect code here

	DebugManager.manual_actions.register_action(grouped_action)
	DebugManager.manual_actions.register_action(ungrouped_action)
