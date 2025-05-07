#include "convertor.h"
#include "core/string/print_string.h" // For print_line/itos

Variant Convertor::fromFirebaseVariant(const firebase::Variant& arg)
{
	if(arg.is_null()) {
		return Variant(); // Return NIL Variant
	} else if(arg.is_vector()) {
		const std::vector<firebase::Variant>& vector = arg.vector();
		Array arrRes; // Use Godot Array
		arrRes.resize(vector.size()); // Optional: pre-allocate
		for(int i = 0; i < vector.size(); i++) {
			arrRes[i] = fromFirebaseVariant(vector[i]);
		}
		return Variant(arrRes);
	} else if(arg.is_map()) {
		const std::map<firebase::Variant, firebase::Variant>& map = arg.map();
		Dictionary dictRes;
		for(std::map<firebase::Variant, firebase::Variant>::const_iterator i = map.begin(); i != map.end(); i++) {
			firebase::Variant first = i->first;
			firebase::Variant second = i->second;
			if (!first.is_string()) {
				print_line("[Convertor] Warning: Non-string key found in Firebase map, skipping.");
				continue;
			}
			// CORRECTED: Use String::utf8()
			String key = String::utf8(first.string_value());
			dictRes[key] = fromFirebaseVariant(second);
		}
		return Variant(dictRes);
	} else if(arg.is_int64()) {
		return Variant(arg.int64_value());
	} else if(arg.is_double()) {
		return Variant(arg.double_value());
	} else if(arg.is_bool()) {
		return Variant(arg.bool_value());
	} else if(arg.is_string()) {
		// CORRECTED: Use String::utf8()
		String str = String::utf8(arg.string_value());
		return Variant(str);
	} else {
		print_line(String("[Convertor] Warning: Unhandled Firebase Variant type: ") + arg.TypeName(arg.type()));
		return Variant(); // Return NIL for unknown types
	}
}

firebase::Variant Convertor::toFirebaseVariant(const String& arg)
{
	std::string tmp = arg.utf8().get_data(); // Use get_data() for const char*
	return firebase::Variant(tmp);
}

firebase::Variant Convertor::toFirebaseVariant(const Dictionary& arg)
{
	std::map<std::string, firebase::Variant> map; // Use std::string keys for Firebase map
	Array keys = arg.keys();
	for (int i = 0; i < keys.size(); ++i) {
		Variant key = keys[i];
		Variant val = arg[key];

		if (key.get_type() != Variant::STRING) {
			print_line(String("[Convertor] Warning: Dictionary key is not a String, skipping. Type: ") + Variant::get_type_name(key.get_type()));
			continue;
		}

		std::string key_utf8 = ((String)key).utf8().get_data();
		// CORRECTED: Use the general Variant converter
		firebase::Variant fval = toFirebaseVariant(val);

		if (!fval.is_null()) { // Only add if conversion was successful
			map[key_utf8] = fval;
		} else {
			 print_line(String("[Convertor] Warning: Could not convert dictionary value for key '") + String(key) + "'. Type: " + Variant::get_type_name(val.get_type()));
		}
	}
	return firebase::Variant(map);
}

// CORRECTED: Implementation for the general Variant converter
firebase::Variant Convertor::toFirebaseVariant(const Variant& arg)
{
	switch (arg.get_type()) {
		case Variant::NIL:
			return firebase::Variant::Null();
		case Variant::BOOL:
			return firebase::Variant(arg.operator bool());
		case Variant::INT:
			return firebase::Variant(static_cast<int64_t>(arg.operator int64_t()));
		case Variant::FLOAT:
			return firebase::Variant(static_cast<double>(arg.operator double()));
		case Variant::STRING:
			// Explicitly call the String overload
			return toFirebaseVariant(arg.operator String());
		case Variant::DICTIONARY:
			// Explicitly call the Dictionary overload
			return toFirebaseVariant(arg.operator Dictionary());
		case Variant::ARRAY: {
			Array arr = arg;
			std::vector<firebase::Variant> vec;
			vec.reserve(arr.size());
			for(int i=0; i<arr.size(); ++i) {
				// Recursively call this general function for array elements
				vec.push_back(toFirebaseVariant(arr[i]));
			}
			return firebase::Variant(vec);
		}
		// Add other conversions if necessary (Vector2, Color, etc.)
		default:
			print_error(String("[Convertor] Error: Unsupported Variant type for Firebase conversion: ") + Variant::get_type_name(arg.get_type()));
			return firebase::Variant::Null(); // Return Null for unsupported types
	}
}
