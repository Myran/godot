#ifndef FirebaseAuth_h
#define FirebaseAuth_h

#include "core/object/ref_counted.h"
#include "firebase.h"
#include "firebase/auth.h"
#include "firebase/auth/user.h"
#include "scene/main/node.h"

class FirebaseAuth : public RefCounted {
	GDCLASS(FirebaseAuth, RefCounted);

protected:
	static bool inited;
	static firebase::auth::Auth *auth;
	static firebase::auth::User::UserProfile profile;
	static void _bind_methods();
	void link_to_provider(firebase::auth::Credential credential);
	void sign_in_provider(firebase::auth::Credential credential);

public:
	FirebaseAuth();
	void sign_in_anonymously();
	void sign_in_facebook(String token);
	void unlink_facebook();
	bool is_logged_in();
	void sign_in_apple(String token, String nonce);
	void unlink_provider(String provider_name);
	Array providers();
	void link_to_facebook(String token);
	void link_to_apple(String token, String nonce);

	String user_name();
	String email();
	String uid();
	String photo_url();
	void sign_out();

	void OnCreateUserCallback(const firebase::Future<firebase::auth::AuthResult> &result, void *user_data);
	void OnLinkUserCallback(const firebase::Future<firebase::auth::AuthResult> &result, void *user_data);
	void OnUnLinkUserCallback(const firebase::Future<firebase::auth::AuthResult> &result, void *user_data);
};

#endif // FirebaseAuth_h
