extends Node

## Test script for the cache manager and TTL functionality
## Add to a scene and run in the editor to test

# Reference to cache manager
var cache_manager: CacheManager

func _ready() -> void:
	print("Starting Cache Manager Tests")
	print("--------------------------")
	
	# Create cache manager with 5-second TTL
	cache_manager = CacheManager.new(5)
	print("Cache manager initialized with TTL: ", cache_manager.default_ttl)
	
	# Run tests
	test_basic_functionality()
	test_ttl_functionality()
	test_statistics()
	
	print("\n--------------------------")
	print("Cache Manager Tests Complete")

func test_basic_functionality() -> void:
	print("\nTesting Basic Functionality:")
	
	# Test setting values
	cache_manager.set("test_key1", "test_value1")
	cache_manager.set("test_key2", {"name": "Test Object", "value": 42})
	cache_manager.set("test_key3", [1, 2, 3, 4, 5])
	
	# Test getting values
	print("test_key1: ", cache_manager.get("test_key1"))
	print("test_key2: ", cache_manager.get("test_key2"))
	print("test_key3: ", cache_manager.get("test_key3"))
	
	# Test has
	print("Has test_key1: ", cache_manager.has("test_key1"))
	print("Has non_existent_key: ", cache_manager.has("non_existent_key"))
	
	# Test default value
	print("Non-existent key with default: ", cache_manager.get("non_existent_key", "default_value"))
	
	# Test remove
	var removed: bool = cache_manager.remove("test_key1")
	print("Removed test_key1: ", removed)
	print("Has test_key1 after removal: ", cache_manager.has("test_key1"))
	
	# Test clear
	cache_manager.clear()
	print("After clear, has test_key2: ", cache_manager.has("test_key2"))
	print("After clear, has test_key3: ", cache_manager.has("test_key3"))

func test_ttl_functionality() -> void:
	print("\nTesting TTL Functionality:")
	
	# Set values with different TTLs
	cache_manager.set("ttl_default", "Default TTL")  # Uses default 5 seconds
	cache_manager.set("ttl_10", "10-second TTL", 10)  # 10 seconds TTL
	cache_manager.set("ttl_0", "No expiration", 0)  # Never expires
	
	print("Initial values set with TTLs")
	print("ttl_default: ", cache_manager.get("ttl_default"))
	print("ttl_10: ", cache_manager.get("ttl_10"))
	print("ttl_0: ", cache_manager.get("ttl_0"))
	
	# Wait for 6 seconds (just past default TTL)
	print("Waiting 6 seconds for TTL expiration...")
	await get_tree().create_timer(6.0).timeout
	
	# Check values after default TTL
	print("\nAfter default TTL (5s):")
	print("ttl_default (should be expired): ", cache_manager.has("ttl_default"))
	print("ttl_10 (should still exist): ", cache_manager.has("ttl_10"))
	print("ttl_0 (should never expire): ", cache_manager.has("ttl_0"))
	
	# Wait 5 more seconds (past 10s TTL)
	print("Waiting 5 more seconds...")
	await get_tree().create_timer(5.0).timeout
	
	# Check values after 10s TTL
	print("\nAfter 10s TTL:")
	print("ttl_10 (should be expired): ", cache_manager.has("ttl_10"))
	print("ttl_0 (should never expire): ", cache_manager.has("ttl_0"))
	
	# Test clear_expired
	cache_manager.set("ttl_expired1", "Will expire", 1)
	cache_manager.set("ttl_expired2", "Will expire too", 1)
	print("\nWaiting 2 seconds for new entries to expire...")
	await get_tree().create_timer(2.0).timeout
	
	var removed_count: int = cache_manager.clear_expired()
	print("Cleared expired entries: ", removed_count)

func test_statistics() -> void:
	print("\nTesting Cache Statistics:")
	
	# Clear cache and add test entries
	cache_manager.clear()
	
	# Add entries with different TTLs
	cache_manager.set("stat_1", "Entry 1", 60)  # 1 minute TTL
	cache_manager.set("stat_2", "Entry 2", 300)  # 5 minutes TTL
	cache_manager.set("stat_3", "Entry 3", 0)  # Never expires
	cache_manager.set("stat_4", "Entry 4")  # Default TTL
	cache_manager.set("stat_5", "Entry 5", 1)  # 1 second TTL
	
	# Wait for the 1-second TTL to expire
	await get_tree().create_timer(2.0).timeout
	
	# Get and print statistics
	var stats: Dictionary = cache_manager.get_stats()
	print("Total entries: ", stats.total_entries)
	print("Expired entries: ", stats.expired_entries)
	print("TTL entries: ", stats.ttl_entries)
	print("Never expire entries: ", stats.never_expire_entries)
	
	# Test with some updated values
	cache_manager.set("stat_1", "Updated Entry 1", 120)  # Updated TTL
	stats = cache_manager.get_stats()
	print("\nAfter update:")
	print("Total entries: ", stats.total_entries)
	print("TTL entries: ", stats.ttl_entries)
