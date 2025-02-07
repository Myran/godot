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
var effects_temp: Array = []
var effects_perm: Array = []
var abilities: Array = []


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
	var abilities_string: String = card_info.abilities
	var new_abilities: Array = AbilitiesHandler.parse_ability_string(abilities_string)
	for _ab: Ability in new_abilities:
		if _ab != null:
			add_ability(_ab)

	var ability: Resource
	# debug init cards with an ability
	if card_info.id == str(1):
		ability = DamageShieldAbility.new()
		add_ability(ability)
	if card_info.id == str(2):
		ability = DeathTriggerHealthAbility.new(2)
		add_ability(ability)
	if card_info.id == str(12):
		ability = EvilSynergyAbility.new()
		add_ability(ability)
	if card_info.id == str(4):
		ability = MergeBonusAbility.new(1, 1)
		add_ability(ability)


func add_ability(_ability: Resource) -> void:
	abilities.append(_ability)


func remove_ability(_ability: Resource) -> void:
	abilities.erase(_ability)


func upgrade_unit_to_level(_new_level: int) -> void:
	level = int(_new_level)
	upgrade_stats_to_new_level(level)


func upgrade_stats_to_new_level(_level: int) -> void:
	var health: String = card_info.health
	var attack: String = card_info.attack
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
	_u_pos: int, _u_side: int, _battle_context: BattleContext, _event: BattleContext.BaseEvent
) -> void:
	check_abilities(core.Tempus.PRE, _u_pos, _u_side, _battle_context, _event)


func post_event_response(
	_u_pos: int, _u_side: int, _battle_context: BattleContext, _event: BattleContext.BaseEvent
) -> void:
	check_abilities(core.Tempus.POST, _u_pos, _u_side, _battle_context, _event)


func check_abilities(
	tempus: int,
	u_pos: int,
	u_side: int,
	battle_context: BattleContext,
	_event: BattleContext.BaseEvent
) -> void:
	for _ability: Ability in abilities:
		_ability.handle_battle_event(tempus, u_pos, u_side, battle_context, _event)


func check_draft_abilities(
	tempus: int, pos: int, context: DraftContext, event: core.CoreEvent, u: Block
) -> void:
	for _ability: Ability in abilities:
		_ability.handle_draft_event(tempus, pos, u, context, event)
