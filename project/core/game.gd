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
@export var clicker: Node
@export var level_controller: Control
@export var game_handler: GameHandler
@export var input_handler: InputHandler
@export var card_handler: CardHandler
@export var draft_handler: DraftHandler
@export var lineup_handler: LineupHandler
@export var battle_handler: BattleHandler

var ui_state: core.UI_STATE = core.UI_STATE.WAITING
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
	ui.event.connect(new_event.bind(core.SOLVE_TYPE.UI))
	core.event.connect(new_event.bind(core.SOLVE_TYPE.CORE))


func setup_systems() -> void:
	input_handler.setup(clicker)
	lineup_handler.setup(holder_allies)
	battle_handler.setup(holder_allies, holder_enemy)
	clicker.setup(level_controller)


func intitialize_game() -> void:
	await data_source.activate_card_cache()
	rng.start_with_base_seed()
	game_handler.set_gamestate(core.GAME_STATE.START)


func new_event(event, solve_type: core.SOLVE_TYPE) -> void:
	printt("New event: ", event, solve_type)
	var draft_context: DraftContext = DraftContext.new(self)
	draft_context = update_context_units(draft_context)
	#var event = Context.Event.new(solve_type,event)
	draft_context.add_event(event)
	draft_context.solve_events()


func update_context_units(_context: DraftContext) -> DraftContext:
	_context.lineup = holder_allies.get_current_lineup()
	_context.draft_area = clicker.get_all_cards()
	return _context


func solve_event(event, _context: DraftContext) -> DraftContext:
	var ret_context: DraftContext = _context
	if event is ui.UIEvent:
		resolve_ui_event(event, _context)
	elif event is core.CoreEvent:
		resolve_core_event(event, _context)
	return ret_context


func resolve_core_event(event: core.CoreEvent, current_context: DraftContext) -> void:
	#print("event:", core.EVENT_TYPE.keys()[event_type])
	#match event_type:
	if event is core.CardStatChangeEvent:
		if event.health != 0:
			card_handler.change_health(event.card, event.health)

		if event.attack != 0:
			card_handler.change_attack(event.card, event.attack)
		event.card.show_upgrade()

	elif event is core.TransitionEvent:
		#var new_state: core.GAME_STATE = _data[0] as core.GAME_STATE
		game_handler.set_gamestate(event.new_state)

	elif event is core.EnemyLineupAddCardEvent:  #	core.EVENT_TYPE.ENEMY_LINEUP_ADD_CARD:
		#var card: Card = _data[0]
		#var pos: int = _data[1]
		var holder: Node = holder_enemy.get_holder(event.pos)
		holder.set_card(event.card)

	elif event is core.DebugLineupAddCardEvent:  #core.EVENT_TYPE.LINEUP_ADD_CARD:
		#if _data.size() == 2:
		#from debug menu
#				var card: Card = _data[0]
#				var pos: int = _data[1]
		lineup_handler.add_card(event.card, event.pos)
		current_context.add_event(core.TrippleTestEvent.new())
		#		current_context.add_event(
		#	DraftContext.Event.new(core.SOLVE_TYPE.CORE, core.EVENT_TYPE.TRIPPLE_TEST, [])
		#)
		#current_context.add_event(
		#{solve_type = core.SOLVE_TYPE.CORE, event_type = core.EVENT_TYPE.TRIPPLE_TEST, data = []}
		#)
		current_context.solve_events()
	elif event is core.LineupAddCardEvent:
		current_context.add_event(core.TrippleTestEvent.new())
#		current_context.add_event(
#			DraftContext.Event.new(core.SOLVE_TYPE.CORE, core.EVENT_TYPE.TRIPPLE_TEST, [])
#		)

	elif event is core.TrippleTestEvent:  #core.EVENT_TYPE.TRIPPLE_TEST:
		var tripples: Array = lineup_handler.find_tripples()
		if not tripples.is_empty():
			#			current_context.add_event(
			#				DraftContext.Event.new(
			#					core.SOLVE_TYPE.CORE, core.EVENT_TYPE.LINEUP_MERGE, [tripples[0], tripples]
			#				)
			#			)
			current_context.add_event(core.LineupMergeEvent.new(tripples[0], tripples))
			#current_context.add_event(
			#{
			#solve_type = core.SOLVE_TYPE.CORE,
			#event_type = core.EVENT_TYPE.LINEUP_MERGE,
			#data = [tripples[0], tripples]
			#}
			#)
		current_context.solve_events()

	elif event is core.LineupMergeEvent:  #core.EVENT_TYPE.LINEUP_MERGE:
		#		var card: Card = _data[0]
		#		var tripples: Array = _data[1]
		var new_card: Card = await lineup_handler.merge(event.card, event.tripples)
		update_context_units(current_context)
		#current_context.add_event(
		#		DraftContext.Event.new(
		#			core.SOLVE_TYPE.CORE, core.EVENT_TYPE.LINEUP_ADD_CARD, [new_card]
		#		)
		#	)
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
		#current_context.add_event(
		#{
		#solve_type = core.SOLVE_TYPE.CORE,
		#event_type = core.EVENT_TYPE.LINEUP_ADD_CARD,
		#data = [new_card]
		#}
		#)
		current_context.solve_events()

	elif event is core.BattleEvent:  #core.EVENT_TYPE.BATTLE:
		#		var battle_events: Array = _data[0]
		var enacter: BattleEnacter = BattleEnacter.new(battle_layer, holder_allies, holder_enemy)
		add_child(enacter)
		await enacter.enact(event.battle_events)
		enacter.queue_free()
		#core.action(core.EVENT_TYPE.GAME_STATE_TRANSITION, [core.GAME_STATE.POSTBATTLE])
		core.action(core.TransitionEvent.new(core.GAME_STATE.POSTBATTLE))

	elif event is core.ResetUnitsEvent:  #core.EVENT_TYPE.RESET_UNITS:
		pass
	elif event is core.DraftSteadyEvent:  #core.EVENT_TYPE.DRAFT_STEADY:
		print("Steady state! unlock")
		ui_state = core.UI_STATE.WAITING

	clicker.on_core_event(event, current_context)


func resolve_ui_event(_event: ui.UIEvent, current_context: DraftContext) -> void:
	if ui_state == core.UI_STATE.LOCKED:
		return
	#print("event:",ui.EVENT_TYPE.keys()[_event_type])

	if _event is ui.DraftHolderToggledEvent:
		#var new_state: bool =
		#var col: int = _data[1]
		draft_handler.hold_toggle(_event.col, _event.new_state)
	elif _event is ui.ShowCardEvent:
		#var card: Card = _data[0]
		card_pop.show_card(_event.card_to_show)

	elif _event is ui.TransitionEvent:
#			var state: Array = _data
		core.action(core.TransitionEvent.new(_event.new_state))
	elif _event is ui.StartBattleEvent:
		print("Start battle")
		current_battle = battle_handler.create_battle()
#			ui.action(ui.EVENT_TYPE.TRANSITION, [core.GAME_STATE.PREBATTLE])
		ui.action(ui.TransitionEvent.new(core.GAME_STATE.PREBATTLE))
	elif _event is ui.RerollEvent:
		ui_state = core.UI_STATE.LOCKED
		draft_handler.reroll()

	elif _event is ui.HideCardEvent:
		card_pop.hide()

	elif _event is ui.UpgradeEvent:
		#check cost here
		ui_state = core.UI_STATE.LOCKED
		draft_handler.upgrade()

	elif _event is ui.TouchEvent:
#		var interacted_object: Node = _data[0]
#		var event: InputEvent = _data[1]
		var update_draft: bool = input_handler.touch_handler(
			_event.event, _event.sender, current_context
		)
		if update_draft:
			ui_state = core.UI_STATE.LOCKED
			core.action(core.UpdateDraftAreaEvent.new())


#			core.action(core.Updatedcore.EVENT_TYPE.UPDATE_DRAFT_AREA, [])


func start_game() -> void:
	print("Start Game")
	ui_state = core.UI_STATE.WAITING
	#core.action(core.EVENT_TYPE.GAME_STATE_TRANSITION, [core.GAME_STATE.PREPARE])
	core.action(core.TransitionEvent.new(core.GAME_STATE.PREPARE))


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
	ui_state = core.UI_STATE.LOCKED
	top_bar.visible = false
	bottom_bar_draft.visible = false
	bottom_bar_prepare.visible = false
	await get_tree().create_timer(0.5).timeout
	#core.action(core.EVENT_TYPE.GAME_STATE_TRANSITION, [core.GAME_STATE.BATTLE])
	core.action(core.TransitionEvent.new(core.GAME_STATE.BATTLE))


func mode_battle() -> void:
	print("Battle Mode")
#	core.action(core.EVENT_TYPE.BATTLE, [current_battle])
	core.action(core.BattleEvent.new(current_battle))


func mode_post_battle() -> void:
	print("Post Battle Mode")
	ui_state = core.UI_STATE.WAITING
	holder_allies.show_lineup()
	holder_enemy.show_lineup()
#	core.action(core.EVENT_TYPE.GAME_STATE_TRANSITION, [core.GAME_STATE.PREPARE])
	core.action(core.TransitionEvent.new(core.GAME_STATE.PREPARE))
