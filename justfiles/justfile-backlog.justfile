# Backlog Management Justfile
#
# Integrates with backlog.md CLI for task management, project health,
# and development workflow automation.
#
# Usage: just <command> [parameters]

# Core backlog configuration
BACKLOG_DIR := "backlog"
BACKLOG_CLI := "backlog"

# ============================================================================
# TASK LISTING & PROJECT HEALTH
# ============================================================================

# List all To Do tasks
backlog-todo:
    {{BACKLOG_CLI}} tasks list --status "To Do" --plain

# List all In Progress tasks
backlog-in-progress:
    {{BACKLOG_CLI}} tasks list --status "In Progress" --plain

# List high priority tasks
backlog-high-priority:
    @echo "High Priority Tasks:"
    @{{BACKLOG_CLI}} tasks list --plain | grep -E "HIGH|high" || echo "  No high priority tasks found"

# List my assigned tasks (@claude)
backlog-my-tasks:
    {{BACKLOG_CLI}} tasks list -a @claude --plain

# Show recent activity (last 10 tasks)
backlog-recent:
    @echo "Recent Task Activity:"
    @{{BACKLOG_CLI}} tasks list --plain | head -10

# Complete project health overview
backlog-health:
    @echo "=== Project Health Overview ==="
    @{{BACKLOG_CLI}} overview
    @echo ""
    @echo "=== High Priority Tasks ==="
    @{{BACKLOG_CLI}} tasks list --plain | grep -E "HIGH|high" || echo "  No high priority tasks"
    @echo ""
    @echo "=== Current To Do Items ==="
    @{{BACKLOG_CLI}} tasks list --status "To Do" --plain | head -5

# ============================================================================
# TASK SEARCH & ANALYSIS
# ============================================================================

# Search tasks by term
backlog-search-tasks term:
    @echo "Searching for tasks matching: {{term}}"
    @{{BACKLOG_CLI}} tasks list --plain | grep -i "{{term}}" || echo "  No tasks found matching: {{term}}"

# Search tasks by label
backlog-search-labels label:
    @echo "Tasks with label: {{label}}"
    @{{BACKLOG_CLI}} tasks list --plain | grep -i "{{label}}" || echo "  No tasks found with label: {{label}}"

# Show task details
backlog-task-details task_id:
    @echo "=== Task Details ==="
    {{BACKLOG_CLI}} tasks view task-{{task_id}} --plain

# ============================================================================
# TASK CREATION HELPERS
# ============================================================================

# Create a new feature task
# Usage: just backlog-create-feature TITLE="title" DESC="description" AC="criteria1,criteria2"
backlog-create-feature TITLE="" DESC="" AC="" priority="high":
    @echo "Creating feature task..."
    @if [ -z "{{TITLE}}" ]; then echo "ERROR: TITLE required"; exit 1; fi
    @if [ -z "{{DESC}}" ]; then echo "ERROR: DESC required"; exit 1; fi
    @if [ -z "{{AC}}" ]; then echo "ERROR: AC required"; exit 1; fi
    {{BACKLOG_CLI}} task create "{{TITLE}}" -d "{{DESC}}" --ac "{{AC}}" -l feature,backend --priority {{priority}}

# Create a new bugfix task
# Usage: just backlog-create-bugfix TITLE="title" DESC="description" AC="criteria1,criteria2"
backlog-create-bugfix TITLE="" DESC="" AC="" priority="high":
    @echo "Creating bugfix task..."
    @if [ -z "{{TITLE}}" ]; then echo "ERROR: TITLE required"; exit 1; fi
    @if [ -z "{{DESC}}" ]; then echo "ERROR: DESC required"; exit 1; fi
    @if [ -z "{{AC}}" ]; then echo "ERROR: AC required"; exit 1; fi
    {{BACKLOG_CLI}} task create "{{TITLE}}" -d "{{DESC}}" --ac "{{AC}}" -l bugfix,backend --priority {{priority}}

# Create investigation task
# Usage: just backlog-create-investigation TITLE="title" DESC="description"
backlog-create-investigation TITLE="" DESC="" priority="high":
    @echo "Creating investigation task..."
    @if [ -z "{{TITLE}}" ]; then echo "ERROR: TITLE required"; exit 1; fi
    @if [ -z "{{DESC}}" ]; then echo "ERROR: DESC required"; exit 1; fi
    {{BACKLOG_CLI}} task create "{{TITLE}}" -d "{{DESC}}" -l investigation,debug --priority {{priority}}

# Create iOS-related task
# Usage: just backlog-create-ios-task TITLE="title" DESC="description" AC="criteria1,criteria2"
backlog-create-ios-task TITLE="" DESC="" AC="" priority="medium":
    @echo "Creating iOS task..."
    @if [ -z "{{TITLE}}" ]; then echo "ERROR: TITLE required"; exit 1; fi
    @if [ -z "{{DESC}}" ]; then echo "ERROR: DESC required"; exit 1; fi
    @if [ -z "{{AC}}" ]; then echo "ERROR: AC required"; exit 1; fi
    {{BACKLOG_CLI}} task create "{{TITLE}}" -d "{{DESC}}" --ac "{{AC}}" -l ios,testing,bugfix --priority {{priority}}

# Create Android-related task
# Usage: just backlog-create-android-task TITLE="title" DESC="description" AC="criteria1,criteria2"
backlog-create-android-task TITLE="" DESC="" AC="" priority="medium":
    @echo "Creating Android task..."
    @if [ -z "{{TITLE}}" ]; then echo "ERROR: TITLE required"; exit 1; fi
    @if [ -z "{{DESC}}" ]; then echo "ERROR: DESC required"; exit 1; fi
    @if [ -z "{{AC}}" ]; then echo "ERROR: AC required"; exit 1; fi
    {{BACKLOG_CLI}} task create "{{TITLE}}" -d "{{DESC}}" --ac "{{AC}}" -l android,testing,bugfix --priority {{priority}}

# ============================================================================
# TASK STATUS MANAGEMENT
# ============================================================================

# Start working on a task
# Usage: just backlog-task-start 123
backlog-task-start task_id:
    @echo "Starting task: task-{{task_id}}"
    @if [ -z "{{task_id}}" ]; then echo "ERROR: task_id required"; exit 1; fi
    {{BACKLOG_CLI}} task edit task-{{task_id}} --status "In Progress"

# Mark task as done
# Usage: just backlog-task-done 123
backlog-task-done task_id:
    @echo "Completing task: task-{{task_id}}"
    @if [ -z "{{task_id}}" ]; then echo "ERROR: task_id required"; exit 1; fi
    {{BACKLOG_CLI}} task edit task-{{task_id}} --status Done

# Put task back to To Do
# Usage: just backlog-task-todo 123
backlog-task-todo task_id:
    @echo "Moving task to To Do: task-{{task_id}}"
    @if [ -z "{{task_id}}" ]; then echo "ERROR: task_id required"; exit 1; fi
    {{BACKLOG_CLI}} task edit task-{{task_id}} --status "To Do"

# ============================================================================
# TASK EDITING HELPERS
# ============================================================================

# Add labels to a task
# Usage: just backlog-task-add-labels 123 "label1,label2"
backlog-task-add-labels task_id labels:
    @echo "Adding labels to task-{{task_id}}: {{labels}}"
    @if [ -z "{{task_id}}" ]; then echo "ERROR: task_id required"; exit 1; fi
    @if [ -z "{{labels}}" ]; then echo "ERROR: labels required"; exit 1; fi
    {{BACKLOG_CLI}} task edit task-{{task_id}} -l {{labels}}

# Set task priority
# Usage: just backlog-task-set-priority 123 "high"
backlog-task-set-priority task_id priority:
    @echo "Setting priority for task-{{task_id}}: {{priority}}"
    @if [ -z "{{task_id}}" ]; then echo "ERROR: task_id required"; exit 1; fi
    @if [ -z "{{priority}}" ]; then echo "ERROR: priority required"; exit 1; fi
    {{BACKLOG_CLI}} task edit task-{{task_id}} --priority {{priority}}

# Add notes to a task
# Usage: just backlog-task-add-notes 123 "implementation notes"
backlog-task-add-notes task_id notes:
    @echo "Adding notes to task-{{task_id}}"
    @if [ -z "{{task_id}}" ]; then echo "ERROR: task_id required"; exit 1; fi
    @if [ -z "{{notes}}" ]; then echo "ERROR: notes required"; exit 1; fi
    {{BACKLOG_CLI}} task edit task-{{task_id}} --notes "{{notes}}"

# ============================================================================
# WORKFLOW INTEGRATION
# ============================================================================

# Quick task status check
# Usage: just backlog-task-status TASK_ID=123
backlog-task-status TASK_ID="":
    @echo "Task status: task-{{TASK_ID}}"
    @if [ -z "{{TASK_ID}}" ]; then echo "ERROR: TASK_ID required"; exit 1; fi
    @echo "---"
    {{BACKLOG_CLI}} tasks view task-{{TASK_ID}} --plain | grep -E "(status|priority|labels)" || echo "  Task not found"

# Create task from test failure
# Usage: just backlog-task-from-test-failure TEST_ID="abc123" ISSUE="description" ROOT_CAUSE="analysis"
backlog-task-from-test-failure TEST_ID="" ISSUE="" ROOT_CAUSE="":
    @echo "Creating task from test failure: {{TEST_ID}}"
    @if [ -z "{{TEST_ID}}" ]; then echo "ERROR: TEST_ID required"; exit 1; fi
    @if [ -z "{{ISSUE}}" ]; then echo "ERROR: ISSUE description required"; exit 1; fi
    @echo "Investigating root cause: {{ROOT_CAUSE}}"
    {{BACKLOG_CLI}} task create "Fix test failure in {{TEST_ID}}" \
        -d "Test {{TEST_ID}} failed: {{ISSUE}}" \
        --ac "Test passes,Root cause fixed,Regression test added" \
        -l bugfix,testing,high-priority \
        --priority high

# Create task from logs analysis
# Usage: just backlog-task-from-logs ISSUE="description" EVIDENCE="log evidence"
backlog-task-from-logs ISSUE="" EVIDENCE="":
    @echo "Creating task from logs analysis"
    @if [ -z "{{ISSUE}}" ]; then echo "ERROR: ISSUE description required"; exit 1; fi
    @if [ -z "{{EVIDENCE}}" ]; then echo "ERROR: EVIDENCE required"; exit 1; fi
    {{BACKLOG_CLI}} task create "Fix: {{ISSUE}}" \
        -d "Issue discovered through log analysis: {{EVIDENCE}}" \
        --ac "Issue resolved,No regression,Logs show success" \
        -l bugfix,debug,investigation \
        --priority medium

# ============================================================================
# BATCH OPERATIONS
# ============================================================================

# List tasks by priority
backlog-list-by-priority priority="high":
    @echo "Tasks with {{priority}} priority:"
    {{BACKLOG_CLI}} tasks list --plain | grep -E "{{priority}}" || echo "  No {{priority}} priority tasks"

# List tasks by assignee
backlog-list-by-assignee assignee="@claude":
    @echo "Tasks assigned to {{assignee}}:"
    {{BACKLOG_CLI}} tasks list -a {{assignee}} --plain

# Count tasks by status (simplified - avoids shell substitution issues)
backlog-count-tasks:
    @echo "=== Task Count by Status ==="
    @echo "Use 'backlog overview' for detailed task counts"
    @echo "Quick status check:"
    @echo "  To Do: $({{BACKLOG_CLI}} tasks list --status 'To Do' --plain | wc -l | tr -d ' ')"
    @echo "  In Progress: $({{BACKLOG_CLI}} tasks list --status 'In Progress' --plain | wc -l | tr -d ' ')"
    @echo "  Done: $({{BACKLOG_CLI}} tasks list --status 'Done' --plain | wc -l | tr -d ' ')"

# ============================================================================
# UTILITIES
# ============================================================================

# Show backlog configuration
backlog-config:
    @echo "=== Backlog Configuration ==="
    @if [ -f "{{BACKLOG_DIR}}/config.yml" ]; then cat {{BACKLOG_DIR}}/config.yml; else echo "  No config.yml found"; fi

# Validate backlog CLI installation
backlog-check:
    @echo "=== Backlog CLI Check ==="
    @if command -v {{BACKLOG_CLI}} >/dev/null 2>&1; then echo "✅ Backlog CLI installed: $(which {{BACKLOG_CLI}})"; else echo "❌ Backlog CLI not found"; exit 1; fi
    @if [ -d "{{BACKLOG_DIR}}" ]; then echo "✅ Backlog directory found: {{BACKLOG_DIR}}"; else echo "❌ Backlog directory not found"; exit 1; fi

# Help for backlog commands
help-backlog:
    @echo "=== Backlog Management Commands ==="
    @echo ""
    @echo "Task Management:"
    @echo "  backlog-todo                    - List To Do tasks"
    @echo "  backlog-in-progress              - List In Progress tasks"
    @echo "  backlog-high-priority            - List high priority tasks"
    @echo "  backlog-my-tasks                - List my assigned tasks"
    @echo "  backlog-recent                  - Show recent activity"
    @echo "  backlog-health                  - Complete project overview"
    @echo ""
    @echo "Task Creation:"
    @echo "  backlog-create-feature TITLE=... DESC=... AC=...        - Create feature task"
    @echo "  backlog-create-bugfix TITLE=... DESC=... AC=...         - Create bugfix task"
    @echo "  backlog-create-investigation TITLE=... DESC=...          - Create investigation task"
    @echo "  backlog-create-ios-task TITLE=... DESC=... AC=...        - Create iOS task"
    @echo "  backlog-create-android-task TITLE=... DESC=... AC=...    - Create Android task"
    @echo ""
    @echo "Task Status:"
    @echo "  backlog-task-start 123...               - Start working on task"
    @echo "  backlog-task-done 123...                - Mark task as complete"
    @echo "  backlog-task-todo 123...                - Move task back to To Do"
    @echo ""
    @echo "Task Editing:"
    @echo "  backlog-task-add-labels 123 'label1,label2' - Add labels to task"
    @echo "  backlog-task-set-priority 123 'high'    - Set task priority"
    @echo "  backlog-task-add-notes 123 'implementation notes' - Add notes to task"
    @echo ""
    @echo "Search & Analysis:"
    @echo "  backlog-search-tasks term=...           - Search tasks by term"
    @echo "  backlog-search-labels label=...         - Search tasks by label"
    @echo "  backlog-task-details 123...             - Show task details"
    @echo "  backlog-task-status 123...             - Quick task status check"
    @echo ""
    @echo "Workflow Integration:"
    @echo "  backlog-task-from-test-failure TEST_ID=... ISSUE=... ROOT_CAUSE=... - Create task from test failure"
    @echo "  backlog-task-from-logs ISSUE=... EVIDENCE=...                       - Create task from logs analysis"
    @echo ""
    @echo "Utilities:"
    @echo "  help-backlog                   - Show this help"
    @echo "  backlog-check                  - Validate backlog CLI installation"
    @echo "  backlog-config                  - Show backlog configuration"
    @echo "  backlog-count-tasks                   - Count tasks by status"
    @echo "  backlog-list-by-priority priority=...   - List tasks by priority level"
    @echo "  backlog-list-by-assignee assignee=... - List tasks by assignee"

# Default help when no command specified (commented out to avoid conflicts)
# default:
#     @just help-backlog