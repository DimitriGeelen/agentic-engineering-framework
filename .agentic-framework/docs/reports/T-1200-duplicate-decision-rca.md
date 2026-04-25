# T-1200: RCA — Duplicate Decision Block in Inception Tasks

## Root Cause

`lib/inception.sh:279` uses `line.startswith('## Decision')` to find the Decision section. This prefix match hits **both**:
- `## Decisions` (standard decisions section from task template)
- `## Decision` (inception decision placeholder)

The script writes the decision block into both sections, duplicating content.

## Evidence

T-1129 task file after Watchtower GO approval showed:
- Lines 89-103: `## Decisions` got decision block (wrong)
- Lines 106-122: `## Decision` got decision block (correct)
- Update entries appended twice at end of file

## Fix

Change `lib/inception.sh:279`:
```python
# Before (prefix match — hits both sections):
if line.startswith('## Decision'):

# After (exact match — hits only ## Decision):
if line.strip() == '## Decision':
```

## Risk Assessment

- **Zero risk**: The `## Decision` section header is deterministic — all inception templates use exactly `## Decision` (not `## Decisions`)
- **Backward compatible**: Existing completed task files are unaffected (already archived)
- **No template changes needed**: Only the parser logic changes
