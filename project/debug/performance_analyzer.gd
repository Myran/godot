class_name DebugPerformanceAnalyzer
extends RefCounted


static func categorize_performance(duration_ms: int) -> String:
	if duration_ms < 100:
		return "EXCELLENT"
	if duration_ms < 500:
		return "GOOD"
	if duration_ms < 1000:
		return "ACCEPTABLE"
	if duration_ms < 3000:
		return "SLOW"
	return "VERY_SLOW"


static func get_performance_color(category: String) -> String:
	match category:
		"EXCELLENT":
			return DebugUIConstants.UI_COLORS.success
		"GOOD":
			return DebugUIConstants.UI_COLORS.success
		"ACCEPTABLE":
			return DebugUIConstants.UI_COLORS.warning
		"SLOW":
			return DebugUIConstants.UI_COLORS.danger
		"VERY_SLOW":
			return DebugUIConstants.UI_COLORS.danger
		_:
			return DebugUIConstants.UI_COLORS.muted


static func extract_timing_info(payload: Variant) -> Dictionary:
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


static func analyze_test_payload(payload: Variant, success: bool) -> Dictionary:
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


static func generate_progress_bar(progress: float, is_success: bool = true) -> String:
	var bar_length: int = 20
	var filled_length: int = int(progress * bar_length)
	var bar_color: String = (
		DebugUIConstants.UI_COLORS.success if is_success else DebugUIConstants.UI_COLORS.danger
	)
	var empty_color: String = DebugUIConstants.UI_COLORS.muted

	var filled_part: String = "█".repeat(filled_length)
	var empty_part: String = "░".repeat(bar_length - filled_length)

	return (
		"[color=%s]%s[/color][color=%s]%s[/color] [color=%s]%.1f%%[/color]"
		% [
			bar_color,
			filled_part,
			empty_color,
			empty_part,
			DebugUIConstants.UI_COLORS.number,
			progress * 100.0
		]
	)


static func generate_performance_bar(duration_ms: int) -> String:
	var category: String = categorize_performance(duration_ms)
	var color: String = get_performance_color(category)

	var bar_length: int = min(20, max(1, int(duration_ms / 50.0)))
	var bar: String = "▓".repeat(bar_length)

	return (
		"[color=%s]%s[/color] [color=%s]%s[/color]"
		% [color, bar, DebugUIConstants.UI_COLORS.text_secondary, category]
	)
