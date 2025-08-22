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

var ui_state: core.UIState = core.UIState.INITIALIZING
var _idle_action_queue: Array[Dictionary] = []
var _processing_idle_action: bool = false


func _input(event: InputEvent) -> void:
	input_handler.input(event)


func _process(delta: float) -> void:
	input_handler.process(delta)


func _ready() -> void:
	Log.debug("Game initializing", {}, [Log.TAG_INITIALIZATION, Log.TAG_SYSTEM])
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
	lineup_handler.setup(holder_allies)
	battle_handler.setup(holder_allies, holder_enemy)
	await clicker.setup(level_controller)


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
		_idle_action_queue.append(
			{"action": event.action_callable, "auto_continue": event.auto_continue}
		)
		core.action(core.ProcessQueueEvent.new())

	elif event is core.ProcessQueueEvent:
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

	action.call()

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


func _restore_board_content(gamestate: Dictionary) -> void:
	"""Restore board content using existing deserialization system"""
	var board_data: Dictionary = gamestate.get("board", {})
	var draft_area: Dictionary = board_data.get("draft_area", {})

	if draft_area.is_empty():
		Log.warning(
			"No draft area data found in gamestate",
			{},
			[Log.TAG_INITIALIZATION, "gamestate", "board"]
		)
		return

	Log.info(
		"Restoring board content from saved state",
		{"total_positions": draft_area.size()},
		[Log.TAG_INITIALIZATION, "gamestate", "board"]
	)

	# Clear all existing blocks before restoring gamestate
	level_controller.clear_all_blocks()

	var blocks_restored: int = 0
	var cards_restored: int = 0

	# Process positions in deterministic order (sorted by Vector2i position)
	var position_keys: Array[Vector2i] = []
	for key: Variant in draft_area.keys():
		# Handle both Vector2i keys (in memory) and string keys (from JSON deserialization)
		var grid_pos: Vector2i
		if key is Vector2i:
			grid_pos = key
		elif key is String:
			# Parse string representation like "(0, 0)" back to Vector2i
			var key_str: String = key
			# Remove parentheses and split by comma
			key_str = key_str.replace("(", "").replace(")", "").replace(" ", "")
			var coords: PackedStringArray = key_str.split(",")
			if coords.size() == 2:
				grid_pos = Vector2i(coords[0].to_int(), coords[1].to_int())
			else:
				Log.warning(
					"Invalid grid position string format",
					{"key": key_str},
					["gamestate", "parsing"]
				)
				continue
		else:
			Log.warning(
				"Unexpected key type in draft_area",
				{"key": key, "type": typeof(key)},
				["gamestate", "parsing"]
			)
			continue

		position_keys.append(grid_pos)

	# Sort position keys deterministically (by y first, then x for row-major order)
	position_keys.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			if a.y == b.y:
				return a.x < b.x
			return a.y < b.y
	)

	# Create a mapping from Vector2i back to original keys for data access
	var pos_to_key: Dictionary = {}
	for key: Variant in draft_area.keys():
		var grid_pos: Vector2i
		if key is Vector2i:
			grid_pos = key
			pos_to_key[grid_pos] = key
		elif key is String:
			var key_str: String = key
			key_str = key_str.replace("(", "").replace(")", "").replace(" ", "")
			var coords: PackedStringArray = key_str.split(",")
			if coords.size() == 2:
				grid_pos = Vector2i(coords[0].to_int(), coords[1].to_int())
				pos_to_key[grid_pos] = key

	# Process blocks in deterministic position order
	for grid_pos: Vector2i in position_keys:
		var original_key: Variant = pos_to_key.get(grid_pos)
		if original_key == null:
			continue
		var block_data: Variant = draft_area[original_key]

		if not block_data is Dictionary:
			continue

		var block_dict: Dictionary = block_data
		var object_type: int = block_dict.get("object_type", 0)

		# Route to appropriate deserializer based on object_type
		var restored_block: Block = await _deserialize_block_by_type(object_type, block_dict)
		if restored_block:
			# Use the Vector2i grid position directly - no conversion needed
			level_controller.add_to_grid(grid_pos, restored_block, 0)

			blocks_restored += 1
			if object_type == core.ObjectType.CARD:
				cards_restored += 1

			Log.debug(
				"Block restored to grid",
				{
					"object_type": object_type,
					"grid_pos": grid_pos,
					"block_type": restored_block.get_class()
				},
				[Log.TAG_INITIALIZATION, "gamestate", "board"]
			)
		else:
			Log.warning(
				"Failed to restore block from data",
				{"object_type": object_type, "grid_pos": grid_pos},
				[Log.TAG_INITIALIZATION, "gamestate", "board"]
			)

	Log.info(
		"Board content restoration complete",
		{
			"total_blocks_restored": blocks_restored,
			"cards_restored": cards_restored,
			"total_positions_processed": draft_area.size()
		},
		[Log.TAG_INITIALIZATION, "gamestate", "board"]
	)


func _deserialize_block_by_type(object_type: int, block_data: Dictionary) -> Block:
	"""Route to appropriate deserializer based on object_type"""
	match object_type:
		core.ObjectType.CARD:
			# Use existing card deserialization system (async because it loads from database)
			return await Card.deserialize_from_dict(block_data)
		core.ObjectType.EMPTY_SPACE, core.ObjectType.BLOCK_ITEM:
			# Use existing item block deserialization system (synchronous)
			return ItemBlock.deserialize_from_dict(block_data)
		core.ObjectType.BLOCK_UPGRADE:
			# Use block factory to create upgrade blocks with proper level
			var upgrade_level: int = block_data.get("level", 1)
			Log.debug(
				"Deserializing upgrade block",
				{"requested_level": upgrade_level, "block_data": block_data},
				["deserialization", "upgrade_block"]
			)
			var created_block: Block = level_controller.create_upgrade_block(upgrade_level)
			Log.debug(
				"Created upgrade block",
				{"created_level": created_block.level},
				["deserialization", "upgrade_block"]
			)
			return created_block
		core.ObjectType.BLOCK_LOCKED:
			# Use block factory to create locked blocks
			return level_controller._block_factory.create_locked_block()
		core.ObjectType.BLOCK_NOSPACE:
			# Use block factory to create nospace blocks
			return level_controller._block_factory.create_nospace_block()
		core.ObjectType.BLOCK_PASSTROUGH:
			# Use block factory to create passthrough blocks
			return level_controller._block_factory.create_passtrough_block()
		_:
			Log.warning(
				"Deserialization not implemented for object type",
				{"object_type": object_type, "available_types": core.ObjectType.keys()},
				[Log.TAG_INITIALIZATION, "gamestate", "deserialization"]
			)
			return null


func _draft_position_to_grid(draft_position: int) -> Vector2i:
	"""Convert draft position to grid coordinates"""
	# Assuming standard grid layout (20 positions in 4 rows x 5 columns)
	var grid_width: int = 5
	var grid_x: int = draft_position % grid_width
	var grid_y: int = draft_position // grid_width
	return Vector2i(grid_x, grid_y)


func load_state_from_file(gamestate_file_path: String) -> bool:
	"""Load and restore gamestate from file without restarting the app"""
	Log.info(
		"Loading gamestate from file in current session",
		{"file_path": gamestate_file_path},
		[Log.TAG_DEBUG, "gamestate", "load"]
	)

	# CRITICAL: Enable gamestate loading mode IMMEDIATELY to prevent any tilemap block creation
	if level_controller:
		level_controller.set_gamestate_loading_mode(true)
	
	# Lock input during gamestate loading to prevent user interaction
	if input_handler:
		input_handler.lock_input()

	# Read and parse JSON file
	var file: FileAccess = FileAccess.open(gamestate_file_path, FileAccess.READ)
	if not file:
		Log.error(
			"Cannot open gamestate file",
			{"file_path": gamestate_file_path},
			[Log.TAG_DEBUG, "gamestate", "load", "error"]
		)
		return false

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)
	if parse_result != OK:
		Log.error(
			"Failed to parse gamestate JSON",
			{"file_path": gamestate_file_path, "error": parse_result},
			[Log.TAG_DEBUG, "gamestate", "load", "error"]
		)
		return false

	var gamestate_data: Dictionary = json.data

	# Extract the actual gamestate and RNG data
	var gamestate: Dictionary = gamestate_data.get("gamestate", {})
	var rng_state: String = gamestate_data.get("rng_state", "")

	if gamestate.is_empty():
		Log.error(
			"No gamestate data found in file",
			{"file_path": gamestate_file_path},
			[Log.TAG_DEBUG, "gamestate", "load", "error"]
		)
		return false

	# Restore RNG state first
	if not rng_state.is_empty():
		if rng.seeded_rng and rng.seeded_rng.has_method("load_state"):
			rng.seeded_rng.load_state(rng_state)
			Log.info("RNG state restored successfully", {}, [Log.TAG_DEBUG, "gamestate", "rng"])

	# Reset all game state before restoration
	await _reset_all_game_state_for_loading()

	# Restore board content
	await _restore_board_content(gamestate)

	# Restore lineup and transition to the saved game state
	var lineup_data: Dictionary = gamestate.get("lineup", {})
	var saved_game_state: String = lineup_data.get("current_game_state", "START")

	# Set the appropriate game state and transition
	var target_state: core.GameState
	match saved_game_state:
		"DRAFT":
			target_state = core.GameState.DRAFT
		"PREPARE":
			target_state = core.GameState.PREPARE
		"PREBATTLE":
			target_state = core.GameState.PREBATTLE
		"BATTLE":
			target_state = core.GameState.BATTLE
		"POSTBATTLE":
			target_state = core.GameState.POSTBATTLE
		_:
			target_state = core.GameState.START

	# Apply the restored game state
	game_handler.current_gamestate = target_state

	# Let LineupHandler restore lineup state if needed
	if not lineup_data.is_empty():
		# TODO: Implement lineup_handler.restore_from_saved_state(lineup_data)
		# For now, skip lineup restoration to focus on board determinism fix
		Log.info(
			"Lineup restoration skipped - method not implemented yet",
			{"lineup_data_size": lineup_data.size()},
			[Log.TAG_DEBUG, "gamestate", "lineup"]
		)

	# CRITICAL: Disable gamestate loading mode after restoration complete
	if level_controller:
		level_controller.set_gamestate_loading_mode(false)
	
	# Unlock input now that gamestate loading is complete
	if input_handler:
		input_handler.unlock_input()

	Log.info(
		"Gamestate loaded and transitioned successfully",
		{
			"file": gamestate_file_path.get_file(),
			"restored_state": saved_game_state,
			"target_state": core.GameState.keys()[target_state]
		},
		[Log.TAG_DEBUG, "gamestate", "load"]
	)

	return true


func _reset_all_game_state_for_loading() -> void:
	"""Complete state reset before gamestate loading - clears all boards, lineups, and UI state"""
	Log.info(
		"Resetting all game state for gamestate loading", {}, [Log.TAG_DEBUG, "gamestate", "reset"]
	)

	var reset_start_time: int = Time.get_ticks_msec()
	var components_reset: Array[String] = []

	# 1. Reset board/clicker state completely
	if level_controller:
		# CRITICAL: Enable gamestate loading mode to prevent tilemap block creation
		level_controller.set_gamestate_loading_mode(true)
		level_controller.clear_all_blocks()  # This already exists and clears grid + scene tree
		components_reset.append("board_blocks")

		# Also clear any level-specific state
		if level_controller.current_level:
			# Clear any remaining tilemap cells that might conflict
			level_controller.current_level.clear()
			components_reset.append("tilemap")

	# 2. Reset lineup completely
	if holder_allies:
		var cleared_allies: int = _clear_holder_container(holder_allies)
		if cleared_allies > 0:
			components_reset.append("allies_lineup")

	if holder_enemy:
		var cleared_enemies: int = _clear_holder_container(holder_enemy)
		if cleared_enemies > 0:
			components_reset.append("enemies_lineup")

	# 3. Reset draft area state if there are held columns
	if clicker:
		clicker.columns_locked.clear()
		clicker.refill_counter.clear()
		components_reset.append("draft_state")

	# 4. Reset UI state to clean slate
	ui_state = core.UIState.LOCKED  # Lock UI during loading
	components_reset.append("ui_state")

	# 5. Reset all game handlers to clean state
	_reset_all_handlers()
	components_reset.append("game_handlers")

	# 6. Clear any queued actions that might interfere
	_idle_action_queue.clear()
	_processing_idle_action = false
	components_reset.append("action_queue")

	var reset_duration: int = Time.get_ticks_msec() - reset_start_time

	Log.info(
		"Game state reset complete for gamestate loading",
		{
			"components_reset": components_reset,
			"reset_duration_ms": reset_duration,
			"ui_state": "LOCKED"
		},
		[Log.TAG_DEBUG, "gamestate", "reset"]
	)


func _clear_holder_container(holder_container: HolderContainer) -> int:
	"""Clear all cards from a holder container and return count cleared"""
	if not holder_container:
		return 0

	var cards_cleared: int = 0
	var lineup: Dictionary = holder_container.get_current_lineup()

	# Remove all cards from holders using silent forceful cleanup
	for holder_pos: int in lineup.keys():
		var holder: Holder = holder_container.get_holder(holder_pos)
		if holder and holder.get_card():
			holder.force_clear_silent()
			cards_cleared += 1

	Log.debug(
		"Holder container cleared",
		{
			"container": holder_container.name if holder_container.name else "unnamed",
			"cards_cleared": cards_cleared
		},
		[Log.TAG_DEBUG, "gamestate", "reset"]
	)

	return cards_cleared


func _reset_all_handlers() -> void:
	"""Reset all game handlers to clean state for gamestate loading"""
	Log.debug(
		"Resetting all game handlers for gamestate loading",
		{},
		[Log.TAG_DEBUG, "gamestate", "handlers"]
	)

	var handlers_reset: Array[String] = []

	# 1. Reset GameHandler state
	if game_handler:
		# GameHandler will be set to the correct state during restoration
		# For now, reset to a clean initial state
		game_handler.set_gamestate(core.GameState.START)
		handlers_reset.append("game_handler")

	# 2. Reset InputHandler state
	if input_handler:
		# Reset input state (touch positions, drag state, etc.)
		input_handler.reset_inputs()
		handlers_reset.append("input_handler")

	# 3. Reset CardHandler state
	if card_handler:
		# CardHandler is typically stateless, no reset needed
		handlers_reset.append("card_handler")

	# 4. Reset DraftHandler state
	if draft_handler:
		# Reset draft upgrade level to default
		draft_handler.current_draft_upgrade_level = 0
		handlers_reset.append("draft_handler")

	# 5. Reset LineupHandler state
	if lineup_handler:
		# LineupHandler works with holder_container which we've already cleared
		# No additional state to reset
		handlers_reset.append("lineup_handler")

	# 6. Reset BattleHandler state
	if battle_handler:
		# BattleHandler is typically stateless for battle creation
		# No persistent state to reset
		handlers_reset.append("battle_handler")

	Log.debug(
		"Game handlers reset complete",
		{"handlers_reset": handlers_reset},
		[Log.TAG_DEBUG, "gamestate", "handlers"]
	)
