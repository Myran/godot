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


func _input(event: InputEvent) -> void:
	input_handler.input(event)


func _process(delta: float) -> void:
	input_handler.process(delta)


func _ready() -> void:
	Log.debug("Game initializing", {}, [Log.TAG_INITIALIZATION, Log.TAG_SYSTEM])
	Log.info("FASTBUILD_VALIDATION_TEST: This message confirms code changes are deployed properly", {"timestamp": Time.get_unix_time_from_system()}, [Log.TAG_SYSTEM, "fastbuild_validation"])
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
	Log.debug(
		"Resolving core event",
		{"event_type": event.get_class()},
		[Log.TAG_GAME_STATE, Log.TAG_EVENT]
	)
	if event is core.CardStatChangeEvent:
		var card: Card = event.card
		if event.health != 0:
			var health: int = event.health
			Log.debug(
				"Changing card health",
				{"card": card.card_info.id, "health_change": health},
				[Log.TAG_CARD]
			)
			card_handler.change_health(card, health)

		if event.attack != 0:
			var attack: int = event.attack
			Log.debug(
				"Changing card attack",
				{"card": card.card_info.id, "attack_change": attack},
				[Log.TAG_CARD]
			)
			card_handler.change_attack(card, attack)
		@warning_ignore("return_value_discarded")
		card.show_upgrade()

	elif event is core.StatEffectEvent:
		var stat_effect_event: core.StatEffectEvent = event as core.StatEffectEvent

		# Fail-fast type assertions per CLAUDE.md requirements
		var target_card: Card = stat_effect_event.target_card as Card
		if not target_card:
			Log.error(
				"StatEffectEvent target_card is null or invalid type",
				{"event": stat_effect_event},
				[Log.TAG_ERROR]
			)
			return

		if not target_card.unit_info:
			Log.error(
				"Target card unit_info is null",
				{"card_id": target_card.card_info.id},
				[Log.TAG_ERROR]
			)
			return

		var source_description: String = core.EventSource.keys()[stat_effect_event.effect_source]
		var permanent_effect: StatEffect = StatEffect.new(
			stat_effect_event.health_bonus, stat_effect_event.attack_bonus, source_description
		)
		target_card.unit_info.effects_perm.append(permanent_effect)

		Log.debug(
			"StatEffect stored in card's effects_perm array",
			{
				"card_id": target_card.card_info.id,
				"effect_description": permanent_effect.get_description(),
				"effects_perm_count": target_card.unit_info.effects_perm.size(),
				"health_bonus": stat_effect_event.health_bonus,
				"attack_bonus": stat_effect_event.attack_bonus,
				"source": source_description
			},
			[Log.TAG_DEBUG, Log.TAG_STATS, Log.TAG_EFFECT]
		)

		Log.debug(
			"APPLYING STATEFFECTS - About to call apply_permanent_effects_to_current_stats()",
			{
				"card_id": target_card.card_info.id,
				"effects_perm_count_before": target_card.unit_info.effects_perm.size(),
				"current_attack_before": target_card.unit_info.current_attack,
				"current_health_before": target_card.unit_info.current_health,
				"context": "StatEffectEvent_processing_unified_application"
			},
			[Log.TAG_DEBUG, Log.TAG_STATS, Log.TAG_EFFECT, "stat_refresh"]
		)

		target_card.unit_info.apply_permanent_effects_to_current_stats()

		target_card.refresh_ui_from_unit_data()

		@warning_ignore("return_value_discarded")
		target_card.show_upgrade()

		Log.info(
			"APPLIED STATEFFECTS - Stats updated via unified method",
			{
				"card_id": target_card.card_info.id,
				"effects_perm_count_after": target_card.unit_info.effects_perm.size(),
				"current_attack_after": target_card.unit_info.current_attack,
				"current_health_after": target_card.unit_info.current_health,
				"context": "StatEffectEvent_processing_unified_completed"
			},
			[Log.TAG_DEBUG, Log.TAG_STATS, Log.TAG_EFFECT, "stat_refresh"]
		)

		Log.info(
			"Added permanent stat effect",
			{"effect": permanent_effect.get_description(), "target": target_card.card_info.id},
			[Log.TAG_DEBUG, Log.TAG_STATS, Log.TAG_EFFECT]
		)

	elif event is core.TransitionEvent:
		var new_state: core.GameState = event.new_state
		var from_state: String = core.GameState.keys()[game_handler.current_gamestate]
		var to_state: String = core.GameState.keys()[new_state]

		Log.info(
			"Game state transition",
			{"from": from_state, "to": to_state},
			[Log.TAG_GAME_STATE, Log.TAG_STATE_TRANSITION]
		)

		if event.source == core.EventSource.PLAYER:
			SemanticLogger.log_state_transition(from_state, to_state)

		game_handler.set_gamestate(new_state)

	elif event is core.EnemyLineupAddCardEvent:
		var pos: int = event.pos
		var card: Card = event.card
		Log.debug(
			"Adding card to enemy lineup",
			{"card": card.card_info.id, "position": pos},
			[Log.TAG_CARD, Log.TAG_BATTLE]
		)
		var holder: Holder = holder_enemy.get_holder(pos)
		holder.set_card(card)

	elif event is core.DebugLineupAddCardEvent:
		var card: Card = event.card
		var pos: int = event.pos
		lineup_handler.add_card(card, pos)
		current_context.add_event(core.TrippleTestEvent.new())
		current_context.solve_events()
	elif event is core.LineupAddCardFromDraftEvent:
		var card: Card = event.card
		var from_pos: Vector2i = event.from_position
		var to_pos: int = event.to_position

		if event.source == core.EventSource.PLAYER:
			var card_id: String = card.card_info.id
			SemanticLogger.log_draft_to_lineup_move(card_id, from_pos, to_pos)

		var remove_event: core.RemoveBlockFromDraft = core.RemoveBlockFromDraft.new(card, false)
		remove_event.source = core.EventSource.SYSTEM_CASCADE
		current_context.add_event(remove_event)
		current_context.solve_events()

		lineup_handler.add_card(card, to_pos)

		core.action(core.BlockEntersPlay.new(card))
		current_context.add_event(core.TrippleTestEvent.new())

		ui_state = core.UIState.LOCKED
		core.action(core.UpdateDraftAreaEvent.new())
	elif event is core.LineupAddCardEvent:
		var block: Block = event.card

		core.action(core.BlockEntersPlay.new(block))
		current_context.add_event(core.TrippleTestEvent.new())

	elif event is core.TrippleTestEvent:
		Log.debug(
			"TRIPPLE TEST EVENT RECEIVED - Starting tripple detection",
			{"event_type": "TrippleTestEvent"},
			[Log.TAG_CARD, Log.TAG_RULES, Log.TAG_DEBUG]
		)

		var tripples: Array[Card] = lineup_handler.find_tripples()

		if not tripples.is_empty():
			Log.info(
				"TRIPPLE MATCH FOUND - Creating LineupMergeEvent",
				{
					"tripple_count": tripples.size(),
					"card_id": tripples[0].card_info.id,
					"card_level": tripples[0].level
				},
				[Log.TAG_CARD, Log.TAG_RULES, Log.TAG_MERGE]
			)
			var card: Card = tripples[0]
			current_context.add_event(core.LineupMergeEvent.new(card, tripples))
		else:
			Log.debug(
				"TRIPPLE TEST COMPLETE - No tripples found",
				{"lineup_checked": true},
				[Log.TAG_CARD, Log.TAG_RULES, Log.TAG_DEBUG]
			)

		current_context.solve_events()

	elif event is core.LineupMergeEvent:
		var card: Card = event.card
		var tripples: Array = event.tripples

		Log.info(
			"LINEUP MERGE EVENT RECEIVED - Starting card merge",
			{
				"base_card_id": card.card_info.id,
				"base_card_level": card.level,
				"tripple_count": tripples.size(),
				"merge_type": "lineup_merge"
			},
			[Log.TAG_CARD, Log.TAG_RULES, Log.TAG_MERGE]
		)

		var new_card: Card = await lineup_handler.merge(card, tripples)

		Log.info(
			"LINEUP MERGE COMPLETED - New card created",
			{
				"new_card_id": new_card.card_info.id,
				"new_card_level": new_card.level,
				"merge_successful": true
			},
			[Log.TAG_CARD, Log.TAG_RULES, Log.TAG_MERGE]
		)

		current_context = update_context_units(current_context)
		current_context.add_event(core.LineupAddCardEvent.new(new_card))
		current_context.solve_events()

	elif event is core.MoveLineupCardEvent:
		var card: Card = event.card
		var from_pos: int = event.from_position
		var to_pos: int = event.to_position

		Log.info(
			"Processing lineup card move action",
			{"card": card.card_info.id, "from_position": from_pos, "to_position": to_pos},
			[Log.TAG_CARD, Log.TAG_LINEUP]
		)

		if event.source == core.EventSource.PLAYER:
			var card_id: String = card.card_info.id
			SemanticLogger.log_lineup_move_card(card_id, from_pos, to_pos)

		var from_holder: Holder = lineup_handler.holder_container.get_holder(from_pos)
		var to_holder: Holder = lineup_handler.holder_container.get_holder(to_pos)

		if from_holder and to_holder and from_holder.get_card() == card:
			if to_holder.set_card(card):
				from_holder.remove_card()

				var system_event: core.MoveLineupCardEvent = core.MoveLineupCardEvent.new(
					card, from_pos, to_pos
				)
				system_event.source = core.EventSource.SYSTEM_CASCADE
				current_context.add_event(system_event)
				current_context.solve_events()
			else:
				Log.warning(
					"Cannot move card - destination occupied",
					{"card": card.card_info.id, "from_position": from_pos, "to_position": to_pos},
					[Log.TAG_CARD, Log.TAG_LINEUP]
				)
		else:
			Log.warning(
				"Invalid lineup card move action - card not at expected position",
				{"card": card.card_info.id, "from_position": from_pos, "to_position": to_pos},
				[Log.TAG_CARD, Log.TAG_LINEUP]
			)

	elif event is core.MoveLineupCardEvent and event.source == core.EventSource.SYSTEM_CASCADE:
		var card: Card = event.card
		var from_pos: int = event.from_position
		var to_pos: int = event.to_position

		Log.info(
			"Lineup card move event (system cascade)",
			{"card": card.card_info.id, "from_position": from_pos, "to_position": to_pos},
			[Log.TAG_CARD, Log.TAG_LINEUP]
		)

	elif event is core.BattleEvent:
		Log.info(
			"Starting battle event sequence",
			{"event_count": event.battle_events.size()},
			[Log.TAG_BATTLE, Log.TAG_EVENT]
		)
		var enacter: BattleEnacter = BattleEnacter.new(battle_layer, holder_allies, holder_enemy)
		add_child(enacter)
		var events: Array[Context.Event] = event.battle_events
		var battle_result_param: Battle.BattleResult = event.battle_result
		await enacter.enact(events, battle_result_param)
		enacter.queue_free()

		Log.info(
			"Battle complete, applying permanent changes to units",
			{},
			[Log.TAG_BATTLE, Log.TAG_RECONCILIATION]
		)
		var battle_result: Battle.BattleResult = event.battle_result
		apply_battle_reconciliation(battle_result)

		_refresh_lineup_card_ui_after_battle()

		Log.debug(
			"Battle complete, transitioning to post-battle",
			{},
			[Log.TAG_BATTLE, Log.TAG_STATE_TRANSITION]
		)
		core.action(core.TransitionEvent.new(core.GameState.POSTBATTLE))

	elif event is core.ResetUnitsEvent:
		pass
	elif event is core.DraftSteadyEvent:
		Log.debug("Draft reached steady state - unlocking UI", {}, [Log.TAG_GAME_STATE, Log.TAG_UI])
		ui_state = core.UIState.WAITING
		core.action(core.ProcessQueueEvent.new())

	elif event is core.LineupOperationStartEvent:
		Log.info("Lineup operation started - locking UI", {}, [Log.TAG_GAME_STATE, Log.TAG_UI])
		ui_state = core.UIState.LOCKED

	elif event is core.LineupOperationCompleteEvent:
		Log.info("Lineup operation completed - unlocking UI", {}, [Log.TAG_GAME_STATE, Log.TAG_UI])
		ui_state = core.UIState.WAITING
		core.action(core.ProcessQueueEvent.new())

	elif event is core.SystemIdleActionEvent:
		var state_name: String = ["INITIALIZING", "WAITING", "HOLDING", "LOCKED"][ui_state]
		var current_test_id: String = DebugAction.get_current_test_id()
		var event_timestamp: float = Time.get_unix_time_from_system()

		Log.info(
			"=== SYSTEM IDLE ACTION EVENT RECEIVED ===",
			{
				"ui_state": state_name,
				"queue_size_before": _idle_action_queue.size(),
				"queue_size_after": _idle_action_queue.size() + 1,
				"processing_idle_action": _processing_idle_action,
				"test_id": current_test_id,
				"event_timestamp": event_timestamp,
				"event_frame": Engine.get_process_frames(),
				"can_process_immediately":
				ui_state == core.UIState.WAITING and not _processing_idle_action
			},
			[
				Log.TAG_SYSTEM,
				Log.TAG_EVENT,
				Log.TAG_IDLE_ACTION,
				"event_received",
				Log.TAG_DIAGNOSTIC
			]
		)

		Log.info(
			"TRACE: Adding action to queue",
			{
				"action_valid": event.action_callable.is_valid(),
				"action_name": str(event.action_callable),
				"auto_continue": event.auto_continue
			},
			["debug", "trace", "queue"]
		)

		_idle_action_queue.append(
			{"action": event.action_callable, "auto_continue": event.auto_continue}
		)
		core.action(core.ProcessQueueEvent.new())

	elif event is core.ProcessQueueEvent:
		# Return early if not ready - preserves queue for later processing
		if ui_state != core.UIState.WAITING or _processing_idle_action:
			return
		_process_one_queue_item()

	clicker.on_core_event(event, current_context)


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
	var queue_item: Dictionary = _idle_action_queue.pop_front()
	var action: Callable = queue_item["action"]
	var auto_continue: bool = queue_item["auto_continue"]
	var action_start_time: float = Time.get_unix_time_from_system()
	var action_start_frame: int = Engine.get_process_frames()

	var current_game_state: String = core.GameState.keys()[game_handler.current_gamestate]

	print("SIMPLE_TRACE: About to log action start")

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

	print("SIMPLE_TRACE: Logged action start")

	print("SIMPLE_TRACE: About to call action - valid: ", action.is_valid(), " name: ", str(action))

	action.call()

	print("SIMPLE_TRACE: Action call completed - name: ", str(action))

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

	if auto_continue and not _idle_action_queue.is_empty():
		Log.info(
			"Auto-continuing to next queue item (action requested immediate continuation)",
			{
				"remaining_queue_size": _idle_action_queue.size(),
				"trigger_timestamp": Time.get_unix_time_from_system(),
				"trigger_frame": Engine.get_process_frames(),
				"test_id": DebugAction.get_current_test_id()
			},
			[
				Log.TAG_SYSTEM,
				Log.TAG_EVENT,
				Log.TAG_IDLE_ACTION,
				"auto_continue",
				Log.TAG_DIAGNOSTIC
			]
		)
		core.action(core.ProcessQueueEvent.new())
	else:
		Log.info(
			"Waiting for natural completion events before processing next action",
			{
				"auto_continue": auto_continue,
				"remaining_queue_size": _idle_action_queue.size(),
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
	await get_tree().create_timer(0.5).timeout
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
