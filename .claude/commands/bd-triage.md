---
allowed-tools: Bash(bd:*)
description: Triage open issues - group by priority and suggest next action
---

# Issue Triage

Review and prioritize open issues in the bd issue tracker.

## Steps

1. Get all open issues:
   ```bash
   bd list
   ```

2. Get issues ready to work on (no blockers):
   ```bash
   bd ready
   ```

3. Get blocked issues:
   ```bash
   bd blocked
   ```

## Analysis Required

After gathering the issue data:

1. **Group by Priority**: Organize issues into P1 (critical), P2 (medium), P3 (low)
2. **Group by Type**: Separate bugs, features, and tasks
3. **Identify Blockers**: Note which issues are blocked and by what
4. **Recommend Next Action**: Suggest which issue to tackle next based on:
   - Highest priority first (P1 > P2 > P3)
   - Bugs before features
   - Ready issues before blocked ones

## Output Format

Present a clear summary:
- Total open issues count
- Count by priority (P1: X, P2: Y, P3: Z)
- Count by type (bugs: X, features: Y, tasks: Z)
- Ready vs blocked counts
- **Recommended next issue** with brief rationale
