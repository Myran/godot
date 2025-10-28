class_name DebugMenuUtilities
extends RefCounted


static func build_run_all_summary(
	results: Array[Dictionary], scope_description: String, successful: int, failed: int
) -> String:
	var total: int = results.size()
	var summary: String = ""

	summary += (
		"[font_size=%s][b]RUN ALL COMPLETE[/b][/font_size]\n" % DebugUIConstants.FONT_SIZE_XXL
	)
	summary += (
		"[font_size=%s][color=%s]%s[/color][/font_size]\n\n"
		% [DebugUIConstants.FONT_SIZE_XL, DebugUIConstants.UI_COLORS.accent, scope_description]
	)

	summary += (
		"[font_size=%s][color=%s]SUMMARY[/color][/font_size]\n"
		% [DebugUIConstants.FONT_SIZE_XL, DebugUIConstants.UI_COLORS.info]
	)
	summary += ("[color=%s]" % DebugUIConstants.UI_COLORS.surface + "─".repeat(50) + "[/color]\n")
	summary += (
		"[color=%s]Total Actions:[/color] [color=%s]%d[/color]\n"
		% [DebugUIConstants.UI_COLORS.text_secondary, DebugUIConstants.UI_COLORS.number, total]
	)
	summary += (
		"[color=%s]Successful:[/color] [color=%s]%d[/color]\n"
		% [
			DebugUIConstants.UI_COLORS.text_secondary,
			DebugUIConstants.UI_COLORS.success,
			successful
		]
	)
	summary += (
		"[color=%s]Failed:[/color] [color=%s]%d[/color]\n\n"
		% [
			DebugUIConstants.UI_COLORS.text_secondary,
			DebugUIConstants.UI_COLORS.danger if failed > 0 else DebugUIConstants.UI_COLORS.muted,
			failed
		]
	)

	var success_rate: float = (float(successful) / float(total)) * 100.0 if total > 0 else 0.0
	var rate_color: String = (
		DebugUIConstants.UI_COLORS.success
		if success_rate >= 90.0
		else (
			DebugUIConstants.UI_COLORS.warning
			if success_rate >= 75.0
			else DebugUIConstants.UI_COLORS.danger
		)
	)
	summary += (
		"[color=%s]Success Rate:[/color] [color=%s]%.1f%%[/color]\n"
		% [DebugUIConstants.UI_COLORS.text_secondary, rate_color, success_rate]
	)
	var rate_bar: String = DebugPerformanceAnalyzer.generate_progress_bar(
		success_rate / 100.0, success_rate >= 80.0
	)
	summary += "%s\n\n" % rate_bar

	summary += (
		"[font_size=%s][color=%s]DETAILED RESULTS[/color][/font_size]\n"
		% [DebugUIConstants.FONT_SIZE_XL, DebugUIConstants.UI_COLORS.info]
	)
	summary += ("[color=%s]" % DebugUIConstants.UI_COLORS.surface + "─".repeat(30) + "[/color]\n")

	for i: int in range(results.size()):
		var result: Dictionary = results[i]
		var action_name: String = result.get("action_name", "Unknown Action")
		var success: bool = result.get("success", false)
		var payload: Variant = result.get("payload", null)

		var status_icon: String = "✓" if success else "✗"
		var status_color: String = (
			DebugUIConstants.UI_COLORS.success if success else DebugUIConstants.UI_COLORS.danger
		)
		var index_str: String = (
			"[color=%s][%02d][/color]" % [DebugUIConstants.UI_COLORS.number, i + 1]
		)

		summary += (
			"%s [color=%s]%s[/color] [color=%s]%s[/color]"
			% [
				index_str,
				status_color,
				status_icon,
				DebugUIConstants.UI_COLORS.text_primary,
				action_name
			]
		)

		if not success and payload != null:
			var error_summary: String = DebugFormatUtilities.extract_concise_error(payload)
			if not error_summary.is_empty():
				summary += (
					" [color=%s]- %s[/color]" % [DebugUIConstants.UI_COLORS.danger, error_summary]
				)

		summary += "\n"

	summary += (
		"\n[color=%s]Execution completed at %s[/color]"
		% [DebugUIConstants.UI_COLORS.text_secondary, Time.get_datetime_string_from_system()]
	)

	return summary


static func apply_error_styling(text: String) -> String:
	return (
		(
			"[font_size=%s][color=%s]⚠ ERROR[/color][/font_size]\n"
			% [DebugUIConstants.FONT_SIZE_XL, DebugUIConstants.UI_COLORS.danger]
		)
		+ (
			"[font_size=%s][color=%s]%s[/color][/font_size]"
			% [DebugUIConstants.FONT_SIZE_L, DebugUIConstants.UI_COLORS.text_primary, text]
		)
	)


static func apply_success_styling(text: String) -> String:
	return (
		"[font_size=%s][color=%s]%s[/color][/font_size]"
		% [DebugUIConstants.FONT_SIZE_L, DebugUIConstants.UI_COLORS.text_primary, text]
	)


static func build_styled_header() -> String:
	var build_type: String = "Debug" if OS.is_debug_build() else "Release"
	var commit_hash: String = Engine.get_version_info().get("hash", "unknown")
	var shortened_hash: String = (
		commit_hash.substr(0, 8) if commit_hash.length() > 8 else commit_hash
	)

	return (
		(
			"[font_size=%s][color=%s]━━━ DEBUG CONSOLE ━━━[/color][/font_size]\n"
			% [DebugUIConstants.FONT_SIZE_XL, DebugUIConstants.UI_COLORS.info]
		)
		+ (
			"[font_size=%s][color=%s]%s • %s • %s[/color][/font_size]"
			% [
				DebugUIConstants.FONT_SIZE_M,
				DebugUIConstants.UI_COLORS.text_secondary,
				OS.get_name(),
				build_type,
				shortened_hash
			]
		)
	)


static func setup_navigation_ui_visibility(item_list: ItemList, run_button: Button = null) -> void:
	"""Common UI visibility setup pattern used by populate functions"""
	if is_instance_valid(item_list):
		item_list.visible = true

	if is_instance_valid(run_button):
		run_button.visible = true


static func generate_category_display_name(category_name: String, has_ungrouped: bool) -> String:
	"""Generate display name for category with appropriate prefix"""
	if has_ungrouped:
		return "• " + category_name  # Bullet indicates direct actions available
	return "▸ " + category_name  # Arrow indicates submenu only


static func generate_action_display_name(action_name: String, prefix: String = "") -> String:
	"""Generate display name for action with optional prefix"""
	return prefix + action_name


static func generate_group_display_name(group_name: String, prefix: String = "▸ ") -> String:
	"""Generate display name for group with optional prefix"""
	return prefix + group_name


static func organize_categories_by_type(categories: Array[String]) -> Array[String]:
	"""Organize categories by type: direct actions first, then submenu-only"""
	var categories_with_direct_actions: Array[String] = []
	var categories_with_only_groups: Array[String] = []

	for category_name: String in categories:
		if DebugRegistry.has_ungrouped_actions(category_name):
			categories_with_direct_actions.append(category_name)
		else:
			categories_with_only_groups.append(category_name)

	categories_with_direct_actions.sort()
	categories_with_only_groups.sort()

	return categories_with_direct_actions + categories_with_only_groups
