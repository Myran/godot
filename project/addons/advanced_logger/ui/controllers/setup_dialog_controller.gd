@tool
class_name TagSetupDialogController
extends RefCounted
## Controller for managing setup dialogs
##
## Provides a centralized way to handle name input dialogs for
## saving and renaming tag setups.

# Signals
signal setup_saved(setup_name: String)
signal setup_renamed(old_name: String, new_name: String)

# UI Components
var _setup_name_dialog: ConfirmationDialog
var _setup_name_input: LineEdit

# Storage for rename operation
var _rename_old_name: String = ""
var _is_rename_mode: bool = false

# Initialize the controller
func _init() -> void:
	pass

# Setup UI components
func setup(setup_name_dialog: ConfirmationDialog, setup_name_input: LineEdit) -> void:
	_setup_name_dialog = setup_name_dialog
	_setup_name_input = setup_name_input
	
	# Connect signals
	_setup_name_dialog.confirmed.connect(_on_dialog_confirmed)

## Show save dialog
func show_save_dialog() -> void:
	_is_rename_mode = false
	_rename_old_name = ""
	
	_setup_name_input.text = ""
	_setup_name_dialog.title = "Save Tag Setup"
	_setup_name_dialog.dialog_text = "Enter a name for this tag setup:"
	_setup_name_dialog.popup_centered()
	_setup_name_input.grab_focus()

## Show rename dialog
func show_rename_dialog(old_name: String) -> void:
	_is_rename_mode = true
	_rename_old_name = old_name
	
	# Store the old name for later reference
	_setup_name_input.text = old_name
	_setup_name_dialog.title = "Rename Setup"
	_setup_name_dialog.dialog_text = ""  # Clear dialog text to avoid overlap
	_setup_name_dialog.popup_centered()
	_setup_name_input.grab_focus()

## Handle dialog confirmation
func _on_dialog_confirmed() -> void:
	var setup_name = _setup_name_input.text.strip_edges()
	if setup_name.is_empty():
		push_warning("Setup name cannot be empty")
		return
		
	if _is_rename_mode:
		if setup_name != _rename_old_name:
			setup_renamed.emit(_rename_old_name, setup_name)
	else:
		setup_saved.emit(setup_name)
