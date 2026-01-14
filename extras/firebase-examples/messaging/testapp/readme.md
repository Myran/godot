Firebase Cloud Messaging Quickstart
===================================

The Firebase Messaging C++ Sample (hereafter the 'test app') demonstrates receiving messages from [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging/)
using the [Firebase C++ SDK](https://firebase.google.com/docs/cpp/setup). This
application has no user interface and simply logs actions it's performing to the
console.

## Set up, build and run the test app

> **_NOTE:_** Do not implement the code changes of the subsequent linked instructions as this codebase already has those functionalities.

1. Complete [Add Firebase to your C++ project](https://firebase.google.com/docs/cpp/setup) for your selected build platforms.
1. [Set up a Firebase Cloud Messaging client app with C++](https://firebase.google.com/docs/cloud-messaging/cpp/client).

### Running the test app
----------------------

- Install and run the test app on your iOS or Android device or emulator.
- The application has minimal user interface. The output of the app can be
viewed via the console:
    * **iOS**: Open select "View -> Debug Area -> Activate Console" from the
    menu in Xcode.
    * **Android**: View the logcat output in Android studio or by running
    `adb logcat` from the command line.
- When you first run the app, it will print:
`Received Registration Token: <code>`. Copy this code to a text editor.

### Send a message from your server environment
-----------------------------------------------

1. Navigate to the FCM REST API Docs for [Method: projects.messages.send](https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages/send)
1. Look for the "Try this method" panel
    1. This might require you to expand your browser window.
1. Follow the API doc to understand what IDs and fields to fill in  for your particular use case.
    1. Your project number is available from [Project settings](https://console.firebase.google.com/project/_/settings/general)
1. Fill in the `Request body` referencing the [FCM REST API docs](https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages).
1. Execute.
1. Observe the command received in the app, via the console output.

Reminder, while this process is currently done from our website, it uses the FCM v1 Send API directly and provides the simplest starting point to switch to using the v1 Send API or the Firebase Admin SDK in production.

## Troubleshooting and Support
- [Firebase Cloud Messaging troubleshooting & FAQ](https://firebase.google.com/docs/cloud-messaging/troubleshooting)
- [Firebase Support](https://firebase.google.com/support/)

License
-------

Copyright 2016 Google, Inc.

Licensed to the Apache Software Foundation (ASF) under one or more contributor
license agreements.  See the NOTICE file distributed with this work for
additional information regarding copyright ownership.  The ASF licenses this
file to you under the Apache License, Version 2.0 (the "License"); you may not
use this file except in compliance with the License.  You may obtain a copy of
the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
License for the specific language governing permissions and limitations under
the License.
