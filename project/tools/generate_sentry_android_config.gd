# Generate Sentry Android configuration from project settings
# Run with: godot --headless --script tools/generate_sentry_android_config.gd

extends SceneTree

func _ready():
	_generate_sentry_android_config()
	quit()

func _generate_sentry_android_config():
	print("🔧 Generating Sentry Android configuration from project settings...")

	# Read Sentry Android settings from project.godot
	# Based on project.godot structure: [sentry] android/dsn="..."
	var dsn = ProjectSettings.get_setting("sentry/android/dsn", "")

	print("=== SENTRY_CONFIG_SCRIPT: ProjectSettings access test ===")
	print("=== SENTRY_CONFIG_SCRIPT: Read DSN: ", dsn, " ===")

	# Fall back to hardcoded if empty
	if dsn == "":
		print("=== SENTRY_CONFIG_SCRIPT: DSN empty, using fallback ===")
		dsn = "https://3f084e8be7d8e0aa07d43789a5f410aa@o4510290068570112.ingest.de.sentry.io/4510290070011984"
	var debug = ProjectSettings.get_setting("sentry/android/debug", true)
	var send_pii = ProjectSettings.get_setting("sentry/android/send_default_pii", true)
	var user_interaction = ProjectSettings.get_setting("sentry/android/user_interaction_breadcrumbs", true)
	var screenshot = ProjectSettings.get_setting("sentry/android/attach_screenshot", true)
	var view_hierarchy = ProjectSettings.get_setting("sentry/android/attach_view_hierarchy", true)
	var traces_rate = ProjectSettings.get_setting("sentry/android/traces_sample_rate", "1.0")
	var profiling_rate = ProjectSettings.get_setting("sentry/android/profiling_session_sample_rate", "1.0")
	var profiling_lifecycle = ProjectSettings.get_setting("sentry/android/profiling_lifecycle", "trace")
	var profiling_start = ProjectSettings.get_setting("sentry/android/profiling_start_on_app_start", true)
	var replay_error_rate = ProjectSettings.get_setting("sentry/android/session_replay_error_sample_rate", "1.0")
	var replay_session_rate = ProjectSettings.get_setting("sentry/android/session_replay_session_sample_rate", "0.1")

	# Generate plugin content
	var plugin_content = 'id "io.sentry.android.gradle" version "5.12.2"'

	# Generate metadata content
	var metadata_lines = []
	metadata_lines.append('        <!-- Required: set your sentry.io project identifier (DSN) -->')
	metadata_lines.append('        <meta-data android:name="io.sentry.dsn" android:value="' + dsn + '" />')
	metadata_lines.append('')
	metadata_lines.append('        <!-- Add data like request headers, user ip address and device name -->')
	metadata_lines.append('        <meta-data android:name="io.sentry.send-default-pii" android:value="' + str(send_pii).to_lower() + '" />')
	metadata_lines.append('')
	metadata_lines.append('        <!-- enable automatic breadcrumbs for user interactions (clicks, swipes, scrolls) -->')
	metadata_lines.append('        <meta-data android:name="io.sentry.traces.user-interaction.enable" android:value="' + str(user_interaction).to_lower() + '" />')
	metadata_lines.append('        <!-- enable screenshot for crashes -->')
	metadata_lines.append('        <meta-data android:name="io.sentry.attach-screenshot" android:value="' + str(screenshot).to_lower() + '" />')
	metadata_lines.append('        <!-- enable view hierarchy for crashes -->')
	metadata_lines.append('        <meta-data android:name="io.sentry.attach-view-hierarchy" android:value="' + str(view_hierarchy).to_lower() + '" />')
	metadata_lines.append('')
	metadata_lines.append('        <!-- enable the performance API by setting a sample-rate, adjust in production env -->')
	metadata_lines.append('        <meta-data android:name="io.sentry.traces.sample-rate" android:value="' + str(traces_rate) + '" />')
	metadata_lines.append('')
	metadata_lines.append('        <!-- Enable UI profiling, adjust in production env. This is evaluated only once per session -->')
	metadata_lines.append('        <meta-data android:name="io.sentry.traces.profiling.session-sample-rate" android:value="' + str(profiling_rate) + '" />')
	metadata_lines.append('        <!-- Set profiling mode. For more info see https://docs.sentry.io/platforms/android/profiling/#enabling-ui-profiling -->')
	metadata_lines.append('        <meta-data android:name="io.sentry.traces.profiling.lifecycle" android:value="' + profiling_lifecycle + '" />')
	metadata_lines.append('        <!-- Enable profiling on app start. The app start profile will be stopped automatically when the app start root span finishes -->')
	metadata_lines.append('        <meta-data android:name="io.sentry.traces.profiling.start-on-app-start" android:value="' + str(profiling_start).to_lower() + '" />')
	metadata_lines.append('')
	metadata_lines.append('        <!-- record session replays for 100% of errors and 10% of sessions -->')
	metadata_lines.append('        <meta-data android:name="io.sentry.session-replay.on-error-sample-rate" android:value="' + str(replay_error_rate) + '" />')
	metadata_lines.append('        <meta-data android:name="io.sentry.session-replay.session-sample-rate" android:value="' + str(replay_session_rate) + '" />')

	var metadata_content = '\n'.join(metadata_lines)

	# Get absolute path to project root
	var project_root = ProjectSettings.globalize_path("res://../")
	print("=== SENTRY_CONFIG_SCRIPT: Project root path: ", project_root, " ===")

	var plugin_path = project_root + "inject/sentry_plugin.gradle"
	var metadata_path = project_root + "inject/sentry_metadata.xml"

	# Write plugin file
	var plugin_file = FileAccess.open(plugin_path, FileAccess.WRITE)
	if plugin_file:
		plugin_file.store_string(plugin_content)
		plugin_file.close()
		print("✅ Generated Sentry plugin: inject/sentry_plugin.gradle")
		print("   Path: ", plugin_path)
	else:
		print("❌ Failed to create plugin file")

	# Write metadata file
	var metadata_file = FileAccess.open(metadata_path, FileAccess.WRITE)
	if metadata_file:
		metadata_file.store_string(metadata_content)
		metadata_file.close()
		print("✅ Generated Sentry metadata: inject/sentry_metadata.xml")
		print("   Path: ", metadata_path)
	else:
		print("❌ Failed to create metadata file")

	print("✅ Sentry Android configuration generated successfully!")
	print("   DSN: ", dsn)