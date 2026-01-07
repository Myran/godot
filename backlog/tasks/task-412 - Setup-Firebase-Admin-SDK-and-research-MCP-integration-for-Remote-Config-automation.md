---
id: task-412
title: >-
  Setup Firebase Admin SDK and research MCP integration for Remote Config
  automation
status: Done
assignee: []
created_date: '2026-01-02 20:16'
updated_date: '2026-01-06 23:08'
labels: []
dependencies:
  - task-411
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Setup Firebase Admin SDK and evaluate firebase-mcp for Remote Config automation

**Research Findings:**
- gannonh/firebase-mcp exists on GitHub (v2.0 released May 2025)
- Enables AI assistants to work directly with Firebase services via MCP
- Works with Claude Desktop
- Source: https://github.com/gannonh/firebase-mcp

**Acceptance Criteria:**
- [ ] Research firebase-mcp capabilities for Remote Config management
- [ ] Evaluate if firebase-mcp supports condition management (add/delete/list)
- [ ] Set up Firebase Admin SDK service account key
- [ ] Test Remote Config template operations (get, validate, publish)
- [ ] Document the workflow for modifying Remote Config programmatically
- [ ] If firebase-mcp supports conditions, remove iOS platform targeting for max_players, retry_count, welcome_message, app_name

**Resources:**
- Firebase MCP: https://github.com/gannonh/firebase-mcp
- Firebase Admin SDK docs: https://firebase.google.com/docs/remote-config/automate-rc
- Firebase Studio MCP docs: https://firebase.google.com/docs/studio/mcp-servers

**Dependencies:**
- task-411 (iOS Remote Config test failures - root cause identified)
<!-- SECTION:DESCRIPTION:END -->
