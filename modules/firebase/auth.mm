#include "auth.h"
#if defined(__APPLE__)
#import "app_delegate.h"
#endif
#include "core/object.h"


bool FirebaseAuth::inited = false;
firebase::auth::Auth* FirebaseAuth::auth = NULL;
firebase::auth::User::UserProfile FirebaseAuth::profile;

FirebaseAuth::FirebaseAuth() {
    print_line(String("[Auth] started"));
    if(!inited) {
        print_line(String("[Auth] Creating firebase app"));
        firebase::App* app = Firebase::AppId();
        print_line(String("[Auth] firebase app created successfully"));
        if(app != NULL) {
            print_line(String("[Auth] Creating singleton"));
            auth = firebase::auth::Auth::GetAuth(app);
            inited = true;
        }
    }
}

void FirebaseAuth::OnCreateUserCallback(const firebase::Future<firebase::auth::User*>& result, void* user_data) {
    // The callback is called when the Future enters the `complete` state.
   // assert(result.status() == firebase::kFutureStatusComplete);
    if (result.error() == firebase::auth::kAuthErrorNone) {
        firebase::auth::User* user = *result.result();
        print_line(String("[Auth] Create/ Sign in user succeeded with name ") + user->display_name().c_str());
        user->UpdateUserProfile(profile);
    } else {
        print_line(String("[Auth] Created user failed with error ") + result.error_message());
    }
    emit_signal("logged_in",result.error());
}
void FirebaseAuth::OnLinkUserCallback(const firebase::Future<firebase::auth::User*>& result, void* user_data) {
    // The callback is called when the Future enters the `complete` state.
   // assert(result.status() == firebase::kFutureStatusComplete);
    if (result.error() == firebase::auth::kAuthErrorNone) {
        firebase::auth::User* user = *result.result();
        print_line(String("[Auth] Link user succeeded"));
        user->UpdateUserProfile(profile);
        emit_signal("account_linked",result.error());
    } else {
        
        print_line(String("[Auth] Link user failed with error message: ") + result.error_message());
    }
    emit_signal("account_linked",result.error());
}
void FirebaseAuth::OnUnLinkUserCallback(const firebase::Future<firebase::auth::User*>& result, void* user_data) {
    // The callback is called when the Future enters the `complete` state.
   // assert(result.status() == firebase::kFutureStatusComplete);
    if (result.error() == firebase::auth::kAuthErrorNone) {
        firebase::auth::User* user = *result.result();
        print_line(String("[Auth] UnLink user succeeded"));
        user->UpdateUserProfile(profile);
    } else {
        print_line(String("[Auth] UnLink user failed with error ") + result.error_message());
    }
    emit_signal("account_unlinked",result.error_message());
}

void FirebaseAuth::sign_in_anonymously()
{
    print_line("[Auth] Start anonymous sign in");
    firebase::Future<firebase::auth::User*> result = auth->SignInAnonymously();
    result.OnCompletion([](const firebase::Future<firebase::auth::User*>& result, void* user_data) {
                            ((FirebaseAuth*)user_data)->OnCreateUserCallback(result, user_data);
                        }, this);
}


void FirebaseAuth::sign_in_apple(String token,String nonce)
{
    print_line("[Auth] Start sign in to firebase with apple account");

    firebase::auth::Credential credential = firebase::auth::OAuthProvider::GetCredential(
        /*provider_id=*/"apple.com", token.utf8().get_data(), nonce.utf8().get_data(),
        /*access_token=*/nullptr);
    sign_in_provider(credential);
    
}
void FirebaseAuth::link_to_apple(String token,String nonce)
{
        print_line("[Auth] Start link firebase in to Apple");
        firebase::auth::Credential credential = firebase::auth::OAuthProvider::GetCredential(
        /*provider_id=*/"apple.com", token.utf8().get_data(), nonce.utf8().get_data(),
        /*access_token=*/nullptr);
        link_to_provider(credential);
}


void FirebaseAuth::sign_in_facebook(String token)
{
    print_line("[Auth] Start sign in to Firebase with Facebook");
    firebase::auth::Credential credential = firebase::auth::FacebookAuthProvider::GetCredential(token.utf8().get_data());
    sign_in_provider(credential);
}
void FirebaseAuth::link_to_facebook(String token)
{
    print_line("[Auth] Start link firebase in to Facebook");
    firebase::auth::Credential credential = firebase::auth::FacebookAuthProvider::GetCredential(token.utf8().get_data());
    link_to_provider(credential);
} 
void FirebaseAuth::sign_in_provider(firebase::auth::Credential credential)
{
    firebase::Future<firebase::auth::User*> result = auth->SignInWithCredential(credential);
    result.OnCompletion([](const firebase::Future<firebase::auth::User*>& result, void* user_data) {
                                ((FirebaseAuth*)user_data)->OnCreateUserCallback(result, user_data);
                            }, this);
}

void FirebaseAuth::link_to_provider(firebase::auth::Credential credential)
{
    firebase::auth::User* current_user = auth->current_user();
    if(current_user != NULL) {
        firebase::Future<firebase::auth::User*> result = current_user->LinkWithCredential(credential);
        result.OnCompletion([](const firebase::Future<firebase::auth::User*>& result, void* user_data) {
                                ((FirebaseAuth*)user_data)->OnLinkUserCallback(result, user_data);
                            }, this);
    }else{
        print_line("Cannot link to provider: no user logged in");
    }
}


void FirebaseAuth::unlink_provider(String provider_name)
{
    firebase::auth::User* current_user = auth->current_user();
     print_line(String("[Auth] unlink attempt with provider: ") + provider_name);
    firebase::Future<firebase::auth::User*> result = current_user->Unlink(provider_name.utf8().get_data());
    result.OnCompletion([](const firebase::Future<firebase::auth::User*>& result, void* user_data) {
                            ((FirebaseAuth*)user_data)->OnUnLinkUserCallback(result, user_data);
                            }, this);
}


Array FirebaseAuth::providers()
{
    Array retArray;
    firebase::auth::User* current_user = auth->current_user();
   for (std::size_t i = 0; i < current_user->provider_data().size(); ++i)
   {
       print_line(String("[Auth] provider: ") + current_user->provider_data()[i]->provider_id().c_str());
        Dictionary tempDict;
        tempDict["name"] = current_user->provider_data()[i]->provider_id().c_str();
        retArray.append(tempDict);
   }
   
    return retArray;
}





bool FirebaseAuth::is_logged_in()
{
    firebase::auth::User* current_user = auth->current_user();
    return (current_user != NULL);
}

String FirebaseAuth::user_name()
{
    firebase::auth::User* current_user = auth->current_user();
    return String(current_user->display_name().c_str());
}

String FirebaseAuth::email()
{
    firebase::auth::User* current_user = auth->current_user();
    return String(current_user->email().c_str());
}

String FirebaseAuth::uid()
{
    firebase::auth::User* current_user = auth->current_user();
    return String(current_user->uid().c_str());
}

String FirebaseAuth::photo_url()
{
    firebase::auth::User* current_user = auth->current_user();
    return String(current_user->photo_url().c_str());
}

void FirebaseAuth::sign_out()
{
    auth->SignOut();
   /* if ([FBSDKAccessToken currentAccessToken]) {
    [FBSDKAccessToken refreshCurrentAccessToken];
    }*/
}

void FirebaseAuth::_bind_methods() {
    ClassDB::bind_method(D_METHOD("sign_in_anonymously"), &FirebaseAuth::sign_in_anonymously);
    ClassDB::bind_method(D_METHOD("sign_in_facebook", "param"), &FirebaseAuth::sign_in_facebook);
    ClassDB::bind_method(D_METHOD("sign_in_apple","param"),&FirebaseAuth::sign_in_apple);
    ClassDB::bind_method(D_METHOD("is_logged_in"), &FirebaseAuth::is_logged_in);
    ClassDB::bind_method(D_METHOD("user_name"), &FirebaseAuth::user_name);
    ClassDB::bind_method(D_METHOD("email"), &FirebaseAuth::email);
    ClassDB::bind_method(D_METHOD("uid"), &FirebaseAuth::uid);
    ClassDB::bind_method(D_METHOD("photo_url"), &FirebaseAuth::photo_url);
    ClassDB::bind_method(D_METHOD("sign_out"), &FirebaseAuth::sign_out);
    ClassDB::bind_method(D_METHOD("providers"), &FirebaseAuth::providers);
    ClassDB::bind_method(D_METHOD("unlink_provider"), &FirebaseAuth::unlink_provider);
    ClassDB::bind_method(D_METHOD("link_to_facebook", "param"), &FirebaseAuth::link_to_facebook);
    ClassDB::bind_method(D_METHOD("link_to_apple","param"),&FirebaseAuth::link_to_apple);
    ADD_SIGNAL(MethodInfo("logged_in"));
    ADD_SIGNAL(MethodInfo("account_linked"));
    ADD_SIGNAL(MethodInfo("account_unlinked"));
}

