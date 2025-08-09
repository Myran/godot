@tool
class_name SetupDialogController
extends RefCounted

signal setup_saved(setup_name: String)
signal setup_renamed(old_name: String, new_name: String)

var _setup_name_dialog: ConfirmationDialog
var _setup_name_input: LineEdit

var _config: ConfigManager
var _tag_list_controller: TagListController
var _setup_list_controller: SetupListController

var _is_renaming: bool = false
var _rename_old_name: String = ""

func _init(
	config: ConfigManager,
	tag_list_controller: TagListController,
	setup_list_controller: SetupListController
) -> void:
	_config = config
	_tag_list_controller = tag_list_controller
	_setup_list_controller = setup_list_controller

func setup(
	setup_name_dialog: ConfirmationDialog,
	setup_name_input: LineEdit
) -> void:
	_setup_name_dialog = setup_name_dialog
	_setup_name_input = setup_name_input

	_setup_name_dialog.confirmed.connect(_on_setup_name_dialog_confirmed)

func show_save_dialog() -> void:
	_is_renaming = false
	_rename_old_name = ""

	_setup_name_input.text = ""
	_setup_name_dialog.title = "Save Tag Setup"
	_setup_name_dialog.dialog_text = "Enter a name for this tag setup:"
	_setup_name_dialog.popup_centered()
	_setup_name_input.grab_focus()

func show_rename_dialog(old_name: String) -> void:
	_is_renaming = true
	_rename_old_name = old_name

	_setup_name_input.text = old_name
	_setup_name_dialog.title = "Rename Setup"
	_setup_name_dialog.dialog_text = ""  # Clear dialog text to avoid overlap

	_setup_name_dialog.popup_centered()
	_setup_name_input.grab_focus()

func _on_setup_name_dialog_confirmed() -> void:
	var setup_name = _setup_name_input.text.strip_edges()
	if setup_name.is_empty():
		push_warning("Setup name cannot be empty")
		return

	if _is_renaming:
		if setup_name != _rename_old_name:
			var result = _setup_list_controller.rename_setup(_rename_old_name, setup_name)
			if result != OK:
				push_error("Failed to rename setup: %s" % error_string(result))
			else:
				setup_renamed.emit(_rename_old_name, setup_name)
				print_rich("[color=#%s]Renamed tag setup: %s → %s[/color]" %
					[LoggerColors.SUCCESS_HTML, _rename_old_name, setup_name])

		_is_renaming = false
		_rename_old_name = ""
	else:
		var tag_lists = _tag_list_controller.get_tag_lists()

		var result = _setup_list_controller.save_setup(
			setup_name,
			tag_lists.active_tags,
			tag_lists.ignored_tags
		)

		if result != OK:
			push_error("Failed to save tag setup: %s" % error_string(result))
		else:
			setup_saved.emit(setup_name)
			print_rich("[color=#%s]Saved tag setup: %s[/color]" %
				[LoggerColors.SUCCESS_HTML, setup_name])
