class_name GameConstants
extends RefCounted

# ================================
# CARD SYSTEM CONSTANTS
# ================================


class CardSystem:
	const DEFAULT_HEALTH: int = 1
	const DEFAULT_ATTACK: int = 1
	const DEFAULT_LEVEL: int = 1
	const LEVEL_TWO: int = 2
	const LEVEL_THREE: int = 3
	const DEFAULT_UNIT_LEVEL: int = 1


# ================================
# UNIT CLASSIFICATION CONSTANTS
# ================================


class UnitTags:
	"""
	Unit Tags - Used to categorize units with multiple possible classifications.
	Units can have multiple tags (comma-separated in data).

	Complete list of all tags found in game data:
	- evil: Found in 3 units (knight_red, monk, mooseman)
	- forest: Found in 3 units (knight_green, monk, swordman)
	- knight: Found in 6 units (knight_blue, knight_green, knight_red, monk, swordman, knight_gold)
	- soldier: Found in 2 units (monk, archer)

	Note: 21 units have no tags (empty string)
	"""
	const EVIL: String = "evil"
	const FOREST: String = "forest"
	const KNIGHT: String = "knight"
	const MAGIC: String = "magic"
	const SOLDIER: String = "soldier"


class BlockSystem:
	const TYPE_ZERO: int = 0
	const UPGRADE_LEVEL_FOUR: int = 4
	const UPGRADE_LEVEL_FIVE: int = 5


# ================================
# GRID AND LAYOUT CONSTANTS
# ================================


class GridSystem:
	const WIDTH: int = 5
	const HEIGHT: int = 5


# ================================
# PLAYER CONSTANTS
# ================================


class PlayerSystem:
	const DEFAULT_LEVEL: int = 1
	const DEFAULT_LIVES: int = 3


# ================================
# RANDOM NUMBER GENERATION
# ================================


class RandomSystem:
	const DEFAULT_SEED: int = 12345
	const HARD_RESET_SEED: int = 54321
	const UNIT_LEVEL_ROLL_MAX: int = 99


# ================================
# BATTLE SYSTEM CONSTANTS
# ================================


class BattleSystem:
	const ZERO_HEALTH_THRESHOLD: int = 0
	const ZERO_ATTACK_THRESHOLD: int = 0
	const ZERO_STAT_VALUE: int = 0


# ================================
# UI AND ANIMATION CONSTANTS
# ================================


class UISystem:
	const FULL_ROTATION_DEGREES: int = 360
	const PADDING: int = 20
	const PANEL_HEIGHT: int = 30


# ================================
# PERFORMANCE AND TIMING
# ================================


class TimingSystem:
	const FPS_ASSUMPTION: int = 60
	const WARNING_THRESHOLD_SEC: int = 5
	const MILLISECONDS_PER_SECOND: int = 1000


# ================================
# NETWORK CONSTANTS
# ================================


class NetworkSystem:
	const HTTP_SUCCESS_MIN: int = 200
	const HTTP_SUCCESS_MAX: int = 300
	const HTTP_NOT_FOUND: int = 404
	const FACEBOOK_API_LIMIT: int = 3000


# ================================
# DATA DEFAULTS
# ================================


class DataSystem:
	const DEFAULT_INT_VALUE: int = 0
	const DEFAULT_TEST_GROUP: int = 0
	const DEFAULT_STACK_TRACE_DEPTH: int = 2
	const DEFAULT_INCREMENT_VALUE: int = 1
	const DEFAULT_REFILL_COUNT: int = 0


# ================================
# ARRAY/STRING OPERATIONS
# ================================


class StringSystem:
	const ARRAY_INDEX_OFFSET: int = 1
	const TRUNCATION_SUFFIX_LENGTH: int = 3
	const MINIMUM_PART_COUNT: int = 2
	const MIDDLE_WILDCARD_PART_COUNT: int = 3
	const EXTENDED_MATCH_PART_COUNT: int = 5


# ================================
# TEST DATA CONSTANTS
# ================================


class TestSystem:
	const CARD_HEALTH: int = 10
	const CARD_ATTACK: int = 5
	const ITEM_BASE_PRICE: int = 10
	const PROGRESS_DEFAULT: int = 1


# ================================
# SYSTEM LIMITS
# ================================


class SystemLimits:
	const SESSION_ID_RANDOM_LIMIT: int = 10000
	const WEBSOCKET_RANDOM_ID_RANGE: int = 1073741824  # 1 << 30
	const SPACE_TO_TAB_DIVISOR: int = 4
