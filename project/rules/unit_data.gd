class_name UnitData extends Resource

const POST_EVENT_RESPONSE: String = "post_event_response"
const PRE_EVENT_RESPONSE: String = "pre_event_response"
const DRAFT_POST_EVENT_RESPONSE: String = "draft_post_event_response"
const DRAFT_PRE_EVENT_RESPONSE: String = "draft_pre_event_response"

var max_health: int = 1
var max_attack: int = 1
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
			# Template abilities are marked as PERMANENT
			_ab.persistence_type = Ability.PersistenceType.PERMANENT
			add_ability(_ab)

	var ability: Ability
	# debug init cards with an ability (permanent template abilities)
	if card_info.id == str(1):
		ability = DamageShieldAbility.new()
		ability.persistence_type = Ability.PersistenceType.PERMANENT
		add_ability(ability)
	if card_info.id == str(2):
		ability = DeathTriggerHealthAbility.new(2)
		ability.persistence_type = Ability.PersistenceType.PERMANENT
		add_ability(ability)
	if card_info.id == str(12):
		ability = EvilSynergyAbility.new()
		ability.persistence_type = Ability.PersistenceType.PERMANENT
		add_ability(ability)
	if card_info.id == str(4):
		ability = MergeBonusAbility.new(1, 1)
		ability.persistence_type = Ability.PersistenceType.PERMANENT
		add_ability(ability)


func add_ability(_ability: Ability) -> void:
	# Check for duplicates before adding
	if not _has_ability_instance(_ability):
		abilities.append(_ability)


# Helper to check for duplicate ability instances
func _has_ability_instance(new_ability: Ability) -> bool:
	for existing_ability: Ability in abilities:
		if existing_ability.get_class() == new_ability.get_class():
			return true
	return false


func remove_ability(_ability: Ability) -> void:
	abilities.erase(_ability)


# Get abilities by persistence type
func get_permanent_abilities() -> Array[Ability]:
	return abilities.filter(
		func(ab: Ability) -> bool: return ab.persistence_type == Ability.PersistenceType.PERMANENT
	)


func get_acquired_abilities() -> Array[Ability]:
	return abilities.filter(
		func(ab: Ability) -> bool: return ab.persistence_type == Ability.PersistenceType.ACQUIRED
	)


func get_temporary_abilities() -> Array[Ability]:
	return abilities.filter(
		func(ab: Ability) -> bool: return ab.persistence_type == Ability.PersistenceType.TEMPORARY
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
	# Default values
	var health: String = "1"
	var attack: String = "1"

	# Get values only if they exist in card_info
	if card_info.has("health"):
		health = card_info.health
	else:
		Log.warning("Card info missing 'health' field", {"card_info": card_info}, ["debug"])

	if card_info.has("attack"):
		attack = card_info.attack
	else:
		Log.warning("Card info missing 'attack' field", {"card_info": card_info}, ["debug"])
	max_health = int(health) * _level
	max_attack = int(attack) * _level
	current_attack = max_attack
	current_health = max_health


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


# --- PERMANENT EFFECTS APPLICATION ---


# Apply all permanent stat effects to current stats (used for battle copies)
func apply_permanent_effects_to_current_stats() -> void:
	var total_health_bonus: int = 0
	var total_attack_bonus: int = 0

	for effect: Variant in effects_perm:
		if effect is StatEffect:
			total_health_bonus += effect.health_bonus
			total_attack_bonus += effect.attack_bonus

	# Apply bonuses to current stats
	current_attack += total_attack_bonus
	current_health += total_health_bonus

	Log.debug(
		"Applied permanent effects to current stats",
		{
			"health_bonus": total_health_bonus,
			"attack_bonus": total_attack_bonus,
			"final_attack": current_attack,
			"final_health": current_health,
			"effects_count": effects_perm.size()
		},
		[Log.TAG_BATTLE, Log.TAG_STAT, Log.TAG_EFFECT]
	)


# --- MERGE AND RECONCILIATION LOGIC ---


# Transfer acquired abilities from source units during merge
func transfer_acquired_abilities_from(source_units: Array[UnitData]) -> void:
	for source_unit: UnitData in source_units:
		var acquired_abilities: Array[Ability] = source_unit.get_acquired_abilities()
		for acquired_ability: Ability in acquired_abilities:
			# Only add if we don't already have this ability type
			if not _has_ability_instance(acquired_ability):
				abilities.append(acquired_ability)
				Log.debug(
					"Transferred acquired ability from merge",
					{"ability": acquired_ability.get_class()},
					[Log.TAG_CARD, Log.TAG_MERGE, Log.TAG_ABILITY]
				)


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

		# Check if we already have this exact effect (avoid duplicates)
		var already_has_effect: bool = false
		for existing_effect: Variant in self.effects_perm:
			if existing_effect is StatEffect:
				if (
					existing_effect.source == battle_effect.source
					and existing_effect.health_bonus == battle_effect.health_bonus
					and existing_effect.attack_bonus == battle_effect.attack_bonus
				):
					already_has_effect = true
					break

		if not already_has_effect:
			self.effects_perm.append(battle_effect)
			effects_transferred += 1
			Log.info(
				"Transferred permanent stat effect from battle",
				{"effect": battle_effect.get_description(), "unit_died": battle_died},
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
			# This is a new permanent ability gained during combat! Add it.
			self.add_ability(battle_ability)
			abilities_transferred += 1
			Log.info(
				"Unit gained new permanent ability from combat",
				{"ability": battle_ability.get_class(), "unit_died": battle_died},
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

	# Temporary abilities are automatically discarded when battle duplicates are discarded
	# Original units should only ever have PERMANENT and ACQUIRED abilities
