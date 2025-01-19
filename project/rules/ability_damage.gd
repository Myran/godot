class_name AbilityDamage extends Ability

var damagetype


func _init(_damagetype):
	damagetype = _damagetype


func action(_tempus, _u_pos, _u_side, _battle_context, _event):
	pass


func draft_action(_tempus, _pos, _u, _draft_context, _event):
	print("draft action happening")
