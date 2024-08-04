def can_build(env, platform):
 if platform == "android":
  return True
 if platform == "ios":
  return True
 return False

def configure(env):
 if (env['platform'] == 'android'):
	 pass
