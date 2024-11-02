class_name Game extends Control


enum UI_STATE { WAITING, HOLDING, LOCKED }
enum SOLVE_TYPE { CORE, UI }

@export var card_pop: Control
@export var holder_draft: Node
@export var holder_allies: Control
@export var holder_enemy: Control
@export var bottom_bar_draft: Control
@export var bottom_bar_prepare: Control
@export var top_bar: CanvasLayer
@export var battle_layer: CanvasLayer
@export var unhandled_layer: CanvasLayer
@export var clicker: Node
@export var level_controller: Control

var ui_state = UI_STATE.WAITING
var current_gamestate

var current_battle
var inputs = InputHandler.new()
var card_handler = CardHandler.new()
var draft_handler = DraftHandler.new()
var lineup_handler
var battle_handler


class CardHandler: 
		func change_health(card,health_amount):
				var current_health = card.unit_info.current_health
				var new_health = current_health + health_amount
				card.unit_info.current_health = new_health
				card.card_base.set_card_health(new_health)
		func change_attack(card,attack_amount):
				var current_attack = card.unit_info.current_attack
				var new_attack = current_attack + attack_amount
				card.unit_info.current_attack = new_attack
				card.card_base.set_card_attack(new_attack)

class LineupHandler:
		var holder
		func _init(_holder) -> void:
			holder = _holder
		func add_card(card,pos):
				var holder_pos = holder.get_holder(pos)
				holder_pos.set_card(card)
		func find_tripples():
			var lineup = holder.get_current_lineup()
			for card in lineup.values():
				var tripples = []
				for lineup_card in lineup.values():
					if (
						lineup_card.card_info.id == card.card_info.id
						and lineup_card.level == card.level
					):
						if not tripples.has(lineup_card):
							tripples.append(lineup_card)
				if tripples.size() >= 3:
					return tripples
			return []
		func merge(card,tripples):
			var new_card
			var merge_pos
			var awaiter = SignalAwaiter.All.new()
			for trip_card in tripples:
				var lineup_pos = holder.get_card_position(trip_card)
				var holder = holder.get_holder(lineup_pos)
				holder.remove_card()
				#update_context_units(current_context)
				if trip_card == card:
					new_card = await card_controller.create_unit_from_id(
						card.card_info.id, card.level + 1
					)
					new_card.block_context = Cards.CONTEXT.LINEUP
					holder.set_card(new_card)
					new_card.show_upgrade()
					merge_pos = new_card.get_global_position()

			for trip_card in tripples:
				awaiter.add(trip_card.movement_done)
				trip_card.move_to_on_top(merge_pos)
			await awaiter.finished
			for trip_card in tripples:
				trip_card.queue_free()
			return new_card

class DraftHandler:
		var current_draft_upgrade_level = 0
		func hold_toggle(col,new_state):
			var state
			if new_state:
				state = core.EVENT_TYPE.DRAFT_COLOUMN_LOCKED
			else:
				state = core.EVENT_TYPE.DRAFT_COLUMN_UNLOCKED
			core.action(state, [col])
		func reroll():
			core.action(core.EVENT_TYPE.REROLL_DRAFT, [])
		func upgrade():
			current_draft_upgrade_level += 1
			core.action(core.EVENT_TYPE.UPGRADE, [current_draft_upgrade_level])

class BattleHandler:
		var holder_allies
		var holder_enemy
		func _init(_allies,_enemies) -> void:
			holder_allies = _allies
			holder_enemy = _enemies
			
		func create_battle():
			var allies = holder_allies.get_current_lineup()
			var enemies = holder_enemy.get_current_lineup()

			var battle_instance = Battle.new()
			var prep_allies = Battle.prepare_lineup_from_holder(allies)
			var prep_enemies = Battle.prepare_lineup_from_holder(enemies)
			return battle_instance.battle_start(prep_allies, prep_enemies)

func _input(event: InputEvent) -> void:
	inputs.input(event)


func _process(delta: float) -> void:
	inputs.process(delta)


func _ready():
	ui.event.connect(new_event.bind(SOLVE_TYPE.UI))
	core.event.connect(new_event.bind(SOLVE_TYPE.CORE))
	debug.debug_event.connect(_on_debug_event)
	lineup_handler = LineupHandler.new(holder_allies)
	battle_handler = BattleHandler.new(holder_allies,holder_enemy)
	await data_source.activate_card_cache()
	rng.start_with_base_seed()
	clicker.setup(level_controller)
	set_gamestate(core.GAME_STATE.START)



func _on_debug_event(event, _data):
	match event:
		debug.DEBUG_EVENT_TYPE.EVENT_RESET_MATCH_LEVEL, debug.DEBUG_EVENT_TYPE.EVENT_FORCE_LOAD_MATCH_LEVEL:
			draft_handler.current_draft_upgrade_level = 0


func new_event(event_type, data, solve_type):
	printt("New event: ", event_type, data, solve_type)
	var draft_context = create_draft_context()
	var event = Context.Event.new(solve_type, event_type, data)
	draft_context.add_event(event)
	draft_context.solve_events()


func create_draft_context():
	var draft_context = DraftContext.new(self)
	draft_context = update_context_units(draft_context)
	return draft_context


func update_context_units(_context):
	_context.lineup = holder_allies.get_current_lineup()
	_context.draft_area = clicker.get_all_cards()
	return _context


func solve_event(event, _context):
	var ret_context = _context
	match event.solve_type:
		SOLVE_TYPE.CORE:
			resolve_core_event(event.event_type, event.data, _context)
		SOLVE_TYPE.UI:
			resolve_ui_event(event.event_type, event.data, _context)
	return ret_context


func resolve_core_event(event_type, _data, current_context):
	print("event:", core.EVENT_TYPE.keys()[event_type])
	match event_type:
		core.EVENT_TYPE.CARD_STAT_CHANGE:
			var card = _data.card
			if _data.has("health"):
				card_handler.change_health(card,_data.health)

			if _data.has("attack"):
				card_handler.change_attack(card,_data.attack)
			card.show_upgrade()

		core.EVENT_TYPE.GAME_STATE_TRANSITION:
			var new_state = _data[0] as core.GAME_STATE
			set_gamestate(new_state)

		core.EVENT_TYPE.ENEMY_LINEUP_ADD_CARD:
			var card = _data[0]
			var pos = _data[1]
			var holder = holder_enemy.get_holder(pos)
			holder.set_card(card)

		core.EVENT_TYPE.LINEUP_ADD_CARD:
			if _data.size() == 2:
				var card = _data[0]
				var 	pos = _data[1]
				lineup_handler.add_card(card,pos)
			current_context.add_event(
				{solve_type = SOLVE_TYPE.CORE, event_type = core.EVENT_TYPE.TRIPPLE_TEST, data = []}
			)

		core.EVENT_TYPE.TRIPPLE_TEST:
			var tripples = lineup_handler.find_tripples()
			if not tripples.is_empty():
					current_context.add_event(
						{
							solve_type = SOLVE_TYPE.CORE,
							event_type = core.EVENT_TYPE.LINEUP_MERGE,
							data = [tripples[0], tripples]
						}
					)
					current_context.solve_events()

		core.EVENT_TYPE.LINEUP_MERGE:
			var card = _data[0]
			var tripples = _data[1]
	
			var new_card = await lineup_handler.merge(card,tripples)
			update_context_units(current_context)
			current_context.add_event(
				{
					solve_type = SOLVE_TYPE.CORE,
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
			ui_state = UI_STATE.WAITING
	
	clicker.on_core_event(event_type, _data, current_context)



func resolve_ui_event(_event_type, _data, current_context):
	if ui_state == UI_STATE.LOCKED:
		return
	#print("event:",ui.EVENT_TYPE.keys()[_event_type])
	match _event_type:
		ui.EVENT_TYPE.DRAFT_HOLD_TOGGLED:
			var new_state = _data[0]
			var col = _data[1]
			draft_handler.hold_toggle(col,new_state)


		ui.EVENT_TYPE.TRANSITION:
			var state = _data
			core.action(core.EVENT_TYPE.GAME_STATE_TRANSITION, state)
		ui.EVENT_TYPE.START_BATTLE:
			print("Start battle")
			current_battle = battle_handler.create_battle()
			ui.action(ui.EVENT_TYPE.TRANSITION, [core.GAME_STATE.PREBATTLE])

		ui.EVENT_TYPE.REROLL:
			ui_state = UI_STATE.LOCKED
			draft_handler.reroll()


		ui.EVENT_TYPE.TAP_POP_CARD:
			card_pop.hide()

		ui.EVENT_TYPE.UPGRADE:
			#check cost here
			ui_state = UI_STATE.LOCKED
			draft_handler.upgrade()

		ui.EVENT_TYPE.TOUCH:
			var interacted_object = _data[0]
			var event = _data[1]
			var update_draft = false

			if event.pressed == true:
				match inputs.tap_state:
					core.TAP_STATE.IDLE:
						match interacted_object.object_type:
							core.OBJECT_TYPE.CARD:
								inputs.tap_state = core.TAP_STATE.PRESSING
								inputs.holding_item = interacted_object
							core.OBJECT_TYPE.CARD_HOLDER:
								pass
							core.OBJECT_TYPE.BLOCK_LOCKED:
								inputs.tap_state = core.TAP_STATE.PRESSING

			elif event.pressed == false:
				match inputs.tap_state:
					core.TAP_STATE.PRESSING:
						if interacted_object.object_type == core.OBJECT_TYPE.CARD:
							card_pop.show_card(interacted_object)
							update_draft = true
						if interacted_object.object_type == core.OBJECT_TYPE.BLOCK_LOCKED:
							core.action(
								core.EVENT_TYPE.REMOVE_BLOCK_FROM_DRAFT, [interacted_object, true]
							)
							update_draft = true

					core.TAP_STATE.HOLDING:
						if inputs.dragging_cargo.object_type == core.OBJECT_TYPE.CARD:
							inputs.dragging_cargo.set_process_input(true)
							var release_handled = false
							var dragging_card = inputs.dragging_cargo
							match interacted_object.object_type:
								core.OBJECT_TYPE.BACKGROUND:
									pass
								core.OBJECT_TYPE.CARD:
									if interacted_object == dragging_card:
										return
								core.OBJECT_TYPE.CARD_HOLDER:
									var interacted_holder = interacted_object
									match dragging_card.block_context:
										Cards.CONTEXT.LINEUP:
											var prev_holder = dragging_card.holder
											if interacted_holder.set_card(dragging_card):
												prev_holder.remove_card()
												release_handled = true

										Cards.CONTEXT.DRAFT:
											if is_instance_valid(dragging_card):
												if clicker.has_card(dragging_card):
													release_handled = interacted_holder.set_card(
														dragging_card
													)
													if release_handled:
														current_context.add_event(
															{
																solve_type = SOLVE_TYPE.CORE,
																event_type =
																(
																	core
																	. EVENT_TYPE
																	. REMOVE_BLOCK_FROM_DRAFT
																),
																data = [dragging_card]
															}
														)
														current_context.solve_events()
														current_context.add_event(
															{
																solve_type = SOLVE_TYPE.CORE,
																event_type =
																core.EVENT_TYPE.LINEUP_ADD_CARD,
																data = [dragging_card]
															}
														)
														current_context.solve_events()
														update_draft = true

							if not release_handled:
								match dragging_card.block_context:
									Cards.CONTEXT.LINEUP:
										dragging_card.holder.pos_card_in_holder()
									Cards.CONTEXT.DRAFT:
										var pos = dragging_card.get_global_position()
										dragging_card.set_as_top_level(false)
										dragging_card.set_global_position(pos)
										update_draft = true

				inputs.reset_inputs()
				if update_draft:
					ui_state = UI_STATE.LOCKED
					core.action(core.EVENT_TYPE.UPDATE_DRAFT_AREA, [])


func set_gamestate(new_state):
	print("Set gamestate:", core.GAME_STATE.keys()[new_state])
	match new_state:
		core.GAME_STATE.START:
			call_deferred("start_game")
		core.GAME_STATE.DRAFT:
			call_deferred("mode_draft")
		core.GAME_STATE.PREPARE:
			call_deferred("mode_prepare")
		core.GAME_STATE.PREBATTLE:
			call_deferred("mode_pre_battle")
		core.GAME_STATE.BATTLE:
			call_deferred("mode_battle")
		core.GAME_STATE.POSTBATTLE:
			call_deferred("mode_post_battle")
	current_gamestate = new_state


func start_game():
	print("Start Game")
	ui_state = UI_STATE.WAITING
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
	ui_state = UI_STATE.LOCKED
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
	ui_state = UI_STATE.WAITING
	holder_allies.show_lineup()
	holder_enemy.show_lineup()
	core.action(core.EVENT_TYPE.GAME_STATE_TRANSITION, [core.GAME_STATE.PREPARE])
