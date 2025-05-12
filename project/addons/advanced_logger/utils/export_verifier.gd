@tool
class_name LoggerExportVerifier
extends RefCounted
## Utility to verify that logger files are properly included in exports

## Verify that all necessary logger files exist
static func verify_files_exist() -> Dictionary:
	print("\n=== Advanced Logger Export Verification ===")

	var result = {
		"core_files_exist": true,
		"android_helper_exists": false,
		"ios_helper_exists": false,
		"missing_files": [],
		"platform": OS.get_name(),
		"logger_functional": false
	}

	# Core files that must exist
	var core_files = [
		"res://addons/advanced_logger/core/logger.gd",
		"res://addons/advanced_logger/core/logger_colors.gd",
		"res://addons/advanced_logger/core/log_formatter.gd",
		"res://addons/advanced_logger/core/ilogger.gd",
		"res://addons/advanced_logger/utils/config_manager.gd",
		"res://addons/advanced_logger/utils/tag_manager.gd"
	]

	# Alternative paths to check (in PCK file)
	var alt_core_files = [
		"addons/advanced_logger/core/logger.gd",
		"advanced_logger/core/logger.gd",
		".addons/advanced_logger/core/logger.gd"
	]

	# Check each core file
	for file_path in core_files:
		var file_exists = FileAccess.file_exists(file_path)

		# If not found at primary path, check alternative paths
		if not file_exists:
			for alt_path in alt_core_files:
				if FileAccess.file_exists(alt_path):
					file_exists = true
					print("✓ Core file exists at alternative path: " + alt_path)
					break

		if not file_exists:
			result.core_files_exist = false
			result.missing_files.append(file_path)
			print("ERROR: Core file missing: " + file_path)
		else:
			print("✓ Core file exists: " + file_path)

	# Check platform-specific helpers
	var android_helper_path = "res://addons/advanced_logger/utils/android_logger_helper.gd"
	if FileAccess.file_exists(android_helper_path):
		result.android_helper_exists = true
		print("✓ Android helper exists: " + android_helper_path)
	else:
		result.missing_files.append(android_helper_path)
		print("ERROR: Android helper missing: " + android_helper_path)

	var ios_helper_path = "res://addons/advanced_logger/utils/ios_logger_helper.gd"
	if FileAccess.file_exists(ios_helper_path):
		result.ios_helper_exists = true
		print("✓ iOS helper exists: " + ios_helper_path)
	else:
		result.missing_files.append(ios_helper_path)
		print("ERROR: iOS helper missing: " + ios_helper_path)

	# Check configuration file
	var config_path = "res://addons/advanced_logger/settings.cfg"
	if FileAccess.file_exists(config_path):
		print("✓ Config file exists: " + config_path)
	else:
		print("WARNING: Config file missing from res:// path. This is expected on mobile platforms.")

		# Check for user:// config on mobile platforms
		if OS.get_name() == "Android" or OS.get_name() == "iOS":
			var user_config_path = "user://advanced_logger_settings.cfg"
			if FileAccess.file_exists(user_config_path):
				print("✓ Mobile config file exists: " + user_config_path)
			else:
				print("ERROR: Mobile config file missing: " + user_config_path)
				result.missing_files.append(user_config_path)

	# Print summary
	print("\nVerification Summary:")
	print("Platform: " + OS.get_name())
	print("Core files exist: " + str(result.core_files_exist))
	print("Android helper exists: " + str(result.android_helper_exists))
	print("iOS helper exists: " + str(result.ios_helper_exists))

	if result.missing_files.size() > 0:
		print("Missing files: " + str(result.missing_files))
	else:
		print("All required files are present!")

	print("=== End Export Verification ===\n")

	return result

## Run at runtime to verify export integrity
static func runtime_verification() -> void:
	# This function should be called from a script that runs on startup
	# For example, in the _ready() function of your main scene
	var result = verify_files_exist()

	print("Advanced Logger Runtime Verification")

	# Check if Log singleton exists and works
	if Engine.has_singleton("Log") or is_instance_valid(Log):
		result.logger_functional = true
		print("✓ Log singleton is accessible")
	else:
		print("ERROR: Log singleton is not accessible")

	# Platform-specific verification
	if OS.get_name() == "iOS":
		if result.ios_helper_exists:
			print("iOS helper verified - Advanced Logger should work correctly on iOS")
		else:
			print("WARNING: iOS helper missing in standard location, but may be included elsewhere")

		# Check if iOS loader autoload exists
		if Engine.has_singleton("LoggerIOSLoader"):
			print("✓ iOS Loader autoload is registered")
		else:
			print("WARNING: iOS Loader autoload not registered")
	elif OS.get_name() == "Android":
		if result.android_helper_exists:
			print("Android helper verified - Advanced Logger should work correctly on Android")
		else:
			print("WARNING: Android helper missing in standard location, but may be included elsewhere")

	# Test logger functionality regardless of file presence
	# This is the ultimate test - if logging works, the files must be there somewhere!
	if Engine.has_singleton("Log"):
		# Safe way to test if Log is available and functional
		Log.debug("Export verification test - Debug message")
		Log.info("Export verification test - Info message")
		Log.warning("Export verification test - Warning message")
		print("✓ Logger functionality verified!")
		result.logger_functional = true
	else:
		print("ERROR: Logger functionality test failed!")
		result.logger_functional = false
