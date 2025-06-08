# project/debug/debug_output_formatter.gd
class_name DebugOutputFormatter
extends RefCounted

# Extract these constants from debug_menu_controller.gd
const FONT_SIZE_XXL: int = 34
const FONT_SIZE_XL: int = 32
const FONT_SIZE_L: int = 30
const FONT_SIZE_M: int = 24

const UI_COLORS: Dictionary = {
	"background": "#37474F",
	"surface": "#455A64",
	"muted": "#9E9E9E",
	"primary": "#64B5F6",
	"secondary": "#81C784",
	"accent": "#FFB74D",
	"success": "#81C784",
	"warning": "#FFB74D",
	"danger": "#E57373",
	"info": "#4FC3F7",
	"text_primary": "#FFFFFF",
	"text_secondary": "#CFD8DC",
	"text_tertiary": "#90A4AE",
	"key": "#FFB74D",
	"string": "#81C784",
	"number": "#4FC3F7",
	"boolean": "#FFB74D",
	"null_value": "#90A4AE",
	"border": "#546E7A",
	"highlight": "#FFECB3",
}


func format_and_output_status(action: DebugAction, text: String, is_error: bool) -> void:
	var formatted: String = _format_status_message(action, text, is_error)
	output_formatted_text(formatted)


func format_completion_report(action: DebugAction, success: bool, result: Variant) -> String:
	return _build_action_report(action, success, result)


func format_completion_report_structured(
	action: DebugAction, action_result: DebugAction.Result
) -> String:
	"""Enhanced formatting for DebugAction.Result with richer error information"""
	return _build_action_report_structured(action, action_result)


func output_formatted_text(formatted_text: String) -> void:
	match OS.get_name():
		"Android", "iOS":
			# Strip BBCode for mobile platforms
			var plain: String = _strip_bbcode_tags(formatted_text)
			print(plain)
		_:
			print_rich(formatted_text)


func _format_status_message(_action: DebugAction, text: String, is_error: bool) -> String:
	if is_error:
		return "[color=%s]⚠ %s[/color]" % [UI_COLORS.danger, text]
	else:
		return "[color=%s]%s[/color]" % [UI_COLORS.text_primary, text]


# Build comprehensive action report - extracted from debug_menu_controller.gd
func _build_action_report(action: DebugAction, success: bool, payload: Variant) -> String:
	"""Generate a comprehensive, beautifully formatted report for a single action execution"""
	var report: String = ""

	# Header with modern styling
	report += "[font_size=%s][b]ACTION EXECUTION COMPLETE[/b][/font_size]\n" % FONT_SIZE_XXL
	report += "[color=%s]" % UI_COLORS.surface + "━".repeat(50) + "[/color]\n\n"

	# Action details section
	report += (
		"[font_size=%s][color=%s]ACTION DETAILS[/color][/font_size]\n"
		% [FONT_SIZE_XL, UI_COLORS.info]
	)
	report += "[color=%s]" % UI_COLORS.surface + "─".repeat(30) + "[/color]\n"
	report += (
		"[color=%s]Name:[/color] [color=%s]%s[/color]\n"
		% [UI_COLORS.text_secondary, UI_COLORS.text_primary, action.action_name]
	)
	report += (
		"[color=%s]Category:[/color] [color=%s]%s[/color]\n"
		% [UI_COLORS.text_secondary, UI_COLORS.accent, action.category]
	)

	if action.group != "":
		report += (
			"[color=%s]Group:[/color] [color=%s]%s[/color]\n"
			% [UI_COLORS.text_secondary, UI_COLORS.accent, action.group]
		)

	if action.description != "":
		report += (
			"[color=%s]Description:[/color] [color=%s]%s[/color]\n"
			% [UI_COLORS.text_secondary, UI_COLORS.text_primary, action.description]
		)

	report += "\n"

	# Status section with enhanced visual indicators
	var status_icon: String = "✓" if success else "✗"
	var status_color: String = UI_COLORS.success if success else UI_COLORS.danger
	var status_text: String = "SUCCESS" if success else "FAILURE"

	report += (
		"[font_size=%s][color=%s]EXECUTION STATUS[/color][/font_size]\n"
		% [FONT_SIZE_XL, UI_COLORS.info]
	)
	report += "[color=%s]" % UI_COLORS.surface + "─".repeat(30) + "[/color]\n"
	report += (
		"[font_size=%s][color=%s]%s %s[/color][/font_size]\n\n"
		% [FONT_SIZE_XL, status_color, status_icon, status_text]
	)

	# Result/error details
	if success:
		report += (
			"[font_size=%s][color=%s]RESULT DATA[/color][/font_size]\n"
			% [FONT_SIZE_XL, UI_COLORS.info]
		)
		report += "[color=%s]" % UI_COLORS.surface + "─".repeat(30) + "[/color]\n"
		if payload != null:
			var formatted_payload: String = _format_payload_summary(payload)
			report += formatted_payload + "\n"
		else:
			report += (
				"[color=%s]Action completed successfully with no return data[/color]\n"
				% UI_COLORS.muted
			)
	else:
		report += (
			"[font_size=%s][color=%s]ERROR DETAILS[/color][/font_size]\n"
			% [FONT_SIZE_XL, UI_COLORS.danger]
		)
		report += "[color=%s]" % UI_COLORS.surface + "─".repeat(30) + "[/color]\n"
		var error_message: String = _format_error_message(payload)
		report += error_message + "\n"

	# Timestamp
	report += (
		"\n[color=%s]Completed at: %s[/color]"
		% [UI_COLORS.text_secondary, Time.get_datetime_string_from_system()]
	)

	return report


# Enhanced action report for DebugAction.Result with structured error information
func _build_action_report_structured(
	action: DebugAction, action_result: DebugAction.Result
) -> String:
	"""Generate enhanced report for DebugAction.Result with richer error categorization"""
	var report: String = ""

	# Header with modern styling
	report += "[font_size=%s][b]ACTION EXECUTION COMPLETE[/b][/font_size]\n" % FONT_SIZE_XXL
	report += "[color=%s]" % UI_COLORS.surface + "━".repeat(50) + "[/color]\n\n"

	# Action details section
	report += (
		"[font_size=%s][color=%s]ACTION DETAILS[/color][/font_size]\n"
		% [FONT_SIZE_XL, UI_COLORS.info]
	)
	report += "[color=%s]" % UI_COLORS.surface + "─".repeat(30) + "[/color]\n"
	report += (
		"[color=%s]Name:[/color] [color=%s]%s[/color]\n"
		% [UI_COLORS.text_secondary, UI_COLORS.text_primary, action.action_name]
	)
	report += (
		"[color=%s]Category:[/color] [color=%s]%s[/color]\n"
		% [UI_COLORS.text_secondary, UI_COLORS.accent, action.category]
	)

	if action.group != "":
		report += (
			"[color=%s]Group:[/color] [color=%s]%s[/color]\n"
			% [UI_COLORS.text_secondary, UI_COLORS.accent, action.group]
		)

	if action.description != "":
		report += (
			"[color=%s]Description:[/color] [color=%s]%s[/color]\n"
			% [UI_COLORS.text_secondary, UI_COLORS.text_primary, action.description]
		)

	report += "\n"

	# Enhanced status section with performance info
	var status_icon: String = "✓" if action_result.is_success() else "✗"
	var status_color: String = UI_COLORS.success if action_result.is_success() else UI_COLORS.danger
	var status_text: String = "SUCCESS" if action_result.is_success() else "FAILURE"

	report += (
		"[font_size=%s][color=%s]EXECUTION STATUS[/color][/font_size]\n"
		% [FONT_SIZE_XL, UI_COLORS.info]
	)
	report += "[color=%s]" % UI_COLORS.surface + "─".repeat(30) + "[/color]\n"
	report += (
		"[font_size=%s][color=%s]%s %s[/color][/font_size]\n"
		% [FONT_SIZE_XL, status_color, status_icon, status_text]
	)

	# Performance information
	var duration_ms: int = action_result.get_duration_ms()
	var perf_category: String = action_result.get_performance_category()
	var perf_color: String = (
		UI_COLORS.success
		if perf_category == "FAST"
		else (UI_COLORS.warning if perf_category == "NORMAL" else UI_COLORS.danger)
	)

	report += (
		"[color=%s]Duration:[/color] [color=%s]%d ms (%s)[/color]\n"
		% [UI_COLORS.text_secondary, perf_color, duration_ms, perf_category]
	)

	# Operation information
	if not action_result.get_operation().is_empty():
		report += (
			"[color=%s]Operation:[/color] [color=%s]%s[/color]\n"
			% [UI_COLORS.text_secondary, UI_COLORS.accent, action_result.get_operation()]
		)

	report += "\n"

	# Result/error details with enhanced error information
	if action_result.is_success():
		report += (
			"[font_size=%s][color=%s]RESULT DATA[/color][/font_size]\n"
			% [FONT_SIZE_XL, UI_COLORS.info]
		)
		report += "[color=%s]" % UI_COLORS.surface + "─".repeat(30) + "[/color]\n"
		var payload: Variant = action_result.get_payload()
		if payload != null:
			var formatted_payload: String = _pretty_print_value_no_truncation(payload)
			report += formatted_payload + "\n"
		else:
			report += (
				"[color=%s]Action completed successfully with no return data[/color]\n"
				% UI_COLORS.muted
			)
	else:
		report += (
			"[font_size=%s][color=%s]ERROR DETAILS[/color][/font_size]\n"
			% [FONT_SIZE_XL, UI_COLORS.danger]
		)
		report += "[color=%s]" % UI_COLORS.surface + "─".repeat(30) + "[/color]\n"

		# Enhanced error information
		report += (
			"[color=%s]Message:[/color] [color=%s]%s[/color]\n"
			% [UI_COLORS.text_secondary, UI_COLORS.danger, action_result.get_error_message()]
		)

		if not action_result.get_error_code().is_empty():
			report += (
				"[color=%s]Code:[/color] [color=%s]%s[/color]\n"
				% [UI_COLORS.text_secondary, UI_COLORS.warning, action_result.get_error_code()]
			)

		var error_category: DebugAction.Result.ErrorCategory = action_result.get_error_category()
		if error_category != DebugAction.Result.ErrorCategory.NONE:
			var category_name: String = DebugAction.Result.ErrorCategory.keys()[error_category]
			report += (
				"[color=%s]Category:[/color] [color=%s]%s[/color]\n"
				% [UI_COLORS.text_secondary, UI_COLORS.warning, category_name]
			)

		# Show payload if available (might contain additional error context)
		var error_payload: Variant = action_result.get_payload()
		if error_payload != null:
			report += (
				"[color=%s]Additional Context:[/color]\n%s\n"
				% [UI_COLORS.text_secondary, _pretty_print_value_no_truncation(error_payload)]
			)

	# Metadata information
	var metadata: Dictionary = action_result.get_metadata()
	if not metadata.is_empty():
		report += (
			"\n[font_size=%s][color=%s]METADATA[/color][/font_size]\n"
			% [FONT_SIZE_L, UI_COLORS.info]
		)
		report += "[color=%s]" % UI_COLORS.surface + "─".repeat(20) + "[/color]\n"
		report += _pretty_print_value_no_truncation(metadata) + "\n"

	# Timestamp
	report += (
		"\n[color=%s]Completed at: %s[/color]"
		% [UI_COLORS.text_secondary, Time.get_datetime_string_from_system()]
	)

	return report


# Pretty-print a value with NO TRUNCATION and modern styling
func _pretty_print_value_no_truncation(
	value: Variant, indent_level: int = 0, max_depth: int = 10
) -> String:
	if indent_level > max_depth:
		return "[color=%s]<maximum depth reached>[/color]" % UI_COLORS.warning

	if value == null:
		return "[color=%s]null[/color]" % UI_COLORS.null_value

	if value is Dictionary:
		var val_dic: Dictionary = value
		return _format_dictionary_no_truncation(val_dic, indent_level, max_depth)
	elif value is Array:
		var val_array: Array = value
		return _format_array_no_truncation(val_array, indent_level, max_depth)
	elif value is String:
		var str_val: String = value
		# NO TRUNCATION - show full string with proper formatting
		var escaped_str: String = str_val.replace("\n", "\\n").replace("\t", "\\t")
		return '[color=%s]"%s"[/color]' % [UI_COLORS.string, escaped_str]
	elif value is bool:
		return "[color=%s]%s[/color]" % [UI_COLORS.boolean, str(value)]
	elif value is int or value is float:
		return "[color=%s]%s[/color]" % [UI_COLORS.number, str(value)]
	else:
		# NO TRUNCATION - show full value regardless of length
		return "[color=%s]%s[/color]" % [UI_COLORS.text_primary, str(value)]


# Format dictionary with NO TRUNCATION and enhanced styling
func _format_dictionary_no_truncation(
	dict: Dictionary, indent_level: int = 0, max_depth: int = 10
) -> String:
	if dict.is_empty():
		return "[color=%s]{ }[/color]" % UI_COLORS.muted

	if indent_level > max_depth:
		return "[color=%s]{ <max depth> }[/color]" % UI_COLORS.warning

	var indent: String = "  ".repeat(indent_level)
	var child_indent: String = "  ".repeat(indent_level + 1)
	var result: String = "[color=%s]{[/color]\n" % UI_COLORS.text_secondary

	var keys: Array = dict.keys()
	keys.sort()  # Sort keys for consistent display

	# NO ITEM LIMIT - show all items regardless of count
	for key: Variant in keys:
		var value: Variant = dict[key]
		var key_str: String = "[color=%s]%s[/color]" % [UI_COLORS.key, str(key)]
		var value_str: String = _pretty_print_value_no_truncation(
			value, indent_level + 1, max_depth
		)

		# Handle multiline values with better formatting
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

	result += indent + "[color=%s]}[/color]" % UI_COLORS.text_secondary
	return result


# Format array with NO TRUNCATION and enhanced styling
func _format_array_no_truncation(
	array: Array, indent_level: int = 0, max_depth: int = 10
) -> String:
	if array.is_empty():
		return "[color=%s][ ][/color]" % UI_COLORS.muted

	if indent_level > max_depth:
		return "[color=%s][ <max depth> ][/color]" % UI_COLORS.warning

	# For small arrays of simple values, show inline with better styling
	if array.size() <= 5 and indent_level > 0:
		var all_simple: bool = true
		for item: Variant in array:
			if item is Dictionary or item is Array:
				all_simple = false
				break

		if all_simple:
			var items: Array[String] = []
			for item: Variant in array:
				items.append(_pretty_print_value_no_truncation(item, indent_level + 1, max_depth))
			return (
				"[color=%s][[/color] %s [color=%s]][/color]"
				% [UI_COLORS.text_secondary, ", ".join(items), UI_COLORS.text_secondary]
			)

	var indent: String = "  ".repeat(indent_level)
	var child_indent: String = "  ".repeat(indent_level + 1)
	var result: String = "[color=%s][[/color]\n" % UI_COLORS.text_secondary

	# NO ITEM LIMIT - show all items regardless of count
	for i: int in range(array.size()):
		var item: Variant = array[i]
		var item_str: String = _pretty_print_value_no_truncation(item, indent_level + 1, max_depth)

		# Handle multiline items with better formatting
		if "\n" in item_str:
			result += (
				child_indent
				+ (
					"[color=%s][%d]:[/color]\n%s%s\n"
					% [
						UI_COLORS.number,
						i,
						"  ".repeat(indent_level + 2),
						item_str.replace("\n", "\n" + "  ".repeat(indent_level + 2))
					]
				)
			)
		else:
			result += (
				child_indent + "[color=%s][%d]:[/color] %s\n" % [UI_COLORS.number, i, item_str]
			)

	result += indent + "[color=%s]][/color]" % UI_COLORS.text_secondary
	return result


# Extract key information from complex payloads for display
func _format_payload_summary(payload: Variant) -> String:
	if payload == null:
		return "No result data"

	# Handle dictionary payloads (common from Firebase actions)
	if payload is Dictionary:
		var dict_payload: Dictionary = payload

		# Firebase operation result
		if dict_payload.has("operation") and dict_payload.has("result"):
			var operation: String = str(dict_payload.get("operation"))
			var result_data: Variant = dict_payload.get("result")
			var path_data: Variant = dict_payload.get("path", "")

			var summary: String = "Operation: %s\n" % operation
			if (
				path_data != null
				and (
					(path_data is Array and path_data.size() > 0)
					or (path_data is String and path_data != "")
				)
			):
				var path_str: String = ""
				if path_data is Array:
					var path_array: Array = path_data
					var string_array: PackedStringArray = PackedStringArray()
					for item: Variant in path_array:
						string_array.append(str(item))
					path_str = "/".join(string_array)  # Convert array to path-like string
				else:
					path_str = str(path_data)
				summary += "Path: %s\n" % path_str

			# Pretty-print result data for better readability
			summary += "Result:\n"
			var formatted_result: String = _pretty_print_value_no_truncation(result_data, 1, 5)
			summary += "  %s" % formatted_result.replace("\n", "\n  ")

			return summary

		# Generic dictionary - use pretty-printing for better readability
		else:
			return (
				"Result:\n  %s"
				% _pretty_print_value_no_truncation(dict_payload, 1, 5).replace("\n", "\n  ")
			)

	# Handle simple types with pretty-printing
	return "Result: %s" % _pretty_print_value_no_truncation(payload, 0, 5)


# Format error message from payload, extracting meaningful info instead of raw dict
func _format_error_message(payload: Variant) -> String:
	if payload == null:
		return "[color=%s]Unknown error - no details provided[/color]" % UI_COLORS.danger

	# Handle dictionary errors (common from Firebase) - NO TRUNCATION
	if payload is Dictionary:
		var dict_payload: Dictionary = payload

		# Firebase error with structured info
		if dict_payload.has("error"):
			var error_data: Variant = dict_payload.get("error")
			var error_str: String = str(error_data)

			# Extract meaningful error messages with full context
			if error_str.contains("PERMISSION_DENIED"):
				return (
					"[color=%s]Permission denied[/color] - check Firebase rules\n[color=%s]Full error:[/color] %s"
					% [UI_COLORS.danger, UI_COLORS.text_secondary, error_str]
				)
			elif error_str.contains("NETWORK_ERROR"):
				return (
					"[color=%s]Network connection issue[/color]\n[color=%s]Full error:[/color] %s"
					% [UI_COLORS.danger, UI_COLORS.text_secondary, error_str]
				)
			elif error_str.contains("DATABASE_ERROR"):
				return (
					"[color=%s]Database operation failed[/color]\n[color=%s]Full error:[/color] %s"
					% [UI_COLORS.danger, UI_COLORS.text_secondary, error_str]
				)
			elif error_str.contains("timeout") or error_str.contains("TIMEOUT"):
				return (
					"[color=%s]Operation timed out[/color]\n[color=%s]Full error:[/color] %s"
					% [UI_COLORS.danger, UI_COLORS.text_secondary, error_str]
				)
			elif error_str.contains("not found") or error_str.contains("NOT_FOUND"):
				return (
					"[color=%s]Resource not found[/color]\n[color=%s]Full error:[/color] %s"
					% [UI_COLORS.danger, UI_COLORS.text_secondary, error_str]
				)
			else:
				# NO TRUNCATION - show full error with styling
				return "[color=%s]Error:[/color] %s" % [UI_COLORS.danger, error_str]

		# Generic dictionary error - show full structured data
		else:
			return (
				"[color=%s]Structured error:[/color]\n%s"
				% [UI_COLORS.danger, _pretty_print_value_no_truncation(dict_payload)]
			)

	var payload_str: String = str(payload)

	# Try to extract meaningful error info from string patterns - NO TRUNCATION
	if payload_str.contains("FirebaseDatabase"):
		return (
			"[color=%s]Firebase connection issue[/color]\n[color=%s]Details:[/color] %s"
			% [UI_COLORS.danger, UI_COLORS.text_secondary, payload_str]
		)
	elif payload_str.contains("timeout"):
		return (
			"[color=%s]Operation timed out[/color]\n[color=%s]Details:[/color] %s"
			% [UI_COLORS.danger, UI_COLORS.text_secondary, payload_str]
		)
	elif payload_str.contains("permission"):
		return (
			"[color=%s]Permission denied[/color]\n[color=%s]Details:[/color] %s"
			% [UI_COLORS.danger, UI_COLORS.text_secondary, payload_str]
		)
	elif payload_str.contains("not found"):
		return (
			"[color=%s]Resource not found[/color]\n[color=%s]Details:[/color] %s"
			% [UI_COLORS.danger, UI_COLORS.text_secondary, payload_str]
		)
	else:
		# NO TRUNCATION - show full error message with proper styling
		return "[color=%s]Error:[/color] %s" % [UI_COLORS.danger, payload_str]


# Helper method to strip BBCode tags for mobile platforms
func _strip_bbcode_tags(text: String) -> String:
	var regex: RegEx = RegEx.new()
	regex.compile("\\[/?[^\\]]+\\]")
	return regex.sub(text, "", true)
