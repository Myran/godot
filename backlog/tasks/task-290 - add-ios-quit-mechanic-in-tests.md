---
id: task-290
title: add ios quit mechanic in tests
status: To Do
assignee: []
created_date: '2025-11-17 22:49'
updated_date: '2025-11-17 22:50'
labels: []
dependencies: []
---

## Description
Q: How do I programmatically quit my iOS application?
There is no API provided for gracefully terminating an iOS application.

In iOS, the user presses the Home button to close applications. Should your application have conditions in which it cannot provide its intended function, the recommended approach is to display an alert for the user that indicates the nature of the problem and possible actions the user could take — turning on WiFi, enabling Location Services, etc. Allow the user to terminate the application at their own discretion.

WARNING: Do not call the exit function. Applications calling exit will appear to the user to have crashed, rather than performing a graceful termination and animating back to the Home screen.

Additionally, data may not be saved, because -applicationWillTerminate: and similar UIApplicationDelegate methods will not be invoked if you call exit.

If during development or testing it is necessary to terminate your application, the abort function, or assert macro is recommended
