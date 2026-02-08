---
allowed-tools: Bash(bd:*), Bash(git:*)
argument-hint: <issue-id> [commit-message]
description: Create a git commit linked to an issue
---

# Commit Linked to Issue

Create a git commit that references issue: **$1**

## Steps

1. Show the issue for context:
   ```bash
   bd show $1
   ```

2. Check git status:
   ```bash
   git status
   ```

3. Stage changes (ask user which files if unclear):
   ```bash
   git add <files>
   ```

4. Create commit with issue reference:

   The commit message should:
   - Reference the issue ID in the message
   - Use "Fixes $1" or "Closes $1" if this commit fully resolves the issue
   - Use "Refs $1" or "Related to $1" for partial progress

   ```bash
   git commit -m "<message>

   Refs $1"
   ```

5. If commit message contains "Fixes" or "Closes", close the issue:
   ```bash
   bd close $1 --reason "Fixed in commit <hash>"
   bd sync
   ```

6. Otherwise just sync:
   ```bash
   bd sync
   ```

## Commit Message Guidelines

Good commit messages:
- Start with verb: "Fix", "Add", "Update", "Remove"
- Reference the issue: "Fix sequencer crash (Fixes Vox-xxx)"
- Keep first line under 72 characters

## Note

This command does NOT push to remote. Run `git push` separately after reviewing.
