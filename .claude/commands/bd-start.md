---
allowed-tools: Bash(bd:*)
argument-hint: <issue-id>
description: Start working on an issue - set status to in_progress and show context
---

# Start Working on Issue

Begin work on issue: **$ARGUMENTS**

## Steps

1. Show full issue details:
   ```bash
   bd show $ARGUMENTS
   ```

2. Update status to in_progress:
   ```bash
   bd update $ARGUMENTS --status in_progress
   ```

3. Sync changes to git:
   ```bash
   bd sync
   ```

## Context to Provide

After fetching issue details, provide:

1. **Issue Summary**: Title, priority, type
2. **Description**: Full issue description
3. **Acceptance Criteria**: What defines "done" for this issue
4. **Related Issues**: Any blocking or related issues
5. **Relevant Files**: If mentioned in description, list files to examine

## Ready to Work

Once status is updated and synced, confirm:
- Issue is now marked as in_progress
- Changes synced to git
- Ready to begin implementation

Ask if there's anything specific about the issue that needs clarification before starting.
