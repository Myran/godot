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
@export var game_handler : GameHandler
@export var input_handler : InputHandler
@export var card_handler : CardHandler
@export var draft_handler : DraftHandler
@export var lineup_handler : LineupHandler
@export var battle_handler : BattleHandler

var ui_state = core.UI_STATE.WAITING
var current_battle


func _input(event: InputEvent) -> void:
	input_handler.input(event)

func _process(delta: float) -> void:
	input_handler.process(delta)

func _ready():
	setup_signals()
	setup_systems()
	intitialize_game()

func setup_signals():
	ui.event.connect(new_event.bind(core.SOLVE_TYPE.UI))
	core.event.connect(new_event.bind(core.SOLVE_TYPE.CORE))

func setup_systems():
	input_handler.setup(clicker)
	lineup_handler.setup(holder_allies)
	battle_handler.setup(holder_allies,holder_enemy)
	clicker.setup(level_controller)

func intitialize_game():
	await data_source.activate_card_cache()
	rng.start_with_base_seed()
	game_handler.set_gamestate(core.GAME_STATE.START)

func new_event(event_type, data, solve_type):
	printt("New event: ", event_type, data, solve_type)
	var draft_context = DraftContext.new(self)
	draft_context = update_context_units(draft_context)
	var event = Context.Event.new(solve_type, event_type, data)
	draft_context.add_event(event)
	draft_context.solve_events()

func update_context_units(_context):
	_context.lineup = holder_allies.get_current_lineup()
	_context.draft_area = clicker.get_all_cards()
	return _context


func solve_event(event, _context):
	var ret_context = _context
	match event.solve_type:
		core.SOLVE_TYPE.CORE:
			resolve_core_event(event.event_type, event.data, _context)
		core.SOLVE_TYPE.UI:
			resolve_ui_event(event.event_type, event.data, _context)
	return ret_context


func resolve_core_event(event_type, _data, current_context):
	print("event:", core.EVENT_TYPE.keys()[event_type])
	match event_type:
		core.EVENT_TYPE.CARD_STAT_CHANGE:
			var card = _data.card
			if _data.has("health"):
				card_handler.change_health(card, _data.health)

			if _data.has("attack"):
				card_handler.change_attack(card, _data.attack)
			card.show_upgrade()

		core.EVENT_TYPE.GAME_STATE_TRANSITION:
			var new_state = _data[0] as core.GAME_STATE
			game_handler.set_gamestate(new_state)

		core.EVENT_TYPE.ENEMY_LINEUP_ADD_CARD:
			var card = _data[0]
			var pos = _data[1]
			var holder = holder_enemy.get_holder(pos)
			holder.set_card(card)

		core.EVENT_TYPE.LINEUP_ADD_CARD:
			if _data.size() == 2:
				#from debug menu
				var card = _data[0]
				var pos = _data[1]
				lineup_handler.add_card(card, pos)
			current_context.add_event(
				{solve_type = core.SOLVE_TYPE.CORE, event_type = core.EVENT_TYPE.TRIPPLE_TEST, data = []}
			)
			current_context.solve_events()

		core.EVENT_TYPE.TRIPPLE_TEST:
			var tripples = lineup_handler.find_tripples()
			if not tripples.is_empty():
				current_context.add_event(
					{
						solve_type = core.SOLVE_TYPE.CORE,
						event_type = core.EVENT_TYPE.LINEUP_MERGE,
						data = [tripples[0], tripples]
					}
				)
				current_context.solve_events()

		core.EVENT_TYPE.LINEUP_MERGE:
			var card = _data[0]
			var tripples = _data[1]

			var new_card = await lineup_handler.merge(card, tripples)
			update_context_units(current_context)
			current_context.add_event(
				{
					solve_type = core.SOLVE_TYPE.CORE,
					event_type = core.EVENT_TYPE.LINEUP_ADD_CARD,
					data = [new_card]
				}
			)
			current_context.solve_events()

		core.EVENT_TYPE.BATTLE:
			var battle_events = _data[0]
			var enacter = BattleEnacter.new(battle_layer, holder_allies, holder_enemy)
			add_child(enacter)
			await enacter.enact(battle_events)
			enacter.queue_free()
			core.action(core.EVENT_TYPE.GAME_STATE_TRANSITION, [core.GAME_STATE.POSTBATTLE])

		core.EVENT_TYPE.RESET_UNITS:
			pass
		core.EVENT_TYPE.DRAFT_STEADY:
			print("Steady state! unlock")
			ui_state = core.UI_STATE.WAITING

	clicker.on_core_event(event_type, _data, current_context)


func resolve_ui_event(_event_type, _data, current_context):
	if ui_state == core.UI_STATE.LOCKED:
		return
	#print("event:",ui.EVENT_TYPE.keys()[_event_type])
	match _event_type:
		ui.EVENT_TYPE.DRAFT_HOLD_TOGGLED:
			var new_state = _data[0]
			var col = _data[1]
			draft_handler.hold_toggle(col, new_state)
		ui.EVENT_TYPE.SHOW_CARD:
			var card = _data[0]
			card_pop.show_card(card)

		ui.EVENT_TYPE.TRANSITION:
			var state = _data
			core.action(core.EVENT_TYPE.GAME_STATE_TRANSITION, state)
		ui.EVENT_TYPE.START_BATTLE:
			print("Start battle")
			current_battle = battle_handler.create_battle()
			ui.action(ui.EVENT_TYPE.TRANSITION, [core.GAME_STATE.PREBATTLE])

		ui.EVENT_TYPE.REROLL:
			ui_state = core.UI_STATE.LOCKED
			draft_handler.reroll()

		ui.EVENT_TYPE.TAP_POP_CARD:
			card_pop.hide()

		ui.EVENT_TYPE.UPGRADE:
			#check cost here
			ui_state = core.UI_STATE.LOCKED
			draft_handler.upgrade()

		ui.EVENT_TYPE.TOUCH:
			var interacted_object = _data[0]
			var event = _data[1]
			var update_draft = input_handler.touch_handler(event, interacted_object, current_context)
			if update_draft:
				ui_state = core.UI_STATE.LOCKED
				core.action(core.EVENT_TYPE.UPDATE_DRAFT_AREA, [])


func start_game():
	print("Start Game")
	ui_state = core.UI_STATE.WAITING
	core.action(core.EVENT_TYPE.GAME_STATE_TRANSITION, [core.GAME_STATE.PREPARE])


func mode_draft():
	print("Draft mode")
	top_bar.visible = true
	bottom_bar_draft.visible = true
	bottom_bar_prepare.visible = false

	holder_enemy.visible = false
	holder_draft.visible = true


func mode_prepare():
	print("Preparation mode")
	top_bar.visible = true
	bottom_bar_draft.visible = false
	bottom_bar_prepare.visible = true

	holder_enemy.visible = true
	holder_draft.visible = false


func mode_pre_battle():
	print("Pre Battle Mode")
	ui_state = core.UI_STATE.LOCKED
	top_bar.visible = false
	bottom_bar_draft.visible = false
	bottom_bar_prepare.visible = false
	await get_tree().create_timer(0.5).timeout
	core.action(core.EVENT_TYPE.GAME_STATE_TRANSITION, [core.GAME_STATE.BATTLE])


func mode_battle():
	print("Battle Mode")
	core.action(core.EVENT_TYPE.BATTLE, [current_battle])


func mode_post_battle():
	print("Post Battle Mode")
	ui_state = core.UI_STATE.WAITING
	holder_allies.show_lineup()
	holder_enemy.show_lineup()
	core.action(core.EVENT_TYPE.GAME_STATE_TRANSITION, [core.GAME_STATE.PREPARE])
