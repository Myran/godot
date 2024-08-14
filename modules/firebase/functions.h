#ifndef FirebaseFunctions_h
#define FirebaseFunctions_h

#include "core/object/ref_counted.h"
//#include "functions.h"
#include "firebase.h"

class FirebaseFunctions : public RefCounted {
    GDCLASS(FirebaseFunctions, RefCounted);
    
    protected:
    static bool inited;
    static firebase::functions::Functions* functions;
    static void _bind_methods();

    public:
    
    FirebaseFunctions();
    void CallFunction(const String& function_name);
    void CallFunctionWithId(const String& function_name, const String& callback_id);
    void CallFunctionWithArg(const String& function_name, const Dictionary& params);
    void CallFunctionWithIdAndArg(const String& function_name, const String& callback_id, const Dictionary& params);

    void ProcessFunctionResult(const std::string& function_name, const firebase::Variant & data);
};

#endif // FirebaseFunctions_h
