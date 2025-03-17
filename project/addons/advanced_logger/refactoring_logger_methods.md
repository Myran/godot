# Logger Method Refactoring

## Overview

This document outlines the changes made to reduce method size and complexity in the Logger class as part of Phase 4 of the Advanced Logger improvement plan.

## Changes Made

### 1. Improved Logging Flow

1. **Message Validation**:
   - Extracted message validation to `_validate_message()`
   - Centralized empty message checking

2. **Level Filtering**:
   - Extracted level filtering to `_should_show_level()`
   - Added clear level validation with `_is_valid_level()`
   - Simplified control flow in the `_log()` method

3. **Source Information Extraction**:
   - Broke down `_get_source_info()` into smaller functions:
     - `_create_default_source_info()` - Creates the initial structure
     - `_find_non_logger_frame()` - Handles stack trace analysis
     - `_update_source_info_from_frame()` - Extracts data from a frame

### 2. Tag Management Improvements

1. **Unified Tag Handling**:
   - Created shared helper method `_add_tag_to_category()`
   - Extracted common tag movement code to `_move_tag_between_categories()`
   - Added `_create_available_tags_list()` for consistent tag list building

2. **Configuration Updates**:
   - Added dedicated methods for config updates:
     - `_update_active_tags_in_config()`
     - `_update_ignored_tags_in_config()`
   - Added `_update_format_setting()` to handle format setting changes

### 3. General Improvements

1. **Method Length Reduction**:
   - Most methods are now under 20 lines
   - Each method has a single responsibility
   - Improved method naming for clarity

2. **Better Error Handling**:
   - More specific validation and error detection
   - Improved error messages for easier debugging
   - Consistent error return values

3. **Documentation**:
   - Added or improved method documentation
   - Clarified parameter requirements
   - Enhanced return value documentation

## Comparison

### _log() Method

**Before:**
```gdscript
func _log(level: LogLevel, message: String, context: Dictionary, tags: Array[String]) -> void:
	# Skip if level filtering prevents this message
	if level < _current_level:
		return

	# Validate tags and check if we should show the message
	var validated_tags := _validate_tags(tags)
	if not _should_show_tags(validated_tags):
		return

	# Get source information and output the log
	var source_info := _get_source_info()
	_output_log(level, message, context, validated_tags, source_info)
```

**After:**
```gdscript
func _log(level: LogLevel, message: String, context: Dictionary, tags: Array[String]) -> void:
	# Skip if level filtering prevents this message
	if !_should_show_level(level):
		return

	# Validate tags and check if we should show the message
	var validated_tags := _validate_tags(tags)
	if !_should_show_tags(validated_tags):
		return

	# Get source information and output the log
	var source_info := _get_source_info()
	_output_log(level, message, context, validated_tags, source_info)
```

### _get_source_info() Method

**Before:**
```gdscript
func _get_source_info() -> Dictionary:
	var source_info: Dictionary = {"file": "unknown", "line": 0, "function": "unknown"}

	const FILE_KEY: String = "file"
	const LINE_KEY: String = "line"
	const FUNCTION_KEY: String = "function"
	const SOURCE_KEY: String = "source"

	var stack: Array = get_stack()
	if stack.is_empty():
		return source_info

	# Find the first stack frame that is NOT from the logger itself
	for frame in stack:
		if not frame.has(SOURCE_KEY):
			continue

		var source: String = frame.get(SOURCE_KEY)
		if not source.ends_with("logger.gd"):
			source_info[FILE_KEY] = source
			source_info[LINE_KEY] = int(frame.get(LINE_KEY, 0))
			source_info[FUNCTION_KEY] = String(frame.get(FUNCTION_KEY, "unknown"))
			break

	return source_info
```

**After:**
```gdscript
func _get_source_info() -> Dictionary:
	var source_info := _create_default_source_info()
	var stack := get_stack()
	
	if stack.is_empty():
		return source_info
		
	var frame := _find_non_logger_frame(stack)
	if frame != null:
		_update_source_info_from_frame(source_info, frame)
		
	return source_info

func _create_default_source_info() -> Dictionary:
	return {
		"file": "unknown",
		"line": 0,
		"function": "unknown"
	}

func _find_non_logger_frame(stack: Array) -> Dictionary:
	const SOURCE_KEY: String = "source"
	
	for frame in stack:
		if not frame.has(SOURCE_KEY):
			continue

		var source: String = frame.get(SOURCE_KEY)
		if not source.ends_with("logger.gd"):
			return frame
			
	return {}

func _update_source_info_from_frame(source_info: Dictionary, frame: Dictionary) -> void:
	const FILE_KEY: String = "file"
	const LINE_KEY: String = "line"
	const FUNCTION_KEY: String = "function"
	const SOURCE_KEY: String = "source"
	
	if frame.has(SOURCE_KEY):
		source_info[FILE_KEY] = frame.get(SOURCE_KEY)
	
	if frame.has(LINE_KEY):
		source_info[LINE_KEY] = int(frame.get(LINE_KEY, 0))
		
	if frame.has(FUNCTION_KEY):
		source_info[FUNCTION_KEY] = String(frame.get(FUNCTION_KEY, "unknown"))
```

### Tag Management Methods

**Before:**
```gdscript
func add_tag(tag: String) -> Error:
	if not TagManager.is_valid_tag(tag):
		push_warning("Cannot add invalid tag: '%s'" % tag)
		return Error.FAILED

	# Track available tags to ensure the tag is included
	var available_tags = [tag]
	if not _active_tags.is_empty() or not _ignored_tags.is_empty():
		# If we have existing tags, create a more complete available list
		available_tags = []
		available_tags.append_array(_active_tags)
		available_tags.append_array(_ignored_tags)
		available_tags.append(tag)

	# Use TagManager for moving tag to active list
	var result = TagManager.move_tag(
		tag,
		"available", # Source doesn't matter since we're adding the tag anyway
		"active",
		available_tags,
		_active_tags,
		_ignored_tags
	)

	# Update tags
	_active_tags = result.active_tags
	_ignored_tags = result.ignored_tags

	# Update both tag lists in config if available
	if _config != null:
		_config.set_active_tags(_active_tags)
		_config.set_ignored_tags(_ignored_tags)

	return OK
```

**After:**
```gdscript
func add_tag(tag: String) -> Error:
	# Use the new helper method for tag operations
	return _add_tag_to_category(tag, "active")

func _add_tag_to_category(tag: String, category: String) -> Error:
	if !_is_valid_tag(tag):
		push_warning("Cannot add invalid tag: '%s'" % tag)
		return Error.FAILED

	# Use the shared tag moving logic
	var update_result = _move_tag_between_categories(tag, "available", category)
	if update_result == OK:
		# Update config based on the category
		if category == "active":
			_update_active_tags_in_config()
			_update_ignored_tags_in_config()
		elif category == "ignored":
			_update_ignored_tags_in_config()
			_update_active_tags_in_config()
	
	return update_result

func _move_tag_between_categories(tag: String, from_category: String, to_category: String) -> Error:
	# Create available tags list that includes all currently known tags
	var available_tags := _create_available_tags_list(tag)
	
	# Use TagManager for moving tag between categories
	var result = TagManager.move_tag(
		tag,
		from_category,
		to_category,
		available_tags,
		_active_tags,
		_ignored_tags
	)

	# Update tags from the result
	_active_tags = result.active_tags
	_ignored_tags = result.ignored_tags
	
	return OK
```

## Benefits

1. **Improved Readability**:
   - Methods now have clearer names and purposes
   - Logic flow is more intuitive
   - Consistent coding style

2. **Better Maintainability**:
   - Smaller methods are easier to understand and modify
   - Single responsibilities make changes more predictable
   - Reduced duplication makes updates simpler

3. **Enhanced Testability**:
   - Smaller functions can be tested in isolation
   - More focused test cases with clearer expectations
   - Easier to mock dependencies

4. **Improved Error Handling**:
   - More specific validation checks
   - Better error messages
   - Consistent error handling patterns

## Next Steps

1. **Integration with ILogger Interface**:
   - Ensure compatibility with ILogger interface
   - Update documentation to reflect changes

2. **Performance Optimization**:
   - Profile the logger to identify any performance bottlenecks
   - Optimize frequently called methods

3. **Additional Testing**:
   - Add more edge case tests
   - Test with large-scale applications
   - Add integration tests with real-world scenarios

## Conclusion

The Logger class has been significantly improved by reducing method size and complexity. The code is now more maintainable, testable, and readable, while preserving all existing functionality. The changes follow SOLID principles and software engineering best practices.
