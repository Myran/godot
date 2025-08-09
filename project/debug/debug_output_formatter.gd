class_name DebugOutputFormatter
extends RefCounted

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


func format_enhanced_status(action: DebugAction, text: String, is_error: bool) -> String:
	"""Generate enhanced real-time status updates with context and progress indicators"""
	var datetime_parts: PackedStringArray = Time.get_datetime_string_from_system().split(" ")
	var timestamp: String = datetime_parts[1] if datetime_parts.size() > 1 else datetime_parts[0]
	var status_icon: String = "⚠️" if is_error else "🔄"
	var color: String = UI_COLORS.danger if is_error else UI_COLORS.info

	var enhanced: String = "[font_size=24]"
	enhanced += "[color=%s]%s[/color] " % [UI_COLORS.muted, timestamp]
	enhanced += "[color=%s]%s[/color] " % [color, status_icon]
	enhanced += "[color=%s][%s][/color] " % [UI_COLORS.accent, action.category]
	enhanced += "[color=%s]%s[/color]" % [UI_COLORS.text_primary, text]
	enhanced += "[/font_size]\n"

	return enhanced


func format_completion_report(action: DebugAction, success: bool, result: Variant) -> String:
	return _build_action_report(action, success, result)


func format_completion_report_structured(
	action: DebugAction, action_result: DebugAction.Result
) -> String:
	"""Enhanced formatting for DebugAction.Result with richer error information"""
	return _build_action_report_structured(action, action_result)


func format_completion_report_with_execution_log(
	action: DebugAction, success: bool, result: Variant, execution_log: Array[Dictionary]
) -> String:
	"""Generate comprehensive report including full execution step history"""
	return _build_action_report_with_execution_log(action, success, result, execution_log)


func output_formatted_text(formatted_text: String) -> void:
	match OS.get_name():
		"Android", "iOS":
			var plain: String = _strip_bbcode_tags(formatted_text)
			print(plain)
		_:
			print_rich(formatted_text)


func _format_status_message(_action: DebugAction, text: String, is_error: bool) -> String:
	if is_error:
		return "[color=%s]⚠ %s[/color]" % [UI_COLORS.danger, text]
	else:
		return "[color=%s]%s[/color]" % [UI_COLORS.text_primary, text]


func _build_action_report(action: DebugAction, success: bool, payload: Variant) -> String:
	"""Generate a comprehensive, beautifully formatted report for a single action execution"""
	var report: String = ""

	var status_icon: String = "✅" if success else "❌"
	report += (
		"[font_size=%s][b]%s ACTION EXECUTION COMPLETE[/b][/font_size]\n"
		% [FONT_SIZE_XXL, status_icon]
	)
	report += "[color=%s]" % UI_COLORS.surface + "━".repeat(50) + "[/color]\n\n"

	var final_status_icon: String = "✓" if success else "✗"
	var final_status_color: String = UI_COLORS.success if success else UI_COLORS.danger
	var final_status_text: String = "SUCCESS" if success else "FAILURE"

	report += (
		"[font_size=%s][color=%s]EXECUTION STATUS[/color][/font_size]\n"
		% [FONT_SIZE_XL, UI_COLORS.info]
	)
	report += "[color=%s]" % UI_COLORS.surface + "─".repeat(30) + "[/color]\n"
	report += (
		"[font_size=%s][color=%s]%s %s[/color][/font_size]\n\n"
		% [FONT_SIZE_XL, final_status_color, final_status_icon, final_status_text]
	)

	var device_info: String = _get_device_context_header()
	report += device_info + "\n"

	report += _build_result_status_section(success, payload)

	report += _build_action_details_section(action)

	report += _build_performance_metrics_section(payload)

	report += _build_test_data_analysis_section(payload, success)

	if action.description != "":
		report += (
			"[color=%s]Description:[/color] [color=%s]%s[/color]\n"
			% [UI_COLORS.text_secondary, UI_COLORS.text_primary, action.description]
		)

	report += "\n"

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

	report += (
		"\n[color=%s]Completed at: %s[/color]"
		% [UI_COLORS.text_secondary, Time.get_datetime_string_from_system()]
	)

	return report


func _build_action_report_structured(
	action: DebugAction, action_result: DebugAction.Result
) -> String:
	"""Generate enhanced report for DebugAction.Result with richer error categorization"""
	var report: String = ""

	report += "[font_size=%s][b]ACTION EXECUTION COMPLETE[/b][/font_size]\n" % FONT_SIZE_XXL
	report += "[color=%s]" % UI_COLORS.surface + "━".repeat(50) + "[/color]\n\n"

	var status_icon: String = "✓" if action_result.is_success() else "✗"
	var status_color: String = UI_COLORS.success if action_result.is_success() else UI_COLORS.danger
	var status_text: String = "SUCCESS" if action_result.is_success() else "FAILURE"

	report += (
		"[font_size=%s][color=%s]EXECUTION STATUS[/color][/font_size]\n"
		% [FONT_SIZE_XL, UI_COLORS.info]
	)
	report += "[color=%s]" % UI_COLORS.surface + "─".repeat(30) + "[/color]\n"
	report += (
		"[font_size=%s][color=%s]%s %s[/color][/font_size]\n\n"
		% [FONT_SIZE_XL, status_color, status_icon, status_text]
	)

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
	report += (
		"[font_size=%s][color=%s]%s %s[/color][/font_size]\n"
		% [FONT_SIZE_XL, status_color, status_icon, status_text]
	)

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

	if not action_result.get_operation().is_empty():
		report += (
			"[color=%s]Operation:[/color] [color=%s]%s[/color]\n"
			% [UI_COLORS.text_secondary, UI_COLORS.accent, action_result.get_operation()]
		)

	report += "\n"

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

		var error_payload: Variant = action_result.get_payload()
		if error_payload != null:
			report += (
				"[color=%s]Additional Context:[/color]\n%s\n"
				% [UI_COLORS.text_secondary, _pretty_print_value_no_truncation(error_payload)]
			)

	var metadata: Dictionary = action_result.get_metadata()
	if not metadata.is_empty():
		report += (
			"\n[font_size=%s][color=%s]METADATA[/color][/font_size]\n"
			% [FONT_SIZE_L, UI_COLORS.info]
		)
		report += "[color=%s]" % UI_COLORS.surface + "─".repeat(20) + "[/color]\n"
		report += _pretty_print_value_no_truncation(metadata) + "\n"

	report += (
		"\n[color=%s]Completed at: %s[/color]"
		% [UI_COLORS.text_secondary, Time.get_datetime_string_from_system()]
	)

	return report


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
		var escaped_str: String = str_val.replace("\n", "\\n").replace("\t", "\\t")
		return '[color=%s]"%s"[/color]' % [UI_COLORS.string, escaped_str]
	elif value is bool:
		return "[color=%s]%s[/color]" % [UI_COLORS.boolean, str(value)]
	elif value is int or value is float:
		return "[color=%s]%s[/color]" % [UI_COLORS.number, str(value)]
	else:
		return "[color=%s]%s[/color]" % [UI_COLORS.text_primary, str(value)]


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

	for key: Variant in keys:
		var value: Variant = dict[key]
		var key_str: String = "[color=%s]%s[/color]" % [UI_COLORS.key, str(key)]
		var value_str: String = _pretty_print_value_no_truncation(
			value, indent_level + 1, max_depth
		)

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


func _format_array_no_truncation(
	array: Array, indent_level: int = 0, max_depth: int = 10
) -> String:
	if array.is_empty():
		return "[color=%s][ ][/color]" % UI_COLORS.muted

	if indent_level > max_depth:
		return "[color=%s][ <max depth> ][/color]" % UI_COLORS.warning

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

	for i: int in range(array.size()):
		var item: Variant = array[i]
		var item_str: String = _pretty_print_value_no_truncation(item, indent_level + 1, max_depth)

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


func _format_payload_summary(payload: Variant) -> String:
	if payload == null:
		return "No result data"

	if payload is Dictionary:
		var dict_payload: Dictionary = payload

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

			summary += "Result:\n"
			var formatted_result: String = _pretty_print_value_no_truncation(result_data, 1, 5)
			summary += "  %s" % formatted_result.replace("\n", "\n  ")

			return summary

		else:
			return (
				"Result:\n  %s"
				% _pretty_print_value_no_truncation(dict_payload, 1, 5).replace("\n", "\n  ")
			)

	return "Result: %s" % _pretty_print_value_no_truncation(payload, 0, 5)


func _format_error_message(payload: Variant) -> String:
	if payload == null:
		return "[color=%s]Unknown error - no details provided[/color]" % UI_COLORS.danger

	if payload is Dictionary:
		var dict_payload: Dictionary = payload

		if dict_payload.has("error"):
			var error_data: Variant = dict_payload.get("error")
			var error_str: String = str(error_data)

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
				return "[color=%s]Error:[/color] %s" % [UI_COLORS.danger, error_str]

		else:
			return (
				"[color=%s]Structured error:[/color]\n%s"
				% [UI_COLORS.danger, _pretty_print_value_no_truncation(dict_payload)]
			)

	var payload_str: String = str(payload)

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
		return "[color=%s]Error:[/color] %s" % [UI_COLORS.danger, payload_str]


func _strip_bbcode_tags(text: String) -> String:
	var regex: RegEx = RegEx.new()
	regex.compile("\\[/?[^\\]]+\\]")
	return regex.sub(text, "", true)




func _get_device_context_header() -> String:
	"""Generate device and environment context information"""
	var platform: String = OS.get_name()
	var version: String = OS.get_version()
	var model: String = OS.get_model_name() if OS.has_method("get_model_name") else "Unknown"
	var memory: String = _format_memory_info()
	var timestamp: String = Time.get_datetime_string_from_system()

	var context: String = ""
	context += (
		"[font_size=%s][color=%s]🔬 TEST EXECUTION CONTEXT[/color][/font_size]\n"
		% [FONT_SIZE_L, UI_COLORS.info]
	)
	context += "[color=%s]" % UI_COLORS.surface + "─".repeat(40) + "[/color]\n"
	context += (
		"[color=%s]Platform:[/color] [color=%s]%s %s[/color]\n"
		% [UI_COLORS.text_secondary, UI_COLORS.accent, platform, version]
	)
	if model != "Unknown":
		context += (
			"[color=%s]Device:[/color] [color=%s]%s[/color]\n"
			% [UI_COLORS.text_secondary, UI_COLORS.accent, model]
		)
	context += (
		"[color=%s]Memory:[/color] [color=%s]%s[/color]\n"
		% [UI_COLORS.text_secondary, UI_COLORS.number, memory]
	)
	context += (
		"[color=%s]Timestamp:[/color] [color=%s]%s[/color]\n"
		% [UI_COLORS.text_secondary, UI_COLORS.muted, timestamp]
	)

	return context


func _format_memory_info() -> String:
	"""Format memory usage information"""
	var memory_used: int = OS.get_static_memory_usage()
	var memory_mb: float = memory_used / (1024.0 * 1024.0)
	return "%.1f MB" % memory_mb


func _build_result_status_section(success: bool, _payload: Variant) -> String:
	"""Build enhanced result status section with visual indicators"""
	var status_text: String = "SUCCESS" if success else "FAILURE"
	var status_color: String = UI_COLORS.success if success else UI_COLORS.danger
	var status_icon: String = "✅" if success else "❌"
	var status_progress: String = _generate_progress_bar(1.0 if success else 0.0, success)

	var section: String = ""
	section += (
		"[font_size=%s][color=%s]📊 EXECUTION RESULT[/color][/font_size]\n"
		% [FONT_SIZE_XL, UI_COLORS.info]
	)
	section += "[color=%s]" % UI_COLORS.surface + "─".repeat(30) + "[/color]\n"
	section += (
		"[font_size=%s][color=%s]%s %s[/color][/font_size]\n"
		% [FONT_SIZE_L, status_color, status_icon, status_text]
	)
	section += "%s\n\n" % status_progress

	return section


func _build_action_details_section(action: DebugAction) -> String:
	"""Build comprehensive action details section"""
	var section: String = ""
	section += (
		"[font_size=%s][color=%s]🎯 ACTION DETAILS[/color][/font_size]\n"
		% [FONT_SIZE_XL, UI_COLORS.info]
	)
	section += "[color=%s]" % UI_COLORS.surface + "─".repeat(30) + "[/color]\n"
	section += (
		"[color=%s]Name:[/color] [color=%s]%s[/color]\n"
		% [UI_COLORS.text_secondary, UI_COLORS.text_primary, action.action_name]
	)
	section += (
		"[color=%s]Category:[/color] [color=%s]%s[/color]\n"
		% [UI_COLORS.text_secondary, UI_COLORS.accent, action.category]
	)

	if action.group != "":
		section += (
			"[color=%s]Group:[/color] [color=%s]%s[/color]\n"
			% [UI_COLORS.text_secondary, UI_COLORS.accent, action.group]
		)

	if action.description != "":
		section += (
			"[color=%s]Description:[/color] [color=%s]%s[/color]\n"
			% [UI_COLORS.text_secondary, UI_COLORS.text_primary, action.description]
		)

	section += "\n"
	return section


func _build_performance_metrics_section(payload: Variant) -> String:
	"""Build performance metrics section with detailed timing analysis"""
	var section: String = ""
	section += (
		"[font_size=%s][color=%s]⚡ PERFORMANCE METRICS[/color][/font_size]\n"
		% [FONT_SIZE_XL, UI_COLORS.info]
	)
	section += "[color=%s]" % UI_COLORS.surface + "─".repeat(30) + "[/color]\n"

	var timing_info: Dictionary = _extract_timing_info(payload)

	if timing_info.has("duration_ms"):
		var duration: int = timing_info["duration_ms"]
		var performance_category: String = _categorize_performance(duration)
		var perf_color: String = _get_performance_color(performance_category)
		var perf_bar: String = _generate_performance_bar(duration)

		section += (
			"[color=%s]Duration:[/color] [color=%s]%d ms[/color] [color=%s](%s)[/color]\n"
			% [
				UI_COLORS.text_secondary,
				UI_COLORS.number,
				duration,
				perf_color,
				performance_category
			]
		)
		section += "%s\n" % perf_bar

	if timing_info.has("operation_count"):
		section += (
			"[color=%s]Operations:[/color] [color=%s]%d[/color]\n"
			% [UI_COLORS.text_secondary, UI_COLORS.number, timing_info["operation_count"]]
		)

	if timing_info.has("duration_ms") and timing_info.has("operation_count"):
		var operation_count_var: Variant = timing_info["operation_count"]
		var duration_ms_var: Variant = timing_info["duration_ms"]
		if operation_count_var is int and duration_ms_var is int:
			var operation_count: int = operation_count_var
			var duration_ms: int = duration_ms_var
			var throughput: float = float(operation_count) / (float(duration_ms) / 1000.0)
			section += (
				"[color=%s]Throughput:[/color] [color=%s]%.2f ops/sec[/color]\n"
				% [UI_COLORS.text_secondary, UI_COLORS.number, throughput]
			)

	section += "\n"
	return section


func _build_test_data_analysis_section(payload: Variant, success: bool) -> String:
	"""Build comprehensive test data analysis section"""
	var section: String = ""
	section += (
		"[font_size=%s][color=%s]📈 TEST DATA ANALYSIS[/color][/font_size]\n"
		% [FONT_SIZE_XL, UI_COLORS.info]
	)
	section += "[color=%s]" % UI_COLORS.surface + "─".repeat(30) + "[/color]\n"

	var analysis: Dictionary = _analyze_test_payload(payload, success)

	if analysis.has("test_type"):
		section += (
			"[color=%s]Test Type:[/color] [color=%s]%s[/color]\n"
			% [UI_COLORS.text_secondary, UI_COLORS.accent, analysis["test_type"]]
		)

	if analysis.has("data_points"):
		section += (
			"[color=%s]Data Points:[/color] [color=%s]%d[/color]\n"
			% [UI_COLORS.text_secondary, UI_COLORS.number, analysis["data_points"]]
		)

	if analysis.has("success_rate"):
		var rate: float = analysis["success_rate"]
		var rate_color: String = (
			UI_COLORS.success
			if rate >= 0.8
			else (UI_COLORS.warning if rate >= 0.6 else UI_COLORS.danger)
		)
		var rate_bar: String = _generate_progress_bar(rate, rate >= 0.8)
		section += (
			"[color=%s]Success Rate:[/color] [color=%s]%.1f%%[/color]\n"
			% [UI_COLORS.text_secondary, rate_color, rate * 100.0]
		)
		section += "%s\n" % rate_bar

	if analysis.has("key_insights") and analysis["key_insights"].size() > 0:
		section += "[color=%s]Key Insights:[/color]\n" % UI_COLORS.text_secondary
		for insight: Variant in analysis["key_insights"]:
			section += "  • [color=%s]%s[/color]\n" % [UI_COLORS.text_primary, insight]

	section += "\n"
	return section


func _generate_progress_bar(progress: float, is_success: bool = true) -> String:
	"""Generate a visual progress bar"""
	var bar_length: int = 20
	var filled_length: int = int(progress * bar_length)
	var bar_color: String = UI_COLORS.success if is_success else UI_COLORS.danger
	var empty_color: String = UI_COLORS.muted

	var filled_part: String = "█".repeat(filled_length)
	var empty_part: String = "░".repeat(bar_length - filled_length)

	return (
		"[color=%s]%s[/color][color=%s]%s[/color] [color=%s]%.1f%%[/color]"
		% [bar_color, filled_part, empty_color, empty_part, UI_COLORS.number, progress * 100.0]
	)


func _generate_performance_bar(duration_ms: int) -> String:
	"""Generate performance visualization bar"""
	var category: String = _categorize_performance(duration_ms)
	var color: String = _get_performance_color(category)

	var bar_length: int = min(20, max(1, int(duration_ms / 50.0)))  # Scale based on duration
	var bar: String = "▓".repeat(bar_length)

	return (
		"[color=%s]%s[/color] [color=%s]%s[/color]"
		% [color, bar, UI_COLORS.text_secondary, category]
	)


func _categorize_performance(duration_ms: int) -> String:
	"""Categorize performance based on duration"""
	if duration_ms < 100:
		return "EXCELLENT"
	elif duration_ms < 500:
		return "GOOD"
	elif duration_ms < 1000:
		return "ACCEPTABLE"
	elif duration_ms < 3000:
		return "SLOW"
	else:
		return "VERY_SLOW"


func _get_performance_color(category: String) -> String:
	"""Get color for performance category"""
	match category:
		"EXCELLENT":
			return UI_COLORS.success
		"GOOD":
			return UI_COLORS.success
		"ACCEPTABLE":
			return UI_COLORS.warning
		"SLOW":
			return UI_COLORS.danger
		"VERY_SLOW":
			return UI_COLORS.danger
		_:
			return UI_COLORS.muted


func _extract_timing_info(payload: Variant) -> Dictionary:
	"""Extract timing information from test payload"""
	var timing: Dictionary = {}

	if payload is Dictionary:
		var dict_payload: Dictionary = payload

		if dict_payload.has("duration_ms"):
			timing["duration_ms"] = dict_payload["duration_ms"]
		elif dict_payload.has("execution_time_ms"):
			timing["duration_ms"] = dict_payload["execution_time_ms"]
		elif dict_payload.has("elapsed_ms"):
			timing["duration_ms"] = dict_payload["elapsed_ms"]

		if dict_payload.has("operation_count"):
			timing["operation_count"] = dict_payload["operation_count"]
		elif dict_payload.has("total_operations"):
			timing["operation_count"] = dict_payload["total_operations"]
		elif dict_payload.has("test_count"):
			timing["operation_count"] = dict_payload["test_count"]

	return timing


func _analyze_test_payload(payload: Variant, success: bool) -> Dictionary:
	"""Analyze test payload for insights and metrics"""
	var analysis: Dictionary = {}

	if payload is Dictionary:
		var dict_payload: Dictionary = payload

		if dict_payload.has("test_type"):
			analysis["test_type"] = dict_payload["test_type"]
		elif dict_payload.has("operation"):
			analysis["test_type"] = dict_payload["operation"]
		else:
			analysis["test_type"] = "General Test"

		var data_points: int = 0
		if dict_payload.has("results") and dict_payload["results"] is Array:
			data_points = dict_payload["results"].size()
		elif dict_payload.has("operations") and dict_payload["operations"] is Array:
			data_points = dict_payload["operations"].size()
		else:
			data_points = 1
		analysis["data_points"] = data_points

		if dict_payload.has("success_rate"):
			var success_rate_var: Variant = dict_payload["success_rate"]
			if success_rate_var is float:
				analysis["success_rate"] = success_rate_var
			elif success_rate_var is int:
				var success_rate_int: int = success_rate_var
				analysis["success_rate"] = float(success_rate_int)
			else:
				analysis["success_rate"] = 1.0 if success else 0.0
		elif dict_payload.has("passed_tests") and dict_payload.has("total_tests"):
			var passed_tests_var: Variant = dict_payload["passed_tests"]
			var total_tests_var: Variant = dict_payload["total_tests"]
			if (
				(passed_tests_var is int or passed_tests_var is float)
				and (total_tests_var is int or total_tests_var is float)
			):
				var passed_val: float
				var total_val: float

				if passed_tests_var is float:
					passed_val = passed_tests_var
				else:
					var passed_int: int = passed_tests_var
					passed_val = float(passed_int)

				if total_tests_var is float:
					total_val = total_tests_var
				else:
					var total_int: int = total_tests_var
					total_val = float(total_int)

				analysis["success_rate"] = passed_val / total_val
			else:
				analysis["success_rate"] = 1.0 if success else 0.0
		else:
			analysis["success_rate"] = 1.0 if success else 0.0

		var insights: Array[String] = []

		if dict_payload.has("performance_metrics"):
			insights.append("Performance metrics collected")

		if dict_payload.has("error_count") and dict_payload["error_count"] > 0:
			insights.append("Errors detected: %d" % dict_payload["error_count"])

		if dict_payload.has("retry_count") and dict_payload["retry_count"] > 0:
			insights.append("Retries required: %d" % dict_payload["retry_count"])

		if analysis["success_rate"] < 1.0:
			insights.append("Partial success - investigate failed operations")

		if data_points > 1:
			insights.append("Batch operation with %d data points" % data_points)

		analysis["key_insights"] = insights

	return analysis


func _build_action_report_with_execution_log(
	action: DebugAction, success: bool, payload: Variant, execution_log: Array[Dictionary]
) -> String:
	"""Generate comprehensive report with complete step-by-step execution history"""
	var report: String = ""

	var status_icon: String = "✅" if success else "❌"
	report += (
		"[font_size=%s][b]%s ACTION EXECUTION COMPLETE[/b][/font_size]\n"
		% [FONT_SIZE_XXL, status_icon]
	)
	report += "[color=%s]" % UI_COLORS.surface + "━".repeat(50) + "[/color]\n\n"

	var final_status_icon: String = "✓" if success else "✗"
	var final_status_color: String = UI_COLORS.success if success else UI_COLORS.danger
	var final_status_text: String = "SUCCESS" if success else "FAILURE"

	report += (
		"[font_size=%s][color=%s]EXECUTION STATUS[/color][/font_size]\n"
		% [FONT_SIZE_XL, UI_COLORS.info]
	)
	report += "[color=%s]" % UI_COLORS.surface + "─".repeat(30) + "[/color]\n"
	report += (
		"[font_size=%s][color=%s]%s %s[/color][/font_size]\n\n"
		% [FONT_SIZE_XL, final_status_color, final_status_icon, final_status_text]
	)

	report += (
		"[font_size=%s][color=%s]📋 EXECUTION STEPS[/color][/font_size]\n"
		% [FONT_SIZE_XL, UI_COLORS.info]
	)
	report += "[color=%s]" % UI_COLORS.surface + "─".repeat(40) + "[/color]\n"

	if execution_log.size() > 0:
		for i: int in range(execution_log.size()):
			var entry: Dictionary = execution_log[i]
			var step_icon: String = "⚠️" if entry.get("is_error", false) else "🔄"
			var step_color: String = (
				UI_COLORS.danger if entry.get("is_error", false) else UI_COLORS.info
			)
			var timestamp: String = entry.get("timestamp", "")
			var message: String = entry.get("message", "")

			var time_part: String = timestamp.split("T")[1] if "T" in timestamp else timestamp
			if " " in time_part:
				time_part = (
					time_part.split(" ")[1] if time_part.split(" ").size() > 1 else time_part
				)

			report += (
				"[color=%s][%02d][/color] [color=%s]%s[/color] [color=%s]%s[/color] [color=%s]%s[/color]\n"
				% [
					UI_COLORS.number,
					i + 1,
					UI_COLORS.muted,
					time_part,
					step_color,
					step_icon,
					UI_COLORS.text_primary,
					message
				]
			)
	else:
		report += "[color=%s]No execution steps recorded[/color]\n" % UI_COLORS.muted

	report += "\n"

	var device_info: String = _get_device_context_header()
	report += device_info + "\n"

	report += _build_result_status_section(success, payload)

	report += _build_action_details_section(action)

	report += _build_performance_metrics_section(payload)

	report += _build_test_data_analysis_section(payload, success)

	if action.description != "":
		report += (
			"[color=%s]Description:[/color] [color=%s]%s[/color]\n"
			% [UI_COLORS.text_secondary, UI_COLORS.text_primary, action.description]
		)

	report += "\n"

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
		if payload != null:
			var error_details: String = _format_error_message(payload)
			report += error_details + "\n"
		else:
			report += (
				"[color=%s]Action failed with no error details provided[/color]\n" % UI_COLORS.muted
			)

	report += (
		"\n[color=%s]Report generated at %s[/color]"
		% [UI_COLORS.text_secondary, Time.get_datetime_string_from_system()]
	)

	return report
