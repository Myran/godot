@tool
class_name AdvancedLoggerIOSLoader
extends Node

const CORE_FILES = [
	"res://addons/advanced_logger/core/logger.gd",
	"res://addons/advanced_logger/core/logger_colors.gd",
	"res://addons/advanced_logger/core/log_formatter.gd",
	"res://addons/advanced_logger/core/ilogger.gd",
	"res://addons/advanced_logger/utils/config_manager.gd",
	"res://addons/advanced_logger/utils/tag_manager.gd",
	"res://addons/advanced_logger/utils/android_logger_helper.gd",
	"res://addons/advanced_logger/utils/ios_logger_helper.gd"
]

func _enter_tree() -> void:
	if OS.get_name() == "iOS":
		_prepare_for_ios()

func _ready() -> void:
	if OS.get_name() == "iOS":
		call_deferred("_verify_ios_dependencies")

func _prepare_for_ios() -> void:
	print("[Advanced Logger] iOS Loader activated")

	var loaded_count = 0
	for file_path in CORE_FILES:
		var resource: Resource = load(file_path)
		if resource:
			loaded_count += 1

	print("[Advanced Logger] iOS Loader: Loaded %d/%d dependencies" % [loaded_count, CORE_FILES.size()])

func _verify_ios_dependencies() -> void:
	if OS.get_name() != "iOS":
		return

	print("[Advanced Logger] Running iOS dependency verification...")

	var ios_helper = load("res://addons/advanced_logger/utils/ios_logger_helper.gd")
	if ios_helper:
		print("[Advanced Logger] ✓ iOS Helper loaded successfully")
	else:
		print("[Advanced Logger] ✗ iOS Helper not found!")

	if Log:
		print("[Advanced Logger] ✓ Log singleton accessible")
		Log.info("iOS Loader verification test", {"platform": OS.get_name()}, ["test", "verification"])
	else:
		print("[Advanced Logger] ✗ Log singleton not accessible!")
