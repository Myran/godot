class_name Game extends Control

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

var ui_state: core.UIState = core.UIState.WAITING
var current_battle: Array[Context.Event]


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
	rng.start_with_base_seed()
	game_handler.set_gamestate(core.GameState.START)


func new_event(event: core.CoreEvent) -> void:
	# printt("New event: ", event)
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
		resolve_ui_event(event as ui.UIEvent, _context)
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

	elif event is core.TransitionEvent:
		var new_state: core.GameState = event.new_state
		Log.info(
			"Game state transition",
			{
				"from": core.GameState.keys()[game_handler.current_gamestate],
				"to": core.GameState.keys()[new_state]
			},
			[Log.TAG_GAME_STATE, Log.TAG_STATE_TRANSITION]
		)
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
	elif event is core.LineupAddCardEvent:
		var block: Block = event.card
		core.action(core.BlockEntersPlay.new(block))
		# detta är inte snyggt med -1,-1. antagligen behövs den inte
		current_context.add_event(core.TrippleTestEvent.new())

	elif event is core.TrippleTestEvent:
		Log.debug("Testing for card tripples", {}, [Log.TAG_CARD, Log.TAG_RULES])
		var tripples: Array[Card] = lineup_handler.find_tripples()
		if not tripples.is_empty():
			Log.info(
				"Found card tripple match",
				{"tripple_count": tripples.size()},
				[Log.TAG_CARD, Log.TAG_RULES]
			)
			var card: Card = tripples[0]
			current_context.add_event(core.LineupMergeEvent.new(card, tripples))
		current_context.solve_events()

	elif event is core.LineupMergeEvent:
		var card: Card = event.card
		var tripples: Array = event.tripples
		Log.info(
			"Merging cards",
			{"base_card": card.card_info.id, "tripple_count": tripples.size()},
			[Log.TAG_CARD, Log.TAG_RULES]
		)
		var new_card: Card = await lineup_handler.merge(card, tripples)
		current_context = update_context_units(current_context)
		# Simplified to avoid potential ternary issues
		current_context.add_event(core.LineupAddCardEvent.new(new_card))
		current_context.solve_events()

	elif event is core.BattleEvent:
		Log.info(
			"Starting battle event sequence",
			{"event_count": event.battle_events.size()},
			[Log.TAG_BATTLE, Log.TAG_EVENT]
		)
		var enacter: BattleEnacter = BattleEnacter.new(battle_layer, holder_allies, holder_enemy)
		add_child(enacter)
		var events: Array[Context.Event] = event.battle_events
		await enacter.enact(events)
		enacter.queue_free()

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
		core.action(core.TransitionEvent.new(new_state))
	elif _event is ui.StartBattleEvent:
		Log.info("Battle started by user", {}, [Log.TAG_GAME_STATE, Log.TAG_BATTLE])
		current_battle = battle_handler.create_battle()
		ui.action(ui.TransitionEvent.new(core.GameState.PREBATTLE))
	elif _event is ui.RerollEvent:
		Log.info("Rerolling draft cards", {}, [Log.TAG_UI, Log.TAG_DRAFT])
		ui_state = core.UIState.LOCKED
		draft_handler.reroll()

	elif _event is ui.HideCardEvent:
		card_pop.hide()

	elif _event is ui.UpgradeEvent:
		Log.info("Upgrading cards", {}, [Log.TAG_UI, Log.TAG_DRAFT, Log.TAG_CARD])
		#check cost here
		ui_state = core.UIState.LOCKED
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


func start_game() -> void:
	Log.info("Game starting", {}, [Log.TAG_GAME_STATE])
	ui_state = core.UIState.WAITING
	core.action(core.TransitionEvent.new(core.GameState.PREPARE))


func mode_draft() -> void:
	Log.debug("Switching to draft mode", {}, [Log.TAG_GAME_STATE, Log.TAG_UI])
	top_bar.visible = true
	bottom_bar_draft.visible = true
	bottom_bar_prepare.visible = false

	holder_enemy.visible = false
	holder_draft.visible = true


func mode_prepare() -> void:
	Log.debug("Switching to preparation mode", {}, [Log.TAG_GAME_STATE, Log.TAG_UI])
	top_bar.visible = true
	bottom_bar_draft.visible = false
	bottom_bar_prepare.visible = true

	holder_enemy.visible = true
	holder_draft.visible = false


func mode_pre_battle() -> void:
	Log.debug("Switching to pre-battle mode", {}, [Log.TAG_GAME_STATE, Log.TAG_BATTLE])
	ui_state = core.UIState.LOCKED
	top_bar.visible = false
	bottom_bar_draft.visible = false
	bottom_bar_prepare.visible = false
	await get_tree().create_timer(0.5).timeout
	core.action(core.TransitionEvent.new(core.GameState.BATTLE))


func mode_battle() -> void:
	Log.debug("Switching to battle mode", {}, [Log.TAG_GAME_STATE, Log.TAG_BATTLE])
	core.action(core.BattleEvent.new(current_battle))


func mode_post_battle() -> void:
	Log.debug("Switching to post-battle mode", {}, [Log.TAG_GAME_STATE, Log.TAG_BATTLE])
	ui_state = core.UIState.WAITING
	holder_allies.show_lineup()
	holder_enemy.show_lineup()
	core.action(core.TransitionEvent.new(core.GameState.PREPARE))
