@tool
class_name TagCategories
extends RefCounted

enum Category { AVAILABLE, ACTIVE, IGNORED }

static func category_to_string(category: int) -> String:
	match category:
		Category.AVAILABLE: return "available"
		Category.ACTIVE: return "active"
		Category.IGNORED: return "ignored"
		_: return ""

static func from_string(category_str: String) -> int:
	match category_str:
		"available", "SOURCE_AVAILABLE": return Category.AVAILABLE
		"active", "SOURCE_ACTIVE": return Category.ACTIVE
		"ignored", "SOURCE_IGNORED": return Category.IGNORED
		_: return -1
