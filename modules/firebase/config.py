def can_build(env, platform):
 if platform == "android":
  return True
 if platform == "ios":
  return True
 if platform == "macos":
  return True
 if platform == "windows":
  return True
 return False

def configure(env):
 if (env['platform'] == 'android'):
	 pass
