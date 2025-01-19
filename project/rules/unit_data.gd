class_name UnitData extends Resource
const POST_EVENT_RESPONSE = "post_event_response"
const PRE_EVENT_RESPONSE = "pre_event_response"

const DRAFT_POST_EVENT_RESPONSE = "draft_post_event_response"
const DRAFT_PRE_EVENT_RESPONSE = "draft_pre_event_response"

var max_health: int = 1
var max_attack = 1
var current_health = 1:
	set = set_current_health
var current_attack = 1:
	set = set_current_attack

var level = 0
var card_info
var effects_temp = []
var effects_perm = []
var abilities = []


func set_current_health(new_health):
	if max_health < new_health:
		max_health = new_health
	current_health = new_health


func set_current_attack(new_attack):
	if max_attack < new_attack:
		max_attack = new_attack
	current_attack = new_attack


func init_with_info(_card_info):
	card_info = _card_info
	var abilities_string = card_info.abilities
	var new_abilities = AbilitiesHandler.parse_abilities(abilities_string)
	for _ab in new_abilities:
		if _ab != null:
			add_ability(_ab)
	var ability
	#debug init cards with an ability
	if card_info.id == str(1):
		ability = AbilityShield.new()
		add_ability(ability)
	if card_info.id == str(2):
		ability = AbilityHealthOnDeath.new(2)
		add_ability(ability)
	if card_info.id == str(12):
		ability = AbilityTroll.new()
		add_ability(ability)
	if card_info.id == str(4):
		ability = AbilityMergeBonus.new(1, 1)
		add_ability(ability)


#Implies on of each ability maximum?
func add_ability(_ability):
	abilities.append(_ability)


func remove_ability(_ability):
	abilities.erase(_ability)


func upgrade_unit_to_level(_new_level):
	level = int(_new_level)
	upgrade_stats_to_new_level(level)


func upgrade_stats_to_new_level(_level):
	max_health = int(card_info.health) * _level
	max_attack = int(card_info.attack) * _level
	current_attack = max_attack
	current_health = max_health


func select_action(_battle_context):
	return {"action": Battle.BattleAction.ATTACK_REGULAR}


func draft_post_event_response(pos, _context, event, _u):
	check_draft_abilities(core.Tempus.POST, pos, _context, event, _u)


func draft_pre_event_response(pos, _context, event, _u):
	check_draft_abilities(core.Tempus.PRE, pos, _context, event, _u)


func pre_event_response(_u_pos, _u_side, _battle_context, _event):
	check_abilities(core.Tempus.PRE, _u_pos, _u_side, _battle_context, _event)


func post_event_response(_u_pos, _u_side, _battle_context, _event):
	check_abilities(core.Tempus.POST, _u_pos, _u_side, _battle_context, _event)


func check_abilities(tempus, _u_pos, _u_side, _battle_context, _event):
	for _ability in abilities:
		_ability.action(tempus, _u_pos, _u_side, _battle_context, _event)


func check_draft_abilities(tempus, pos, _context, event, _u):
	for _ability in abilities:
		_ability.draft_action(tempus, pos, _context, event, _u)
