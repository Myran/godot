#ifndef FirebaseDatabase_h
#define FirebaseDatabase_h

#include "core/object/ref_counted.h"
#include "firebase/database.h"
#include "firebase.h"

class FirebaseDatabase;

class FirebaseChildListener : public firebase::database::ChildListener {
private:
    FirebaseDatabase *database;
public:
    FirebaseChildListener(FirebaseDatabase *db);
    void OnCancelled(const firebase::database::Error & error, const char *error_message);
    void OnChildAdded(const firebase::database::DataSnapshot & snapshot, const char *previous_sibling_key);
    void OnChildChanged(const firebase::database::DataSnapshot & snapshot, const char *previous_sibling_key);
    void OnChildMoved(const firebase::database::DataSnapshot & snapshot, const char *previous_sibling_key);
    void OnChildRemoved(const firebase::database::DataSnapshot & snapshot);
};

class FirebaseDatabase : public RefCounted {
    GDCLASS(FirebaseDatabase, RefCounted);
    
    protected:
    static bool inited;
    static firebase::database::Database *database;
    static firebase::database::DatabaseReference dbref;
    static FirebaseChildListener *listener;
    static void _bind_methods();

    //Variant ConvertVariant(const firebase::Variant& val);
    firebase::database::DatabaseReference GetReferenceToPath(const Array& keys);
    firebase::database::Query GetQueryFromReference(const firebase::database::DatabaseReference& ref, const Dictionary& query_params);

    public:
    
    FirebaseDatabase();
    ~FirebaseDatabase();
    void SetDBRoot(const Array& keys);
    void SetValue(const Array& keys, const Variant& value);
    String PushChild(const Array& keys);
    void UpdateChildren(const Array& paths, const Dictionary& params);
    void RemoveValue(const Array& keys);
    void GetValue(const Array& keys);
    void OnGetValue(const firebase::Future<firebase::database::DataSnapshot>& result, void* user_data);
    
    // New query functionality
    void QueryOrderedData(const Array& keys, const Dictionary& query_params);
    void OnQueryResult(const firebase::Future<firebase::database::DataSnapshot>& result, void* user_data);
    
    // Server timestamp
    void SetServerTimestamp(const Array& keys);
    
    // Transaction support - simplified to numeric increment
    void RunTransaction(const Array& keys, int increment_by = 1);
    void OnTransactionCompleted(const firebase::Future<firebase::database::DataSnapshot>& result, void* user_data);
    
    // Connection state monitoring
    void MonitorConnectionState();
    void OnConnectionStateChanged(const firebase::database::DataSnapshot& snapshot);
};

#endif // FirebaseDatabase_h
