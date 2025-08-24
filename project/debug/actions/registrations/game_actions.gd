class_name GameDebugActions
extends RefCounted


static func register_all(registry: DebugActionRegistry) -> void:
	_register_gameplay_actions(registry)
	_register_match_level_actions(registry)
	_register_lineup_actions(registry)
	_register_battle_actions(registry)
	_register_database_actions(registry)
	_register_quick_actions(registry)

	Log.info("Game debug actions registered", {}, ["debug", "game"])


static func _register_gameplay_actions(registry: DebugActionRegistry) -> void:
	registry.register_action(
		(
			DebugAction
			. create(
				"game.match.reset_level",
				GameActionCore._reset_match_level
			)
			. set_category("Gameplay")
			. set_description("Reset the current match level")
		)
	)


static func _register_match_level_actions(registry: DebugActionRegistry) -> void:
	registry.register_action(
		(
			DebugAction
			. create(
				"game.match.load_level_1",
				func() -> bool: return GameActionCore._load_match_level(1)
			)
			. set_category("Gameplay")
			. set_group("Match Levels")
			. set_description("Force load match level 1")
		)
	)
	registry.register_action(
		(
			DebugAction
			. create(
				"game.match.load_level_2",
				func() -> bool: return GameActionCore._load_match_level(2)
			)
			. set_category("Gameplay")
			. set_group("Match Levels")
			. set_description("Force load match level 2")
		)
	)
	registry.register_action(
		(
			DebugAction
			. create(
				"game.match.load_level_3",
				func() -> bool: return GameActionCore._load_match_level(3)
			)
			. set_category("Gameplay")
			. set_group("Match Levels")
			. set_description("Force load match level 3")
		)
	)
	registry.register_action(
		(
			DebugAction
			. create("game.match.load_level_4", func() -> bool: return _load_match_level(4))
			. set_category("Gameplay")
			. set_group("Match Levels")
			. set_description("Force load match level 4")
		)
	)
	registry.register_action(
		(
			DebugAction
			. create("game.match.load_level_5", func() -> bool: return _load_match_level(5))
			. set_category("Gameplay")
			. set_group("Match Levels")
			. set_description("Force load match level 5")
		)
	)


static func _register_lineup_actions(registry: DebugActionRegistry) -> void:
	registry.register_action(
		(
			DebugAction
			. create(
				"game.lineup.populate_enemy",
				GameActionCore._populate_enemy_lineup
			)
			. set_category("Gameplay")
			. set_group("Preset Lineups")
			. set_description("Add test cards to enemy lineup")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create(
				"game.test.simple_player_events",
				GameActionCore._test_simple_player_events
			)
			. set_category("Gameplay")
			. set_group("Test")
			. set_description("Simple test to validate action registration")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create(
				"game.lineup.populate_enemy_as_player",
				GameActionCore._populate_enemy_lineup_as_player
			)
			. set_category("Gameplay")
			. set_group("Test")
			. set_description("Populate enemy lineup using fake PLAYER events to test recording")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create(
				"game.board.reset_state",
				GameActionCore._reset_board_state
			)
			. set_category("Gameplay")
			. set_group("Board State")
			. set_description("Reset board to initial state for deterministic testing")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create(
				"game.draft.reroll_player",
				GameActionPlayer._reroll_player
			)
			. set_category("Gameplay")
			. set_group("Player Actions")
			. set_description("Simulate player reroll action")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create(
				"game.draft.upgrade_player",
				GameActionPlayer._upgrade_player
			)
			. set_category("Gameplay")
			. set_group("Player Actions")
			. set_description("Simulate player upgrade action")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create(
				"game.draft.toggle_column_player",
				GameActionPlayer._toggle_column_player
			)
			. set_category("Gameplay")
			. set_group("Player Actions")
			. set_description("Simulate player column toggle action")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create(
				"game.lineup.move_card_player",
				GameActionPlayer._move_card_player
			)
			. set_category("Gameplay")
			. set_group("Player Actions")
			. set_description("Simulate player card move action")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create(
				"game.draft.move_card_to_lineup_player",
				GameActionPlayer._move_card_to_lineup_player
			)
			. set_category("Gameplay")
			. set_group("Player Actions")
			. set_description("Atomic draft-to-lineup move operation")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create(
				"game.state.transition_player",
				GameActionPlayer._transition_player
			)
			. set_category("Gameplay")
			. set_group("Player Actions")
			. set_description("Simulate player state transition action")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create(
				"game.battle.start_player",
				GameActionPlayer._start_battle_player
			)
			. set_category("Gameplay")
			. set_group("Player Actions")
			. set_description("Simulate player battle start action")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create(
				"game.draft.remove_block_player",
				GameActionPlayer._remove_block_player
			)
			. set_category("Gameplay")
			. set_group("Player Actions")
			. set_description("Simulate player block removal action")
		)
	)


static func _register_battle_actions(registry: DebugActionRegistry) -> void:
	registry.register_action(
		(
			DebugAction
			. create(
				"game.battle.start",
				GameActionCore._start_battle
			)
			. set_category("Gameplay")
			. set_group("Battle")
			. set_description("Start battle and wait for completion")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create(
				"game.battle.populate_enemy_and_start",
				GameActionCore._populate_enemy_and_start_battle
			)
			. set_category("Gameplay")
			. set_group("Battle")
			. set_description("Populate enemy lineup then start battle")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create(
				"game.battle.test_determinism_animated",
				GameActionCore._battle_test_determinism
			)
			. set_category("Gameplay")
			. set_group("Battle")
			. set_description("Test battle determinism with full animation (comprehensive)")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create(
				"game.battle.test_determinism_logic_only",
				GameActionCore._battle_test_determinism_logic_only
			)
			. set_category("Gameplay")
			. set_group("Battle")
			. set_description("Test battle determinism with logic-only execution (fast)")
		)
	)


static func _register_database_actions(registry: DebugActionRegistry) -> void:
	registry.register_action(
		(
			DebugAction
			. create(
				"game.cache.clear_cards",
				GameActionCore._clear_card_cache
			)
			. set_category("Database")
			. set_group("Cache")
			. set_description("Clear the card data cache")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create(
				"game.database.toggle_local_battle",
				GameActionCore._toggle_local_battle_db
			)
			. set_category("Database")
			. set_description("Toggle between local and remote battle database")
		)
	)


static func _register_quick_actions(registry: DebugActionRegistry) -> void:
	registry.register_action(
		(
			DebugAction
			. create(
				"game.debug.cycle_asset_variant",
				GameActionCore._cycle_asset_variant
			)
			. set_category("Quick Actions")
			. set_description("Cycle through asset variants (1-3)")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create(
				"game.debug.print_info",
				GameActionCore._print_debug_info
			)
			. set_category("Quick Actions")
			. set_description("Print current debug settings")
		)
	)

	registry.register_action(
		(
			DebugAction
			. create(
				"game.debug.hide_debug_menu",
				GameActionCore._hide_debug_menu
			)
			. set_category("Quick Actions")
			. set_description("Hide the debug menu interface")
		)
	)

