def can_build(env, platform):
	# Skip for editor - not needed in editor play mode
	# GDScript explicitly bypasses Firebase when OS.has_feature("editor")
	if env.get('target') == 'editor':
		return False

	# Build for export templates only (production features)
	if platform in ["android", "ios", "macos", "windows"]:
		return True
	return False

def configure(env):
 if (env['platform'] == 'android'):
	 pass
