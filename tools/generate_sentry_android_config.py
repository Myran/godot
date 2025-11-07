#!/usr/bin/env python3
"""
Generate Sentry Android configuration from project.godot settings
"""

import os
import sys
from pathlib import Path

def read_project_godot():
    """Read project.godot and extract sentry/android settings"""
    project_path = Path(__file__).parent.parent
    godot_file = project_path / "project" / "project.godot"

    if not godot_file.exists():
        print(f"❌ project.godot not found at: {godot_file}")
        return None

    settings = {}
    current_section = None

    with open(godot_file, 'r') as f:
        for line in f:
            line = line.strip()

            # Skip comments and empty lines
            if not line or line.startswith(';'):
                continue

            # Section headers
            if line.startswith('[') and line.endswith(']'):
                current_section = line[1:-1]
                continue

            # Key=value pairs
            if '=' in line and current_section:
                key, value = line.split('=', 1)
                key = key.strip()
                value = value.strip().strip('"')  # Remove quotes if present

                # Store with full section path
                full_key = f"{current_section}/{key}"
                settings[full_key] = value

    return settings

def generate_sentry_plugin(settings):
    """Generate Sentry plugin content"""
    return 'id "io.sentry.android.gradle" version "5.12.2"'

def generate_sentry_metadata(settings):
    """Generate Sentry metadata from project settings"""
    # Base settings from sentry/android section
    base_prefix = "sentry/android/"

    # Default values if not in project.godot
    dsn = settings.get(f"{base_prefix}dsn", "")
    debug = settings.get(f"{base_prefix}debug", "true").lower() == "true"
    send_pii = settings.get(f"{base_prefix}send_default_pii", "true").lower() == "true"
    user_interaction = settings.get(f"{base_prefix}user_interaction_breadcrumbs", "true").lower() == "true"
    screenshot = settings.get(f"{base_prefix}attach_screenshot", "true").lower() == "true"
    view_hierarchy = settings.get(f"{base_prefix}attach_view_hierarchy", "true").lower() == "true"
    traces_rate = settings.get(f"{base_prefix}traces_sample_rate", "1.0")
    profiling_rate = settings.get(f"{base_prefix}profiling_session_sample_rate", "1.0")
    profiling_lifecycle = settings.get(f"{base_prefix}profiling_lifecycle", "trace")
    profiling_start = settings.get(f"{base_prefix}profiling_start_on_app_start", "true").lower() == "true"
    replay_error_rate = settings.get(f"{base_prefix}session_replay_error_sample_rate", "1.0")
    replay_session_rate = settings.get(f"{base_prefix}session_replay_session_sample_rate", "0.1")

    metadata_lines = [
        f'        <!-- Required: set your sentry.io project identifier (DSN) -->',
        f'        <meta-data android:name="io.sentry.dsn" android:value="{dsn}" />',
        '',
        f'        <!-- Add data like request headers, user ip address and device name -->',
        f'        <meta-data android:name="io.sentry.send-default-pii" android:value="{str(send_pii).lower()}" />',
        '',
        f'        <!-- enable automatic breadcrumbs for user interactions (clicks, swipes, scrolls) -->',
        f'        <meta-data android:name="io.sentry.traces.user-interaction.enable" android:value="{str(user_interaction).lower()}" />',
        f'        <!-- enable screenshot for crashes -->',
        f'        <meta-data android:name="io.sentry.attach-screenshot" android:value="{str(screenshot).lower()}" />',
        f'        <!-- enable view hierarchy for crashes -->',
        f'        <meta-data android:name="io.sentry.attach-view-hierarchy" android:value="{str(view_hierarchy).lower()}" />',
        '',
        f'        <!-- enable the performance API by setting a sample-rate, adjust in production env -->',
        f'        <meta-data android:name="io.sentry.traces.sample-rate" android:value="{traces_rate}" />',
        '',
        f'        <!-- Enable UI profiling, adjust in production env. This is evaluated only once per session -->',
        f'        <meta-data android:name="io.sentry.traces.profiling.session-sample-rate" android:value="{profiling_rate}" />',
        f'        <!-- Set profiling mode. For more info see https://docs.sentry.io/platforms/android/profiling/#enabling-ui-profiling -->',
        f'        <meta-data android:name="io.sentry.traces.profiling.lifecycle" android:value="{profiling_lifecycle}" />',
        f'        <!-- Enable profiling on app start. The app start profile will be stopped automatically when the app start root span finishes -->',
        f'        <meta-data android:name="io.sentry.traces.profiling.start-on-app-start" android:value="{str(profiling_start).lower()}" />',
        '',
        f'        <!-- record session replays for 100% of errors and 10% of sessions -->',
        f'        <meta-data android:name="io.sentry.session-replay.on-error-sample-rate" android:value="{replay_error_rate}" />',
        f'        <meta-data android:name="io.sentry.session-replay.session-sample-rate" android:value="{replay_session_rate}" />'
    ]

    return '\n'.join(metadata_lines)

def write_injection_files(settings):
    """Write the injection files with actual values from project settings"""
    project_path = Path(__file__).parent.parent

    # Generate plugin file
    plugin_content = generate_sentry_plugin(settings)
    plugin_file = project_path / "inject" / "sentry_plugin.gradle"

    # Generate metadata file
    metadata_content = generate_sentry_metadata(settings)
    metadata_file = project_path / "inject" / "sentry_metadata.xml"

    # Write files
    with open(plugin_file, 'w') as f:
        f.write(plugin_content)

    with open(metadata_file, 'w') as f:
        f.write(metadata_content)

    print(f"✅ Generated Sentry plugin: {plugin_file}")
    print(f"✅ Generated Sentry metadata: {metadata_file}")
    print(f"✅ Using DSN: {settings.get('sentry/android/dsn', 'NOT FOUND')}")

def main():
    """Main function"""
    print("🔧 Generating Sentry Android configuration from project.godot...")

    settings = read_project_godot()
    if settings is None:
        sys.exit(1)

    write_injection_files(settings)
    print("✅ Sentry Android configuration generated successfully!")

if __name__ == "__main__":
    main()