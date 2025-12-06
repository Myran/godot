class_name CoreEventResolver extends RefCounted

## Static utility for handling resolution of core events
##
## This class extracts the large resolve_core_event function from Game.gd
## to improve maintainability and respect the 1000-line file limit.
## All event resolution logic is preserved exactly as-is.


static func resolve_core_event(
	event: core.CoreEvent,
	current_context: DraftContext,
	game: Game,
	card_handler: CardHandler,
	lineup_handler: LineupHandler,
	game_handler: GameHandler,
	holder_allies: HolderContainer,
	holder_enemy: HolderContainer,
	battle_layer: CanvasLayer,
	clicker: Clicker
) -> void:
	Log.debug(
		"Resolving core event",
		{"event_type": Utils.get_type(event)},
		[Log.TAG_GAME_STATE, Log.TAG_EVENT]
	)
	if event is core.CardStatChangeEvent:
		var card: Card = event.card
		if event.health != 0:
			var health: int = event.health
			Log.debug(
				"Changing card health",
				{"card": card.card_definition.id, "health_change": health},
				[Log.TAG_CARD]
			)
			card_handler.change_health(card, health)

		if event.attack != 0:
			var attack: int = event.attack
			Log.debug(
				"Changing card attack",
				{"card": card.card_definition.id, "attack_change": attack},
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
				{"card_id": target_card.card_definition.id},
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
				"card_id": target_card.card_definition.id,
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
				"card_id": target_card.card_definition.id,
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
				"card_id": target_card.card_definition.id,
				"effects_perm_count_after": target_card.unit_info.effects_perm.size(),
				"current_attack_after": target_card.unit_info.current_attack,
				"current_health_after": target_card.unit_info.current_health,
				"context": "StatEffectEvent_processing_unified_completed"
			},
			[Log.TAG_DEBUG, Log.TAG_STATS, Log.TAG_EFFECT, "stat_refresh"]
		)

		Log.info(
			"Added permanent stat effect",
			{
				"effect": permanent_effect.get_description(),
				"target": target_card.card_definition.id
			},
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
			{"card": card.card_definition.id, "position": pos},
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
			var card_id: String = card.card_definition.id
			SemanticLogger.log_draft_to_lineup_move(card_id, from_pos, to_pos)

		var remove_event: core.RemoveBlockFromDraft = core.RemoveBlockFromDraft.new(card, false)
		remove_event.source = core.EventSource.SYSTEM_CASCADE
		current_context.add_event(remove_event)
		current_context.solve_events()

		lineup_handler.add_card(card, to_pos)

		core.action(core.BlockEntersPlay.new(card))
		current_context.add_event(core.TrippleTestEvent.new())

		game.ui_state = core.UIState.LOCKED
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
					"card_id": tripples[0].card_definition.id,
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
				"base_card_id": card.card_definition.id,
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
				"new_card_id": new_card.card_definition.id,
				"new_card_level": new_card.level,
				"merge_successful": true
			},
			[Log.TAG_CARD, Log.TAG_RULES, Log.TAG_MERGE]
		)

		current_context = game.update_context_units(current_context)
		current_context.add_event(core.LineupAddCardEvent.new(new_card))
		current_context.solve_events()

	elif event is core.MoveLineupCardEvent:
		var card: Card = event.card
		var from_pos: int = event.from_position
		var to_pos: int = event.to_position

		Log.info(
			"Processing lineup card move action",
			{"card": card.card_definition.id, "from_position": from_pos, "to_position": to_pos},
			[Log.TAG_CARD, Log.TAG_LINEUP]
		)

		if event.source == core.EventSource.PLAYER:
			var card_id: String = card.card_definition.id
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
					{
						"card": card.card_definition.id,
						"from_position": from_pos,
						"to_position": to_pos
					},
					[Log.TAG_CARD, Log.TAG_LINEUP]
				)
		else:
			Log.warning(
				"Invalid lineup card move action - card not at expected position",
				{"card": card.card_definition.id, "from_position": from_pos, "to_position": to_pos},
				[Log.TAG_CARD, Log.TAG_LINEUP]
			)

	elif event is core.MoveLineupCardEvent and event.source == core.EventSource.SYSTEM_CASCADE:
		var card: Card = event.card
		var from_pos: int = event.from_position
		var to_pos: int = event.to_position

		Log.info(
			"Lineup card move event (system cascade)",
			{"card": card.card_definition.id, "from_position": from_pos, "to_position": to_pos},
			[Log.TAG_CARD, Log.TAG_LINEUP]
		)

	elif event is core.BattleEvent:
		Log.info(
			"Starting battle event sequence",
			{"event_count": event.battle_events.size()},
			[Log.TAG_BATTLE, Log.TAG_EVENT]
		)
		var enacter: BattleEnacter = BattleEnacter.new(battle_layer, holder_allies, holder_enemy)
		game.add_child(enacter)
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
		game.apply_battle_reconciliation(battle_result)

		game._refresh_lineup_card_ui_after_battle()

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
		game.ui_state = core.UIState.WAITING
		core.action(core.ProcessQueueEvent.new())

	elif event is core.LineupOperationStartEvent:
		Log.info("Lineup operation started - locking UI", {}, [Log.TAG_GAME_STATE, Log.TAG_UI])
		game.ui_state = core.UIState.LOCKED

	elif event is core.LineupOperationCompleteEvent:
		Log.info("Lineup operation completed - unlocking UI", {}, [Log.TAG_GAME_STATE, Log.TAG_UI])
		game.ui_state = core.UIState.WAITING
		core.action(core.ProcessQueueEvent.new())

	elif event is core.SequentialActionCompleteEvent:
		# Unified handler for all sequential actions (Firebase Backend, RTDB, etc.)
		var category_label: String = event.category if event.category != "" else "Sequential"

		# CRITICAL FIX: Set _processing_idle_action=false for completed async operations
		# This allows Desktop auto_quit to work correctly after SequentialActionCompleteEvent
		if game._processing_idle_action:
			Log.info(
				"SETTING _processing_idle_action=false - SequentialActionCompleteEvent processed",
				{
					"action_name": event.action_name,
					"success": event.success,
					"category": event.category,
					"async_operation_complete": true,
					"auto_quit_can_now_proceed": true,
					"test_id": DebugAction.get_current_test_id()
				},
				[
					Log.TAG_SYSTEM,
					Log.TAG_IDLE_ACTION,
					"sequential_complete",
					"async_operation",
					Log.TAG_DIAGNOSTIC
				]
			)
			game._processing_idle_action = false

		Log.info(
			"Sequential action completed - continuing queue processing",
			{
				"action_name": event.action_name,
				"success": event.success,
				"category": event.category,
				"trigger_reason": "sequential_action_completion"
			},
			[Log.TAG_SYSTEM, Log.TAG_EVENT, "sequential_action_complete"]
		)
		core.action(core.ProcessQueueEvent.new())

	elif event is core.SystemIdleActionEvent:
		var state_name: String = ["INITIALIZING", "WAITING", "HOLDING", "LOCKED"][game.ui_state]
		var current_test_id: String = DebugAction.get_current_test_id()
		var event_timestamp: float = Time.get_unix_time_from_system()

		Log.info(
			"=== SYSTEM IDLE ACTION EVENT RECEIVED ===",
			{
				"ui_state": state_name,
				"queue_size_before": game._idle_action_queue.size(),
				"queue_size_after": game._idle_action_queue.size() + 1,
				"processing_idle_action": game._processing_idle_action,
				"test_id": current_test_id,
				"event_timestamp": event_timestamp,
				"event_frame": Engine.get_process_frames(),
				"can_process_immediately":
				game.ui_state == core.UIState.WAITING and not game._processing_idle_action
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

		game._idle_action_queue.append(
			{"action": event.action_callable, "auto_continue": event.auto_continue}
		)
		core.action(core.ProcessQueueEvent.new())

	elif event is core.ProcessQueueEvent:
		# CRITICAL FIX (Task-314): Prevent queue processing during batch dispatch
		# This ensures all actions are added to the queue before any processing starts
		if game._queue_paused:
			Log.info(
				"Queue processing paused during batch dispatch",
				{
					"queue_size": game._idle_action_queue.size(),
					"batch_dispatch_active": true,
					"test_id": DebugAction.get_current_test_id()
				},
				[Log.TAG_SYSTEM, Log.TAG_EVENT, "queue_paused", Log.TAG_DIAGNOSTIC]
			)
			return
		# If processing an action, remember the continuation request for after completion
		if game._processing_idle_action:
			game._queue_continuation_requested = true
			return
		# Return early if UI not ready - preserves queue for later processing
		if game.ui_state != core.UIState.WAITING:
			return
		game._process_one_queue_item()

	elif Utils.get_type(event) == "QuitApplicationEvent":
		Log.info(
			"QuitApplicationEvent received - starting application termination",
			{
				"event_type": "QuitApplicationEvent",
				"ui_state": ["INITIALIZING", "WAITING", "HOLDING", "LOCKED"][game.ui_state],
				"test_id": DebugAction.get_current_test_id()
			},
			[Log.TAG_SYSTEM, Log.TAG_EVENT, "quit", Log.TAG_DIAGNOSTIC]
		)

		# Execute the quit event's async logic
		await event.execute()

	clicker.on_core_event(event, current_context)
