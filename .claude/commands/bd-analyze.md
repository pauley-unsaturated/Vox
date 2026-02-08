---
allowed-tools: Bash(bd:*)
description: Find duplicate issues and identify root causes across related issues
---

# Issue Analysis - Find Duplicates & Root Causes

Analyze open issues to find duplicates, related issues, and underlying root causes that could fix multiple problems at once.

## Steps

1. Get all open issues with full details:
   ```bash
   bd list --json
   ```

2. Check for potential duplicates:
   ```bash
   bd duplicates
   ```

3. For each potential group, show details:
   ```bash
   bd show <issue-id>
   ```

## Analysis Required

After gathering issue data, analyze for:

### 1. Duplicate Detection
- Issues with similar titles or descriptions
- Issues affecting the same file or component
- Issues with the same error message or symptom

### 2. Related Issue Clusters
- Group issues that touch the same subsystem
- Identify issues that might have a common root cause
- Find issues that would naturally be fixed together

### 3. Root Cause Identification
- Look for "umbrella" issues that would fix multiple smaller issues
- Identify architectural problems causing multiple symptoms
- Suggest which issue to tackle first to potentially resolve others

## Output Format

Present findings as:

1. **Potential Duplicates**: List pairs/groups that may be the same issue
2. **Related Clusters**: Group issues by subsystem or root cause
3. **Recommended Consolidation**: Suggest which issues to merge or close as duplicates
4. **Root Cause Issues**: Highlight issues that would fix multiple problems if resolved

## Actions to Suggest

For each finding, suggest:
- `bd duplicate <issue1> <issue2>` to mark duplicates
- Which issue should be the "primary" and which should be closed
- Whether a new umbrella issue should be created
