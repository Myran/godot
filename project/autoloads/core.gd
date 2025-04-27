extends Node

signal event(event_data: CoreEvent)

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

const CARD_MERGE_AMOUNT: int = 3


class CoreEvent:
	extends Context.Event


class RerollDraftEvent:
	extends CoreEvent


class UpgradeEvent:
	extends CoreEvent
	var new_level: int

	func _init(m_level: int) -> void:
		self.new_level = m_level


class DraftMergeEvent:
	extends CoreEvent
	var matches: Array[Card]

	func _init(m_matches: Array[Card]) -> void:
		self.matches = m_matches


class DraftAddBlockEvent:
	extends CoreEvent
	var pos: Vector2i
	var block: Block
	var refill_count: int

	func _init(m_block: Block, m_pos: Vector2i, m_refill_count: int = 0) -> void:
		self.block = m_block
		self.pos = m_pos
		self.refill_count = m_refill_count


class BlockEntersPlay:
	extends CoreEvent
	var block: Block
	var pos: Vector2i

	func _init(m_block: Block, m_pos: Vector2i = Vector2i(-1, -1)) -> void:
		self.block = m_block
		self.pos = m_pos


class DraftColumnLocked:
	extends CoreEvent
	var col: int

	func _init(m_col: int) -> void:
		self.col = m_col


class DraftColumnUnlocked:
	extends CoreEvent
	var col: int

	func _init(m_col: int) -> void:
		self.col = m_col


class UpdateDraftAreaEvent:
	extends CoreEvent


class CardStatChangeEvent:
	extends CoreEvent
	var card: Card
	var health: int
	var attack: int

	func _init(m_card: Card, m_health: int = 0, m_attack: int = 0) -> void:
		self.card = m_card
		self.health = m_health
		self.attack = m_attack


class TransitionEvent:
	extends CoreEvent
	var new_state: GameState

	func _init(m_state: GameState) -> void:
		self.new_state = m_state


class EnemyLineupAddCardEvent:
	extends CoreEvent
	var card: Card
	var pos: int

	func _init(m_card: Card, m_pos: int) -> void:
		self.card = m_card
		self.pos = m_pos


class DebugLineupAddCardEvent:
	extends CoreEvent
	var card: Card
	var pos: int

	func _init(m_card: Card, m_pos: int) -> void:
		self.card = m_card
		self.pos = m_pos


class LineupAddCardEvent:
	extends CoreEvent
	var card: Card

	func _init(m_card: Card) -> void:
		self.card = m_card


class TrippleTestEvent:
	extends CoreEvent


class LineupMergeEvent:
	extends CoreEvent
	var card: Card
	var tripples: Array[Card]

	func _init(m_card: Card, m_tripples: Array[Card]) -> void:
		self.card = m_card
		self.tripples = m_tripples


class BattleEvent:
	extends CoreEvent
	var battle_events: Array[Context.Event]

	func _init(m_battle_events: Array[Context.Event]) -> void:
		self.battle_events = m_battle_events


class ResetUnitsEvent:
	extends CoreEvent


class DraftSteadyEvent:
	extends CoreEvent


class RemoveBlockFromDraft:
	extends CoreEvent
	var block: Block
	var destroy_block: bool

	func _init(m_block: Block, m_destroy_block: bool = false) -> void:
		self.block = m_block
		self.destroy_block = m_destroy_block


func action(_event: CoreEvent) -> void:
	event.emit(_event)


func _ready() -> void:
	Log.info("Core autoload initialized", {}, [Log.TAG_SYSTEM])
