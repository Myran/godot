@tool
class_name AdvancedLoggerIOSLoader
extends Node
## iOS-specific loader for Advanced Logger
## Ensures all required files are available

# Core files needed
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
	# This function runs when the autoload loads
	if OS.get_name() == "iOS":
		_prepare_for_ios()

func _ready() -> void:
	# This runs after _enter_tree
	if OS.get_name() == "iOS":
		# Run a verification after everything is loaded
		call_deferred("_verify_ios_dependencies")

## Prepare the logger for iOS
func _prepare_for_ios() -> void:
	print("[Advanced Logger] iOS Loader activated")

	# Load required dependencies
	var loaded_count = 0
	for file_path in CORE_FILES:
		var resource = load(file_path)
		if resource:
			loaded_count += 1

	print("[Advanced Logger] iOS Loader: Loaded %d/%d dependencies" % [loaded_count, CORE_FILES.size()])

## Verify all dependencies are working
func _verify_ios_dependencies() -> void:
	# Disable if not iOS
	if OS.get_name() != "iOS":
		return

	print("[Advanced Logger] Running iOS dependency verification...")

	# Check for iOS helper
	var ios_helper = load("res://addons/advanced_logger/utils/ios_logger_helper.gd")
	if ios_helper:
		print("[Advanced Logger] ✓ iOS Helper loaded successfully")
	else:
		print("[Advanced Logger] ✗ iOS Helper not found!")

	# Test logging
	if Log:
		print("[Advanced Logger] ✓ Log singleton accessible")
		Log.info("iOS Loader verification test", {"platform": OS.get_name()}, ["test", "verification"])
	else:
		print("[Advanced Logger] ✗ Log singleton not accessible!")
