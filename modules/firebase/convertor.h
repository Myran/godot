#ifndef FirebaseConvertor_h
#define FirebaseConvertor_h

#include "core/object/ref_counted.h"
#include "functions.h"
#include "firebase.h"
#include "firebase/variant.h"

class Convertor {
    public:
    static Variant fromFirebaseVariant(const firebase::Variant& arg);
    static firebase::Variant toFirebaseVariant(const Dictionary& arg);
    static firebase::Variant toFirebaseVariant(const String& arg);

};

#endif // FirebaseConvertor_h
