---
allowed-tools: Bash(bd:*)
description: Show project issue status overview and health check
---

# Project Status Overview

Quick health check of the issue tracker.

## Steps

1. Get database overview:
   ```bash
   bd status
   ```

2. List all open issues:
   ```bash
   bd list
   ```

3. Show stale issues (not updated recently):
   ```bash
   bd stale
   ```

4. Show ready issues (no blockers):
   ```bash
   bd ready
   ```

## Output Format

Present a dashboard-style summary:

### Issue Counts
- Total open issues
- By priority: P1 (critical), P2 (medium), P3 (low)
- By type: bugs, features, tasks
- By status: open, in_progress, blocked

### Health Indicators
- Any P1 issues? (urgent attention needed)
- Issues in_progress? (work underway)
- Stale issues? (may need review)
- Blocked issues? (dependencies to resolve)

### Recommendations
- If P1 issues exist: highlight them as needing immediate attention
- If no issues in_progress: suggest starting one
- If stale issues exist: suggest reviewing or closing them
