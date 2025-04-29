extends SceneTree

## Test script for CacheManager functionality
## Run with --script parameter from command line

func _init():
	print("Starting Cache Manager Tests")
	print("--------------------------------")
	
	# Run the tests
	test_cache_manager()
	
	print("--------------------------------")
	print("All tests completed")
	quit()

func test_cache_manager():
	# Create a CacheManager with default TTL
	var cache_manager = CacheManager.new(10) # 10 seconds TTL
	
	print("\nTesting Basic Cache Operations:")
	
	# Test setting and getting values
	cache_manager.set("test_key", "test_value")
	var value = cache_manager.get("test_key")
	print("Set and get: ", value == "test_value")
	
	# Test has method
	var has_key = cache_manager.has("test_key")
	print("Has key: ", has_key)
	
	# Test has method with non-existent key
	has_key = cache_manager.has("non_existent_key")
	print("Has non-existent key: ", has_key)
	
	# Test get with default value
	var default_value = cache_manager.get("non_existent_key", "default")
	print("Get with default: ", default_value == "default")
	
	# Test overwriting a value
	cache_manager.set("test_key", "new_value")
	value = cache_manager.get("test_key")
	print("Overwrite value: ", value == "new_value")
	
	print("\nTesting TTL Functionality:")
	
	# Test setting with custom TTL
	cache_manager.set("short_ttl", "expires_quickly", 1) # 1 second TTL
	value = cache_manager.get("short_ttl")
	print("Set with custom TTL: ", value == "expires_quickly")
	
	# Wait for expiration
	print("Waiting for expiration...")
	await get_tree().create_timer(1.5).timeout
	
	# Check if expired
	has_key = cache_manager.has("short_ttl")
	print("Key expired: ", not has_key)
	
	print("\nTesting Cache Management:")
	
	# Fill cache with multiple entries
	for i in range(5):
		cache_manager.set("key_" + str(i), "value_" + str(i))
	
	# Get cache stats
	var stats = cache_manager.get_stats()
	print("Cache entry count: ", stats.entry_count)
	
	# Test clearing specific key
	cache_manager.remove("key_0")
	has_key = cache_manager.has("key_0")
	print("Removed specific key: ", not has_key)
	
	# Test clearing expired entries
	# Set some entries with expired TTL
	cache_manager.set("expired_1", "value", -1) # Already expired
	cache_manager.set("expired_2", "value", -1) # Already expired
	
	# Clear expired entries
	var removed_count = cache_manager.clear_expired()
	print("Cleared expired entries: ", removed_count >= 2)
	
	# Test complete clear
	cache_manager.clear()
	stats = cache_manager.get_stats()
	print("Cleared all entries: ", stats.entry_count == 0)
	
	print("\nTesting Complex Object Caching:")
	
	# Test with dictionary
	var dict_value = {
		"name": "Test Dictionary",
		"values": [1, 2, 3],
		"nested": {
			"property": "value"
		}
	}
	cache_manager.set("dict_key", dict_value)
	var retrieved_dict = cache_manager.get("dict_key")
	print("Dictionary caching: ", retrieved_dict.name == "Test Dictionary" and retrieved_dict.values.size() == 3)
	
	# Test with array
	var array_value = [1, "string", {"key": "value"}]
	cache_manager.set("array_key", array_value)
	var retrieved_array = cache_manager.get("array_key")
	print("Array caching: ", retrieved_array.size() == 3 and retrieved_array[1] == "string")