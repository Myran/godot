class_name Utils extends RefCounted


## Gets the type name of an object, preferring script global names over built-in class names
static func get_type(obj: Object) -> StringName:
	var script : Variant = obj.get_script()
	var global_name : StringName = script.get_global_name() if script else StringName()
	return global_name if not global_name.is_empty() else StringName(obj.get_class())
