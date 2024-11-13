extends Node

signal event
const CARD_MERGE_AMOUNT = 3
enum UI_STATE { WAITING, HOLDING, LOCKED }
enum SOLVE_TYPE { CORE, UI, BATTLE }
enum Tempus { PRE, POST }
enum TAP_STATE { IDLE, PRESSING, UNPRESSING, HOLDING }

enum GAME_STATE { START, DRAFT, PREPARE, PREBATTLE, BATTLE, POSTBATTLE }

enum EVENT_TYPE {
	TEST,
	UPDATE_DRAFT_AREA,
	REMOVE_BLOCK_FROM_DRAFT,
	UPGRADE,
	GAME_STATE_TRANSITION,
	DRAFT_ADD_BLOCK,
	REROLL_DRAFT,
	LINEUP_MERGE,
	DRAFT_MERGE,
	LINEUP_ADD_CARD,
	CARD_FINISHED_MOVING,
	CARD_MERGE_MOVE_FINISHED,
	CARD_FINISHED_MOVING_TOP,
	ENEMY_LINEUP_ADD_CARD,
	DRAFT_COLOUMN_LOCKED,
	DRAFT_COLUMN_UNLOCKED,
	BATTLE,
	RESET_UNITS,
	CARD_STAT_CHANGE,
	TRIPPLE_TEST,
	DRAFT_STEADY,
}

enum OBJECT_TYPE {
	TEST,
	CARD,
	CARD_HOLDER,
	BACKGROUND,
	BLOCK_LOCKED,
	BLOCK_UPGRADE,
	EMPTY_SPACE,
	BLOCK_NOSPACE,
	BLOCK_PASSTROUGH,
	BLOCK_ITEM
}


class CoreEvent:
	pass


class RerollDraftEvent:
	extends CoreEvent


class UpgradeEvent:
	extends CoreEvent
	var new_level: int

	func _init(_new_level: int) -> void:
		new_level = _new_level


class DraftMergeEvent:
	extends CoreEvent
	var matches: Array

	func _init(_matches: Array) -> void:
		matches = _matches


class DraftAddBlockEvent:
	extends CoreEvent
	var info: Dictionary

	func _init(_info: Dictionary) -> void:
		info = _info


class DraftColumnLocked:
	extends CoreEvent
	var col: int

	func _init(_col: int) -> void:
		col = _col


class DraftColumnUnlocked:
	extends CoreEvent
	var col: int

	func _init(_col: int) -> void:
		col = _col


class UpdateDraftAreaEvent:
	extends CoreEvent
	pass


class CardStatChangeEvent:
	extends CoreEvent
	var card: Card
	var health: int
	var attack: int

	func _init(_card: Card, _health: int = 0, _attack: int = 0) -> void:
		card = _card
		health = _health
		attack = _attack


class TransitionEvent:
	extends CoreEvent
	var new_state: core.GAME_STATE

	func _init(_new_state: core.GAME_STATE) -> void:
		new_state = _new_state


class EnemyLineupAddCardEvent:
	extends CoreEvent
	var card: Card
	var pos: int

	func _init(_card: Card, _pos: int) -> void:
		card = _card
		pos = _pos


class DebugLineupAddCardEvent:
	extends CoreEvent
	var card: Card
	var pos: int

	func _init(_card: Card, _pos: int) -> void:
		card = _card
		pos = _pos


class LineupAddCardEvent:
	extends CoreEvent
	var card

	func _init(_card: Card) -> void:
		card = _card


class TrippleTestEvent:
	extends CoreEvent
	pass


class LineupMergeEvent:
	extends CoreEvent
	var card: Card
	var tripples: Array

	func _init(_card: Card, _tripples: Array) -> void:
		card = _card
		tripples = _tripples


class BattleEvent:
	extends CoreEvent
	var battle_events: Array

	func _init(_battle_events: Array) -> void:
		battle_events = _battle_events


class ResetUnitsEvent:
	extends CoreEvent
	pass


class DraftSteadyEvent:
	extends CoreEvent
	pass


class RemoveBlockFromDraft:
	extends CoreEvent
	var block: Variant
	var destroy_block: bool

	func _init(_block: Variant, _destroy_block: bool = false) -> void:
		block = _block
		destroy_block = _destroy_block


func action(_event: core.CoreEvent):
	event.emit(_event)


func _ready():
	print("core autoload ready")
