class_name Game extends Control

signal initialization_complete

@export_group("UI Elements")
@export var card_pop: CardPop
@export var holder_draft: Node
@export var holder_allies: HolderContainer
@export var holder_enemy: HolderContainer
@export var bottom_bar_draft: Control
@export var bottom_bar_prepare: Control
@export var top_bar: CanvasLayer
@export var battle_layer: CanvasLayer
@export var unhandled_layer: CanvasLayer

@export_group("Systems")
@export var clicker: Clicker
@export var level_controller: LevelController
@export var game_handler: GameHandler
@export var input_handler: InputHandler
@export var card_handler: CardHandler
@export var draft_handler: DraftHandler
@export var lineup_handler: LineupHandler
@export var battle_handler: BattleHandler
@export var card_controller: CardController

var ui_state: core.UIState = core.UIState.INITIALIZING
var _idle_action_queue: Array[Dictionary] = []
var _processing_idle_action: bool = false
var _queue_continuation_requested: bool = false


func _input(event: InputEvent) -> void:
	input_handler.input(event)


func _process(delta: float) -> void:
	input_handler.process(delta)


func _ready() -> void:
	Log.debug("Game initializing", {}, [Log.TAG_INITIALIZATION, Log.TAG_SYSTEM])
	Log.info(
		"FASTBUILD_VALIDATION_TEST: This message confirms code changes are deployed properly",
		{"timestamp": Time.get_unix_time_from_system()},
		[Log.TAG_SYSTEM, "fastbuild_validation"]
	)
	setup_signals()
	if !data_source.is_initialized():
		await data_source.startup_completed
	await setup_systems()
	intitialize_game()


func setup_signals() -> void:
	@warning_ignore("return_value_discarded")
	ui.event.connect(new_event)
	@warning_ignore("return_value_discarded")
	core.event.connect(new_event)


func setup_systems() -> void:
	Log.debug("Setting up game systems", {}, [Log.TAG_INITIALIZATION, Log.TAG_SYSTEM])
	input_handler.setup(clicker)
	lineup_handler.setup(holder_allies, self)
	battle_handler.setup(holder_allies, holder_enemy)
	await clicker.setup(level_controller, self)


func intitialize_game() -> void:
	Log.info("Initializing game", {}, [Log.TAG_INITIALIZATION, Log.TAG_SYSTEM])
	await data_source.activate_card_cache()
	# RNG is now auto-initialized during autoload _ready() phase

	Log.info(
		"Normal initialization, starting fresh game", {}, [Log.TAG_INITIALIZATION, Log.TAG_SYSTEM]
	)
	game_handler.set_gamestate(core.GameState.START)

	Log.info(
		"Game initialization complete - UI remains LOCKED until state transition",
		{},
		[Log.TAG_INITIALIZATION, Log.TAG_SYSTEM, Log.TAG_UI]
	)

	Log.info(
		"Emitting initialization_complete signal", {}, [Log.TAG_INITIALIZATION, Log.TAG_SYSTEM]
	)
	initialization_complete.emit()

	SessionManager.start_gameplay_session()


func new_event(event: core.CoreEvent) -> void:
	var draft_context: DraftContext = DraftContext.new(self)
	draft_context = update_context_units(draft_context)
	draft_context.add_event(event)
	draft_context.solve_events()


func update_context_units(_context: DraftContext) -> DraftContext:
	_context.lineup = holder_allies.get_current_lineup()
	_context.draft_area = clicker.get_all_cards()
	return _context


func solve_event(event: core.CoreEvent, _context: DraftContext) -> DraftContext:
	var ret_context: DraftContext = _context
	if event is ui.UIEvent:
		var ui_event: ui.UIEvent = event as ui.UIEvent
		resolve_ui_event(ui_event, _context)
	elif event is core.CoreEvent:
		resolve_core_event(event, _context)
	return ret_context


func resolve_core_event(event: core.CoreEvent, current_context: DraftContext) -> void:
	await CoreEventResolver.resolve_core_event(
		event,
		current_context,
		self,
		card_handler,
		lineup_handler,
		game_handler,
		holder_allies,
		holder_enemy,
		battle_layer,
		clicker
	)


func resolve_ui_event(_event: ui.UIEvent, current_context: DraftContext) -> void:
	Log.debug("Resolving UI event", {"event_type": _event.get_class()}, [Log.TAG_UI, Log.TAG_EVENT])
	if ui_state == core.UIState.LOCKED:
		Log.debug(
			"UI locked, ignoring event",
			{"event_type": _event.get_class()},
			[Log.TAG_UI, Log.TAG_GAME_STATE]
		)
		return

	if _event is ui.DraftHolderToggledEvent:
		var col: int = _event.col
		var new_state: bool = _event.new_state
		Log.debug(
			"Draft holder toggled",
			{"column": col, "new_state": new_state},
			[Log.TAG_UI, Log.TAG_DRAFT]
		)
		draft_handler.hold_toggle(col, new_state)
	elif _event is ui.ShowCardEvent:
		var card: Card = _event.card_to_show
		Log.debug("Showing card details", {"card": card.card_info.id}, [Log.TAG_UI, Log.TAG_CARD])
		card_pop.show_card(card)

	elif _event is ui.TransitionEvent:
		var new_state: core.GameState = _event.new_state

		var from_state: String = core.GameState.keys()[game_handler.current_gamestate]
		var to_state: String = core.GameState.keys()[new_state]
		SemanticLogger.log_state_transition(from_state, to_state)

		core.action(core.TransitionEvent.new(new_state))
	elif _event is ui.StartBattleEvent:
		Log.info("Battle started by user", {}, [Log.TAG_GAME_STATE, Log.TAG_BATTLE])

		var current_lineup: Array = []
		var lineup_dict: Dictionary = holder_allies.get_current_lineup()
		for card: Card in DictUtils.values_sorted(lineup_dict):
			if card:
				current_lineup.append(card)
		SemanticLogger.log_battle_start(current_lineup, [])

		var battle_result: Battle.BattleResult = battle_handler.create_battle()
		core.action(core.BattleEvent.new(battle_result.events, battle_result))
		ui.action(ui.TransitionEvent.new(core.GameState.PREBATTLE))
	elif _event is ui.RerollEvent:
		Log.info("Rerolling draft cards", {}, [Log.TAG_UI, Log.TAG_DRAFT])

		draft_handler.reroll()

	elif _event is ui.HideCardEvent:
		card_pop.hide()

	elif _event is ui.UpgradeEvent:
		Log.info("Upgrading cards", {}, [Log.TAG_UI, Log.TAG_DRAFT, Log.TAG_CARD])

		draft_handler.upgrade()

	elif _event is ui.TouchEvent:
		var event: InputEvent = _event.event
		var sender: Object = _event.sender
		Log.debug(
			"Touch event received", {"sender": sender.get_class()}, [Log.TAG_UI, Log.TAG_UI_INPUT]
		)
		var update_draft: bool = input_handler.touch_handler(event, sender, current_context)
		if update_draft:
			ui_state = core.UIState.LOCKED
			core.action(core.UpdateDraftAreaEvent.new())


func _process_one_queue_item() -> void:
	var timestamp: float = Time.get_unix_time_from_system()
	var current_test_id: String = DebugAction.get_current_test_id()

	Log.info(
		"=== PROCESSING ONE QUEUE ITEM ===",
		{
			"ui_state": ["INITIALIZING", "WAITING", "HOLDING", "LOCKED"][ui_state],
			"processing_idle_action": _processing_idle_action,
			"queue_size": _idle_action_queue.size(),
			"queue_empty": _idle_action_queue.is_empty(),
			"timestamp": timestamp,
			"test_id": current_test_id,
			"system_frame": Engine.get_process_frames()
		},
		[Log.TAG_SYSTEM, Log.TAG_EVENT, Log.TAG_IDLE_ACTION, "queue_item_start", Log.TAG_DIAGNOSTIC]
	)

	if ui_state != core.UIState.WAITING or _processing_idle_action or _idle_action_queue.is_empty():
		Log.info(
			"Queue item processing skipped",
			{
				"reason": _get_queue_skip_reason(),
				"ui_state": ["INITIALIZING", "WAITING", "HOLDING", "LOCKED"][ui_state],
				"processing_idle_action": _processing_idle_action,
				"queue_empty": _idle_action_queue.is_empty(),
				"timestamp": timestamp,
				"test_id": current_test_id,
				"system_frame": Engine.get_process_frames(),
				"skip_analysis":
				{
					"ui_not_waiting": ui_state != core.UIState.WAITING,
					"already_processing": _processing_idle_action,
					"queue_empty": _idle_action_queue.is_empty()
				}
			},
			[
				Log.TAG_SYSTEM,
				Log.TAG_EVENT,
				Log.TAG_IDLE_ACTION,
				"queue_item_skip",
				Log.TAG_DIAGNOSTIC
			]
		)
		return

	_processing_idle_action = true
	_queue_continuation_requested = false
	var queue_item: Dictionary = _idle_action_queue.pop_front()
	var action: Callable = queue_item["action"]
	var auto_continue: bool = queue_item["auto_continue"]
	var action_start_time: float = Time.get_unix_time_from_system()
	var action_start_frame: int = Engine.get_process_frames()

	var current_game_state: String = core.GameState.keys()[game_handler.current_gamestate]

	Log.info(
		"=== PROCESSING ONE QUEUE ITEM - EXECUTING ACTION ===",
		{
			"remaining_queue_size": _idle_action_queue.size(),
			"action_start_time": action_start_time,
			"action_start_frame": action_start_frame,
			"test_id": current_test_id,
			"ui_state_before_action": ["INITIALIZING", "WAITING", "HOLDING", "LOCKED"][ui_state],
			"game_state_before_action": current_game_state,
			"auto_continue": auto_continue
		},
		[Log.TAG_SYSTEM, Log.TAG_EVENT, Log.TAG_IDLE_ACTION, "action_start", Log.TAG_DIAGNOSTIC]
	)

	await action.call()

	# CRITICAL FIX: Wait for Android logging completion before queue progression
	# Prevents race condition where auto-continue starts next action while
	# previous action's DEBUG_TEST_SUCCESS logging is still async processing
	var metadata: Dictionary = DebugConfigReader.get_metadata() if DebugConfigReader != null else {}
	var is_auto_quit: bool = metadata.get("auto_quit", false) == true

	if OS.get_name() == "Android" and is_auto_quit and Log.has_pending_android_chunks():
		Log.info(
			"QUEUE_SYNC: Waiting for Android logging completion before queue progression",
			{
				"pending_chunks": Log.get_android_chunk_count(),
				"auto_continue": auto_continue,
				"test_id": DebugAction.get_current_test_id()
			},
			["debug", "queue", "android", "sync"]
		)
		await Log.wait_for_chunk_processing_complete_signal()
		Log.info(
			"QUEUE_SYNC: Android logging completed, queue can proceed",
			{"auto_continue": auto_continue, "test_id": DebugAction.get_current_test_id()},
			["debug", "queue", "android", "sync"]
		)

	var action_end_time: float = Time.get_unix_time_from_system()
	var action_end_frame: int = Engine.get_process_frames()
	var execution_time_ms: float = (action_end_time - action_start_time) * 1000.0

	var current_game_state_after: String = core.GameState.keys()[game_handler.current_gamestate]

	_processing_idle_action = false

	Log.info(
		"=== ONE QUEUE ITEM PROCESSING COMPLETE ===",
		{
			"remaining_queue_size": _idle_action_queue.size(),
			"game_state_after_action": current_game_state_after,
			"execution_time_ms": execution_time_ms,
			"frames_elapsed": action_end_frame - action_start_frame,
			"test_id": current_test_id,
			"ui_state_after_action": ["INITIALIZING", "WAITING", "HOLDING", "LOCKED"][ui_state],
			"action_end_time": action_end_time,
			"action_end_frame": action_end_frame,
			"auto_continue": auto_continue
		},
		[Log.TAG_SYSTEM, Log.TAG_EVENT, Log.TAG_IDLE_ACTION, "action_complete", Log.TAG_DIAGNOSTIC]
	)

	# Check if we should continue to next queue item
	# Removed AUTOMATED_MODE_OVERRIDE to allow proper sequential processing for Firebase actions
	var should_continue: bool = (
		(auto_continue or _queue_continuation_requested) and not _idle_action_queue.is_empty()
	)

	if should_continue:
		var continuation_reason: String = (
			"action_auto_continue" if auto_continue else "completion_event_received"
		)
		Log.info(
			"Auto-continuing to next queue item",
			{
				"remaining_queue_size": _idle_action_queue.size(),
				"trigger_timestamp": Time.get_unix_time_from_system(),
				"trigger_frame": Engine.get_process_frames(),
				"test_id": DebugAction.get_current_test_id(),
				"auto_continue": auto_continue,
				"queue_continuation_requested": _queue_continuation_requested,
				"continuation_reason": continuation_reason
			},
			[
				Log.TAG_SYSTEM,
				Log.TAG_EVENT,
				Log.TAG_IDLE_ACTION,
				"auto_continue",
				Log.TAG_DIAGNOSTIC
			]
		)
		_queue_continuation_requested = false
		core.action(core.ProcessQueueEvent.new())
	else:
		Log.info(
			"Waiting for natural completion events before processing next action",
			{
				"auto_continue": auto_continue,
				"remaining_queue_size": _idle_action_queue.size(),
				"queue_continuation_requested": _queue_continuation_requested,
				"wait_reason":
				"action_requires_natural_completion" if not auto_continue else "queue_empty"
			},
			[Log.TAG_SYSTEM, Log.TAG_EVENT, Log.TAG_IDLE_ACTION, "natural_wait", Log.TAG_DIAGNOSTIC]
		)


func start_game() -> void:
	Log.info(
		"Game starting - locking UI during state transition", {}, [Log.TAG_GAME_STATE, Log.TAG_UI]
	)
	game_handler.current_gamestate = core.GameState.START
	Log.info(
		"Game state updated atomically",
		{"state": "START"},
		[Log.TAG_GAME_STATE, Log.TAG_ATOMIC_TRANSITION]
	)

	ui_state = core.UIState.LOCKED
	core.action(core.TransitionEvent.new(core.GameState.PREPARE))


func mode_draft() -> void:
	Log.debug("Switching to draft mode", {}, [Log.TAG_GAME_STATE, Log.TAG_UI])
	game_handler.current_gamestate = core.GameState.DRAFT
	Log.info(
		"Game state updated atomically",
		{"state": "DRAFT"},
		[Log.TAG_GAME_STATE, Log.TAG_ATOMIC_TRANSITION]
	)

	top_bar.visible = true
	bottom_bar_draft.visible = true
	bottom_bar_prepare.visible = false

	holder_enemy.visible = false
	holder_draft.visible = true

	if clicker:
		Log.debug(
			"Triggering draft update to reach steady state", {}, [Log.TAG_GAME_STATE, Log.TAG_DRAFT]
		)
		core.action(core.UpdateDraftAreaEvent.new())


func mode_prepare() -> void:
	Log.debug("Switching to preparation mode", {}, [Log.TAG_GAME_STATE, Log.TAG_UI])
	game_handler.current_gamestate = core.GameState.PREPARE
	Log.info(
		"Game state updated atomically",
		{"state": "PREPARE"},
		[Log.TAG_GAME_STATE, Log.TAG_ATOMIC_TRANSITION]
	)

	top_bar.visible = true
	bottom_bar_draft.visible = false
	bottom_bar_prepare.visible = true

	holder_enemy.visible = true
	holder_draft.visible = false

	Log.info(
		"PREPARE mode active - unlocking UI and processing idle actions",
		{},
		[Log.TAG_GAME_STATE, Log.TAG_UI, "state_transition_complete"]
	)
	ui_state = core.UIState.WAITING
	core.action(core.ProcessQueueEvent.new())


func mode_pre_battle() -> void:
	Log.debug("Switching to pre-battle mode", {}, [Log.TAG_GAME_STATE, Log.TAG_BATTLE])
	game_handler.current_gamestate = core.GameState.PREBATTLE
	Log.info(
		"Game state updated atomically",
		{"state": "PREBATTLE"},
		[Log.TAG_GAME_STATE, Log.TAG_ATOMIC_TRANSITION]
	)

	ui_state = core.UIState.LOCKED
	top_bar.visible = false
	bottom_bar_draft.visible = false
	bottom_bar_prepare.visible = false
	core.action(core.TransitionEvent.new(core.GameState.BATTLE))


func mode_battle() -> void:
	Log.debug("Switching to battle mode", {}, [Log.TAG_GAME_STATE, Log.TAG_BATTLE])
	game_handler.current_gamestate = core.GameState.BATTLE
	Log.info(
		"Game state updated atomically",
		{"state": "BATTLE"},
		[Log.TAG_GAME_STATE, Log.TAG_ATOMIC_TRANSITION]
	)


func apply_battle_reconciliation(battle_result: Battle.BattleResult) -> void:
	var units_processed: int = 0
	var dead_units_processed: int = 0
	var surviving_units_processed: int = 0

	var all_battle_units: Array[UnitData] = []

	for battle_unit: UnitData in battle_result.final_allied_units.values():
		all_battle_units.append(battle_unit)

	for battle_unit: UnitData in battle_result.final_dead_allied_units.values():
		all_battle_units.append(battle_unit)

	Log.debug(
		"Starting reference-based battle reconciliation",
		{
			"total_battle_units": all_battle_units.size(),
			"surviving_units": battle_result.final_allied_units.size(),
			"dead_units": battle_result.final_dead_allied_units.size()
		},
		[Log.TAG_BATTLE, Log.TAG_RECONCILIATION]
	)

	for battle_unit: UnitData in all_battle_units:
		if battle_unit.battle_original_reference == null:
			Log.warning(
				"Battle unit has no original reference - skipping reconciliation",
				{"unit_id": battle_unit.card_info.get("id", "unknown")},
				[Log.TAG_BATTLE, Log.TAG_RECONCILIATION, Log.TAG_ERROR]
			)
			continue

		var original_unit: UnitData = battle_unit.battle_original_reference
		var unit_survived: bool = battle_unit in battle_result.final_allied_units.values()

		original_unit.apply_permanent_changes_from(battle_unit)
		units_processed += 1

		if unit_survived:
			surviving_units_processed += 1
		else:
			dead_units_processed += 1

		Log.debug(
			"Applied reference-based battle reconciliation",
			{
				"original_unit_id": original_unit.card_info.get("id", "unknown"),
				"battle_unit_id": battle_unit.card_info.get("id", "unknown"),
				"survived": unit_survived,
				"had_permanent_effects": battle_unit.effects_perm.size() > 0,
				"had_acquired_abilities": battle_unit.get_acquired_abilities().size() > 0,
				"reference_valid": battle_unit.battle_original_reference == original_unit
			},
			[Log.TAG_BATTLE, Log.TAG_RECONCILIATION, Log.TAG_CARD]
		)

	validate_no_effects_lost(battle_result)

	Log.info(
		"Reference-based battle reconciliation complete",
		{
			"total_units_processed": units_processed,
			"surviving_units_reconciled": surviving_units_processed,
			"dead_units_reconciled": dead_units_processed,
			"total_battle_units": all_battle_units.size()
		},
		[Log.TAG_BATTLE, Log.TAG_RECONCILIATION]
	)


func validate_no_effects_lost(battle_result: Battle.BattleResult) -> void:
	var total_battle_effects: int = 0
	var total_battle_acquired_abilities: int = 0
	var total_original_effects: int = 0
	var total_original_acquired_abilities: int = 0

	for battle_unit: UnitData in battle_result.final_allied_units.values():
		total_battle_effects += battle_unit.effects_perm.size()
		total_battle_acquired_abilities += battle_unit.get_acquired_abilities().size()

	for dead_unit: UnitData in battle_result.final_dead_allied_units.values():
		total_battle_effects += dead_unit.effects_perm.size()
		total_battle_acquired_abilities += dead_unit.get_acquired_abilities().size()

	var original_allies: Dictionary[int, Card] = holder_allies.get_current_lineup()
	for card: Card in original_allies.values():
		total_original_effects += card.unit_info.effects_perm.size()
		total_original_acquired_abilities += card.unit_info.get_acquired_abilities().size()

	var validation_passed: bool = (
		total_original_effects >= total_battle_effects
		and total_original_acquired_abilities >= total_battle_acquired_abilities
	)

	if validation_passed:
		Log.info(
			"Battle reconciliation validation PASSED",
			{
				"battle_effects_total": total_battle_effects,
				"battle_acquired_abilities_total": total_battle_acquired_abilities,
				"original_effects_total": total_original_effects,
				"original_acquired_abilities_total": total_original_acquired_abilities
			},
			[Log.TAG_BATTLE, Log.TAG_RECONCILIATION, Log.TAG_VALIDATION]
		)
	else:
		Log.error(
			"Battle reconciliation validation FAILED - permanent effects may have been lost!",
			{
				"battle_effects_total": total_battle_effects,
				"battle_acquired_abilities_total": total_battle_acquired_abilities,
				"original_effects_total": total_original_effects,
				"original_acquired_abilities_total": total_original_acquired_abilities,
				"effects_deficit": total_battle_effects - total_original_effects,
				"abilities_deficit":
				total_battle_acquired_abilities - total_original_acquired_abilities
			},
			[Log.TAG_BATTLE, Log.TAG_RECONCILIATION, Log.TAG_VALIDATION, Log.TAG_ERROR]
		)


func mode_post_battle() -> void:
	Log.debug("Switching to post-battle mode", {}, [Log.TAG_GAME_STATE, Log.TAG_BATTLE])
	game_handler.current_gamestate = core.GameState.POSTBATTLE
	Log.info(
		"Game state updated atomically",
		{"state": "POSTBATTLE"},
		[Log.TAG_GAME_STATE, Log.TAG_ATOMIC_TRANSITION]
	)

	ui_state = core.UIState.WAITING
	holder_allies.show_lineup()
	holder_enemy.show_lineup()
	core.action(core.TransitionEvent.new(core.GameState.PREPARE))


func _get_queue_skip_reason() -> String:
	if ui_state != core.UIState.WAITING:
		return "ui_state_not_waiting"
	if _processing_idle_action:
		return "already_processing"
	return "queue_empty"


func _capture_lineup_state() -> Dictionary:
	var lineup: Dictionary = holder_allies.get_current_lineup()
	var lineup_data: Dictionary = {}

	for lineup_position: int in DictUtils.keys_sorted(lineup):
		var card: Card = lineup[lineup_position]
		if card:
			lineup_data[str(lineup_position)] = {
				"card_id": card.card_info.id,
				"level": card.unit_info.level,
				"health": card.unit_info.health,
				"attack": card.unit_info.attack
			}

	return lineup_data


func _refresh_lineup_card_ui_after_battle() -> void:
	var lineup: Dictionary[int, Card] = holder_allies.get_current_lineup()
	var cards_refreshed: int = 0

	for card: Card in lineup.values():
		if card and card.has_method("refresh_ui_from_unit_data"):
			card.refresh_ui_from_unit_data()
			cards_refreshed += 1
			Log.debug(
				"Refreshed card UI after battle reconciliation",
				{
					"card_id": card.card_info.id,
					"current_attack": card.unit_info.current_attack,
					"current_health": card.unit_info.current_health,
					"effects_count": card.unit_info.effects_perm.size()
				},
				[Log.TAG_BATTLE, Log.TAG_RECONCILIATION, Log.TAG_UI]
			)

	Log.info(
		"Battle reconciliation UI refresh completed",
		{"cards_refreshed": cards_refreshed, "total_lineup_size": lineup.size()},
		[Log.TAG_BATTLE, Log.TAG_RECONCILIATION, Log.TAG_UI]
	)


func load_state_from_file(gamestate_file_path: String) -> bool:
	"""Load and restore gamestate from file without restarting the app"""
	return await GamestateLoader.load_state_from_file(self, gamestate_file_path)
