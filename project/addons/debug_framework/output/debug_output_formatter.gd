class_name DebugOutputFormatter
extends RefCounted


func format_and_output_status(action: DebugAction, text: String, is_error: bool) -> void:
	var formatted: String = _format_status_message(action, text, is_error)
	output_formatted_text(formatted)


func format_enhanced_status(action: DebugAction, text: String, is_error: bool) -> String:
	"""Generate enhanced real-time status updates with context and progress indicators"""
	var datetime_parts: PackedStringArray = Time.get_datetime_string_from_system().split(" ")
	var timestamp: String = datetime_parts[1] if datetime_parts.size() > 1 else datetime_parts[0]
	var status_icon: String = "⚠️" if is_error else "🔄"
	var color: String = (
		DebugUIConstants.UI_COLORS.danger if is_error else DebugUIConstants.UI_COLORS.info
	)

	var enhanced: String = "[font_size=24]"
	enhanced += "[color=%s]%s[/color] " % [DebugUIConstants.UI_COLORS.muted, timestamp]
	enhanced += "[color=%s]%s[/color] " % [color, status_icon]
	enhanced += "[color=%s][%s][/color] " % [DebugUIConstants.UI_COLORS.accent, action.category]
	enhanced += "[color=%s]%s[/color]" % [DebugUIConstants.UI_COLORS.text_primary, text]
	enhanced += "[/font_size]\n"

	return enhanced


func format_completion_report(action: DebugAction, success: bool, result: Variant) -> String:
	return _build_action_report(action, success, result)


func format_completion_report_structured(
	action: DebugAction, action_result: DebugActionResult
) -> String:
	"""Enhanced formatting for DebugActionResult with richer error information"""
	return _build_action_report_structured(action, action_result)


func format_completion_report_with_execution_log(
	action: DebugAction, success: bool, result: Variant, execution_log: Array[Dictionary]
) -> String:
	"""Generate comprehensive report including full execution step history"""
	return _build_action_report_with_execution_log(action, success, result, execution_log)


func output_formatted_text(formatted_text: String) -> void:
	match OS.get_name():
		"Android", "iOS":
			var plain: String = DebugFormatUtilities.strip_bbcode_tags(formatted_text)
			print(plain)
		_:
			print_rich(formatted_text)


func _format_status_message(_action: DebugAction, text: String, is_error: bool) -> String:
	if is_error:
		return "[color=%s]⚠ %s[/color]" % [DebugUIConstants.UI_COLORS.danger, text]
	return "[color=%s]%s[/color]" % [DebugUIConstants.UI_COLORS.text_primary, text]


func _build_action_report(action: DebugAction, success: bool, payload: Variant) -> String:
	"""Generate a comprehensive, beautifully formatted report for a single action execution"""
	var report: String = ""

	var status_icon: String = "✅" if success else "❌"
	report += (
		"[font_size=%s][b]%s ACTION EXECUTION COMPLETE[/b][/font_size]\n"
		% [DebugUIConstants.FONT_SIZE_XXL, status_icon]
	)
	report += "[color=%s]" % DebugUIConstants.UI_COLORS.surface + "━".repeat(50) + "[/color]\n\n"

	var final_status_icon: String = "✓" if success else "✗"
	var final_status_color: String = (
		DebugUIConstants.UI_COLORS.success if success else DebugUIConstants.UI_COLORS.danger
	)
	var final_status_text: String = "SUCCESS" if success else "FAILURE"

	report += (
		"[font_size=%s][color=%s]EXECUTION STATUS[/color][/font_size]\n"
		% [DebugUIConstants.FONT_SIZE_XL, DebugUIConstants.UI_COLORS.info]
	)
	report += "[color=%s]" % DebugUIConstants.UI_COLORS.surface + "─".repeat(30) + "[/color]\n"
	report += (
		"[font_size=%s][color=%s]%s %s[/color][/font_size]\n\n"
		% [DebugUIConstants.FONT_SIZE_XL, final_status_color, final_status_icon, final_status_text]
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
			% [
				DebugUIConstants.UI_COLORS.text_secondary,
				DebugUIConstants.UI_COLORS.text_primary,
				action.description
			]
		)

	report += "\n"

	if success:
		report += (
			"[font_size=%s][color=%s]RESULT DATA[/color][/font_size]\n"
			% [DebugUIConstants.FONT_SIZE_XL, DebugUIConstants.UI_COLORS.info]
		)
		report += "[color=%s]" % DebugUIConstants.UI_COLORS.surface + "─".repeat(30) + "[/color]\n"
		if payload != null:
			var formatted_payload: String = _format_payload_summary(payload)
			report += formatted_payload + "\n"
		else:
			report += (
				"[color=%s]Action completed successfully with no return data[/color]\n"
				% DebugUIConstants.UI_COLORS.muted
			)
	else:
		report += (
			"[font_size=%s][color=%s]ERROR DETAILS[/color][/font_size]\n"
			% [DebugUIConstants.FONT_SIZE_XL, DebugUIConstants.UI_COLORS.danger]
		)
		report += "[color=%s]" % DebugUIConstants.UI_COLORS.surface + "─".repeat(30) + "[/color]\n"
		var error_message: String = _format_error_message(payload)
		report += error_message + "\n"

	report += (
		"\n[color=%s]Completed at: %s[/color]"
		% [DebugUIConstants.UI_COLORS.text_secondary, Time.get_datetime_string_from_system()]
	)

	return report


func _build_action_report_structured(
	action: DebugAction, action_result: DebugActionResult
) -> String:
	"""Generate enhanced report for DebugActionResult with richer error categorization"""
	var report: String = ""

	report += (
		"[font_size=%s][b]ACTION EXECUTION COMPLETE[/b][/font_size]\n"
		% DebugUIConstants.FONT_SIZE_XXL
	)
	report += "[color=%s]" % DebugUIConstants.UI_COLORS.surface + "━".repeat(50) + "[/color]\n\n"

	var status_icon: String = "✓" if action_result.is_success() else "✗"
	var status_color: String = (
		DebugUIConstants.UI_COLORS.success
		if action_result.is_success()
		else DebugUIConstants.UI_COLORS.danger
	)
	var status_text: String = "SUCCESS" if action_result.is_success() else "FAILURE"

	report += (
		"[font_size=%s][color=%s]EXECUTION STATUS[/color][/font_size]\n"
		% [DebugUIConstants.FONT_SIZE_XL, DebugUIConstants.UI_COLORS.info]
	)
	report += "[color=%s]" % DebugUIConstants.UI_COLORS.surface + "─".repeat(30) + "[/color]\n"
	report += (
		"[font_size=%s][color=%s]%s %s[/color][/font_size]\n\n"
		% [DebugUIConstants.FONT_SIZE_XL, status_color, status_icon, status_text]
	)

	report += (
		"[font_size=%s][color=%s]ACTION DETAILS[/color][/font_size]\n"
		% [DebugUIConstants.FONT_SIZE_XL, DebugUIConstants.UI_COLORS.info]
	)
	report += "[color=%s]" % DebugUIConstants.UI_COLORS.surface + "─".repeat(30) + "[/color]\n"
	report += (
		"[color=%s]Name:[/color] [color=%s]%s[/color]\n"
		% [
			DebugUIConstants.UI_COLORS.text_secondary,
			DebugUIConstants.UI_COLORS.text_primary,
			action.action_name
		]
	)
	report += (
		"[color=%s]Category:[/color] [color=%s]%s[/color]\n"
		% [
			DebugUIConstants.UI_COLORS.text_secondary,
			DebugUIConstants.UI_COLORS.accent,
			action.category
		]
	)

	if action.group != "":
		report += (
			"[color=%s]Group:[/color] [color=%s]%s[/color]\n"
			% [
				DebugUIConstants.UI_COLORS.text_secondary,
				DebugUIConstants.UI_COLORS.accent,
				action.group
			]
		)

	if action.description != "":
		report += (
			"[color=%s]Description:[/color] [color=%s]%s[/color]\n"
			% [
				DebugUIConstants.UI_COLORS.text_secondary,
				DebugUIConstants.UI_COLORS.text_primary,
				action.description
			]
		)

	report += "\n"
	report += (
		"[font_size=%s][color=%s]%s %s[/color][/font_size]\n"
		% [DebugUIConstants.FONT_SIZE_XL, status_color, status_icon, status_text]
	)

	var duration_ms: int = action_result.get_duration_ms()
	var perf_category: String = action_result.get_performance_category()
	var perf_color: String = (
		DebugUIConstants.UI_COLORS.success
		if perf_category == "FAST"
		else (
			DebugUIConstants.UI_COLORS.warning
			if perf_category == "NORMAL"
			else DebugUIConstants.UI_COLORS.danger
		)
	)

	report += (
		"[color=%s]Duration:[/color] [color=%s]%d ms (%s)[/color]\n"
		% [DebugUIConstants.UI_COLORS.text_secondary, perf_color, duration_ms, perf_category]
	)

	if not action_result.get_operation().is_empty():
		report += (
			"[color=%s]Operation:[/color] [color=%s]%s[/color]\n"
			% [
				DebugUIConstants.UI_COLORS.text_secondary,
				DebugUIConstants.UI_COLORS.accent,
				action_result.get_operation()
			]
		)

	report += "\n"

	if action_result.is_success():
		report += (
			"[font_size=%s][color=%s]RESULT DATA[/color][/font_size]\n"
			% [DebugUIConstants.FONT_SIZE_XL, DebugUIConstants.UI_COLORS.info]
		)
		report += "[color=%s]" % DebugUIConstants.UI_COLORS.surface + "─".repeat(30) + "[/color]\n"
		var payload: Variant = action_result.get_payload()
		if payload != null:
			var formatted_payload: String = DebugFormatUtilities.pretty_print_value_no_truncation(
				payload
			)
			report += formatted_payload + "\n"
		else:
			report += (
				"[color=%s]Action completed successfully with no return data[/color]\n"
				% DebugUIConstants.UI_COLORS.muted
			)
	else:
		report += (
			"[font_size=%s][color=%s]ERROR DETAILS[/color][/font_size]\n"
			% [DebugUIConstants.FONT_SIZE_XL, DebugUIConstants.UI_COLORS.danger]
		)
		report += "[color=%s]" % DebugUIConstants.UI_COLORS.surface + "─".repeat(30) + "[/color]\n"

		report += (
			"[color=%s]Message:[/color] [color=%s]%s[/color]\n"
			% [
				DebugUIConstants.UI_COLORS.text_secondary,
				DebugUIConstants.UI_COLORS.danger,
				action_result.get_error_message()
			]
		)

		if not action_result.get_error_code().is_empty():
			report += (
				"[color=%s]Code:[/color] [color=%s]%s[/color]\n"
				% [
					DebugUIConstants.UI_COLORS.text_secondary,
					DebugUIConstants.UI_COLORS.warning,
					action_result.get_error_code()
				]
			)

		var error_category: DebugActionResult.ErrorCategory = action_result.get_error_category()
		if error_category != DebugActionResult.ErrorCategory.NONE:
			var category_name: String = DebugActionResult.ErrorCategory.keys()[error_category]
			report += (
				"[color=%s]Category:[/color] [color=%s]%s[/color]\n"
				% [
					DebugUIConstants.UI_COLORS.text_secondary,
					DebugUIConstants.UI_COLORS.warning,
					category_name
				]
			)

		var error_payload: Variant = action_result.get_payload()
		if error_payload != null:
			report += (
				"[color=%s]Additional Context:[/color]\n%s\n"
				% [
					DebugUIConstants.UI_COLORS.text_secondary,
					DebugFormatUtilities.pretty_print_value_no_truncation(error_payload)
				]
			)

	var metadata: Dictionary = action_result.get_metadata()
	if not metadata.is_empty():
		report += (
			"\n[font_size=%s][color=%s]METADATA[/color][/font_size]\n"
			% [DebugUIConstants.FONT_SIZE_L, DebugUIConstants.UI_COLORS.info]
		)
		report += "[color=%s]" % DebugUIConstants.UI_COLORS.surface + "─".repeat(20) + "[/color]\n"
		report += DebugFormatUtilities.pretty_print_value_no_truncation(metadata) + "\n"

	report += (
		"\n[color=%s]Completed at: %s[/color]"
		% [DebugUIConstants.UI_COLORS.text_secondary, Time.get_datetime_string_from_system()]
	)

	return report


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
					path_str = "/".join(string_array)
				else:
					path_str = str(path_data)
				summary += "Path: %s\n" % path_str
			summary += "Result:\n"
			var formatted_result: String = DebugFormatUtilities.pretty_print_value_no_truncation(
				result_data, 1, 5
			)
			summary += "  %s" % formatted_result.replace("\n", "\n  ")
			return summary
		return (
			"Result:\n  %s"
			% DebugFormatUtilities.pretty_print_value_no_truncation(dict_payload, 1, 5).replace(
				"\n", "\n  "
			)
		)
	return "Result: %s" % DebugFormatUtilities.pretty_print_value_no_truncation(payload, 0, 5)


func _format_error_message(payload: Variant) -> String:
	if payload == null:
		return (
			"[color=%s]Unknown error - no details provided[/color]"
			% DebugUIConstants.UI_COLORS.danger
		)
	if payload is Dictionary:
		var dict_payload: Dictionary = payload
		if dict_payload.has("error"):
			var error_data: Variant = dict_payload.get("error")
			var error_str: String = str(error_data)
			if error_str.contains("PERMISSION_DENIED"):
				return (
					"[color=%s]Permission denied[/color] - check Firebase rules\n[color=%s]Full error:[/color] %s"
					% [
						DebugUIConstants.UI_COLORS.danger,
						DebugUIConstants.UI_COLORS.text_secondary,
						error_str
					]
				)
			if error_str.contains("NETWORK_ERROR"):
				return (
					"[color=%s]Network connection issue[/color]\n[color=%s]Full error:[/color] %s"
					% [
						DebugUIConstants.UI_COLORS.danger,
						DebugUIConstants.UI_COLORS.text_secondary,
						error_str
					]
				)
			if error_str.contains("DATABASE_ERROR"):
				return (
					"[color=%s]Database operation failed[/color]\n[color=%s]Full error:[/color] %s"
					% [
						DebugUIConstants.UI_COLORS.danger,
						DebugUIConstants.UI_COLORS.text_secondary,
						error_str
					]
				)
			if error_str.contains("timeout") or error_str.contains("TIMEOUT"):
				return (
					"[color=%s]Operation timed out[/color]\n[color=%s]Full error:[/color] %s"
					% [
						DebugUIConstants.UI_COLORS.danger,
						DebugUIConstants.UI_COLORS.text_secondary,
						error_str
					]
				)
			if error_str.contains("not found") or error_str.contains("NOT_FOUND"):
				return (
					"[color=%s]Resource not found[/color]\n[color=%s]Full error:[/color] %s"
					% [
						DebugUIConstants.UI_COLORS.danger,
						DebugUIConstants.UI_COLORS.text_secondary,
						error_str
					]
				)
			return "[color=%s]Error:[/color] %s" % [DebugUIConstants.UI_COLORS.danger, error_str]
		return (
			"[color=%s]Structured error:[/color]\n%s"
			% [
				DebugUIConstants.UI_COLORS.danger,
				DebugFormatUtilities.pretty_print_value_no_truncation(dict_payload)
			]
		)
	var payload_str: String = str(payload)
	if payload_str.contains("FirebaseDatabase"):
		return (
			"[color=%s]Firebase connection issue[/color]\n[color=%s]Details:[/color] %s"
			% [
				DebugUIConstants.UI_COLORS.danger,
				DebugUIConstants.UI_COLORS.text_secondary,
				payload_str
			]
		)
	if payload_str.contains("timeout"):
		return (
			"[color=%s]Operation timed out[/color]\n[color=%s]Details:[/color] %s"
			% [
				DebugUIConstants.UI_COLORS.danger,
				DebugUIConstants.UI_COLORS.text_secondary,
				payload_str
			]
		)
	if payload_str.contains("permission"):
		return (
			"[color=%s]Permission denied[/color]\n[color=%s]Details:[/color] %s"
			% [
				DebugUIConstants.UI_COLORS.danger,
				DebugUIConstants.UI_COLORS.text_secondary,
				payload_str
			]
		)
	if payload_str.contains("not found"):
		return (
			"[color=%s]Resource not found[/color]\n[color=%s]Details:[/color] %s"
			% [
				DebugUIConstants.UI_COLORS.danger,
				DebugUIConstants.UI_COLORS.text_secondary,
				payload_str
			]
		)
	return "[color=%s]Error:[/color] %s" % [DebugUIConstants.UI_COLORS.danger, payload_str]


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
		% [DebugUIConstants.FONT_SIZE_L, DebugUIConstants.UI_COLORS.info]
	)
	context += "[color=%s]" % DebugUIConstants.UI_COLORS.surface + "─".repeat(40) + "[/color]\n"
	context += (
		"[color=%s]Platform:[/color] [color=%s]%s %s[/color]\n"
		% [
			DebugUIConstants.UI_COLORS.text_secondary,
			DebugUIConstants.UI_COLORS.accent,
			platform,
			version
		]
	)
	if model != "Unknown":
		context += (
			"[color=%s]Device:[/color] [color=%s]%s[/color]\n"
			% [DebugUIConstants.UI_COLORS.text_secondary, DebugUIConstants.UI_COLORS.accent, model]
		)
	context += (
		"[color=%s]Memory:[/color] [color=%s]%s[/color]\n"
		% [DebugUIConstants.UI_COLORS.text_secondary, DebugUIConstants.UI_COLORS.number, memory]
	)
	context += (
		"[color=%s]Timestamp:[/color] [color=%s]%s[/color]\n"
		% [DebugUIConstants.UI_COLORS.text_secondary, DebugUIConstants.UI_COLORS.muted, timestamp]
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
	var status_color: String = (
		DebugUIConstants.UI_COLORS.success if success else DebugUIConstants.UI_COLORS.danger
	)
	var status_icon: String = "✅" if success else "❌"
	var status_progress: String = DebugPerformanceAnalyzer.generate_progress_bar(
		1.0 if success else 0.0, success
	)

	var section: String = ""
	section += (
		"[font_size=%s][color=%s]📊 EXECUTION RESULT[/color][/font_size]\n"
		% [DebugUIConstants.FONT_SIZE_XL, DebugUIConstants.UI_COLORS.info]
	)
	section += "[color=%s]" % DebugUIConstants.UI_COLORS.surface + "─".repeat(30) + "[/color]\n"
	section += (
		"[font_size=%s][color=%s]%s %s[/color][/font_size]\n"
		% [DebugUIConstants.FONT_SIZE_L, status_color, status_icon, status_text]
	)
	section += "%s\n\n" % status_progress

	return section


func _build_action_details_section(action: DebugAction) -> String:
	"""Build comprehensive action details section"""
	var section: String = ""
	section += (
		"[font_size=%s][color=%s]🎯 ACTION DETAILS[/color][/font_size]\n"
		% [DebugUIConstants.FONT_SIZE_XL, DebugUIConstants.UI_COLORS.info]
	)
	section += "[color=%s]" % DebugUIConstants.UI_COLORS.surface + "─".repeat(30) + "[/color]\n"
	section += (
		"[color=%s]Name:[/color] [color=%s]%s[/color]\n"
		% [
			DebugUIConstants.UI_COLORS.text_secondary,
			DebugUIConstants.UI_COLORS.text_primary,
			action.action_name
		]
	)
	section += (
		"[color=%s]Category:[/color] [color=%s]%s[/color]\n"
		% [
			DebugUIConstants.UI_COLORS.text_secondary,
			DebugUIConstants.UI_COLORS.accent,
			action.category
		]
	)

	if action.group != "":
		section += (
			"[color=%s]Group:[/color] [color=%s]%s[/color]\n"
			% [
				DebugUIConstants.UI_COLORS.text_secondary,
				DebugUIConstants.UI_COLORS.accent,
				action.group
			]
		)

	if action.description != "":
		section += (
			"[color=%s]Description:[/color] [color=%s]%s[/color]\n"
			% [
				DebugUIConstants.UI_COLORS.text_secondary,
				DebugUIConstants.UI_COLORS.text_primary,
				action.description
			]
		)

	section += "\n"
	return section


func _build_performance_metrics_section(payload: Variant) -> String:
	"""Build performance metrics section with detailed timing analysis"""
	var section: String = ""
	section += (
		"[font_size=%s][color=%s]⚡ PERFORMANCE METRICS[/color][/font_size]\n"
		% [DebugUIConstants.FONT_SIZE_XL, DebugUIConstants.UI_COLORS.info]
	)
	section += "[color=%s]" % DebugUIConstants.UI_COLORS.surface + "─".repeat(30) + "[/color]\n"

	var timing_info: Dictionary = DebugPerformanceAnalyzer.extract_timing_info(payload)

	if timing_info.has("duration_ms"):
		var duration: int = timing_info["duration_ms"]
		var performance_category: String = DebugPerformanceAnalyzer.categorize_performance(duration)
		var perf_color: String = DebugPerformanceAnalyzer.get_performance_color(
			performance_category
		)
		var perf_bar: String = DebugPerformanceAnalyzer.generate_performance_bar(duration)

		section += (
			"[color=%s]Duration:[/color] [color=%s]%d ms[/color] [color=%s](%s)[/color]\n"
			% [
				DebugUIConstants.UI_COLORS.text_secondary,
				DebugUIConstants.UI_COLORS.number,
				duration,
				perf_color,
				performance_category
			]
		)
		section += "%s\n" % perf_bar

	if timing_info.has("operation_count"):
		section += (
			"[color=%s]Operations:[/color] [color=%s]%d[/color]\n"
			% [
				DebugUIConstants.UI_COLORS.text_secondary,
				DebugUIConstants.UI_COLORS.number,
				timing_info["operation_count"]
			]
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
				% [
					DebugUIConstants.UI_COLORS.text_secondary,
					DebugUIConstants.UI_COLORS.number,
					throughput
				]
			)

	section += "\n"
	return section


func _build_test_data_analysis_section(payload: Variant, success: bool) -> String:
	"""Build comprehensive test data analysis section"""
	var section: String = ""
	section += (
		"[font_size=%s][color=%s]📈 TEST DATA ANALYSIS[/color][/font_size]\n"
		% [DebugUIConstants.FONT_SIZE_XL, DebugUIConstants.UI_COLORS.info]
	)
	section += "[color=%s]" % DebugUIConstants.UI_COLORS.surface + "─".repeat(30) + "[/color]\n"

	var analysis: Dictionary = DebugPerformanceAnalyzer.analyze_test_payload(payload, success)

	if analysis.has("test_type"):
		section += (
			"[color=%s]Test Type:[/color] [color=%s]%s[/color]\n"
			% [
				DebugUIConstants.UI_COLORS.text_secondary,
				DebugUIConstants.UI_COLORS.accent,
				analysis["test_type"]
			]
		)

	if analysis.has("data_points"):
		section += (
			"[color=%s]Data Points:[/color] [color=%s]%d[/color]\n"
			% [
				DebugUIConstants.UI_COLORS.text_secondary,
				DebugUIConstants.UI_COLORS.number,
				analysis["data_points"]
			]
		)

	if analysis.has("success_rate"):
		var rate: float = analysis["success_rate"]
		var rate_color: String = (
			DebugUIConstants.UI_COLORS.success
			if rate >= 0.8
			else (
				DebugUIConstants.UI_COLORS.warning
				if rate >= 0.6
				else DebugUIConstants.UI_COLORS.danger
			)
		)
		var rate_bar: String = DebugPerformanceAnalyzer.generate_progress_bar(rate, rate >= 0.8)
		section += (
			"[color=%s]Success Rate:[/color] [color=%s]%.1f%%[/color]\n"
			% [DebugUIConstants.UI_COLORS.text_secondary, rate_color, rate * 100.0]
		)
		section += "%s\n" % rate_bar

	if analysis.has("key_insights") and analysis["key_insights"].size() > 0:
		section += "[color=%s]Key Insights:[/color]\n" % DebugUIConstants.UI_COLORS.text_secondary
		for insight: Variant in analysis["key_insights"]:
			section += (
				"  • [color=%s]%s[/color]\n" % [DebugUIConstants.UI_COLORS.text_primary, insight]
			)

	section += "\n"
	return section


func _build_action_report_with_execution_log(
	action: DebugAction, success: bool, payload: Variant, execution_log: Array[Dictionary]
) -> String:
	"""Generate comprehensive report with complete step-by-step execution history"""
	var report: String = ""

	var status_icon: String = "✅" if success else "❌"
	report += (
		"[font_size=%s][b]%s ACTION EXECUTION COMPLETE[/b][/font_size]\n"
		% [DebugUIConstants.FONT_SIZE_XXL, status_icon]
	)
	report += "[color=%s]" % DebugUIConstants.UI_COLORS.surface + "━".repeat(50) + "[/color]\n\n"

	var final_status_icon: String = "✓" if success else "✗"
	var final_status_color: String = (
		DebugUIConstants.UI_COLORS.success if success else DebugUIConstants.UI_COLORS.danger
	)
	var final_status_text: String = "SUCCESS" if success else "FAILURE"

	report += (
		"[font_size=%s][color=%s]EXECUTION STATUS[/color][/font_size]\n"
		% [DebugUIConstants.FONT_SIZE_XL, DebugUIConstants.UI_COLORS.info]
	)
	report += "[color=%s]" % DebugUIConstants.UI_COLORS.surface + "─".repeat(30) + "[/color]\n"
	report += (
		"[font_size=%s][color=%s]%s %s[/color][/font_size]\n\n"
		% [DebugUIConstants.FONT_SIZE_XL, final_status_color, final_status_icon, final_status_text]
	)

	report += (
		"[font_size=%s][color=%s]📋 EXECUTION STEPS[/color][/font_size]\n"
		% [DebugUIConstants.FONT_SIZE_XL, DebugUIConstants.UI_COLORS.info]
	)
	report += "[color=%s]" % DebugUIConstants.UI_COLORS.surface + "─".repeat(40) + "[/color]\n"

	if execution_log.size() > 0:
		for i: int in range(execution_log.size()):
			var entry: Dictionary = execution_log[i]
			var step_icon: String = "⚠️" if entry.get("is_error", false) else "🔄"
			var step_color: String = (
				DebugUIConstants.UI_COLORS.danger
				if entry.get("is_error", false)
				else DebugUIConstants.UI_COLORS.info
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
					DebugUIConstants.UI_COLORS.number,
					i + 1,
					DebugUIConstants.UI_COLORS.muted,
					time_part,
					step_color,
					step_icon,
					DebugUIConstants.UI_COLORS.text_primary,
					message
				]
			)
	else:
		report += (
			"[color=%s]No execution steps recorded[/color]\n" % DebugUIConstants.UI_COLORS.muted
		)

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
			% [
				DebugUIConstants.UI_COLORS.text_secondary,
				DebugUIConstants.UI_COLORS.text_primary,
				action.description
			]
		)

	report += "\n"

	if success:
		report += (
			"[font_size=%s][color=%s]RESULT DATA[/color][/font_size]\n"
			% [DebugUIConstants.FONT_SIZE_XL, DebugUIConstants.UI_COLORS.info]
		)
		report += "[color=%s]" % DebugUIConstants.UI_COLORS.surface + "─".repeat(30) + "[/color]\n"
		if payload != null:
			var formatted_payload: String = _format_payload_summary(payload)
			report += formatted_payload + "\n"
		else:
			report += (
				"[color=%s]Action completed successfully with no return data[/color]\n"
				% DebugUIConstants.UI_COLORS.muted
			)
	else:
		report += (
			"[font_size=%s][color=%s]ERROR DETAILS[/color][/font_size]\n"
			% [DebugUIConstants.FONT_SIZE_XL, DebugUIConstants.UI_COLORS.danger]
		)
		report += "[color=%s]" % DebugUIConstants.UI_COLORS.surface + "─".repeat(30) + "[/color]\n"
		if payload != null:
			var error_details: String = _format_error_message(payload)
			report += error_details + "\n"
		else:
			report += (
				"[color=%s]Action failed with no error details provided[/color]\n"
				% DebugUIConstants.UI_COLORS.muted
			)

	report += (
		"\n[color=%s]Report generated at %s[/color]"
		% [DebugUIConstants.UI_COLORS.text_secondary, Time.get_datetime_string_from_system()]
	)

	return report
