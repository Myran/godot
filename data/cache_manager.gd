class_name CacheManager
extends RefCounted

## Cache management utility class.
## Provides centralized cache management with TTL (time-to-live) functionality.

# Cache entry structure: { "data": Variant, "timestamp": int, "ttl": int }
var _cache: Dictionary = {}

# Default TTL for cache entries in seconds (0 = no expiration)
var default_ttl: int = 300  # 5 minutes

## Initialize the cache manager
## @param p_default_ttl Default TTL for cache entries (0 = no expiration)
func _init(p_default_ttl: int = 0) -> void:
	# If TTL is specified, use it, otherwise load from project settings
	if p_default_ttl > 0:
		default_ttl = p_default_ttl
	else:
		default_ttl = _get_project_setting("gametwo/data/cache_ttl_seconds", 300)
		
	Log.debug("CacheManager initialized", {
		"default_ttl": default_ttl,
		"instance_id": get_instance_id()
	}, [Log.TAG_CACHE])

## Set a cache entry
## @param key The cache key
## @param value The value to cache
## @param ttl Optional TTL in seconds, or 0 to use default
## @return void
func set(key: String, value: Variant, ttl: int = 0) -> void:
	var entry_ttl: int = ttl if ttl > 0 else default_ttl
	var timestamp: int = Time.get_unix_time_from_system()
	
	_cache[key] = {
		"data": value,
		"timestamp": timestamp,
		"ttl": entry_ttl
	}
	
	Log.debug("Cache entry set", {
		"key": key,
		"ttl": entry_ttl,
		"timestamp": timestamp,
		"instance_id": get_instance_id()
	}, [Log.TAG_CACHE])

## Get a cache entry
## @param key The cache key
## @param default_value The default value to return if key not found or expired
## @param force_refresh Whether to ignore TTL and return the value even if expired
## @return The cached value or default_value if not found or expired
func get(key: String, default_value: Variant = null, force_refresh: bool = false) -> Variant:
	# Check if the key exists in cache
	if not _cache.has(key):
		Log.debug("Cache miss - key not found", {
			"key": key,
			"instance_id": get_instance_id()
		}, [Log.TAG_CACHE])
		return default_value
	
	var entry: Dictionary = _cache[key]
	var current_time: int = Time.get_unix_time_from_system()
	var entry_age: int = current_time - entry.timestamp
	
	# Check if entry has expired (skip check if TTL is 0 or force_refresh is true)
	if not force_refresh and entry.ttl > 0 and entry_age > entry.ttl:
		Log.debug("Cache entry expired", {
			"key": key,
			"ttl": entry.ttl,
			"age": entry_age,
			"instance_id": get_instance_id()
		}, [Log.TAG_CACHE])
		
		# Remove expired entry
		_cache.erase(key)
		return default_value
	
	Log.debug("Cache hit", {
		"key": key,
		"ttl": entry.ttl,
		"age": entry_age,
		"instance_id": get_instance_id()
	}, [Log.TAG_CACHE])
	
	return entry.data

## Check if a cache entry exists and is valid
## @param key The cache key
## @param ignore_ttl Whether to ignore TTL and check only if the key exists
## @return True if the entry exists and is valid
func has(key: String, ignore_ttl: bool = false) -> bool:
	if not _cache.has(key):
		return false
	
	if ignore_ttl:
		return true
		
	var entry: Dictionary = _cache[key]
	var current_time: int = Time.get_unix_time_from_system()
	var entry_age: int = current_time - entry.timestamp
	
	# Check if entry has expired (if TTL is 0, entry never expires)
	if entry.ttl > 0 and entry_age > entry.ttl:
		return false
		
	return true

## Remove a cache entry
## @param key The cache key
## @return bool True if entry was removed, false if not found
func remove(key: String) -> bool:
	if _cache.has(key):
		_cache.erase(key)
		
		Log.debug("Cache entry removed", {
			"key": key,
			"instance_id": get_instance_id()
		}, [Log.TAG_CACHE])
		
		return true
		
	return false

## Clear all cache entries
## @return void
func clear() -> void:
	var entry_count: int = _cache.size()
	_cache.clear()
	
	Log.info("Cache cleared", {
		"entry_count": entry_count,
		"instance_id": get_instance_id()
	}, [Log.TAG_CACHE])

## Clear expired cache entries
## @return int Number of expired entries removed
func clear_expired() -> int:
	var expired_keys: Array = []
	var current_time: int = Time.get_unix_time_from_system()
	
	# Find all expired keys
	for key in _cache.keys():
		var entry: Dictionary = _cache[key]
		
		# Skip entries with TTL of 0 (never expire)
		if entry.ttl <= 0:
			continue
			
		var entry_age: int = current_time - entry.timestamp
		if entry_age > entry.ttl:
			expired_keys.append(key)
	
	# Remove all expired keys
	for key in expired_keys:
		_cache.erase(key)
	
	Log.info("Expired cache entries cleared", {
		"expired_count": expired_keys.size(),
		"remaining_count": _cache.size(),
		"instance_id": get_instance_id()
	}, [Log.TAG_CACHE])
	
	return expired_keys.size()

## Get cache statistics
## @return Dictionary with cache statistics
func get_stats() -> Dictionary:
	var total_entries: int = _cache.size()
	var expired_entries: int = 0
	var current_time: int = Time.get_unix_time_from_system()
	var ttl_entries: int = 0
	var never_expire_entries: int = 0
	var oldest_timestamp: int = current_time
	var newest_timestamp: int = 0
	
	# Calculate statistics
	for key in _cache.keys():
		var entry: Dictionary = _cache[key]
		
		# Count TTL vs non-TTL entries
		if entry.ttl <= 0:
			never_expire_entries += 1
		else:
			ttl_entries += 1
			
			# Check if expired
			var entry_age: int = current_time - entry.timestamp
			if entry_age > entry.ttl:
				expired_entries += 1
		
		# Track oldest and newest timestamps
		if entry.timestamp < oldest_timestamp:
			oldest_timestamp = entry.timestamp
		if entry.timestamp > newest_timestamp:
			newest_timestamp = entry.timestamp
	
	return {
		"total_entries": total_entries,
		"expired_entries": expired_entries,
		"ttl_entries": ttl_entries,
		"never_expire_entries": never_expire_entries,
		"oldest_timestamp": oldest_timestamp,
		"newest_timestamp": newest_timestamp,
		"default_ttl": default_ttl
	}

## Helper to get a project setting with fallback
## @param setting_name The name of the project setting
## @param default_value The default value if setting doesn't exist
## @return The setting value or default value
func _get_project_setting(setting_name: String, default_value: Variant) -> Variant:
	if ProjectSettings.has_setting(setting_name):
		return ProjectSettings.get_setting(setting_name)
	return default_value
