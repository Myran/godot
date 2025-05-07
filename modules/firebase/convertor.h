#ifndef FirebaseConvertor_h
#define FirebaseConvertor_h

#include "core/object/ref_counted.h"
#include "core/variant/variant.h"
#include "core/string/ustring.h"
#include "core/variant/dictionary.h"
#include "firebase/variant.h"
#include <vector>
#include <map>

class Convertor {
public:
	static Variant fromFirebaseVariant(const firebase::Variant& arg);
	static firebase::Variant toFirebaseVariant(const String& arg);
	static firebase::Variant toFirebaseVariant(const Dictionary& arg);
	// Declaration for the general Variant converter
	static firebase::Variant toFirebaseVariant(const Variant& arg);
};

#endif // FirebaseConvertor_h
