---
allowed-tools: Bash(bd:*)
argument-hint: <issue-id> [close-reason]
description: Close an issue with proper documentation
---

# Close Issue

Close issue: **$1**

## Steps

1. Show current issue details:
   ```bash
   bd show $1
   ```

2. Close the issue with reason:
   ```bash
   bd close $1 --reason "$2"
   ```

   If no reason provided in arguments, ask the user for a brief close reason before running the close command.

3. Sync changes to git:
   ```bash
   bd sync
   ```

4. Check if any issues were blocked by this one:
   ```bash
   bd list
   ```

## Close Reason Guidelines

If user didn't provide a reason, prompt for one. Good close reasons include:
- What was done to resolve the issue
- Which commit or PR fixed it
- If not fixed, why it's being closed (won't fix, duplicate, etc.)

## Post-Close Actions

After closing:
- Confirm issue is closed
- List any issues that were blocked by this one (now potentially unblocked)
- Confirm sync completed
