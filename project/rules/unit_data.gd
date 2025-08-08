class_name UnitData extends Resource

const POST_EVENT_RESPONSE: String = "post_event_response"
const PRE_EVENT_RESPONSE: String = "pre_event_response"
const DRAFT_POST_EVENT_RESPONSE: String = "draft_post_event_response"
const DRAFT_PRE_EVENT_RESPONSE: String = "draft_pre_event_response"

var max_health: int = 1
var max_attack: int = 1
var base_health: int = 1
var base_attack: int = 1

var current_health: int = 1:
	set = set_current_health
var current_attack: int = 1:
	set = set_current_attack
var level: int = 0
var card_info: Dictionary
var effects_temp: Array[Variant] = []
var effects_perm: Array[Variant] = []
# Single array with metadata-based persistence management
var abilities: Array[Ability] = []
# Reference to original unit for battle reconciliation (only set on battle duplicates)
var battle_original_reference: UnitData = null


# Helper to get all active abilities for the current context (e.g., during combat)
func get_active_abilities() -> Array[Ability]:
	return abilities


func set_current_health(new_health: int) -> void:
	if max_health < new_health:
		max_health = new_health
	current_health = new_health


func set_current_attack(new_attack: int) -> void:
	if max_attack < new_attack:
		max_attack = new_attack
	current_attack = new_attack


func init_with_info(_card_info: Dictionary) -> void:
	card_info = _card_info

	# Check if abilities exists in the card info
	var abilities_string: String = ""
	if card_info.has("abilities"):
		abilities_string = card_info.abilities
	else:
		Log.warning("Card info missing 'abilities' field", {"card_info": card_info}, ["debug"])

	var new_abilities: Array[Ability] = AbilitiesHandler.parse_ability_string(abilities_string)
	for _ab: Ability in new_abilities:
		if _ab != null:
			# Template abilities are marked as TEMPLATE
			_ab.persistence_type = Ability.PersistenceType.TEMPLATE
			add_ability(_ab)

	var ability: Ability
	# debug init cards with an ability (template abilities)
	if card_info.id == str(1):
		ability = DamageShieldAbility.new()
		ability.persistence_type = Ability.PersistenceType.TEMPLATE
		add_ability(ability)
	if card_info.id == str(2):
		ability = DeathTriggerHealthAbility.new(2)
		ability.persistence_type = Ability.PersistenceType.TEMPLATE
		add_ability(ability)
	if card_info.id == str(12):
		ability = EvilSynergyAbility.new()
		ability.persistence_type = Ability.PersistenceType.TEMPLATE
		add_ability(ability)
	if card_info.id == str(4):
		ability = MergeBonusAbility.new(1, 1)
		ability.persistence_type = Ability.PersistenceType.TEMPLATE
		add_ability(ability)


func add_ability(_ability: Ability) -> void:
	# Check for duplicates before adding
	# if not _has_ability_instance(_ability):
	abilities.append(_ability)


# Helper to check for duplicate ability instances
func _has_ability_instance(new_ability: Ability) -> bool:
	for existing_ability: Ability in abilities:
		if existing_ability.get_class() == new_ability.get_class():
			return true
	return false


# Helper function to convert persistence type to readable name for debugging
func _persistence_type_name(persistence_type: int) -> String:
	match persistence_type:
		Ability.PersistenceType.TEMPLATE:
			return "TEMPLATE"
		Ability.PersistenceType.ACQUIRED:
			return "ACQUIRED"
		Ability.PersistenceType.TEMPORARY:
			return "TEMPORARY"
		Ability.PersistenceType.ENHANCEMENT:
			return "ENHANCEMENT"
		_:
			return "UNKNOWN"


func remove_ability(_ability: Ability) -> void:
	abilities.erase(_ability)


# Get abilities by persistence type
func get_template_abilities() -> Array[Ability]:
	return abilities.filter(
		func(ab: Ability) -> bool: return ab.persistence_type == Ability.PersistenceType.TEMPLATE
	)


func get_permanent_abilities() -> Array[Ability]:
	# Legacy method - returns template abilities for backward compatibility
	return get_template_abilities()


func get_acquired_abilities() -> Array[Ability]:
	return abilities.filter(
		func(ab: Ability) -> bool: return ab.persistence_type == Ability.PersistenceType.ACQUIRED
	)


func get_temporary_abilities() -> Array[Ability]:
	return abilities.filter(
		func(ab: Ability) -> bool: return ab.persistence_type == Ability.PersistenceType.TEMPORARY
	)


func get_enhancement_abilities() -> Array[Ability]:
	return abilities.filter(
		func(ab: Ability) -> bool: return ab.persistence_type == Ability.PersistenceType.ENHANCEMENT
	)


# Clear only temporary abilities after battle
func clear_temporary_abilities() -> void:
	abilities = abilities.filter(
		func(ab: Ability) -> bool: return ab.persistence_type != Ability.PersistenceType.TEMPORARY
	)


func upgrade_unit_to_level(_new_level: int) -> void:
	level = int(_new_level)
	upgrade_stats_to_new_level(level)


func upgrade_stats_to_new_level(_level: int) -> void:
	var health: int = card_info.health.to_int()
	var attack: int = card_info.attack.to_int()

	base_health = health * _level
	base_attack = attack * _level

	apply_permanent_effects_to_current_stats()


func select_action(_battle_context: BattleContext) -> Dictionary:
	return {"action": Battle.BattleAction.ATTACK_REGULAR}


func draft_post_event_response(
	pos: int, _u: Block, _context: DraftContext, event: core.CoreEvent
) -> void:
	check_draft_abilities(core.Tempus.POST, pos, _context, event, _u)


func draft_pre_event_response(
	pos: int, _u: Block, _context: DraftContext, event: core.CoreEvent
) -> void:
	check_draft_abilities(core.Tempus.PRE, pos, _context, event, _u)


func pre_event_response(
	_u_pos: int, _u_side: int, _battle_context: BattleContext, _event: Context.Event
) -> void:
	check_abilities(core.Tempus.PRE, _u_pos, _u_side, _battle_context, _event)


func post_event_response(
	_u_pos: int, _u_side: int, _battle_context: BattleContext, _event: Context.Event
) -> void:
	check_abilities(core.Tempus.POST, _u_pos, _u_side, _battle_context, _event)


func check_abilities(
	tempus: int, u_pos: int, u_side: int, battle_context: BattleContext, _event: Context.Event
) -> void:
	for _ability: Ability in get_active_abilities():
		_ability.handle_battle_event(tempus, u_pos, u_side, battle_context, _event)


func check_draft_abilities(
	tempus: int, pos: int, context: DraftContext, event: core.CoreEvent, u: Block
) -> void:
	for _ability: Ability in get_active_abilities():
		_ability.handle_draft_event(tempus, pos, u, context, event)


# --- DEEP COPY HELPERS ---


# Create a deep copy of the abilities array with proper state isolation
func deep_duplicate_abilities() -> Array[Ability]:
	var duplicated_abilities: Array[Ability] = []
	for ability: Ability in abilities:
		duplicated_abilities.append(ability.deep_duplicate())
	return duplicated_abilities


# Create a deep copy of the effects_perm array with proper state isolation
func deep_duplicate_effects_perm() -> Array[Variant]:
	var duplicated_effects: Array[Variant] = []
	for effect: Variant in effects_perm:
		if effect is StatEffect:
			var stat_effect: StatEffect = effect
			if not stat_effect:
				Log.error(
					"Invalid StatEffect during duplication",
					{"card_id": card_info.get("id", "unknown")},
					[Log.TAG_ERROR]
				)
				continue
			duplicated_effects.append(stat_effect.deep_duplicate())
		else:
			# For non-StatEffect types, use standard duplication
			duplicated_effects.append(effect.duplicate(true) if effect is Resource else effect)
	return duplicated_effects


# --- PERMANENT EFFECTS APPLICATION ---


# Apply all permanent stat effects to current stats (used for battle copies)
func apply_permanent_effects_to_current_stats() -> void:
	var stats_before_attack: int = current_attack
	var stats_before_health: int = current_health
	var total_health_bonus: int = 0
	var total_attack_bonus: int = 0

	Log.debug(
		"STAT REAPPLICATION CALLED - Before applying effects",
		{
			"card_id": card_info.get("id", "unknown"),
			"level": level,
			"current_attack_before": stats_before_attack,
			"current_health_before": stats_before_health,
			"max_attack": max_attack,
			"max_health": max_health,
			"effects_perm_count": effects_perm.size(),
			"call_source": "apply_permanent_effects_to_current_stats"
		},
		[Log.TAG_BATTLE, Log.TAG_STAT, Log.TAG_EFFECT, "stat_refresh"]
	)

	for effect: Variant in effects_perm:
		if effect is StatEffect:
			var stat_effect: StatEffect = effect
			if not stat_effect:
				Log.error(
					"Invalid StatEffect in effects_perm array",
					{"card_id": card_info.get("id", "unknown")},
					[Log.TAG_ERROR]
				)
				continue

			total_health_bonus += stat_effect.health_bonus
			total_attack_bonus += stat_effect.attack_bonus
			Log.debug(
				"Processing StatEffect for reapplication",
				{
					"card_id": card_info.get("id", "unknown"),
					"effect_health": stat_effect.health_bonus,
					"effect_attack": stat_effect.attack_bonus,
					"running_health_total": total_health_bonus,
					"running_attack_total": total_attack_bonus
				},
				[Log.TAG_BATTLE, Log.TAG_STAT, Log.TAG_EFFECT, "stat_refresh"]
			)

	# Apply bonuses to base stats (max_attack/max_health are the level-appropriate base stats)
	max_attack = base_attack + total_attack_bonus
	max_health = base_health + total_health_bonus
	current_attack = max_attack
	current_health = max_health

	Log.info(
		"STAT REAPPLICATION COMPLETED - Stats updated",
		{
			"card_id": card_info.get("id", "unknown"),
			"level": level,
			"stats_before_attack": stats_before_attack,
			"stats_before_health": stats_before_health,
			"stats_after_attack": current_attack,
			"stats_after_health": current_health,
			"health_bonus_applied": total_health_bonus,
			"attack_bonus_applied": total_attack_bonus,
			"final_attack": current_attack,
			"final_health": current_health,
			"effects_count": effects_perm.size(),
			"stat_delta_attack": current_attack - stats_before_attack,
			"stat_delta_health": current_health - stats_before_health
		},
		[Log.TAG_BATTLE, Log.TAG_STAT, Log.TAG_EFFECT, "stat_refresh"]
	)


# --- MERGE AND RECONCILIATION LOGIC ---


# Transfer acquired abilities from source units during merge
func transfer_acquired_abilities_from(source_units: Array[UnitData]) -> void:
	for source_unit: UnitData in source_units:
		var acquired_abilities: Array[Ability] = source_unit.get_acquired_abilities()
		for acquired_ability: Ability in acquired_abilities:
			# Only add if we don't already have this ability type
			# if not _has_ability_instance(acquired_ability):
			abilities.append(acquired_ability)
			Log.debug(
				"Transferred acquired ability from merge",
				{"ability": acquired_ability.get_class()},
				[Log.TAG_CARD, Log.TAG_MERGE, Log.TAG_ABILITY]
			)


# Transfer stat effects from source units during merge
func transfer_stat_effects_from(source_units: Array[UnitData]) -> void:
	Log.debug(
		"Starting StatEffect transfer",
		{
			"target_card_id": card_info.get("id", ""),
			"source_units_count": source_units.size(),
			"target_effects_before": effects_perm.size()
		},
		[Log.TAG_MERGE, Log.TAG_EFFECT, Log.TAG_DEBUG]
	)

	for i: int in range(source_units.size()):
		var source_unit: UnitData = source_units[i]
		var source_card_id: String = source_unit.card_info.get("id", "")

		Log.debug(
			"Processing source unit for StatEffect transfer",
			{
				"source_index": i,
				"source_card_id": source_card_id,
				"source_effects_count": source_unit.effects_perm.size()
			},
			[Log.TAG_MERGE, Log.TAG_EFFECT, Log.TAG_DEBUG]
		)

		for j: int in range(source_unit.effects_perm.size()):
			var effect: Variant = source_unit.effects_perm[j]
			if effect is StatEffect:
				var stat_effect: StatEffect = effect
				if not stat_effect:
					Log.error(
						"Invalid StatEffect during transfer",
						{"source_card_id": source_card_id},
						[Log.TAG_ERROR, Log.TAG_MERGE]
					)
					continue
				# Create a deep copy to avoid reference sharing
				var copied_effect: StatEffect = stat_effect.deep_duplicate()
				effects_perm.append(copied_effect)

				Log.debug(
					"Transferred StatEffect from source unit",
					{
						"source_card_id": source_card_id,
						"target_card_id": card_info.get("id", ""),
						"effect_description": stat_effect.get_description(),
						"health_bonus": stat_effect.health_bonus,
						"attack_bonus": stat_effect.attack_bonus,
						"effect_source": stat_effect.source,
						"effect_id": stat_effect.get_instance_id(),
						"copied_effect_id": copied_effect.get_instance_id()
					},
					[Log.TAG_MERGE, Log.TAG_EFFECT, Log.TAG_DEBUG]
				)
			else:
				Log.debug(
					"Skipping non-StatEffect during transfer",
					{
						"source_card_id": source_card_id,
						"effect_type": effect.get_class() if effect != null else "null"
					},
					[Log.TAG_MERGE, Log.TAG_EFFECT, Log.TAG_DEBUG]
				)

	Log.debug(
		"Completed StatEffect transfer",
		{
			"target_card_id": card_info.get("id", ""),
			"target_effects_after": effects_perm.size(),
			"effects_transferred": effects_perm.size() - 0  # We know it started at 0 for new cards
		},
		[Log.TAG_MERGE, Log.TAG_EFFECT, Log.TAG_DEBUG]
	)


# Transfer both abilities and stat effects from source units during merge
func transfer_merge_effects_from(source_units: Array[UnitData]) -> void:
	Log.debug(
		"Starting merge effects transfer",
		{
			"target_card_id": card_info.get("id", ""),
			"source_units_count": source_units.size(),
			"target_abilities_before": abilities.size(),
			"target_effects_before": effects_perm.size()
		},
		[Log.TAG_MERGE, Log.TAG_EFFECT, Log.TAG_DEBUG]
	)

	# Transfer abilities (ACQUIRED + ENHANCEMENT types and temporary)
	for i: int in range(source_units.size()):
		var source_unit: UnitData = source_units[i]
		var source_card_id: String = source_unit.card_info.get("id", "")

		# Debug: Log ALL abilities in source unit with their persistence types
		Log.debug(
			"Source unit ability inventory (ALL abilities)",
			{
				"source_index": i,
				"source_card_id": source_card_id,
				"total_abilities": source_unit.abilities.size()
			},
			[Log.TAG_MERGE, Log.TAG_ABILITY, Log.TAG_DEBUG]
		)

		for j: int in range(source_unit.abilities.size()):
			var source_ability: Ability = source_unit.abilities[j]
			Log.debug(
				"Source ability details",
				{
					"source_card_id": source_card_id,
					"ability_index": j,
					"ability_class": source_ability.get_class(),
					"persistence_type": source_ability.persistence_type,
					"persistence_name": _persistence_type_name(source_ability.persistence_type)
				},
				[Log.TAG_MERGE, Log.TAG_ABILITY, Log.TAG_DEBUG]
			)

		var transferable_abilities: Array[Ability] = []
		transferable_abilities.append_array(source_unit.get_acquired_abilities())
		transferable_abilities.append_array(source_unit.get_enhancement_abilities())
		transferable_abilities.append_array(source_unit.get_temporary_abilities())

		Log.debug(
			"Processing source unit for ability transfer",
			{
				"source_index": i,
				"source_card_id": source_card_id,
				"template_abilities": source_unit.get_template_abilities().size(),
				"acquired_abilities": source_unit.get_acquired_abilities().size(),
				"enhancement_abilities": source_unit.get_enhancement_abilities().size(),
				"temporary_abilities": source_unit.get_temporary_abilities().size(),
				"transferable_abilities": transferable_abilities.size()
			},
			[Log.TAG_MERGE, Log.TAG_ABILITY, Log.TAG_DEBUG]
		)

		for ability: Ability in transferable_abilities:
			Log.debug(
				"Transferring ability",
				{
					"source_card_id": source_card_id,
					"target_card_id": card_info.get("id", ""),
					"ability_class": ability.get_class(),
					"persistence_type": ability.persistence_type,
					"persistence_name": _persistence_type_name(ability.persistence_type)
				},
				[Log.TAG_MERGE, Log.TAG_ABILITY, Log.TAG_DEBUG]
			)
			abilities.append(ability)

	# Transfer stat effects
	transfer_stat_effects_from(source_units)

	Log.debug(
		"Completed merge effects transfer",
		{
			"target_card_id": card_info.get("id", ""),
			"target_abilities_after": abilities.size(),
			"target_effects_after": effects_perm.size()
		},
		[Log.TAG_MERGE, Log.TAG_EFFECT, Log.TAG_DEBUG]
	)


# Optimized transfer directly from Cards (avoids intermediate UnitData array)
func transfer_merge_effects_from_cards(source_cards: Array[Card]) -> void:
	var source_units: Array[UnitData] = []
	for card: Card in source_cards:
		source_units.append(card.unit_info)
	transfer_merge_effects_from(source_units)


# Called after battle to apply permanent changes from battle duplicates back to originals
func apply_permanent_changes_from(final_battle_state: UnitData) -> void:
	var _original_effects_count: int = self.effects_perm.size()
	var _original_abilities_count: int = self.get_acquired_abilities().size()
	var battle_died: bool = final_battle_state.current_health <= 0

	Log.debug(
		"Applying permanent changes from battle",
		{
			"original_health": self.current_health,
			"battle_health": final_battle_state.current_health,
			"unit_died_in_battle": battle_died,
			"battle_effects_perm_count": final_battle_state.effects_perm.size(),
			"battle_acquired_abilities_count": final_battle_state.get_acquired_abilities().size()
		},
		[Log.TAG_BATTLE, Log.TAG_RECONCILIATION, Log.TAG_ABILITY]
	)

	# 1. Update max stats if they changed (abilities can permanently modify stats)
	if final_battle_state.max_health > self.max_health:
		self.max_health = final_battle_state.max_health
		Log.debug(
			"Max health increased during battle",
			{"old": self.max_health, "new": final_battle_state.max_health},
			[Log.TAG_BATTLE, Log.TAG_RECONCILIATION, Log.TAG_STAT]
		)
	if final_battle_state.max_attack > self.max_attack:
		self.max_attack = final_battle_state.max_attack
		Log.debug(
			"Max attack increased during battle",
			{"old": self.max_attack, "new": final_battle_state.max_attack},
			[Log.TAG_BATTLE, Log.TAG_RECONCILIATION, Log.TAG_STAT]
		)

	# 2. Restore health to max (battle damage is not permanent)
	self.current_health = self.max_health

	# 3. Transfer NEW permanent stat effects from battle (effects_perm array)
	var effects_transferred: int = 0
	for battle_effect: Variant in final_battle_state.effects_perm:
		if not battle_effect is StatEffect:
			continue

		var battle_stat_effect: StatEffect = battle_effect
		if not battle_stat_effect:
			Log.error(
				"Invalid StatEffect in battle state during reconciliation",
				{"unit_died": battle_died},
				[Log.TAG_ERROR, Log.TAG_BATTLE]
			)
			continue

		# Check if we already have this exact effect (avoid duplicates)
		var already_has_effect: bool = false
		for existing_effect: Variant in self.effects_perm:
			if existing_effect is StatEffect:
				var existing_stat_effect: StatEffect = existing_effect
				if not existing_stat_effect:
					continue
				if (
					existing_stat_effect.source == battle_stat_effect.source
					and existing_stat_effect.health_bonus == battle_stat_effect.health_bonus
					and existing_stat_effect.attack_bonus == battle_stat_effect.attack_bonus
				):
					already_has_effect = true
					break

		if not already_has_effect:
			self.effects_perm.append(battle_stat_effect)
			effects_transferred += 1
			Log.info(
				"Transferred permanent stat effect from battle",
				{"effect": battle_stat_effect.get_description(), "unit_died": battle_died},
				[Log.TAG_BATTLE, Log.TAG_RECONCILIATION, Log.TAG_STAT, Log.TAG_EFFECT]
			)

	# 4. Transfer ONLY NEW acquired abilities from the battle (ACQUIRED type)
	var current_ability_classes: Array[String] = []
	for ab: Ability in self.abilities:
		current_ability_classes.append(ab.get_class())

	var abilities_transferred: int = 0
	for battle_ability: Ability in final_battle_state.abilities:
		# Only transfer ACQUIRED abilities that we don't already have
		if (
			battle_ability.persistence_type == Ability.PersistenceType.ACQUIRED
			and not battle_ability.get_class() in current_ability_classes
		):
			# This is a new permanent ability gained during combat!
			# Convert it to ENHANCEMENT to prevent re-transfer in future combats
			var enhanced_ability: Ability = battle_ability.deep_duplicate()
			enhanced_ability.persistence_type = Ability.PersistenceType.ENHANCEMENT
			self.add_ability(enhanced_ability)
			abilities_transferred += 1
			Log.info(
				"Unit gained new permanent ability from combat (converted to ENHANCEMENT)",
				{
					"ability": enhanced_ability.get_class(),
					"unit_died": battle_died,
					"converted_from": "ACQUIRED"
				},
				[Log.TAG_BATTLE, Log.TAG_RECONCILIATION, Log.TAG_ABILITY]
			)

	# 5. Summary logging for validation
	Log.info(
		"Battle reconciliation summary",
		{
			"unit_died_in_battle": battle_died,
			"effects_perm_transferred": effects_transferred,
			"abilities_transferred": abilities_transferred,
			"final_effects_perm_count": self.effects_perm.size(),
			"final_acquired_abilities_count": self.get_acquired_abilities().size()
		},
		[Log.TAG_BATTLE, Log.TAG_RECONCILIATION, Log.TAG_VALIDATION]
	)

	# **CRITICAL**: Apply newly transferred permanent effects to current stats
	# This ensures that effects gained during battle affect the unit's current stats
	if effects_transferred > 0:
		self.apply_permanent_effects_to_current_stats()
		Log.debug(
			"Applied transferred battle effects to current stats",
			{
				"current_attack": self.current_attack,
				"current_health": self.current_health,
				"effects_applied": effects_transferred
			},
			[Log.TAG_BATTLE, Log.TAG_RECONCILIATION, Log.TAG_STAT]
		)

	# Temporary abilities are automatically discarded when battle duplicates are discarded
	# Original units should only ever have PERMANENT and ACQUIRED abilities
