class_name Game extends Control

@export_group("UI Elements")
@export var card_pop: Control
@export var holder_draft: Node
@export var holder_allies: Control
@export var holder_enemy: Control
@export var bottom_bar_draft: Control
@export var bottom_bar_prepare: Control
@export var top_bar: CanvasLayer
@export var battle_layer: CanvasLayer
@export var unhandled_layer: CanvasLayer

@export_group("Systems")
@export var clicker: Clicker
@export var level_controller: Control
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
	ui.event.connect(new_event)
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
		resolve_ui_event(event, _context)
	elif event is core.CoreEvent:
		resolve_core_event(event, _context)
	return ret_context


func resolve_core_event(event: core.CoreEvent, current_context: DraftContext) -> void:
	if event is core.CardStatChangeEvent:
		if event.health != 0:
			card_handler.change_health(event.card, event.health)

		if event.attack != 0:
			card_handler.change_attack(event.card, event.attack)
		event.card.show_upgrade()

	elif event is core.TransitionEvent:
		game_handler.set_gamestate(event.new_state)

	elif event is core.EnemyLineupAddCardEvent:
		var holder: Node = holder_enemy.get_holder(event.pos)
		holder.set_card(event.card)

	elif event is core.DebugLineupAddCardEvent:
		lineup_handler.add_card(event.card, event.pos)
		current_context.add_event(core.TrippleTestEvent.new())
		current_context.solve_events()
	elif event is core.LineupAddCardEvent:
		current_context.add_event(core.TrippleTestEvent.new())

	elif event is core.TrippleTestEvent:
		var tripples: Array = lineup_handler.find_tripples()
		if not tripples.is_empty():
			current_context.add_event(core.LineupMergeEvent.new(tripples[0], tripples))
		current_context.solve_events()

	elif event is core.LineupMergeEvent:
		var new_card: Card = await lineup_handler.merge(event.card, event.tripples)
		update_context_units(current_context)
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
		await enacter.enact(event.battle_events)
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
		draft_handler.hold_toggle(_event.col, _event.new_state)
	elif _event is ui.ShowCardEvent:
		card_pop.show_card(_event.card_to_show)

	elif _event is ui.TransitionEvent:
		core.action(core.TransitionEvent.new(_event.new_state))
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
		var update_draft: bool = input_handler.touch_handler(
			_event.event, _event.sender, current_context
		)
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
