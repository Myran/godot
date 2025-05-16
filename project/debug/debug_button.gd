class_name DebugButton
extends RefCounted
## Data container for debug menu buttons

## Signal emitted when a test passes
signal test_passed(result: Variant)
## Signal emitted when a test fails
signal test_failed(error: Variant)

## The callback to execute when the button is pressed
var callback: Callable = Callable()
## Whether this button represents a test function
var is_test: bool = false
## Category that this button belongs to
var category: String = ""
## Whether this is a category navigation button
var is_category: bool = false
## Subcategory name (if is_category is true)
var category_name: String = ""
## Button label/text
var text: String = ""
## Optional description
var description: String = ""
## Is this for mobile device
var is_mobile: bool = false
## Original button text
var original_text: String = ""


func _init(
	p_label: String,
	p_callback: Callable,
	p_is_test: bool = false,
	p_category: String = "",
	p_description: String = ""
) -> void:
	text = p_label
	original_text = p_label
	callback = p_callback
	is_test = p_is_test
	category = p_category
	description = p_description

	# Detect if we're on a mobile device
	is_mobile = OS.get_name() == "iOS" or OS.get_name() == "Android"


## Create a category navigation button
static func create_category_button(category_name: String, full_path: String) -> DebugButton:
	var button = DebugButton.new(category_name, Callable(), false)
	button.is_category = true
	button.category_name = category_name
	button.category = full_path
	return button


## Execute button's callback and handle result
func execute() -> Variant:
	if not callback.is_valid():
		Log.error("Debug button callback is invalid: " + text, {}, ["debug_menu"])
		return null

	return callback.call()


## Run the test function and return the result
func run_test() -> Array:
	# Execute the test (expects a tuple with [bool, Variant] format)
	var result

	# Handle the case where the callback might be async (awaitable)
	if callback.is_valid():
		result = callback.call()

		# If result is a Signal (meaning it's awaitable), return a placeholder
		# The actual caller should handle awaiting this correctly
		if result is Signal:
			Log.debug("Test returned a Signal (awaitable result)", {}, ["debug_menu"])
			return [false, {"awaiting": true, "message": "Test is running..."}]
	else:
		return [false, {"error": "Invalid callback", "details": "Callback is not valid"}]

	# Validate and standardize the result format
	var success: bool = false
	var payload: Variant = null

	if result is Array and result.size() == 2 and result[0] is bool:
		success = result[0]
		payload = result[1]
	else:
		success = false
		payload = {"error": "Invalid test result format", "details": str(result)}

	if success:
		test_passed.emit(payload)
	else:
		test_failed.emit(payload)

	return [success, payload]
