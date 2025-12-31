---
id: task-404
title: Implement Steam Authentication with Firebase Custom Tokens
status: Consider
assignee: []
created_date: '2025-12-30 23:33'
labels:
  - firebase
  - steam
  - authentication
  - gdextension
  - integration
dependencies:
  - task-399
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Overview

Integrate Steam authentication into GameTwo, allowing players to sign in with their Steam account and have it linked to Firebase Auth via custom tokens.

## Research Findings

### GodotSteam Integration

**GodotSteam GDExtension** is the primary solution for Steam integration with Godot 4:
- **Latest Version**: GDExtension 4.4+ (December 2025)
- **Steamworks SDK**: 1.63 (latest)
- **Platforms**: Windows, Linux, macOS
- **Repository**: https://github.com/GodotSteam/GodotSteam
- **Documentation**: https://godotsteam.com/

Key GodotSteam features for authentication:
- `Steam.steamInit()` - Initialize Steam client
- `Steam.getSteamID()` - Get user's Steam ID (64-bit)
- `Steam.getAuthSessionTicket()` - Generate encrypted auth ticket for server validation
- `Steam.getPersonaName()` - Get Steam display name

### Firebase Custom Token Authentication

Firebase supports custom tokens for integrating third-party auth providers like Steam:

**Flow Architecture**:
```
1. Godot Game (GodotSteam)
   ↓ getAuthSessionTicket()
2. Backend Server (Cloud Function / Node.js)
   ↓ Verify ticket with Steam Web API
   ↓ Create Firebase custom token
3. Firebase Auth
   ↓ signInWithCustomToken()
4. Authenticated User
```

**Firebase Admin SDK** (server-side) creates custom tokens:
```javascript
const admin = require('firebase-admin');
const customToken = await admin.auth().createCustomToken(steamId, {
  provider: 'steam',
  displayName: steamPersonaName
});
```

### Reference Implementation: firebase-steam-login

GitHub library demonstrating the complete flow:
- **Repository**: https://github.com/nicholasareed/firebase-steam-login
- **Key Components**:
  - Steam OpenID validation
  - Firebase custom token generation
  - Client-side token exchange

### Required Components

1. **Client-Side (Godot)**:
   - GodotSteam GDExtension integration
   - Steam session ticket generation
   - HTTP request to backend for custom token
   - Firebase signInWithCustomToken()

2. **Server-Side (Cloud Function)**:
   - Steam Web API ticket validation
   - Firebase Admin SDK for custom token creation
   - Secure endpoint for token exchange

3. **Steam Developer Setup**:
   - Steam Web API key
   - App ID configuration
   - Steamworks SDK agreement

## Implementation Approach

### Phase 1: GodotSteam Setup
- Add GodotSteam GDExtension to project
- Initialize Steam on game launch
- Verify Steam client connection
- Test basic Steam API calls

### Phase 2: Steam Auth Ticket Flow
- Implement `getAuthSessionTicket()` in GDScript
- Create backend Cloud Function for ticket validation
- Integrate with Steam Web API ISteamUserAuth/AuthenticateUserTicket

### Phase 3: Firebase Custom Token Bridge
- Generate Firebase custom tokens from validated Steam tickets
- Include Steam user metadata (SteamID, persona name)
- Handle token expiration and refresh

### Phase 4: Client Token Exchange
- Add signInWithCustomToken() to FirebaseAuth C++ module
- Link Steam identity to Firebase Auth user
- Support account linking (Steam + anonymous → merged account)

## C++ Module Enhancement Required

Add to `godot/modules/firebase/auth.cpp`:
```cpp
void FirebaseAuth::sign_in_with_custom_token(String token) {
    print_line("[Auth] Start sign in with custom token");
    firebase::Future<firebase::auth::AuthResult> result = 
        auth->SignInWithCustomToken(token.utf8().get_data());
    result.OnCompletion([](const firebase::Future<firebase::auth::AuthResult>& result, void* user_data) {
        ((FirebaseAuth*)user_data)->OnCreateUserCallback(result, user_data);
    }, this);
}
```

## GDScript Integration Layer

```gdscript
# steam_auth_service.gd
class_name SteamAuthService
extends Node

signal steam_auth_completed(success: bool, firebase_user_id: String)
signal steam_auth_failed(error: String)

var _steam_initialized: bool = false

func initialize_steam() -> bool:
    if not Steam.steamInit():
        push_error("[SteamAuth] Failed to initialize Steam")
        return false
    _steam_initialized = true
    return true

func authenticate_with_firebase() -> void:
    if not _steam_initialized:
        steam_auth_failed.emit("Steam not initialized")
        return
    
    var ticket_data = Steam.getAuthSessionTicket()
    var steam_id = Steam.getSteamID()
    var persona_name = Steam.getPersonaName()
    
    # Send to backend for custom token generation
    var http = HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_on_token_request_completed)
    
    var body = JSON.stringify({
        "ticket": ticket_data.hex_encode(),
        "steam_id": str(steam_id),
        "persona_name": persona_name
    })
    
    http.request(
        "https://your-backend.com/steam-auth",
        ["Content-Type: application/json"],
        HTTPClient.METHOD_POST,
        body
    )

func _on_token_request_completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    if code != 200:
        steam_auth_failed.emit("Backend returned error: %d" % code)
        return
    
    var json = JSON.parse_string(body.get_string_from_utf8())
    var custom_token = json.get("firebase_token", "")
    
    if custom_token.is_empty():
        steam_auth_failed.emit("No token in response")
        return
    
    # Sign in to Firebase with custom token
    FirebaseAuth.sign_in_with_custom_token(custom_token)
```

## Dependencies

- **task-399**: Firebase Auth Enhancement (signInWithCustomToken requires base Auth improvements)
- GodotSteam GDExtension 4.4+
- Backend infrastructure (Cloud Functions or custom server)
- Steam Web API key

## Testing Requirements

1. **Unit Tests**: Mock Steam ticket validation
2. **Integration Tests**: Full auth flow with test Steam account
3. **Debug Actions**:
   - `system.steam.init_status` - Check Steam initialization
   - `system.steam.user_info` - Display Steam user data
   - `system.steam.auth_flow` - Test complete authentication flow

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 GodotSteam GDExtension integrated and initializing
- [ ] #2 Steam session tickets generated successfully
- [ ] #3 Backend validates tickets with Steam Web API
- [ ] #4 Firebase custom tokens created from validated tickets
- [ ] #5 signInWithCustomToken() working in C++ module
- [ ] #6 GDScript service layer for Steam auth
- [ ] #7 Account linking (Steam + existing Firebase user)
- [ ] #8 Debug actions for testing Steam auth flow
- [ ] #9 Cross-platform support (Windows, Linux, macOS)
<!-- SECTION:DESCRIPTION:END -->
<!-- AC:END -->
