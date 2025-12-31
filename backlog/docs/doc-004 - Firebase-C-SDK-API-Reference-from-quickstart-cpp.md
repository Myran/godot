---
id: doc-004
title: Firebase C++ SDK API Reference (from quickstart-cpp)
type: other
created_date: '2025-12-31 11:38'
---
# Firebase C++ SDK API Reference

Extracted from `extras/quickstart-cpp-main/` - Official Firebase C++ examples.

## 1. Analytics - SIMPLEST (Fire-and-Forget)

**Source**: `analytics/testapp/src/common_main.cc`

### Initialization
```cpp
#include "firebase/analytics.h"
#include "firebase/analytics/event_names.h"
#include "firebase/analytics/parameter_names.h"
#include "firebase/analytics/user_property_names.h"

namespace analytics = ::firebase::analytics;
analytics::Initialize(*app);
```

### Configuration
```cpp
analytics::SetAnalyticsCollectionEnabled(true);
analytics::SetSessionTimeoutDuration(1000 * 60 * 30);  // 30 minutes
```

### User Properties
```cpp
analytics::SetUserId("user_123");
analytics::SetUserProperty(analytics::kUserPropertySignUpMethod, "Google");
```

### Event Logging (FIRE-AND-FORGET - NO CALLBACKS!)
```cpp
// No parameters
analytics::LogEvent(analytics::kEventLogin);

// Single parameter variants
analytics::LogEvent("progress", "percent", 0.4f);                    // float
analytics::LogEvent(analytics::kEventPostScore, analytics::kParameterScore, 42);  // int
analytics::LogEvent(analytics::kEventJoinGroup, analytics::kParameterGroupID, "guild_1");  // string

// Multiple parameters
const analytics::Parameter params[] = {
    analytics::Parameter(analytics::kParameterLevel, 5),
    analytics::Parameter(analytics::kParameterCharacter, "warrior"),
    analytics::Parameter("hit_accuracy", 3.14f),
};
analytics::LogEvent(analytics::kEventLevelUp, params, sizeof(params) / sizeof(params[0]));

// Screen view
analytics::LogEvent(analytics::kEventScreenView, "screen_class", "screen_name");
```

### Only Async Operation
```cpp
auto future = analytics::GetAnalyticsInstanceId();
// Wait for completion
if (future.status() == firebase::kFutureStatusComplete) {
    LogMessage("Instance ID: %s", future.result()->c_str());
}
```

### Cleanup
```cpp
analytics::Terminate();
```

### Pre-defined Constants
- **Events**: `kEventLogin`, `kEventPostScore`, `kEventJoinGroup`, `kEventLevelUp`, `kEventScreenView`
- **Params**: `kParameterScore`, `kParameterGroupID`, `kParameterLevel`, `kParameterCharacter`
- **User Props**: `kUserPropertySignUpMethod`

---

## 2. Auth - Comprehensive (Many Async Operations)

**Source**: `auth/testapp/src/common_main.cc`

### Initialization
```cpp
#include "firebase/auth.h"
#include "firebase/auth/credential.h"

firebase::auth::Auth* auth = firebase::auth::Auth::GetAuth(app);
```

### Sign-In Methods
```cpp
// Anonymous
Future<AuthResult> future = auth->SignInAnonymously();

// Email/Password
Future<AuthResult> future = auth->SignInWithEmailAndPassword(email, password);

// With Credential (generic)
Future<User> future = auth->SignInWithCredential(credential);
Future<AuthResult> future = auth->SignInAndRetrieveDataWithCredential(credential);

// CRITICAL FOR STEAM: Custom Token
Future<AuthResult> future = auth->SignInWithCustomToken(token);
```

### Credential Providers
```cpp
// Email
Credential cred = EmailAuthProvider::GetCredential(email, password);

// Facebook
Credential cred = FacebookAuthProvider::GetCredential(accessToken);

// Google
Credential cred = GoogleAuthProvider::GetCredential(idToken, accessToken);

// Apple (OAuth)
Credential cred = OAuthProvider::GetCredential("apple.com", idToken, nonce, nullptr);

// Twitter
Credential cred = TwitterAuthProvider::GetCredential(idToken, accessToken);

// GitHub
Credential cred = GitHubAuthProvider::GetCredential(accessToken);

// Play Games (Android only)
Credential cred = PlayGamesAuthProvider::GetCredential(serverAuthCode);

// Game Center (iOS only)
Future<Credential> cred = GameCenterAuthProvider::GetCredential();
```

### Account Management
```cpp
Future<AuthResult> future = auth->CreateUserWithEmailAndPassword(email, password);
auth->SignOut();
Future<void> future = auth->SendPasswordResetEmail(email);
Future<Auth::FetchProvidersResult> future = auth->FetchProvidersForEmail(email);
```

### User Operations
```cpp
User user = auth->current_user();

// Profile
user.uid();
user.email();
user.display_name();
user.photo_url();
user.is_anonymous();
user.is_email_verified();
user.metadata().last_sign_in_timestamp;
user.metadata().creation_timestamp;
user.provider_data();  // std::vector<UserInfoInterface>

// Token
Future<std::string> future = user.GetToken(force_refresh);

// Updates
User::UserProfile profile;
profile.display_name = "Name";
profile.photo_url = "https://...";
Future<void> future = user.UpdateUserProfile(profile);
Future<void> future = user.UpdateEmail(newEmail);
Future<void> future = user.UpdatePassword(newPassword);
Future<void> future = user.SendEmailVerification();
Future<void> future = user.Reload();

// Linking
Future<AuthResult> future = user.LinkWithCredential(credential);
Future<AuthResult> future = user.Unlink(provider_id);
Future<void> future = user.Reauthenticate(credential);
Future<AuthResult> future = user.ReauthenticateAndRetrieveData(credential);

// Delete
Future<void> future = user.Delete();
```

### State Listeners
```cpp
class AuthStateChangeCounter : public firebase::auth::AuthStateListener {
    void OnAuthStateChanged(Auth* auth) override {
        // User signed in/out
    }
};

class IdTokenChangeCounter : public firebase::auth::IdTokenListener {
    void OnIdTokenChanged(Auth* auth) override {
        // Token refreshed
    }
};

auth->AddAuthStateListener(&counter);
auth->RemoveAuthStateListener(&counter);
auth->AddIdTokenListener(&token_counter);
auth->RemoveIdTokenListener(&token_counter);
```

### Error Codes
- `kAuthErrorNone` - Success
- `kAuthErrorUserNotFound` - Invalid email
- `kAuthErrorWrongPassword` - Invalid password
- `kAuthErrorEmailAlreadyInUse` - Duplicate account
- `kAuthErrorInvalidCredential` - Bad credentials
- `kAuthErrorProviderAlreadyLinked` - Provider already linked
- `kAuthErrorNoSuchProvider` - Provider not found

---

## 3. Remote Config - Simple Async

**Source**: `remote_config/testapp/src/common_main.cc`

### Initialization
```cpp
#include "firebase/remote_config.h"

RemoteConfig* rc = RemoteConfig::GetInstance(app);
```

### Set Defaults
```cpp
static const remote_config::ConfigKeyValueVariant defaults[] = {
    {"TestBoolean", "True"},
    {"TestLong", 42},
    {"TestDouble", 3.14},
    {"TestString", "Hello World"},
    {"TestData", firebase::Variant::FromStaticBlob(data, size)},
};
rc->SetDefaults(defaults, count);
```

### Fetch & Activate
```cpp
// Combined
auto future = rc->FetchAndActivate();  // Returns Future<bool>

// Separate
auto fetch_future = rc->Fetch(cache_expiration_seconds);
auto activate_future = rc->Activate();  // Returns Future<bool>
```

### Get Values
```cpp
remote_config::ValueInfo value_info;
bool val = rc->GetBoolean("key", &value_info);
int64_t val = rc->GetLong("key", &value_info);
double val = rc->GetDouble("key", &value_info);
std::string val = rc->GetString("key", &value_info);
std::vector<unsigned char> val = rc->GetData("key");

// Value source: kValueSourceStaticValue, kValueSourceRemoteValue, kValueSourceDefaultValue
```

### Keys
```cpp
std::vector<std::string> keys = rc->GetKeys();
std::vector<std::string> keys = rc->GetKeysByPrefix("prefix");
```

### Info
```cpp
const remote_config::ConfigInfo& info = rc->GetInfo();
info.fetch_time;
info.last_fetch_status;
info.last_fetch_failure_reason;
info.throttled_end_time;
```

### Cleanup
```cpp
future.Release();  // Release future before shutdown
delete rc;
```

---

## 4. Firestore - Complex (Requires Auth)

**Source**: `firestore/testapp/src/common_main.cc`

### Initialization (Requires Auth First!)
```cpp
#include "firebase/firestore.h"

// Sign in first!
auth->SignInAnonymously();

firebase::firestore::Firestore* firestore = nullptr;
firebase::InitResult result;
firestore = firebase::firestore::Firestore::GetInstance(app, &result);
firestore->set_log_level(firebase::kLogLevelDebug);
```

### Settings
```cpp
firebase::firestore::Settings settings = firestore->settings();
firestore->set_settings(settings);
```

### Collection/Document References
```cpp
firebase::firestore::CollectionReference collection = firestore->Collection("users");
firebase::firestore::DocumentReference document = firestore->Document("users/user123");

collection.id();           // "users"
document.path();           // "users/user123"
document.firestore();      // Returns Firestore*
collection.Document("doc"); // Nested document
```

### Document Operations
```cpp
// Set (create/overwrite)
Future<void> future = document.Set(firebase::firestore::MapFieldValue{
    {"name", firebase::firestore::FieldValue::String("John")},
    {"age", firebase::firestore::FieldValue::Integer(25)},
});

// Update (merge)
Future<void> future = document.Update(firebase::firestore::MapFieldValue{
    {"age", firebase::firestore::FieldValue::Integer(26)},
});

// Get
Future<DocumentSnapshot> future = document.Get();
const DocumentSnapshot* snapshot = future.result();
for (const auto& kv : snapshot->GetData()) {
    if (kv.second.type() == FieldValue::Type::kString) {
        // kv.first = key, kv.second.string_value() = value
    } else if (kv.second.type() == FieldValue::Type::kInteger) {
        // kv.second.integer_value()
    }
}

// Delete
Future<void> future = document.Delete();
```

### Queries
```cpp
firebase::firestore::Query query = collection
    .WhereGreaterThan("score", firebase::firestore::FieldValue::Integer(100))
    .Limit(10);

Future<QuerySnapshot> future = query.Get();
const QuerySnapshot* snapshot = future.result();
for (const auto& doc : snapshot->documents()) {
    doc.id();
    doc.Get("field").integer_value();
}
```

### Batch Writes
```cpp
firebase::firestore::WriteBatch batch = firestore->batch();
batch.Set(collection.Document("one"), MapFieldValue{...});
batch.Set(collection.Document("two"), MapFieldValue{...});
Future<void> future = batch.Commit();
```

### Transactions
```cpp
Future<void> future = firestore->RunTransaction(
    [collection](Transaction& transaction, std::string& error) -> Error {
        transaction.Update(collection.Document("one"), MapFieldValue{...});
        transaction.Delete(collection.Document("two"));
        transaction.Set(collection.Document("three"), MapFieldValue{...});
        return firebase::firestore::kErrorOk;
    });
```

### Snapshot Listeners
```cpp
ListenerRegistration registration = document.AddSnapshotListener(
    [](const DocumentSnapshot& snapshot, Error error, const std::string& error_message) {
        if (error != kErrorOk) { /* handle error */ }
        // Process snapshot
    });
registration.Remove();  // Stop listening
```

### Special Types
```cpp
firebase::Timestamp timestamp{seconds, nanoseconds};
firebase::firestore::GeoPoint point{latitude, longitude};
firebase::firestore::SnapshotMetadata metadata{has_pending_writes, is_from_cache};
```

---

## Key Patterns for GameTwo Implementation

### Thread-Safe Singleton (from database.h)
```cpp
static std::mutex initialization_mutex;
static std::atomic<bool> inited;
static std::atomic<bool> is_shutting_down;
```

### MessageQueue Marshalling (for callbacks)
```cpp
// In callback (worker thread):
MessageQueue::get_singleton()->push_callable(
    callable_mp(singleton_instance, &Class::handle_on_main_thread)
        .bind(args...)
);
```

### Future Handling Pattern
```cpp
future.OnCompletion([](const Future<T>& result, void* user_data) {
    auto* self = static_cast<MyClass*>(user_data);
    if (self->is_shutting_down) return;  // Safety check
    
    if (result.error() == kErrorNone) {
        // Success - marshal to main thread
    } else {
        // Error - marshal error to main thread
    }
}, this);
```

---

*Reference document for Firebase C++ SDK implementation in GameTwo.*
