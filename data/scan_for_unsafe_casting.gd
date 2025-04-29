extends SceneTree

# A script to find potentially unsafe type casting in GDScript files
# Run with: godot --headless --script scan_for_unsafe_casting.gd [directory]

func _init() -> void:
	print("Looking for potentially unsafe 'as' type casting patterns...")
	
	var args = OS.get_cmdline_args()
	var search_dir = "."  # Default to current directory
	
	if args.size() > 0:
		search_dir = args[0]
	
	print("Searching in directory: " + search_dir)
	var files = find_gdscript_files(search_dir)
	
	print("Found %d GDScript files to analyze" % files.size())
	scan_files_for_unsafe_patterns(files)
	
	quit()

func find_gdscript_files(path: String) -> Array:
	var files = []
	var dir = DirAccess.open(path)
	
	if not dir:
		push_error("Failed to open directory: " + path)
		return files
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = path + "/" + file_name
		
		if dir.current_is_dir() and not file_name.begins_with("."):
			# Recursively search subdirectories
			files.append_array(find_gdscript_files(full_path))
		elif file_name.ends_with(".gd"):
			files.append(full_path)
			
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return files

func scan_files_for_unsafe_patterns(files: Array) -> void:
	var total_issues = 0
	
	for file_path in files:
		var issues = scan_file(file_path)
		total_issues += issues
	
	print("\nScan complete. Found %d potential unsafe type casting issues." % total_issues)
	
	if total_issues > 0:
		print("\nRecommended safe alternatives:")
		print("1. Use 'is' to check type before accessing: 'if node is Node2D:'")
		print("2. Use assertions: 'assert(node is Node2D, \"Expected Node2D\")'")
		print("3. Use 'is not' for early returns: 'if node is not Node2D: return'")
		print("4. Create properly typed variables after checking: 'var typed_node: Node2D = node'")

func scan_file(file_path: String) -> int:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open file: " + file_path)
		return 0
	
	var content = file.get_as_text()
	var lines = content.split("\n")
	var issues = 0
	
	# Define patterns to look for
	var as_pattern = " as "
	var null_check_after_as_pattern = "if\\s+[not]*\\s*\\w+\\s*[:|=|==|!=|<>]"
	
	for i in range(lines.size()):
		var line = lines[i]
		var line_num = i + 1
		
		# Look for direct 'as' usage
		if line.find(as_pattern) != -1 and not line.strip_edges().begins_with("#"):
			print("\nPotential unsafe cast in %s (line %d):" % [file_path, line_num])
			print("  " + line.strip_edges())
			issues += 1
			
			# Check for null checks after the cast
			if i < lines.size() - 1:
				var next_line = lines[i + 1]
				if next_line.match(null_check_after_as_pattern):
					print("  Found null check after cast (line %d):" % (line_num + 1))
					print("  " + next_line.strip_edges())
					print("  Consider using 'is' instead of 'as' followed by null check.")
			
			# Suggest safer alternatives based on context
			suggest_safer_alternative(line)
	
	return issues

func suggest_safer_alternative(line: String) -> void:
	var as_pos = line.find(" as ")
	if as_pos == -1:
		return
	
	var before_as = line.substr(0, as_pos).strip_edges()
	var after_as = line.substr(as_pos + 4).strip_edges()
	
	# Try to extract the variable and type
	var variable_name = ""
	var variable_type = after_as
	
	if before_as.find("=") != -1:
		var parts = before_as.split("=")
		variable_name = parts[0].strip_edges()
		if variable_name.find(":") != -1:
			variable_name = variable_name.split(":")[0].strip_edges()
	else:
		variable_name = before_as
	
	if variable_name.find("var ") != -1:
		variable_name = variable_name.replace("var ", "").strip_edges()
	
	# Print safer alternative
	print("  Safer alternative:")
	print("  if %s is %s:" % [variable_name.split(" ")[-1], variable_type])
	print("      var safe_%s: %s = %s" % [variable_name.split(" ")[-1], variable_type, variable_name.split(" ")[-1]])
	print("      # Use safe_%s here" % variable_name.split(" ")[-1])
