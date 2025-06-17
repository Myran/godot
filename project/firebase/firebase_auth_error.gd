class_name FirebaseAuthError
extends RefCounted

## Firebase Auth Error Codes
## Maps to firebase::auth::AuthError enum from Firebase C++ SDK
## Values must match the constants used in Firebase C++ module

enum Code {
	# Success case
	NONE = 0,  # kAuthErrorNone - operation succeeded
	# Common auth errors (based on Firebase C++ SDK)
	INVALID_CUSTOM_TOKEN = 1,
	CUSTOM_TOKEN_MISMATCH = 2,
	INVALID_CREDENTIAL = 3,
	USER_DISABLED = 4,
	OPERATION_NOT_ALLOWED = 5,
	EMAIL_ALREADY_IN_USE = 6,
	INVALID_EMAIL = 7,
	WRONG_PASSWORD = 8,
	TOO_MANY_REQUESTS = 9,
	USER_NOT_FOUND = 10,
	ACCOUNT_EXISTS_WITH_DIFFERENT_CREDENTIAL = 11,
	REQUIRES_RECENT_LOGIN = 12,
	PROVIDER_ALREADY_LINKED = 13,
	NO_SUCH_PROVIDER = 14,
	INVALID_USER_TOKEN = 15,
	NETWORK_ERROR = 16,
	USER_TOKEN_EXPIRED = 17,
	INVALID_API_KEY = 18,
	USER_MISMATCH = 19,
	CREDENTIAL_ALREADY_IN_USE = 20,
	WEAK_PASSWORD = 21,
	APP_NOT_AUTHORIZED = 22
}


## Check if the error code represents success
static func is_success(error_code: Code) -> bool:
	return error_code == Code.NONE


## Get human-readable error message
static func get_error_message(error_code: Code) -> String:
	match error_code:
		Code.NONE:
			return "Success"
		Code.INVALID_CUSTOM_TOKEN:
			return "Invalid custom token"
		Code.CUSTOM_TOKEN_MISMATCH:
			return "Custom token mismatch"
		Code.INVALID_CREDENTIAL:
			return "Invalid credential"
		Code.USER_DISABLED:
			return "User account disabled"
		Code.OPERATION_NOT_ALLOWED:
			return "Operation not allowed"
		Code.EMAIL_ALREADY_IN_USE:
			return "Email already in use"
		Code.INVALID_EMAIL:
			return "Invalid email"
		Code.WRONG_PASSWORD:
			return "Wrong password"
		Code.TOO_MANY_REQUESTS:
			return "Too many requests"
		Code.USER_NOT_FOUND:
			return "User not found"
		Code.ACCOUNT_EXISTS_WITH_DIFFERENT_CREDENTIAL:
			return "Account exists with different credential"
		Code.REQUIRES_RECENT_LOGIN:
			return "Requires recent login"
		Code.PROVIDER_ALREADY_LINKED:
			return "Provider already linked"
		Code.NO_SUCH_PROVIDER:
			return "No such provider"
		Code.INVALID_USER_TOKEN:
			return "Invalid user token"
		Code.NETWORK_ERROR:
			return "Network error"
		Code.USER_TOKEN_EXPIRED:
			return "User token expired"
		Code.INVALID_API_KEY:
			return "Invalid API key"
		Code.USER_MISMATCH:
			return "User mismatch"
		Code.CREDENTIAL_ALREADY_IN_USE:
			return "Credential already in use"
		Code.WEAK_PASSWORD:
			return "Weak password"
		Code.APP_NOT_AUTHORIZED:
			return "App not authorized"
		_:
			return "Unknown error: " + str(error_code)
