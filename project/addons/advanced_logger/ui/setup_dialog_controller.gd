@tool
class_name SetupDialogController
extends RefCounted
## Controller for tag setup dialog operations
##
## Manages the tag setup dialog UI and interactions,
## including saving and renaming tag setups.

signal setup_saved(setup_name: String)
signal setup_renamed(old_name: String, new_name: String)

# UI Components (set via setup method)
var _setup_name_dialog: ConfirmationDialog
var _setup_name_input: LineEdit

# Dependencies (injected in constructor)
var _config: ConfigManager
var _tag_list_controller: TagListController
var _setup_list_controller: SetupListController

# Current state for renaming
var _is_renaming: bool = false
var _rename_old_name: String = ""

# Constructor with dependency injection
func _init(
	config: ConfigManager, 
	tag_list_controller: TagListController,
	setup_list_controller: SetupListController
) -> void:
	_config = config
	_tag_list_controller = tag_list_controller
	_setup_list_controller = setup_list_controller

## Setup UI components - called by the main dock
func setup(
	setup_name_dialog: ConfirmationDialog,
	setup_name_input: LineEdit
) -> void:
	# Store references to UI components
	_setup_name_dialog = setup_name_dialog
	_setup_name_input = setup_name_input
	
	# Connect UI signals
	_setup_name_dialog.confirmed.connect(_on_setup_name_dialog_confirmed)

## Show the setup dialog for saving a new setup
func show_save_dialog() -> void:
	_is_renaming = false
	_rename_old_name = ""
	
	_setup_name_input.text = ""
	_setup_name_dialog.title = "Save Tag Setup"
	_setup_name_dialog.dialog_text = "Enter a name for this tag setup:"
	_setup_name_dialog.popup_centered()
	_setup_name_input.grab_focus()

## Show the rename dialog for an existing setup
func show_rename_dialog(old_name: String) -> void:
	_is_renaming = true
	_rename_old_name = old_name
	
	# Store the old name for later reference
	_setup_name_input.text = old_name
	_setup_name_dialog.title = "Rename Setup"
	_setup_name_dialog.dialog_text = ""  # Clear dialog text to avoid overlap
	
	_setup_name_dialog.popup_centered()
	_setup_name_input.grab_focus()

## Handle dialog confirmation - either save or rename
func _on_setup_name_dialog_confirmed() -> void:
	var setup_name = _setup_name_input.text.strip_edges()
	if setup_name.is_empty():
		push_warning("Setup name cannot be empty")
		return

	if _is_renaming:
		# Handle rename operation
		if setup_name != _rename_old_name:
			var result = _setup_list_controller.rename_setup(_rename_old_name, setup_name)
			if result != OK:
				push_error("Failed to rename setup: %s" % error_string(result))
			else:
				setup_renamed.emit(_rename_old_name, setup_name)
				print_rich("[color=#%s]Renamed tag setup: %s → %s[/color]" %
					[LoggerColors.SUCCESS_HTML, _rename_old_name, setup_name])
		
		# Reset state after operation
		_is_renaming = false
		_rename_old_name = ""
	else:
		# Handle save operation
		# Get current tags
		var tag_lists = _tag_list_controller.get_tag_lists()

		# Save the setup
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
