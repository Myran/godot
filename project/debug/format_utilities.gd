class_name DebugFormatUtilities
extends RefCounted


static func pretty_print_value_no_truncation(
	value: Variant, indent_level: int = 0, max_depth: int = 10
) -> String:
	if indent_level > max_depth:
		return "[color=%s]<maximum depth reached>[/color]" % DebugUIConstants.UI_COLORS.warning

	if value == null:
		return "[color=%s]null[/color]" % DebugUIConstants.UI_COLORS.null_value

	if value is Dictionary:
		var val_dic: Dictionary = value
		return format_dictionary_no_truncation(val_dic, indent_level, max_depth)
	if value is Array:
		var val_array: Array = value
		return format_array_no_truncation(val_array, indent_level, max_depth)
	if value is String:
		var str_val: String = value
		var escaped_str: String = str_val.replace("\n", "\\n").replace("\t", "\\t")
		return '[color=%s]"%s"[/color]' % [DebugUIConstants.UI_COLORS.string, escaped_str]
	if value is bool:
		return "[color=%s]%s[/color]" % [DebugUIConstants.UI_COLORS.boolean, str(value)]
	if value is int or value is float:
		return "[color=%s]%s[/color]" % [DebugUIConstants.UI_COLORS.number, str(value)]
	return "[color=%s]%s[/color]" % [DebugUIConstants.UI_COLORS.text_primary, str(value)]


static func format_dictionary_no_truncation(
	dict: Dictionary, indent_level: int = 0, max_depth: int = 10
) -> String:
	if dict.is_empty():
		return "[color=%s]{ }[/color]" % DebugUIConstants.UI_COLORS.muted

	if indent_level > max_depth:
		return "[color=%s]{ <max depth> }[/color]" % DebugUIConstants.UI_COLORS.warning

	var indent: String = "  ".repeat(indent_level)
	var child_indent: String = "  ".repeat(indent_level + 1)
	var result: String = "[color=%s]{[/color]\n" % DebugUIConstants.UI_COLORS.text_secondary

	var keys: Array = dict.keys()
	keys.sort()

	for key: Variant in keys:
		var value: Variant = dict[key]
		var key_str: String = "[color=%s]%s[/color]" % [DebugUIConstants.UI_COLORS.key, str(key)]
		var value_str: String = pretty_print_value_no_truncation(value, indent_level + 1, max_depth)

		if "\n" in value_str:
			result += (
				child_indent
				+ (
					"%s:\n%s%s\n"
					% [
						key_str,
						"  ".repeat(indent_level + 2),
						value_str.replace("\n", "\n" + "  ".repeat(indent_level + 2))
					]
				)
			)
		else:
			result += child_indent + "%s: %s\n" % [key_str, value_str]

	result += indent + "[color=%s]}[/color]" % DebugUIConstants.UI_COLORS.text_secondary
	return result


static func format_array_no_truncation(
	array: Array, indent_level: int = 0, max_depth: int = 10
) -> String:
	if array.is_empty():
		return "[color=%s][ ][/color]" % DebugUIConstants.UI_COLORS.muted

	if indent_level > max_depth:
		return "[color=%s][ <max depth> ][/color]" % DebugUIConstants.UI_COLORS.warning

	if array.size() <= 5 and indent_level > 0:
		var all_simple: bool = true
		for item: Variant in array:
			if item is Dictionary or item is Array:
				all_simple = false
				break

		if all_simple:
			var items: Array[String] = []
			for item: Variant in array:
				items.append(pretty_print_value_no_truncation(item, indent_level + 1, max_depth))
			return (
				"[color=%s][[/color] %s [color=%s]][/color]"
				% [
					DebugUIConstants.UI_COLORS.text_secondary,
					", ".join(items),
					DebugUIConstants.UI_COLORS.text_secondary
				]
			)

	var indent: String = "  ".repeat(indent_level)
	var child_indent: String = "  ".repeat(indent_level + 1)
	var result: String = "[color=%s][[/color]\n" % DebugUIConstants.UI_COLORS.text_secondary

	for i: int in range(array.size()):
		var item: Variant = array[i]
		var item_str: String = pretty_print_value_no_truncation(item, indent_level + 1, max_depth)

		if "\n" in item_str:
			result += (
				child_indent
				+ (
					"[color=%s][%d]:[/color]\n%s%s\n"
					% [
						DebugUIConstants.UI_COLORS.number,
						i,
						"  ".repeat(indent_level + 2),
						item_str.replace("\n", "\n" + "  ".repeat(indent_level + 2))
					]
				)
			)
		else:
			result += (
				child_indent
				+ "[color=%s][%d]:[/color] %s\n" % [DebugUIConstants.UI_COLORS.number, i, item_str]
			)

	result += indent + "[color=%s]][/color]" % DebugUIConstants.UI_COLORS.text_secondary
	return result


static func strip_bbcode_tags(text: String) -> String:
	var regex: RegEx = RegEx.new()
	regex.compile("\\[/?[^\\]]+\\]")
	return regex.sub(text, "", true)


static func extract_concise_error(payload: Variant) -> String:
	if payload == null:
		return ""
	var payload_str: String = str(payload)
	if payload_str.contains("PERMISSION_DENIED"):
		return "Permission denied"
	if payload_str.contains("NETWORK_ERROR"):
		return "Network error"
	if payload_str.contains("timeout"):
		return "Timeout"
	if payload_str.contains("not found"):
		return "Not found"
	if payload_str.contains("Firebase"):
		return "Firebase error"
	if payload_str.length() > 50:
		return payload_str.substr(0, 50) + "..."
	return payload_str
