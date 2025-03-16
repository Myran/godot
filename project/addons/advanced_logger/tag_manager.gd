@tool
class_name TagManager
extends RefCounted
## Centralized manager for tag operations in the Advanced Logger.
##
## Provides validation, filtering, categorization, and formatting of logger tags,
## eliminating duplication across the codebase. All tag-related operations
## should go through this class to ensure consistency.

## Validates a tag name is properly formatted
## 
## Tags must be non-empty strings and follow allowed naming conventions:
## - Cannot be empty
## - Must contain only alphanumeric characters, underscores, or hyphens
##
## Returns true if the tag is valid, false otherwise
static func is_valid_tag(tag) -> bool:
    # First, check if it's a String
    if not (tag is String):
        return false
    
    # Check if it's empty
    if tag.is_empty():
        return false

    # Enhanced validation - alphanumeric, underscores, hyphens only
    var regex = RegEx.new()
    regex.compile("^[a-zA-Z0-9_-]+$")
    return regex.search(tag) != null

## Validates an array of tags, returning only valid ones
## 
## Parameters:
## - tags: Array of tags to validate
##
## Returns an array containing only valid tags
static func validate_tags(tags: Array) -> Array[String]:
    var validated_tags: Array[String] = []
    for tag in tags:
        if is_valid_tag(tag):
            validated_tags.append(tag)
    return validated_tags

## Determines if a log with the specified tags should be shown
## 
## Parameters:
## - tags: Tags associated with the log message
## - active_tags: Tags that are actively being filtered for
## - ignored_tags: Tags that should cause a log to be hidden
##
## Returns true if the log should be shown, false otherwise
static func should_show_tags(tags: Array, active_tags: Array[String], ignored_tags: Array[String]) -> bool:
    # If tags are ignored, don't show
    for tag in tags:
        if tag is String and ignored_tags.has(tag):
            return false

    # If no active tags are set, show all logs
    if active_tags.is_empty():
        return true

    # If there are active tags but message has no tags, don't show
    if tags.is_empty():
        return false

    # Show if any message tag matches active tags
    for tag in tags:
        if tag is String and active_tags.has(tag):
            return true

    return false

## Moves a tag between categories
##
## Parameters:
## - tag: The tag to move
## - from_category: Source category ("available", "active", or "ignored")
## - to_category: Target category for the tag
## - available_tags: Array of all available tags
## - active_tags: Array of active filter tags
## - ignored_tags: Array of ignored filter tags
##
## Returns a dictionary with updated arrays: {available_tags, active_tags, ignored_tags}
static func move_tag(
    tag: String, 
    from_category: String, 
    to_category: String,
    available_tags: Array[String],
    active_tags: Array[String],
    ignored_tags: Array[String]
) -> Dictionary:
    if not is_valid_tag(tag) or from_category == to_category:
        return {
            "available_tags": available_tags,
            "active_tags": active_tags,
            "ignored_tags": ignored_tags
        }
    
    # Always ensure tag is in the available tags master list
    if not available_tags.has(tag):
        available_tags.append(tag)
    
    # Handle tag removal from source
    match from_category:
        "active", "SOURCE_ACTIVE":
            if active_tags.has(tag):
                active_tags.erase(tag)
        "ignored", "SOURCE_IGNORED":
            if ignored_tags.has(tag):
                ignored_tags.erase(tag)
    
    # Handle tag addition to target
    match to_category:
        "available", "SOURCE_AVAILABLE":
            # Remove from both filtered lists
            active_tags.erase(tag)
            ignored_tags.erase(tag)
        "active", "SOURCE_ACTIVE":
            ignored_tags.erase(tag)
            if not active_tags.has(tag):
                active_tags.append(tag)
        "ignored", "SOURCE_IGNORED":
            active_tags.erase(tag)
            if not ignored_tags.has(tag):
                ignored_tags.append(tag)
    
    return {
        "available_tags": available_tags,
        "active_tags": active_tags,
        "ignored_tags": ignored_tags
    }

## Formats a tag for display in the UI
## 
## Capitalizes the first letter of the tag for better readability
##
## Parameters:
## - tag: The tag to format
##
## Returns a formatted version of the tag
static func format_tag_for_display(tag: String) -> String:
    if tag.is_empty():
        return tag
    return tag.substr(0, 1).capitalize() + tag.substr(1)

## Filters a list of tags based on active and ignored tag rules
##
## Parameters:
## - all_tags: List of all tags to filter
## - active_tags: Tags that are actively being filtered for
## - ignored_tags: Tags that should be excluded
##
## Returns a filtered list of tags
static func filter_tags(all_tags: Array[String], active_tags: Array[String], ignored_tags: Array[String]) -> Array[String]:
    var filtered_tags: Array[String] = []
    
    for tag in all_tags:
        # Skip ignored tags
        if ignored_tags.has(tag):
            continue
            
        # If active tags are set, only include matching tags
        if not active_tags.is_empty():
            if active_tags.has(tag):
                filtered_tags.append(tag)
        else:
            # If no active tags set, include all non-ignored tags
            filtered_tags.append(tag)
    
    return filtered_tags

## Merges tags from multiple sources into a single unique list
##
## Parameters:
## - tag_arrays: Array of tag arrays to merge
##
## Returns a consolidated array with unique tags
static func merge_tags(tag_arrays: Array) -> Array[String]:
    var merged_tags: Array[String] = []
    
    for tag_array in tag_arrays:
        for tag in tag_array:
            if tag is String and is_valid_tag(tag) and not merged_tags.has(tag):
                merged_tags.append(tag)
    
    return merged_tags

## Sorts tags alphabetically
##
## Parameters:
## - tags: Array of tags to sort
##
## Returns the sorted array
static func sort_tags(tags: Array[String]) -> Array[String]:
    var sorted_tags = tags.duplicate()
    sorted_tags.sort()
    return sorted_tags
