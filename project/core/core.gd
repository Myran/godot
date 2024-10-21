extends Control 
#class_name draft

#@onready var card_pop = get_node("%popup_card")
# @onready var faction_pop = get_node("%popup_faction")
#@onready var holder_draft = get_node("%holder_draft")
#@onready var holder_allies = get_node("%holder_allies")
#@onready var holder_enemy = get_node("%holder_enemy")
#@onready var bottom_bar_draft = get_node("%bottom_bar_draft")
#@onready var bottom_bar_prepare = get_node("%bottom_bar_prepare")
#@onready var blur_layer = get_node("%canvas_layer_blur")
#@onready var top_bar = get_node("%canvas_layer_top_bar")
#@onready var battle_layer = get_node("%canvas_layer_battle")
#@onready var unhandled_layer = get_node("canvas_layer_unhandled_events")
@export var card_pop : Control
@export var holder_draft : Node
@export var holder_allies : Control
@export var holder_enemy : Control
@export var bottom_bar_draft : Control
@export var bottom_bar_prepare : Control
@export var blur_layer : CanvasLayer
@export var top_bar : CanvasLayer
@export var battle_layer : CanvasLayer
@export var unhandled_layer : CanvasLayer

enum TAP_STATE {IDLE,PRESSING,UNPRESSING,HOLDING}
enum UI_STATE{WAITING,HOLDING,LOCKED}

enum SOLVE_TYPE{CORE,UI}

const tap_time = 0.25
signal merge_done

var main = null
var tap_timer = 0
var holding_item = null
var last_item = null
var tap_state = TAP_STATE.IDLE
var dragging_cargo = null
var drag_start_pos = null
var ui_state = UI_STATE.WAITING
var current_gamestate
var enacter

var current_draft_upgrade_level = 0
var merging_tripples = []
var current_battle
var last_touch_pos = null
var _seed = 1
func _ready():
	await data_source.activate_card_cache()
	rng.seededRNG.reset(_seed)
	holder_draft.setup()
	set_gamestate(core.GAME_STATE.START)
	blur_layer.unblur()
	ui.connect(ui.SIGNAL_EVENT, Callable(self, "new_event").bind(SOLVE_TYPE.UI))
	core.connect(core.SIGNAL_EVENT, Callable(self, "new_event").bind(SOLVE_TYPE.CORE))
	debug.connect(debug.SIGNAL_DEBUG, Callable(self, "_on_debug_event"))
	
	enacter = battle_enacter.new(battle_layer,holder_allies,holder_enemy)
	add_child(enacter)

func _input(event):
	if (event is InputEventScreenDrag and (tap_state == TAP_STATE.HOLDING or tap_state == TAP_STATE.PRESSING)):
		last_touch_pos = event.position
		
func _process(delta):
	if tap_state == TAP_STATE.PRESSING:
		tap_timer = tap_timer + delta
		if holding_item and last_touch_pos and tap_timer> 0.15:
			holding_item.set_global_position(lerp(holding_item.get_global_position(),last_touch_pos,0.25))
		if tap_timer > tap_time:
			if holding_item:
				tap_state = TAP_STATE.HOLDING
				tap_timer = 0
				holding()
	elif tap_state == TAP_STATE.HOLDING:
		if last_touch_pos and dragging_cargo:
				dragging_cargo.set_global_position(lerp(dragging_cargo.get_global_position(),last_touch_pos,0.99))

func holding():
	var pos = holding_item.get_global_position()
	holding_item.set_as_top_level(true)
	holding_item.set_global_position(pos)# prova addera offset från event på kortet
	dragging_cargo = holding_item
	dragging_cargo.set_process_input(false)
	holding_item = null
	#unhandled_layer.input_handling(true)


func _on_debug_event(event,_data):
	match event:
		debug.DEBUG_EVENT_TYPE.EVENT_RESET_MATCH_LEVEL,debug.DEBUG_EVENT_TYPE.EVENT_FORCE_LOAD_MATCH_LEVEL:
			current_draft_upgrade_level = 0

func new_event(event_type,data,solve_type):
	printt("New event: ", event_type,data,solve_type)
	var _context = create_draft_context()
	var event = context.event.new(solve_type,event_type,data)
	_context.add_event(event)
	_context.solve_events()

func create_draft_context():
	var _context = draft_context.new(self)
	_context = update_context_units(_context)
	return _context

func update_context_units(_context):
	_context.lineup = holder_allies.get_current_lineup()
	if core.clicker:
		_context.draft_area = core.clicker.get_all_cards()
	return _context


func solve_event(event,_context):
	var ret_context = _context
	match event.solve_type:
		SOLVE_TYPE.CORE:
			resolve_core_event(event.event_type,event.data,_context)
			if core.clicker:
				core.clicker._on_core_event(event.event_type,event.data)
		SOLVE_TYPE.UI:
			resolve_ui_event(event.event_type,event.data,_context)
			pass
	return ret_context
	



func resolve_core_event(event_type,_data,current_context):
	print("event:",core.EVENT_TYPE.keys()[event_type])
	match event_type:
		core.EVENT_TYPE.CARD_STAT_CHANGE:
			var _card = _data.card
			if _data.has("health"):
				var _health_amount = _data.health
				var current_health = _card.unit_info.current_health
				var new_health = current_health + _health_amount
				_card.unit_info.current_health = new_health
				_card.card_base.set_card_health(new_health)
			if _data.has("attack"):
				var _attack_amount = _data.attack
				var current_attack = _card.unit_info.current_attack
				var new_attack = current_attack + _attack_amount
				_card.unit_info.current_attack = new_attack
				_card.card_base.set_card_attack(new_attack)
			_card.show_upgrade()
			
		core.EVENT_TYPE.CARD_FINISHED_MOVING_TOP:
			var card = _data
			card.queue_free()
			merging_tripples.erase(card)
			if merging_tripples.size() == 0:
				update_context_units(current_context)
				emit_signal("merge_done")

		core.EVENT_TYPE.GAME_STATE_TRANSITION:
			var new_state = _data[0]
			set_gamestate(new_state)
			
		core.EVENT_TYPE.ENEMY_LINEUP_ADD_CARD:
			var card = _data[0]
			var pos = _data[1]
			var holder = holder_enemy.get_holder(pos)
			holder.set_card(card)

		core.EVENT_TYPE.LINEUP_ADD_CARD:
			var card = _data[0]
			var pos = null
			if _data.size() == 2:
				pos = _data[1]
				var holder = holder_allies.get_holder(pos)
				holder.set_card(card)
			current_context.add_event({solve_type = SOLVE_TYPE.CORE,event_type = core.EVENT_TYPE.TRIPPLE_TEST,data = []})

		core.EVENT_TYPE.TRIPPLE_TEST:
			var lineup = holder_allies.get_current_lineup()
			for card in lineup.values():
				var tripples = []
				for lineup_card in lineup.values():
					if lineup_card.card_info.id == card.card_info.id and lineup_card.level == card.level:
						if not tripples.has(lineup_card):
							tripples.append(lineup_card)
				if tripples.size() >= 3:
					print("Tripple found: ",tripples)
					current_context.add_event({solve_type = SOLVE_TYPE.CORE,event_type = core.EVENT_TYPE.LINEUP_MERGE,data = [card,tripples]})
					current_context.solve_events()
					break

			
		core.EVENT_TYPE.LINEUP_MERGE:
			var card = _data[0]
			var tripples = _data[1]
			var new_card
			var merge_pos
			
			for trip_card in tripples:
				merging_tripples.append(trip_card)
				var lineup_pos = holder_allies.get_card_position(trip_card)
				var holder = holder_allies.get_holder(lineup_pos)
				holder.remove_card()
				update_context_units(current_context)
				if trip_card == card:
					new_card = await card_controller.create_unit_from_id(card.card_info.id,card.level+1)
					new_card.context = cards.CONTEXT.LINEUP
					holder.set_card(new_card)
					new_card.show_upgrade()
					merge_pos = new_card.get_global_position()

				#trip_card.queue_free()
			for trip_card in tripples:
				trip_card.move_to_on_top(merge_pos)
			await self.merge_done
			current_context.add_event({solve_type = SOLVE_TYPE.CORE,event_type = core.EVENT_TYPE.LINEUP_ADD_CARD,data = [new_card]})
			current_context.solve_events()

		core.EVENT_TYPE.BATTLE:
			var battle_events = _data[0]
			enacter.enact(battle_events)

		core.EVENT_TYPE.RESET_UNITS:
			pass



	
func resolve_ui_event(_event_type,_data,current_context):
	if ui_state == UI_STATE.LOCKED: return
	#print("event:",ui.EVENT_TYPE.keys()[_event_type])
	match _event_type:
		ui.EVENT_TYPE.DRAFT_HOLD_TOGGLED:
			var new_state = _data[0]
			var col = _data[1]
			var state
			if new_state:
				state = core.EVENT_TYPE.DRAFT_COLOUMN_LOCKED
			else:
				state = core.EVENT_TYPE.DRAFT_COLUMN_UNLOCKED
			core.emit_signal(core.SIGNAL_EVENT,state,[col])

		ui.EVENT_TYPE.TRANSITION:
			var state = _data
			core.emit_signal(core.SIGNAL_EVENT,core.EVENT_TYPE.GAME_STATE_TRANSITION,state)
			
		ui.EVENT_TYPE.START_BATTLE:
			print("Start battle")
			# create battle events and result
			var allies = holder_allies.get_current_lineup()
			var enemies = holder_enemy.get_current_lineup()
			var _battle = await battle.new()
			var prep_allies = _battle.prepare_lineup_from_holder(allies)
			var prep_enemies = _battle.prepare_lineup_from_holder(enemies)
			var battle_result = _battle.battle_start(prep_allies,prep_enemies)
			current_battle = battle_result
			ui.emit_signal(ui.SIGNAL_EVENT,ui.EVENT_TYPE.TRANSITION,[core.GAME_STATE.PREBATTLE])
			#save result
			# new state, close input
			# enact battle
		ui.EVENT_TYPE.REROLL:
			core.emit_signal(core.SIGNAL_EVENT,core.EVENT_TYPE.REROLL_DRAFT,[])

		ui.EVENT_TYPE.TAP_POP_CARD:
			blur_layer.unblur()
			card_pop.hide()

		ui.EVENT_TYPE.UPGRADE:
			#check cost here
			current_draft_upgrade_level += 1
			core.emit_signal(core.SIGNAL_EVENT,core.EVENT_TYPE.UPGRADE,[current_draft_upgrade_level])

		ui.EVENT_TYPE.TOUCH:
			var interacted_object = _data[0]
			var event = _data[1]
			#printt("interacted_object: ",interacted_object,"event:",event,"is_pressed:",event.pressed,"current cargo:",dragging_cargo)
			var update_draft = false

			if event.pressed == true:
				match tap_state:
					TAP_STATE.IDLE:
						match interacted_object.object_type:
							core.OBJECT_TYPE.CARD:
								tap_state = TAP_STATE.PRESSING
								#unhandled_layer.input_handling(false)
								holding_item = interacted_object
								drag_start_pos = interacted_object.position
							core.OBJECT_TYPE.CARD_HOLDER:
								pass
							core.OBJECT_TYPE.BLOCK_LOCKED:
								tap_state = TAP_STATE.PRESSING

			elif event.pressed == false:
				match tap_state:
					TAP_STATE.PRESSING:
						if interacted_object.object_type == core.OBJECT_TYPE.CARD:
							blur_layer.blur()
							card_pop.show_card(interacted_object)
							update_draft = true
						if interacted_object.object_type == core.OBJECT_TYPE.BLOCK_LOCKED:
							core.emit_signal(core.SIGNAL_EVENT,core.EVENT_TYPE.REMOVE_BLOCK_FROM_DRAFT,[interacted_object,true])
							update_draft = true

					TAP_STATE.HOLDING:
						if dragging_cargo.object_type == core.OBJECT_TYPE.CARD:
							dragging_cargo.set_process_input(true)
							var release_handled = false
							var dragging_card = dragging_cargo
							match interacted_object.object_type:
								core.OBJECT_TYPE.BACKGROUND:
									pass
								core.OBJECT_TYPE.CARD:
									if interacted_object == dragging_card:
										return
								core.OBJECT_TYPE.CARD_HOLDER:
									var interacted_holder = interacted_object
									match dragging_card.context:
										cards.CONTEXT.LINEUP:
											var prev_holder = dragging_card.holder
											if interacted_holder.set_card(dragging_card):
												prev_holder.remove_card()
												release_handled = true

										cards.CONTEXT.DRAFT:
											if is_instance_valid(dragging_card):
												if core.clicker.has_card(dragging_card):
													release_handled = interacted_holder.set_card(dragging_card)
													if release_handled:
														current_context.add_event({solve_type = SOLVE_TYPE.CORE,event_type = core.EVENT_TYPE.REMOVE_BLOCK_FROM_DRAFT,data = [dragging_card]})
														current_context.solve_events()
														current_context.add_event({solve_type = SOLVE_TYPE.CORE,event_type = core.EVENT_TYPE.LINEUP_ADD_CARD,data = [dragging_card]})
														current_context.solve_events()
														update_draft = true

							if not release_handled:
								match dragging_card.context:
									cards.CONTEXT.LINEUP:
										dragging_card.holder.pos_card_in_holder()
									cards.CONTEXT.DRAFT:
										var pos = dragging_card.get_global_position()
										dragging_card.set_as_top_level(false)
										dragging_card.set_global_position(pos)
										update_draft = true

				tap_state = TAP_STATE.IDLE
				tap_timer = 0
				dragging_cargo = null
				holding_item = null
				last_touch_pos = null

				if update_draft:
					core.emit_signal(core.SIGNAL_EVENT,core.EVENT_TYPE.UPDATE_DRAFT_AREA,[])


func set_gamestate(new_state):
	print("Set gamestate:",core.GAME_STATE.keys()[new_state])
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
	core.emit_signal(core.SIGNAL_EVENT,core.EVENT_TYPE.GAME_STATE_TRANSITION,[core.GAME_STATE.PREPARE])

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
	core.emit_signal(core.SIGNAL_EVENT,core.EVENT_TYPE.GAME_STATE_TRANSITION,[core.GAME_STATE.BATTLE])

func mode_battle():
	print("Battle Mode")
	core.emit_signal(core.SIGNAL_EVENT,core.EVENT_TYPE.BATTLE,[current_battle])

func mode_post_battle():
	print("Post Battle Mode")
	ui_state = UI_STATE.WAITING
	holder_allies.show_lineup()
	holder_enemy.show_lineup()
	core.emit_signal(core.SIGNAL_EVENT,core.EVENT_TYPE.GAME_STATE_TRANSITION,[core.GAME_STATE.PREPARE])
