@tool
extends EditorExportPlugin
## Export plugin for Advanced Logger
## Ensures the logger configuration file is included in exports

const CONFIG_PATH = "res://addons/advanced_logger/settings.cfg"


func _get_name() -> String:
	return "AdvancedLoggerExportPlugin"


func _export_begin(
	_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int
) -> void:
	# Check if the config file exists and add it to the export
	if FileAccess.file_exists(CONFIG_PATH):
		print_rich(
			(
				"[color=#%s]Advanced Logger: Including config file in export[/color]"
				% LoggerColors.INFO_HTML
			)
		)
		# Force include the config file in the export
		#include_file(CONFIG_PATH)
	else:
		push_warning("Advanced Logger config file not found: %s" % CONFIG_PATH)


func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	# Ensure our config file is not excluded
	if path == CONFIG_PATH:
		# Do not skip this file
		pass
