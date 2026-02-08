---
allowed-tools: Bash(bd:*), Read, Bash(ls:*), Grep
description: Create an issue from the most recent build or test failure
---

# Create Issue from Failure

Create a bd issue from the most recent build or test failure.

## Steps

1. Find the most recent log file:
   ```bash
   ls -t build/logs/ | head -5
   ```

2. Read the most recent log to find failures:
   - For test logs: look for "FAILED" or "error:" lines
   - For build logs: look for "error:" lines

3. Extract failure information:
   - Error message
   - File and line number if available
   - Test name if it's a test failure

4. Create the issue:
   ```bash
   bd create "<title>" -t bug -p <priority> -d "<description>"
   ```

   Priority guidelines:
   - P1 for build failures (blocks all development)
   - P2 for test failures (functionality broken)

5. Sync to git:
   ```bash
   bd sync
   ```

## Issue Format

Title: `[Build/Test] <brief error description>`

Description should include:
- Error message
- File location (if known)
- Steps to reproduce (run ./build.sh or ./test.sh)
- Log file reference

## Output

Confirm:
- Issue created with ID
- Priority set appropriately
- Synced to git
