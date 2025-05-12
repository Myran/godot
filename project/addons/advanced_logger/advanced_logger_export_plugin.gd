@tool
extends EditorExportPlugin
## Export plugin for Advanced Logger
## Ensures the logger configuration file is included in exports
## and handles platform-specific adjustments

const CONFIG_PATH = "res://addons/advanced_logger/settings.cfg"
const ANDROID_HELPER_PATH = "res://addons/advanced_logger/utils/android_logger_helper.gd"
const IOS_HELPER_PATH = "res://addons/advanced_logger/utils/ios_logger_helper.gd"
const LOGGER_CORE_PATH = "res://addons/advanced_logger/core/logger.gd"
const LOGGER_COLORS_PATH = "res://addons/advanced_logger/core/logger_colors.gd"
const LOGGER_FORMATTER_PATH = "res://addons/advanced_logger/core/log_formatter.gd"
const CONFIG_MANAGER_PATH = "res://addons/advanced_logger/utils/config_manager.gd"
const TAG_MANAGER_PATH = "res://addons/advanced_logger/utils/tag_manager.gd"

# Track files we want to ensure are included
var _files_to_keep = []


func _get_name() -> String:
	return "AdvancedLoggerExportPlugin"


func _export_begin(
	features: PackedStringArray, _is_debug: bool, _path: String, _flags: int
) -> void:
	# Reset our list of files to keep
	_files_to_keep.clear()

	# Check for platform-specific features
	var is_android = features.has("android")
	var is_ios = features.has("ios")

	# Log platform detection
	print_rich(
		(
			"[color=#%s]Advanced Logger: Export platform - Android: %s, iOS: %s[/color]"
			% [LoggerColors.INFO_HTML, is_android, is_ios]
		)
	)

	# Essential files to always include
	var core_files = [
		CONFIG_PATH,
		LOGGER_CORE_PATH,
		LOGGER_COLORS_PATH,
		LOGGER_FORMATTER_PATH,
		CONFIG_MANAGER_PATH,
		TAG_MANAGER_PATH,
	]

	# Add all core files to our keep list
	for file_path in core_files:
		if FileAccess.file_exists(file_path):
			print_rich(
				(
					"[color=#%s]Advanced Logger: Including core file in export: %s[/color]"
					% [LoggerColors.INFO_HTML, file_path.get_file()]
				)
			)
			_files_to_keep.append(file_path)

	# Add platform-specific helpers to our keep list
	if is_android and FileAccess.file_exists(ANDROID_HELPER_PATH):
		print_rich(
			(
				"[color=#%s]Advanced Logger: Including Android helper in export[/color]"
				% [LoggerColors.INFO_HTML]
			)
		)
		_files_to_keep.append(ANDROID_HELPER_PATH)

	if is_ios and FileAccess.file_exists(IOS_HELPER_PATH):
		print_rich(
			(
				"[color=#%s]Advanced Logger: Including iOS helper in export[/color]"
				% [LoggerColors.INFO_HTML]
			)
		)
		_files_to_keep.append(IOS_HELPER_PATH)


func _export_file(path: String, type: String, features: PackedStringArray) -> void:
	# In Godot 4.5, the _export_file method is called for each file being exported
	# If the file is in our keep list, we should NOT skip it (return false)
	# If we want to skip a file, we should return true

	# Don't skip any files in our keep list
	if _files_to_keep.has(path):
		# We don't need to do anything, the file will be included by default
		pass


func _export_end() -> void:
	print_rich(
		(
			"[color=#%s]Advanced Logger: Export completed. Required files marked for inclusion.[/color]"
			% [LoggerColors.SUCCESS_HTML]
		)
	)

	# Clear our list after export
	_files_to_keep.clear()
