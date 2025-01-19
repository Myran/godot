extends Node

signal event
enum UIState { WAITING, HOLDING, LOCKED }
enum Tempus { PRE, POST }
enum TapState { IDLE, PRESSING, UNPRESSING, HOLDING }
enum GameState { START, DRAFT, PREPARE, PREBATTLE, BATTLE, POSTBATTLE }
enum ObjectType {
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
const CARD_MERGE_AMOUNT = 3


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
	var pos: Vector2i
	var block: Block
	var refill_count: int

	func _init(_block: Block, _pos: Vector2i, _refill_count: int = 0) -> void:
		block = _block
		pos = _pos
		refill_count = _refill_count


class BlockEntersPlay:
	extends CoreEvent
	var block: Block
	var pos: Vector2i

	func _init(_block: Block, _pos: Vector2i = Vector2i(-1, -1)) -> void:
		block = _block
		pos = _pos


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
	var new_state: GameState

	func _init(_new_state: GameState) -> void:
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
	var card: Card

	func _init(_card: Card) -> void:
		card = _card


class TrippleTestEvent:
	extends CoreEvent


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


class DraftSteadyEvent:
	extends CoreEvent


class RemoveBlockFromDraft:
	extends CoreEvent
	var block: Variant
	var destroy_block: bool

	func _init(_block: Variant, _destroy_block: bool = false) -> void:
		block = _block
		destroy_block = _destroy_block


func action(_event: CoreEvent):
	event.emit(_event)


func _ready():
	print("core autoload ready")
