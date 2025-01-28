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
var current_battle: Array


func _input(event: InputEvent) -> void:
	input_handler.input(event)


func _process(delta: float) -> void:
	input_handler.process(delta)


func _ready() -> void:
	setup_signals()
	setup_systems()
	intitialize_game()


func setup_signals() -> void:
	@warning_ignore("return_value_discarded")
	ui.event.connect(new_event)
	@warning_ignore("return_value_discarded")
	core.event.connect(new_event)


func setup_systems() -> void:
	input_handler.setup(clicker)
	lineup_handler.setup(holder_allies)
	battle_handler.setup(holder_allies, holder_enemy)
	clicker.setup(level_controller)


func intitialize_game() -> void:
	await data_source.activate_card_cache()
	rng.start_with_base_seed()
	game_handler.set_gamestate(core.GameState.START)


func new_event(event: core.CoreEvent) -> void:
	printt("New event: ", event)
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
	if event is core.CardStatChangeEvent:
		var card: Card = event.card
		if event.health != 0:
			var health: int = event.health
			card_handler.change_health(card, health)

		if event.attack != 0:
			var attack: int = event.attack
			card_handler.change_attack(card, attack)
		@warning_ignore("return_value_discarded")
		card.show_upgrade()

	elif event is core.TransitionEvent:
		var new_state: core.GameState = event.new_state
		game_handler.set_gamestate(new_state)

	elif event is core.EnemyLineupAddCardEvent:
		var pos: int = event.pos
		var card: Card = event.card
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
		var tripples: Array = lineup_handler.find_tripples()
		if not tripples.is_empty():
			var card: Card = tripples[0]
			current_context.add_event(core.LineupMergeEvent.new(card, tripples))
		current_context.solve_events()

	elif event is core.LineupMergeEvent:
		var card: Card = event.card
		var tripples: Array = event.tripples
		var new_card: Card = await lineup_handler.merge(card, tripples)
		current_context = update_context_units(current_context)
		(
			current_context
			. add_event(
				(
					core
					. LineupAddCardEvent
					. new(
						new_card,
					)
				)
			)
		)
		current_context.solve_events()

	elif event is core.BattleEvent:
		var enacter: BattleEnacter = BattleEnacter.new(battle_layer, holder_allies, holder_enemy)
		add_child(enacter)
		var events: Array = event.battle_events
		await enacter.enact(events)
		enacter.queue_free()

		core.action(core.TransitionEvent.new(core.GameState.POSTBATTLE))

	elif event is core.ResetUnitsEvent:
		pass
	elif event is core.DraftSteadyEvent:
		print("Steady state! unlock")
		ui_state = core.UIState.WAITING

	clicker.on_core_event(event, current_context)


func resolve_ui_event(_event: ui.UIEvent, current_context: DraftContext) -> void:
	if ui_state == core.UIState.LOCKED:
		return

	if _event is ui.DraftHolderToggledEvent:
		var col: int = _event.col
		var new_state: bool = _event.new_state
		draft_handler.hold_toggle(col, new_state)
	elif _event is ui.ShowCardEvent:
		var card: Card = _event.card_to_show
		card_pop.show_card(card)

	elif _event is ui.TransitionEvent:
		var new_state: core.GameState = _event.new_state
		core.action(core.TransitionEvent.new(new_state))
	elif _event is ui.StartBattleEvent:
		print("Start battle")
		current_battle = battle_handler.create_battle()
		ui.action(ui.TransitionEvent.new(core.GameState.PREBATTLE))
	elif _event is ui.RerollEvent:
		ui_state = core.UIState.LOCKED
		draft_handler.reroll()

	elif _event is ui.HideCardEvent:
		card_pop.hide()

	elif _event is ui.UpgradeEvent:
		#check cost here
		ui_state = core.UIState.LOCKED
		draft_handler.upgrade()

	elif _event is ui.TouchEvent:
		var event: InputEvent = _event.event
		var sender: Object = _event.sender
		var update_draft: bool = input_handler.touch_handler(event, sender, current_context)
		if update_draft:
			ui_state = core.UIState.LOCKED
			core.action(core.UpdateDraftAreaEvent.new())


func start_game() -> void:
	print("Start Game")
	ui_state = core.UIState.WAITING
	core.action(core.TransitionEvent.new(core.GameState.PREPARE))


func mode_draft() -> void:
	print("Draft mode")
	top_bar.visible = true
	bottom_bar_draft.visible = true
	bottom_bar_prepare.visible = false

	holder_enemy.visible = false
	holder_draft.visible = true


func mode_prepare() -> void:
	print("Preparation mode")
	top_bar.visible = true
	bottom_bar_draft.visible = false
	bottom_bar_prepare.visible = true

	holder_enemy.visible = true
	holder_draft.visible = false


func mode_pre_battle() -> void:
	print("Pre Battle Mode")
	ui_state = core.UIState.LOCKED
	top_bar.visible = false
	bottom_bar_draft.visible = false
	bottom_bar_prepare.visible = false
	await get_tree().create_timer(0.5).timeout
	core.action(core.TransitionEvent.new(core.GameState.BATTLE))


func mode_battle() -> void:
	print("Battle Mode")
	core.action(core.BattleEvent.new(current_battle))


func mode_post_battle() -> void:
	print("Post Battle Mode")
	ui_state = core.UIState.WAITING
	holder_allies.show_lineup()
	holder_enemy.show_lineup()
	core.action(core.TransitionEvent.new(core.GameState.PREPARE))
