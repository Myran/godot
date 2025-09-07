# Copyright (c) 2019-2023 Krayon
# Copyright (c) 2018 Calvin Ikenberry.


@tool
extends EditorPlugin

const SHORTCUT_SCANCODE = KEY_E
const SHORTCUT_MODIFIERS = KEY_MASK_CTRL

const USE_EXTERNAL_EDITOR_SETTING = "text_editor/external/use_external_editor"
const EXEC_PATH_SETTING = "text_editor/external/exec_path"
const EXEC_FLAGS_SETTING = "text_editor/external/exec_flags"

var godot_version

var script_editor
var editor_settings
var button

var shortcut: InputEventShortcut = InputEventShortcut.new()


func _get_plugin_name() -> String:
	return "Open External Editor"


func _enter_tree() -> void:
	godot_version = Engine.get_version_info()
	if godot_version["major"] < 4:
		print(
			'This version of the "Open External Editor" plugin requires Godot 4.0 or higher.'
		)
		return
	script_editor = get_editor_interface().get_script_editor()
	editor_settings = get_editor_interface().get_editor_settings()
	var input_event: InputEventKey = InputEventKey.new()
	input_event.physical_keycode = SHORTCUT_SCANCODE
	if SHORTCUT_MODIFIERS & KEY_MASK_ALT:
		input_event.alt = true
	if OS.has_feature("OSX") or OS.has_feature("iOS"):
		if SHORTCUT_MODIFIERS & KEY_MASK_CMD_OR_CTRL:
			input_event.set_cmd_pressed(true)
	if SHORTCUT_MODIFIERS & KEY_MASK_CTRL:
		input_event.set_ctrl_pressed(true)
	if SHORTCUT_MODIFIERS & KEY_MASK_META:
		input_event.set_meta_pressed(true)
	if SHORTCUT_MODIFIERS & KEY_MASK_SHIFT:
		input_event.set_shift_pressed(true)

	var sc: Shortcut = Shortcut.new()
	sc.set_events([input_event])
	shortcut.set_shortcut(sc)

	button = Button.new()
	button.text = editor_settings.get_setting(EXEC_PATH_SETTING)
	if button.text.rfind("/") >= 0:
		button.text = button.text.right(button.text.length() - (button.text.rfind("/") + 1))
	if button.text == "":
		button.text = "Set Ext. Editor"
	button.tooltip_text = "Open script in external editor"
	if shortcut && shortcut.shortcut:
		button.tooltip_text += " (" + shortcut.shortcut.get_as_text() + ")"
	button.pressed.connect(self.open_external_editor)
	var vbox1 = script_editor.get_child(0)
	var hbox1 = vbox1.get_child(0)
	hbox1.add_child(button)


func _exit_tree() -> void:
	if button != null:
		button.free()


func _input(event: InputEvent) -> void:
	if (
		shortcut
		&& shortcut.shortcut
		&& shortcut.shortcut.matches_event(event)
		&& !event.pressed
		&& script_editor.is_visible_in_tree()
	):
		open_external_editor()


func open_external_editor() -> void:
	var use_external_editor: bool = editor_settings.get_setting(USE_EXTERNAL_EDITOR_SETTING)
	var exec_path: String = editor_settings.get_setting(EXEC_PATH_SETTING)
	var exec_flags: String = editor_settings.get_setting(EXEC_FLAGS_SETTING)
	if use_external_editor:
		return
	var args = parse_exec_flags(exec_flags)
	if exec_path == null:
		return
	OS.execute(exec_path, args)


func get_text_edit() -> Control:
	var vbox1 = script_editor.get_child(0)
	var hsplit1 = vbox1.get_child(1)
	var tab_cont1 = hsplit1.get_child(1)
	var tab_cont2 = tab_cont1.get_child(0)
	var current_script = script_editor.get_current_script()
	var open_scripts = script_editor.get_open_scripts()
	var i = 0
	for child in tab_cont2.get_children():
		if child.get_class() != "ScriptTextEditor":
			continue
		if current_script == open_scripts[i]:
			var editor = child.get_child(0)
			return editor.get_child(0).get_child(0)
		i += 1
	return null


func parse_exec_flags(flags: String) -> PackedStringArray:
	var text_edit = get_text_edit()
	if text_edit == null:
		printerr("Couldn't get TextEdit node")
		return PackedStringArray()
	var script: Script = script_editor.get_current_script()
	if script == null:
		return PackedStringArray()
	var project_path = ProjectSettings.globalize_path("res://")
	var script_path = ProjectSettings.globalize_path(script.resource_path)
	if script_path.is_empty():
		return PackedStringArray()
	var line = text_edit.get_caret_line() + 1
	var column = text_edit.get_caret_column() + 1
	flags = flags.replacen("{line}", str(max(1, line)))
	flags = flags.replacen("{col}", str(column))
	flags = flags.strip_edges().replace("\\\\", "\\")
	var args = PackedStringArray()
	var from = 0
	var num_chars = 0
	var inside_quotes = false
	for i in range(flags.length() + 1):
		if i == flags.length() || (!inside_quotes && flags[i] == " "):
			var arg = flags.substr(from, num_chars)
			arg = arg.replacen("{project}", project_path)
			arg = arg.replacen("{file}", script_path)
			args.push_back(arg)
			from = i + 1
			num_chars = 0
		elif flags[i] == '"' && (!i || flags[i - 1] != "\\"):
			if !inside_quotes:
				from += 1
			inside_quotes = !inside_quotes
		else:
			num_chars += 1
	return args
