# Backlog Management with Claude Code

**Essential CLI tool for project task management with comprehensive task creation, editing, and workflow integration.**

## 🚀 Quick Start

**Core Commands:**
```bash
backlog overview                    # Project statistics and health
backlog tasks list --plain          # List all tasks (AI-friendly)
backlog tasks view task-XXX --plain # View task details
backlog task create "Title"         # Create new task
backlog task edit task-XXX          # Edit existing task
backlog task edit task-XXX --status Done  # Update status (REQUIRED)
```

**🚨 CRITICAL: Use CLI Commands, Not Direct File Editing**

Backlog maintains a separate database that doesn't sync with direct markdown edits.

## 📋 Task Creation Workflow

**1. Create Task with Essential Parameters:**
```bash
backlog task create "Implement feature name" \
  -d "Clear description of what needs to be done" \
  --ac "First measurable outcome,Second outcome" \
  -l feature,backend \
  --priority high
```

**2. Set Dependencies (if needed):**
```bash
backlog task edit task-XXX --dep task-123 --dep task-456
```

**3. Update Status:**
```bash
backlog task edit task-XXX --status "In Progress"  # When starting
backlog task edit task-XXX --status Done          # When complete (REQUIRED)
```

## 🎯 Task Structure Standards

**High-Quality Task Anatomy:**
```markdown
# task-XXX - Brief imperative title

## Description (The WHY)
Clear explanation of purpose and business context.
Avoid implementation details and technical jargon.

## Acceptance Criteria (The WHAT)
- [ ] Measurable outcome 1 (testable/verifiable)
- [ ] User-facing behavior 2 (observable)
- [ ] Performance requirement 3 (quantifiable)
```

**Title Guidelines:**
- ✅ "Fix Firebase authentication timeout"
- ✅ "Add user profile management system"
- ✅ "Implement battle replay validation"
- ❌ "Auth fix" (too vague)
- ❌ "Work on profile" (not actionable)
- ❌ "Debug issue" (not specific)

**Acceptance Criteria Best Practices:**
- **Outcome-Focused**: "User can login with Google credentials" vs "Add Google OAuth"
- **Testable**: Each criterion can be objectively verified
- **Atomic**: Single task = single pull request scope
- **Complete**: ACs cover entire task scope

## 🔄 Status Management

**Status Flow:** `Consider` → `To Do` → `In Progress` → `Done`

**Critical Rules:**
1. **ALWAYS update status** using CLI commands: `backlog task edit task-XXX --status Done`
2. **NEVER edit status directly** in markdown files (won't sync to database)
3. **Status changes trigger** automated workflow actions
4. **Required for sync** - CLI updates maintain database consistency

## 🔗 Dependency Management

**Creating Dependencies:**
```bash
# During task creation
backlog task create "Feature" --dep task-123,task-456

# Adding to existing task
backlog task edit task-XXX --dep task-123 --dep task-456
```

**Dependency Rules:**
- **Forward Only**: Tasks can only depend on tasks with lower IDs (already created)
- **No Future Dependencies**: Cannot depend on tasks that don't exist yet
- **Avoid Circular Dependencies**: System prevents circular references
- **Keep Dependencies Minimal**: Prefer independent tasks when possible

**Task Ordering Strategy:**
1. **Foundation First**: Infrastructure before features
2. **Independent Tasks**: Maximize parallel development
3. **Clear Dependencies**: Explicit blockers vs. nice-to-have prerequisites
4. **Priority-Based**: Use priority levels for importance within dependencies

## 📊 Project Health & Analytics

**Project Overview:**
```bash
backlog overview                    # Shows:
# - Completion rate (223/254 = 88%)
# - Status breakdown (To Do, In Progress, Done)
# - Priority distribution (High, Medium, Low)
# - Recent activity and stale tasks
# - Blocked tasks and dependencies
```

**Health Indicators:**
- **Completion Rate**: Above 80% is healthy
- **Stale Tasks**: >30 days without updates needs attention
- **Blocked Tasks**: Dependencies preventing progress
- **Balance**: Mix of foundation, feature, and maintenance tasks

## 🏷️ Labels & Prioritization

**Priority Levels:**
```bash
--priority high    # Critical infrastructure, release blockers
--priority medium   # Important features, architectural improvements
--priority low      # Nice-to-have, optimizations, cleanup
```

**Common Labels:**
```bash
-l feature,backend        # Feature development
-l bugfix,frontend       # Bug fixes by component
-l infrastructure,devops  # Build/deployment systems
-l documentation,research   # Documentation and investigation
-l testing,quality        # Quality assurance
```

**Label Strategy:**
- **Consistent Naming**: Use established label patterns
- **Multi-dimensional**: Combine priority, component, and type labels
- **Searchable**: Labels enable filtering and reporting

## 🔍 Task Discovery & Analysis

**Find Tasks:**
```bash
# By status
backlog tasks list --status "To Do"

# By assignee
backlog tasks list -a @claude

# Combined filters
backlog tasks list --status "To Do" -l high,backend
```

**Task Analysis:**
```bash
# Quick view (AI-friendly)
backlog tasks view task-XXX --plain

# Interactive view (for detailed editing)
backlog tasks view task-XXX        # Press 'E' to edit in editor
```

**Pattern Matching:**
```bash
# Find related tasks
backlog tasks list --plain | grep "firebase"
backlog tasks list --plain | grep "high"
```

## 🛠️ Integration with Development Workflow

### **Git Integration**
**Commit Message Format:**
```bash
git commit -m "$(cat <<'EOF'
fix: resolve Firebase authentication timeout

Add proper error handling and retry logic for Firebase Auth
timeouts occurring on poor network connections.

Closes: task-123
Related: backlog/tasks/task-123-resolve-firebase-timeout.md

🤖 Generated with [Claude Code](https://claude.com/claude-code)
Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

**Bidirectional Linking:**
1. **Commit → Task**: Reference task ID in commit message
2. **Task → Commit**: Add commit hash to task's implementation notes

### **Justfile Integration**
**Task-Centric Justfile Commands:**
```makefile
# Task management shortcuts
backlog-todo:
    @backlog tasks list --status "To Do" --plain

backlog-my-tasks:
    @backlog tasks list -a @claude --plain

backlog-high-priority:
    @backlog tasks list --plain | grep HIGH

# Task creation helpers
task-feature:
    @backlog task create "$(FEATURE)" -d "$(DESC)" --ac "$(AC)" -l feature,backend --priority high

task-bugfix:
    @backlog task create "$(BUGFIX)" -d "$(DESC)" --ac "$(AC)" -l bugfix --priority high
```

### **Development Workflow Integration**
**OODA Loop with Backlog:**

**OBSERVE:**
```bash
backlog overview                    # Project health
backlog tasks list --status "In Progress"  # Current work
```

**ORIENT:**
```bash
backlog tasks view task-XXX --plain # Task details
just logs-errors TEST_ID             # Debug analysis
```

**DECIDE:**
```bash
# Create investigation task
backlog task create "Investigate issue" \
  -d "Analyze root cause based on evidence" \
  -l investigation,debug \
  --priority high
```

**ACT:**
```bash
backlog task edit task-XXX --status "In Progress"  # Start work
# Complete implementation
backlog task edit task-XXX --status Done           # Mark complete
```

## 📚 Advanced Features

### **Draft Tasks**
**Create Investigation Tasks:**
```bash
# Create draft for research
backlog task create "Investigate performance issue" --draft

# Promote to full task
backlog draft promote task-XXX
```

### **Task Relationships**
**Parent-Child Tasks:**
```bash
# Create subtask
backlog task create "Implementation detail" -p task-123

# View subtasks
backlog tasks list --parent task-123
```

### **Bulk Operations**
**Multiple Task Updates:**
```bash
# Batch status updates
for task in 123 124 125; do
    backlog task edit task-$task --status Done
done
```

## 🎯 Best Practices

### **Task Creation**
1. **Start with WHY**: Business purpose before technical implementation
2. **Make Testable**: Each AC must be verifiable
3. **Keep Atomic**: One task = one PR
4. **Avoid Dependencies**: Prefer independent tasks
5. **Use Standard Format**: Consistent structure improves readability

### **Task Management**
1. **Update Status Daily**: Keep task status current
2. **Use CLI Commands**: Never edit markdown files directly
3. **Link to Commits**: Bidirectional linking for traceability
4. **Review Dependencies**: Ensure they're necessary and minimal
5. **Archive Completed**: Use `backlog task archive` for cleanup

### **Project Health**
1. **Monitor Completion Rate**: Aim for 80%+ completion
2. **Watch Stale Tasks**: Address tasks >30 days old
3. **Balance Priorities**: Mix of high/medium/low priority work
4. **Regular Reviews**: Weekly task planning and dependency management

## 🚨 Common Pitfalls to Avoid

**❌ Direct File Editing:**
```bash
# WRONG - Won't sync to database
echo "status: Done" >> backlog/tasks/task-123.md

# CORRECT - Updates database
backlog task edit task-123 --status Done
```

**❌ Vague Task Titles:**
- ❌ "Fix auth" → ✅ "Fix Firebase authentication timeout"
- ❌ "Work on UI" → ✅ "Implement user profile edit form"
- ❌ "Debug crash" → ✅ "Fix SIGSEGV in battle animation system"

**❌ Implementation-Focused ACs:**
- ❌ "- [ ] Add new function to auth.js"
- ✅ "- [ ] User can successfully login with valid credentials"

**❌ Future Dependencies:**
```bash
# WRONG - Depends on non-existent task
backlog task create "Feature" --dep task-999

# CORRECT - Depends on existing tasks only
backlog task create "Feature" --dep task-123 --dep task-456
```

## 📖 Integration Documentation

**Related Documentation:**
- `../CLAUDE.md` - Main project development patterns
- `../justfiles/CLAUDE.md` - Build system and justfile commands
- `../project/CLAUDE.md` - GDScript development patterns
- `../tests/CLAUDE.md` - Testing infrastructure patterns

**Workflow Examples:**
- **Feature Development**: Task creation → Implementation → Testing → Documentation
- **Bug Investigation**: Create investigation task → Root cause analysis → Fix implementation
- **Architecture Work**: Research task → Design task → Implementation tasks
- **Release Preparation**: Feature completion → Testing → Documentation → Release tasks

## 🔗 GameTwo Justfile Integration

### **Task Management Shortcuts**
**Add to justfile-core.justfile or create justfile-backlog.justfile:**
```makefile
# Task listing and management
backlog-todo:
    @backlog tasks list --status "To Do" --plain

backlog-in-progress:
    @backlog tasks list --status "In Progress" --plain

backlog-high-priority:
    @backlog tasks list --plain | grep -E "HIGH|high" || echo "No high priority tasks"

backlog-my-tasks:
    @backlog tasks list -a @claude --plain

backlog-recent:
    @backlog tasks list --plain | head -10

# Task creation helpers
task-create:
    @echo "Usage: make task-create FEATURE='title' DESC='description' AC='criteria1,criteria2'"
    @if [ -z "$(FEATURE)" ]; then echo "ERROR: FEATURE required"; exit 1; fi
    @backlog task create "$(FEATURE)" -d "$(DESC)" --ac "$(AC)" -l feature,backend --priority high

task-bugfix:
    @echo "Usage: make task-bugfix BUG='title' DESC='description' AC='criteria1,criteria2'"
    @if [ -z "$(BUG)" ]; then echo "ERROR: BUG required"; exit 1; fi
    @backlog task create "$(BUG)" -d "$(DESC)" --ac "$(AC)" -l bugfix,backend --priority high

task-investigation:
    @echo "Usage: make task-investigation TITLE='title' DESC='description'"
    @if [ -z "$(TITLE)" ]; then echo "ERROR: TITLE required"; exit 1; fi
    @backlog task create "$(TITLE)" -d "$(DESC)" -l investigation,debug --priority high

# Status management
task-done:
    @echo "Usage: make task-done TASK=XXX"
    @if [ -z "$(TASK)" ]; then echo "ERROR: TASK required"; exit 1; fi
    @backlog task edit task-$(TASK) --status Done

task-start:
    @echo "Usage: make task-start TASK=XXX"
    @if [ -z "$(TASK)" ]; then echo "ERROR: TASK required"; exit 1; fi
    @backlog task edit task-$(TASK) --status "In Progress"

# Project health
backlog-health:
    @echo "=== Project Overview ==="
    @backlog overview
    @echo ""
    @echo "=== High Priority Tasks ==="
    @backlog tasks list --plain | grep -E "HIGH|high" || echo "No high priority tasks"
    @echo ""
    @echo "=== Recent Activity ==="
    @backlog tasks list --plain | head -5

# Task search and analysis
search-tasks:
    @echo "Usage: make search-tasks TERM='search term'"
    @if [ -z "$(TERM)" ]; then echo "ERROR: TERM required"; exit 1; fi
    @backlog tasks list --plain | grep -i "$(TERM)" || echo "No tasks found matching: $(TERM)"
```

### **Development Workflow Integration**

**OODA Loop with Backlog + Justfiles:**

**OBSERVE (Project Health):**
```bash
just backlog-health        # Project overview and high priority tasks
just backlog-todo          # Current To Do items
just logs-last            # Latest test results
```

**ORIENT (Task Analysis):**
```bash
just search-tasks TERM="firebase"  # Find relevant tasks
backlog tasks view task-XXX --plain  # Detailed task analysis
just logs-errors TEST_ID               # Debug analysis
```

**DECIDE (Task Planning):**
```bash
# Create investigation task
just task-investigation TITLE="Investigate Firebase timeout" \
  DESC="Analyze root cause of Firebase authentication timeouts" \
  AC="Root cause identified,Fix implemented,Tests pass"

# Start work on existing task
just task-start TASK=123
```

**ACT (Implementation + Testing):**
```bash
# Development workflow
just ci-validate                    # Code quality
just fastbuild-android              # Build
just test-android-target CONFIG     # Test
just task-done TASK=123            # Mark complete
```

### **Git Integration Patterns**

**Enhanced Commit Workflow:**
```makefile
# Add to justfile-core.justfile
commit-with-task:
    @echo "Usage: make commit-with-task TASK=XXX MESSAGE='commit message'"
    @if [ -z "$(TASK)" ]; then echo "ERROR: TASK required"; exit 1; fi
    @if [ -z "$(MESSAGE)" ]; then echo "ERROR: MESSAGE required"; exit 1; fi
    @git add -A
    @git commit -m "$(MESSAGE)

    # Update task with commit reference
    @backlog task edit task-$(TASK) --notes "Implemented in $(git rev-parse --short HEAD): $(MESSAGE)"

# Quick commit for backlog tasks
commit-task-complete:
    @echo "Usage: make commit-task-complete TASK=XXX"
    @if [ -z "$(TASK)" ]; then echo "ERROR: TASK required"; exit 1; fi
    @backlog tasks view task-$(TASK) --plain > /tmp/task_$(TASK).txt
    @TITLE=$$(head -1 /tmp/task_$(TASK).txt | sed 's/Task task-$(TASK) - //')
    @git add -A
    @git commit -m "Complete $(TITLE)

    Closes: task-$(TASK)

    🤖 Generated with [Claude Code](https://claude.com/claude-code)

    Co-Authored-By: Claude <noreply@anthropic.com>"
    @backlog task edit task-$(TASK) --status Done
    @rm /tmp/task_$(TASK).txt
```

### **Testing Integration**

**Test-Driven Task Management:**
```makefile
# Create task from test failure
task-from-test-failure:
    @echo "Usage: make task-from-test-failure TEST_ID=XXX DESCRIPTION='issue description'"
    @if [ -z "$(TEST_ID)" ]; then echo "ERROR: TEST_ID required"; exit 1; fi
    @if [ -z "$(DESCRIPTION)" ]; then echo "ERROR: DESCRIPTION required"; exit 1; fi
    @backlog task create "Fix test failure in $(TEST_ID)" \
      -d "$(DESCRIPTION)" \
      --ac "Test passes,Root cause fixed,Regression test added" \
      -l bugfix,testing,high-priority \
      --priority high

# Validate task completion with testing
validate-task-completion:
    @echo "Usage: make validate-task-completion TASK=XXX CONFIG='test-config'"
    @if [ -z "$(TASK)" ]; then echo "ERROR: TASK required"; exit 1; fi
    @if [ -z "$(CONFIG)" ]; then echo "ERROR: CONFIG required"; exit 1; fi
    @echo "Running tests for task-$(TASK) with config: $(CONFIG)"
    @just test-android-target $(CONFIG)
    @echo "Check test results with: just logs-errors $$(just logs-last | tail -1)"
    @echo "If tests pass, run: just task-done TASK=$(TASK)"
```

---

**This backlog system integrates with GameTwo's development workflow to provide structured, trackable project management with bidirectional Git linking and comprehensive task lifecycle management.**