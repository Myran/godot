@tool
extends Node
class_name TestTagManagerMoveTags

# This test validates the tag movement functionality in TagManager
# which is a core function that has been refactored from Logger/LoggerDock

var TagManager = preload("res://addons/advanced_logger/tag_manager.gd")

func _ready():
    print("\n=== Running TagManager Move Tags Tests ===")
    test_move_tag_basic()
    test_move_tag_edge_cases()
    print("=== TagManager Move Tags Tests Complete ===\n")

func test_move_tag_basic():
    print("\nTesting basic tag movement:")
    
    # Test moving from active to ignored
    var available_tags: Array[String] = ["tag1", "tag2", "tag3"]
    var active_tags: Array[String] = ["tag1"]
    var ignored_tags: Array[String] = []
    
    var result = TagManager.move_tag(
        "tag1",
        "active",
        "ignored",
        available_tags,
        active_tags,
        ignored_tags
    )
    
    var success = result.active_tags.size() == 0 && result.ignored_tags.size() == 1 && result.ignored_tags[0] == "tag1"
    print("- Move from active to ignored: %s" % ("✓" if success else "✗"))
    
    # Test moving from available to active
    available_tags = ["tag1", "tag2", "tag3"]
    active_tags = []
    ignored_tags = []
    
    result = TagManager.move_tag(
        "tag2",
        "available",
        "active",
        available_tags,
        active_tags,
        ignored_tags
    )
    
    success = result.active_tags.size() == 1 && result.active_tags[0] == "tag2" && result.ignored_tags.size() == 0
    print("- Move from available to active: %s" % ("✓" if success else "✗"))
    
    # Test moving from ignored to available
    available_tags = ["tag1", "tag2", "tag3"]
    active_tags = []
    ignored_tags = ["tag3"]
    
    result = TagManager.move_tag(
        "tag3",
        "ignored",
        "available",
        available_tags,
        active_tags,
        ignored_tags
    )
    
    success = result.ignored_tags.size() == 0 && result.active_tags.size() == 0
    print("- Move from ignored to available: %s" % ("✓" if success else "✗"))
    
    print("Basic tag movement test: %s" % ("PASSED" if success else "FAILED"))

func test_move_tag_edge_cases():
    print("\nTesting edge cases:")
    
    # Test invalid tag
    var available_tags: Array[String] = ["tag1", "tag2", "tag3"]
    var active_tags: Array[String] = ["tag1"]
    var ignored_tags: Array[String] = []
    
    var result = TagManager.move_tag(
        "",
        "active",
        "ignored",
        available_tags,
        active_tags,
        ignored_tags
    )
    
    var success = result.active_tags.size() == 1 && result.active_tags[0] == "tag1" && result.ignored_tags.size() == 0
    print("- Invalid tag not moved: %s" % ("✓" if success else "✗"))
    
    # Test same source and target
    result = TagManager.move_tag(
        "tag1",
        "active",
        "active",
        available_tags,
        active_tags,
        ignored_tags
    )
    
    success = result.active_tags.size() == 1 && result.active_tags[0] == "tag1" && result.ignored_tags.size() == 0
    print("- Same source and target: %s" % ("✓" if success else "✗"))
    
    # Test tag not in source
    result = TagManager.move_tag(
        "tag2",
        "active",
        "ignored",
        available_tags,
        active_tags,
        ignored_tags
    )
    
    success = result.active_tags.size() == 1 && result.active_tags[0] == "tag1" && result.ignored_tags.size() == 0
    print("- Tag not in source: %s" % ("✓" if success else "✗"))
    
    # Test tag already in target
    active_tags = ["tag1"]
    ignored_tags = ["tag2"]
    
    result = TagManager.move_tag(
        "tag2",
        "active",
        "ignored",
        available_tags,
        active_tags,
        ignored_tags
    )
    
    success = result.active_tags.size() == 1 && result.active_tags[0] == "tag1" && result.ignored_tags.size() == 1 && result.ignored_tags[0] == "tag2"
    print("- Tag already in target: %s" % ("✓" if success else "✗"))
    
    print("Edge cases test: %s" % ("PASSED" if success else "FAILED"))
