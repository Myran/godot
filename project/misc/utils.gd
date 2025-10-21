class_name Utils extends RefCounted


## Gets the type name of an object, preferring script global names over built-in class names
static func get_type(obj: Object) -> StringName:
	var script: Variant = obj.get_script()
	var global_name: StringName = script.get_global_name() if script else StringName()
	return global_name if not global_name.is_empty() else StringName(obj.get_class())


## Alias for get_type() - for when you know you have an Object
static func get_object_type(obj: Object) -> StringName:
	return get_type(obj)


## Safely gets the type name of a variant, handling null and non-Object values
static func get_variant_type(variant: Variant) -> String:
	if variant != null and variant is Object:
		var object: Object = variant
		return str(get_type(object))
	return "null"
