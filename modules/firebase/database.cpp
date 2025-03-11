#include "database.h"
#include "convertor.h"
bool FirebaseDatabase::inited = false;
firebase::database::Database *FirebaseDatabase::database = NULL;
firebase::database::DatabaseReference FirebaseDatabase::dbref;
FirebaseChildListener *FirebaseDatabase::listener = NULL;

////////////////////////////
//
// FirebaseChildListener
//

FirebaseChildListener::FirebaseChildListener(FirebaseDatabase* db): database(db)
{
}

void FirebaseChildListener::OnCancelled(const firebase::database::Error & error, const char *error_message)
{
    print_line(String("[RTDB] ChildListener: OnCancelled"));
}

void FirebaseChildListener::OnChildAdded(const firebase::database::DataSnapshot & snapshot, const char *previous_sibling_key)
{
    //print_line(String("[RTDB] ChildListener: OnChildAdded ") + snapshot.key());

    String key(snapshot.key());
    firebase::Variant val = snapshot.value();
    Variant value = Convertor::fromFirebaseVariant(val);
    database->call_deferred("emit_signal", "child_added", key, value);
}

void FirebaseChildListener::OnChildChanged(const firebase::database::DataSnapshot & snapshot, const char *previous_sibling_key)
{
    print_line(String("[RTDB] ChildListener: OnChildChanged ") + snapshot.key());

    String key(snapshot.key());
    firebase::Variant val = snapshot.value();
    Variant value = Convertor::fromFirebaseVariant(val);
    database->call_deferred("emit_signal", "child_changed", key, value);
}

void FirebaseChildListener::OnChildMoved(const firebase::database::DataSnapshot & snapshot, const char *previous_sibling_key)
{
    print_line(String("[RTDB] ChildListener: OnChildMoved ") + snapshot.key());

    String key(snapshot.key());
    firebase::Variant val = snapshot.value();
    Variant value = Convertor::fromFirebaseVariant(val);
    database->call_deferred("emit_signal", "child_moved", key, value);
}

void FirebaseChildListener::OnChildRemoved(const firebase::database::DataSnapshot & snapshot)
{
    print_line(String("[RTDB] ChildListener: OnChildRemoved ") + snapshot.key());

    String key(snapshot.key());
    firebase::Variant val = snapshot.value();
    Variant value = Convertor::fromFirebaseVariant(val);
    database->call_deferred("emit_signal", "child_removed", key, value);
}

////////////////////////////
//
// FirebaseDatabase
//

FirebaseDatabase::FirebaseDatabase()
{
    if(!inited) {
        firebase::App* app = Firebase::AppId();
        if(app != NULL) {
            database = firebase::database::Database::GetInstance(app);
            database->set_persistence_enabled(true);
            dbref = database->GetReference();
            inited = true;
        }
    }
}

FirebaseDatabase::~FirebaseDatabase()
{
    // Only clean up if this is the last instance and resources were initialized
    if (get_reference_count() == 1 && inited && listener != NULL) {
        delete listener;
        listener = NULL;
        // We don't delete the database instance here as it's managed by Firebase SDK
    }
}

void FirebaseDatabase::SetDBRoot(const Array& keys)
{
    // Input validation
    if (keys.size() == 0) {
        print_line("[RTDB] Error: Empty database path");
        call_deferred("emit_signal", "db_error", "INVALID_PATH", "Empty database path");
        return;
    }
    
    // Null checks
    if (!database) {
        print_line("[RTDB] Error: Database not initialized");
        call_deferred("emit_signal", "db_error", "NOT_INITIALIZED", "Database not initialized");
        return;
    }
    
    // Clean up existing listeners
    if(dbref.is_valid()) {
        dbref.RemoveAllChildListeners();
        dbref.RemoveAllValueListeners();
    }
    
    // Set up new reference
    dbref = database->GetReference();
    dbref = GetReferenceToPath(keys);
    
    print_line(String("[RTDB] Set DB root: ") + dbref.key());
    
    // Set up listener
    if(listener == NULL) {
        listener = new FirebaseChildListener(this);
    }
    
    // Add error handling for listener registration
    if (dbref.is_valid()) {
        dbref.AddChildListener(listener);
    } else {
        print_line("[RTDB] Error: Invalid database reference");
        call_deferred("emit_signal", "db_error", "INVALID_REF", "Invalid database reference");
    }
}

firebase::database::DatabaseReference FirebaseDatabase::GetReferenceToPath(const Array& keys)
{
    firebase::database::DatabaseReference ref = dbref;
    for(int i=0; i<keys.size(); i++) {
        Variant key = keys[i];
        if(key.get_type() == Variant::STRING) {
            ref = ref.Child(((String)key).utf8().get_data());
        }
    }
    return ref;
}

void FirebaseDatabase::SetValue(const Array& keys, const Variant& value)
{
    firebase::database::DatabaseReference ref = GetReferenceToPath(keys);
    if(value.get_type() == Variant::INT)
        ref.SetValue(firebase::Variant((int)value));
   // else if(value.get_type() == Variant::REAL)
     //   ref.SetValue(firebase::Variant((double)value));
    else
        ref.SetValue(Convertor::toFirebaseVariant((String)value));
}

String FirebaseDatabase::PushChild(const Array& keys)
{
    firebase::database::DatabaseReference ref = GetReferenceToPath(keys);
    ref = ref.PushChild();
    return String(ref.key());
}

void FirebaseDatabase::UpdateChildren(const Array& paths, const Dictionary& params)
{
    std::map<std::string, firebase::Variant> entryValues;
    for(int i=0; i<params.size(); i++) {
        Variant key = params.get_key_at_index(i);
        Variant val = params.get_value_at_index(i);
        std::string strKey = std::string(((String)key).utf8().get_data());
        if(val.get_type() == Variant::INT)
            entryValues[strKey] = firebase::Variant((int)val);
        //else if(val.get_type() == Variant::REAL)
          //  entryValues[strKey] = firebase::Variant((double)val);
        else
            entryValues[strKey] = Convertor::toFirebaseVariant((String)val);
    }
    
    std::map<std::string, firebase::Variant> childUpdates;// = new std::map<std::string, firebase::Variant>();
    for(int i=0; i<paths.size(); i++) {
        Variant path = paths[i];
        if(path.get_type() == Variant::STRING) {
            std::string strPath = std::string(((String)path).utf8().get_data());
            childUpdates[strPath] = entryValues;
        }
    }
    dbref.UpdateChildren(childUpdates);
}

void FirebaseDatabase::RemoveValue(const Array& keys)
{
    firebase::database::DatabaseReference ref = GetReferenceToPath(keys);
    ref.RemoveValue();
}

void FirebaseDatabase::GetValue(const Array& keys)
{
    firebase::database::DatabaseReference ref = GetReferenceToPath(keys);
    firebase::Future<firebase::database::DataSnapshot> result = ref.GetValue();
    result.OnCompletion([](const firebase::Future<firebase::database::DataSnapshot>& result, void* user_data) {
                            ((FirebaseDatabase*)user_data)->OnGetValue(result, user_data);
                        }, this);
}

void FirebaseDatabase::OnGetValue(const firebase::Future<firebase::database::DataSnapshot>& result, void* user_data)
{
    //assert(result.status() == firebase::kFutureStatusComplete);
    if (result.error() == firebase::database::kErrorNone) {
        firebase::Variant val = result.result()->value();
        String key(result.result()->key());
        Variant value = Convertor::fromFirebaseVariant(val);
        call_deferred("emit_signal", "get_value", key, value);
    } else {
        print_line(String("[RTDB] Reading DB failed with error ") + result.error_message());
        String error_code = String::num_int64(result.error());
        call_deferred("emit_signal", "db_error", error_code, result.error_message());
    }
}

/*
Variant FirebaseDatabase::ConvertVariant(const firebase::Variant& val)
{
    if(val.is_null()) {
        return Variant((void*)NULL);
    } else if(val.is_vector()) {
        const std::vector<firebase::Variant>& vector = val.vector();
        Vector<Variant> vecRes;
        for(int i=0; i<vector.size(); i++) {
            vecRes.push_back(ConvertVariant(vector[i]));
        }
        return Variant(vecRes);
    } else if(val.is_map()) {
        const std::map<firebase::Variant, firebase::Variant>& map = val.map();
        Dictionary dictRes;
        for(std::map<firebase::Variant, firebase::Variant>::const_iterator i=map.begin(); i!=map.end(); i++) {
            firebase::Variant first = i->first;
            firebase::Variant second = i->second;
            String key = String(first.string_value());
            dictRes[key] = ConvertVariant(second);
        }
        return Variant(dictRes);
    } else if(val.is_int64()) {
        return Variant(val.int64_value());
    } else if(val.is_double()) {
        return Variant(val.double_value());
    } else if(val.is_bool()) {
        return Variant(val.bool_value());
    } else if(val.is_string()) {
        return Variant(val.string_value());
    } else {
        return Variant((void*)NULL);
    }
}
*/

firebase::database::Query FirebaseDatabase::GetQueryFromReference(const firebase::database::DatabaseReference& ref, const Dictionary& query_params) {
    firebase::database::Query query = ref;
    
    if (query_params.has("orderByChild")) {
        String child_key = query_params["orderByChild"];
        query = query.OrderByChild(child_key.utf8().get_data());
    } else if (query_params.has("orderByKey")) {
        query = query.OrderByKey();
    } else if (query_params.has("orderByValue")) {
        query = query.OrderByValue();
    }
    
    if (query_params.has("limitToFirst")) {
        int limit = query_params["limitToFirst"];
        query = query.LimitToFirst(limit);
    } else if (query_params.has("limitToLast")) {
        int limit = query_params["limitToLast"];
        query = query.LimitToLast(limit);
    }
    
    if (query_params.has("startAt")) {
        Variant start = query_params["startAt"];
        if (start.get_type() == Variant::INT) {
            query = query.StartAt(firebase::Variant((int)start));
        } else if (start.get_type() == Variant::FLOAT) {
            query = query.StartAt(firebase::Variant((float)start));
        } else {
            String str_val = start;
            query = query.StartAt(firebase::Variant(str_val.utf8().get_data()));
        }
    }
    
    if (query_params.has("endAt")) {
        Variant end = query_params["endAt"];
        if (end.get_type() == Variant::INT) {
            query = query.EndAt(firebase::Variant((int)end));
        } else if (end.get_type() == Variant::FLOAT) {
            query = query.EndAt(firebase::Variant((float)end));
        } else {
            String str_val = end;
            query = query.EndAt(firebase::Variant(str_val.utf8().get_data()));
        }
    }
    
    if (query_params.has("equalTo")) {
        Variant equal = query_params["equalTo"];
        if (equal.get_type() == Variant::INT) {
            query = query.EqualTo(firebase::Variant((int)equal));
        } else if (equal.get_type() == Variant::FLOAT) {
            query = query.EqualTo(firebase::Variant((float)equal));
        } else {
            String str_val = equal;
            query = query.EqualTo(firebase::Variant(str_val.utf8().get_data()));
        }
    }
    
    return query;
}

void FirebaseDatabase::QueryOrderedData(const Array& keys, const Dictionary& query_params) {
    if (!database) {
        print_line("[RTDB] Error: Database not initialized");
        call_deferred("emit_signal", "db_error", "NOT_INITIALIZED", "Database not initialized");
        return;
    }
    
    firebase::database::DatabaseReference ref = GetReferenceToPath(keys);
    if (!ref.is_valid()) {
        print_line("[RTDB] Error: Invalid database reference");
        call_deferred("emit_signal", "db_error", "INVALID_REF", "Invalid database reference");
        return;
    }
    
    firebase::database::Query query = GetQueryFromReference(ref, query_params);
    firebase::Future<firebase::database::DataSnapshot> result = query.GetValue();
    result.OnCompletion([](const firebase::Future<firebase::database::DataSnapshot>& result, void* user_data) {
        ((FirebaseDatabase*)user_data)->OnQueryResult(result, user_data);
    }, this);
}

void FirebaseDatabase::OnQueryResult(const firebase::Future<firebase::database::DataSnapshot>& result, void* user_data) {
    if (result.error() == firebase::database::kErrorNone) {
        const firebase::database::DataSnapshot* snapshot = result.result();
        firebase::Variant val = snapshot->value();
        String key(snapshot->key());
        Variant value = Convertor::fromFirebaseVariant(val);
        call_deferred("emit_signal", "query_result", key, value);
    } else {
        print_line(String("[RTDB] Query failed with error ") + result.error_message());
        String error_code = String::num_int64(result.error());
        call_deferred("emit_signal", "db_error", error_code, result.error_message());
    }
}

void FirebaseDatabase::SetServerTimestamp(const Array& keys) {
    if (!database) {
        print_line("[RTDB] Error: Database not initialized");
        call_deferred("emit_signal", "db_error", "NOT_INITIALIZED", "Database not initialized");
        return;
    }
    
    firebase::database::DatabaseReference ref = GetReferenceToPath(keys);
    if (!ref.is_valid()) {
        print_line("[RTDB] Error: Invalid database reference");
        call_deferred("emit_signal", "db_error", "INVALID_REF", "Invalid database reference");
        return;
    }
    
    ref.SetValue(firebase::database::ServerTimestamp());
}

// Structure to hold transaction data
struct TransactionData {
    int increment_by;
    FirebaseDatabase* database;
};

// Simple Increment Function for transaction
firebase::database::TransactionResult IncrementTransactionFn(
    firebase::database::MutableData* data, 
    void* transaction_value) {
    
    TransactionData* tx_data = static_cast<TransactionData*>(transaction_value);
    
    // Get the current value
    firebase::Variant val = data->value();
    int current_value = 0;
    
    // If the value is not null and is a number, use it
    if (!val.is_null()) {
        if (val.is_int64()) {
            current_value = static_cast<int>(val.int64_value());
        } else if (val.is_double()) {
            current_value = static_cast<int>(val.double_value());
        }
    }
    
    // Increment by the specified amount
    int new_value = current_value + tx_data->increment_by;
    
    // Set the new value
    data->set_value(firebase::Variant(new_value));
    
    return firebase::database::kTransactionResultSuccess;
}

// This gets called when the transaction completes
void TransactionCompletionCallback(
    const firebase::Future<firebase::database::DataSnapshot>& result, 
    void* transaction_value) {
    
    // Get the transaction data
    TransactionData* tx_data = static_cast<TransactionData*>(transaction_value);
    
    // Process the result
    tx_data->database->OnTransactionCompleted(result, nullptr);
    
    // Clean up
    delete tx_data;
}

void FirebaseDatabase::RunTransaction(const Array& keys, int increment_by) {
    if (!database) {
        print_line("[RTDB] Error: Database not initialized");
        call_deferred("emit_signal", "db_error", "NOT_INITIALIZED", "Database not initialized");
        return;
    }
    
    firebase::database::DatabaseReference ref = GetReferenceToPath(keys);
    if (!ref.is_valid()) {
        print_line("[RTDB] Error: Invalid database reference");
        call_deferred("emit_signal", "db_error", "INVALID_REF", "Invalid database reference");
        return;
    }
    
    // Create transaction data structure
    TransactionData* tx_data = new TransactionData();
    tx_data->increment_by = increment_by;
    tx_data->database = this;
    
    print_line(String("[RTDB] Running transaction to increment value by ") + String::num_int64(increment_by));
    
    // Run the transaction
    ref.RunTransaction(IncrementTransactionFn, tx_data, &TransactionCompletionCallback);
}

void FirebaseDatabase::OnTransactionCompleted(const firebase::Future<firebase::database::DataSnapshot>& result, void* user_data) {
    if (result.error() == firebase::database::kErrorNone) {
        const firebase::database::DataSnapshot* snapshot = result.result();
        firebase::Variant val = snapshot->value();
        String key(snapshot->key());
        Variant value = Convertor::fromFirebaseVariant(val);
        
        print_line(String("[RTDB] Transaction completed successfully for key: ") + key);
        call_deferred("emit_signal", "transaction_completed", key, value, true);
    } else {
        print_line(String("[RTDB] Transaction failed with error ") + result.error_message());
        String error_code = String::num_int64(result.error());
        call_deferred("emit_signal", "transaction_completed", "", Variant(), false);
        call_deferred("emit_signal", "db_error", error_code, result.error_message());
    }
}

void FirebaseDatabase::MonitorConnectionState() {
    if (!database) {
        print_line("[RTDB] Error: Database not initialized");
        call_deferred("emit_signal", "db_error", "NOT_INITIALIZED", "Database not initialized");
        return;
    }
    
    firebase::database::DatabaseReference ref = database->GetReference(".info/connected");
    
    // We need to use a ValueListener instead of OnCompletion for persistent monitoring
    class ConnectionStateListener : public firebase::database::ValueListener {
    private:
        FirebaseDatabase* database;
    public:
        ConnectionStateListener(FirebaseDatabase* db) : database(db) {}
        
        void OnValueChanged(const firebase::database::DataSnapshot& snapshot) override {
            database->OnConnectionStateChanged(snapshot);
        }
        
        void OnCancelled(const firebase::database::Error& error, const char* error_message) override {
            print_line(String("[RTDB] Connection monitoring cancelled: ") + error_message);
        }
    };
    
    static ConnectionStateListener* connection_listener = new ConnectionStateListener(this);
    ref.AddValueListener(connection_listener);
}

void FirebaseDatabase::OnConnectionStateChanged(const firebase::database::DataSnapshot& snapshot) {
    bool connected = snapshot.value().bool_value();
    call_deferred("emit_signal", "connection_state_changed", connected);
}

void FirebaseDatabase::_bind_methods() {

    ClassDB::bind_method(D_METHOD("set_db_root", "keys"), &FirebaseDatabase::SetDBRoot);
    ClassDB::bind_method(D_METHOD("set_value", "keys", "value"), &FirebaseDatabase::SetValue);
    ClassDB::bind_method(D_METHOD("push_child", "keys"), &FirebaseDatabase::PushChild);
    ClassDB::bind_method(D_METHOD("update_children", "paths", "params"), &FirebaseDatabase::UpdateChildren);
    ClassDB::bind_method(D_METHOD("remove_value", "keys"), &FirebaseDatabase::RemoveValue);
    ClassDB::bind_method(D_METHOD("get_value", "keys"), &FirebaseDatabase::GetValue);
    
    // New query functionality
    ClassDB::bind_method(D_METHOD("query_ordered_data", "keys", "query_params"), &FirebaseDatabase::QueryOrderedData);
    
    // Server timestamp
    ClassDB::bind_method(D_METHOD("set_server_timestamp", "keys"), &FirebaseDatabase::SetServerTimestamp);
    
    // Transaction support - simplified to numeric increment
    ClassDB::bind_method(D_METHOD("run_transaction", "keys", "increment_by"), &FirebaseDatabase::RunTransaction, DEFVAL(1));
    
    // Connection state monitoring
    ClassDB::bind_method(D_METHOD("monitor_connection_state"), &FirebaseDatabase::MonitorConnectionState);

    ADD_SIGNAL(MethodInfo("get_value", PropertyInfo(Variant::STRING, "key"), PropertyInfo(Variant::NIL, "value")));
    ADD_SIGNAL(MethodInfo("child_added", PropertyInfo(Variant::STRING, "key"), PropertyInfo(Variant::NIL, "value")));
    ADD_SIGNAL(MethodInfo("child_changed", PropertyInfo(Variant::STRING, "key"), PropertyInfo(Variant::NIL, "value")));
    ADD_SIGNAL(MethodInfo("child_moved", PropertyInfo(Variant::STRING, "key"), PropertyInfo(Variant::NIL, "value")));
    ADD_SIGNAL(MethodInfo("child_removed", PropertyInfo(Variant::STRING, "key"), PropertyInfo(Variant::NIL, "value")));
    ADD_SIGNAL(MethodInfo("db_error", PropertyInfo(Variant::STRING, "code"), PropertyInfo(Variant::STRING, "message")));
    
    // New signals
    ADD_SIGNAL(MethodInfo("query_result", PropertyInfo(Variant::STRING, "key"), PropertyInfo(Variant::NIL, "value")));
    ADD_SIGNAL(MethodInfo("transaction_completed", PropertyInfo(Variant::STRING, "key"), PropertyInfo(Variant::NIL, "value"), PropertyInfo(Variant::BOOL, "success")));
    ADD_SIGNAL(MethodInfo("connection_state_changed", PropertyInfo(Variant::BOOL, "connected")));
}
