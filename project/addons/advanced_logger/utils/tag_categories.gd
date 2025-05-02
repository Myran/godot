@tool
class_name TagCategories
extends RefCounted
## Centralized definition of tag categories for consistent usage across the addon

enum Category { AVAILABLE, ACTIVE, IGNORED }

# Convert enum to string (for drag data or persistence)
static func category_to_string(category: int) -> String:
	match category:
		Category.AVAILABLE: return "available"
		Category.ACTIVE: return "active"
		Category.IGNORED: return "ignored"
		_: return ""

# Convert string to enum (from drag data or persistence)
static func from_string(category_str: String) -> int:
	match category_str:
		"available", "SOURCE_AVAILABLE": return Category.AVAILABLE
		"active", "SOURCE_ACTIVE": return Category.ACTIVE
		"ignored", "SOURCE_IGNORED": return Category.IGNORED
		_: return -1
