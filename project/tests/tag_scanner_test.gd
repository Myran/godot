#!/usr/bin/env -S godot --headless --script
# Test file for demonstrating log tag scanning
extends SceneTree

func _init():
	print("Testing log tag usage...")
	
	# Tags in various formats for scanner to find
	Log.debug("Debug message", {}, ["ui", "debug"])
	Log.info("Info with tags", {"data": 123}, ["network", "system"])
	Log.warning("Warning message", {}, ["security", "network"])
	Log.error("Error occurred", {"code": 404}, ["api", "network"])
	Log.critical("Critical failure", {}, ["system", "database"])
	
	# Different formats
	Log.info("Different format", tags = ["formatting", "style"])
	
	print("Test complete")
	quit()
