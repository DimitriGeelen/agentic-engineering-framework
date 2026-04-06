#!/usr/bin/env python3
"""T-963: Add ## Recommendation sections to inception tasks that have decisions but lack them.

Reads each inception task in .tasks/active/, extracts existing decision/rationale,
and inserts a ## Recommendation section in the format Watchtower batch review expects.
"""

import os
import re
import sys

TASKS_DIR = os.path.join(os.path.dirname(__file__), '../../.tasks/active')

def extract_frontmatter_field(content, field):
    """Extract a field from YAML frontmatter."""
    m = re.search(rf'^{field}:\s*(.+)$', content, re.MULTILINE)
    return m.group(1).strip().strip('"') if m else None

def extract_decision_rationale(content):
    """Extract decision and rationale from ## Decisions or ## Decision sections."""
    decision = None
    rationale = None

    # Look for **Decision**: GO/NO-GO/DEFER
    dec_match = re.search(r'\*\*Decision\*\*:\s*(.+)', content)
    if dec_match:
        dec_text = dec_match.group(1).strip()
        if 'NO-GO' in dec_text.upper():
            decision = 'NO-GO'
        elif 'DEFER' in dec_text.upper():
            decision = 'DEFER'
        elif 'GO' in dec_text.upper():
            decision = 'GO'

    # Look for **Rationale**: text
    rat_match = re.search(r'\*\*Rationale\*\*:\s*(.+?)(?:\n\n|\n\*\*)', content, re.DOTALL)
    if rat_match:
        rationale = rat_match.group(1).strip()
        # Clean up multi-line rationale
        rationale = ' '.join(rationale.split('\n')).strip()

    return decision, rationale

def has_recommendation_section(content):
    """Check if file already has ## Recommendation section."""
    return bool(re.search(r'^## Recommendation\s*$', content, re.MULTILINE))

def is_inception(content):
    """Check if task is inception workflow type."""
    return extract_frontmatter_field(content, 'workflow_type') == 'inception'

def add_recommendation_section(content, decision, rationale):
    """Insert ## Recommendation before ## Decisions or ## Decision."""
    rec_section = f"""## Recommendation

**Recommendation:** {decision}
**Rationale:** {rationale}

"""
    # Insert before ## Decisions (or ## Decision if no ## Decisions)
    if '## Decisions' in content:
        content = content.replace('## Decisions', rec_section + '## Decisions', 1)
    elif '## Decision' in content:
        content = content.replace('## Decision', rec_section + '## Decision', 1)
    else:
        # Fallback: insert before ## Updates
        content = content.replace('## Updates', rec_section + '## Updates', 1)

    return content

def main():
    modified = 0
    skipped = 0
    errors = []

    for fname in sorted(os.listdir(TASKS_DIR)):
        if not fname.startswith('T-') or not fname.endswith('.md'):
            continue

        filepath = os.path.join(TASKS_DIR, fname)
        content = open(filepath).read()

        if not is_inception(content):
            continue

        if has_recommendation_section(content):
            skipped += 1
            continue

        decision, rationale = extract_decision_rationale(content)

        if not decision:
            # No decision recorded yet — skip
            task_id = extract_frontmatter_field(content, 'id')
            continue

        if not rationale:
            rationale = f"{decision} — see Decisions section for details"

        new_content = add_recommendation_section(content, decision, rationale)

        if new_content != content:
            open(filepath, 'w').write(new_content)
            task_id = extract_frontmatter_field(content, 'id')
            modified += 1
            print(f"  Added: {task_id} ({decision})")

    print(f"\nDone: {modified} modified, {skipped} already had recommendations")
    return 0 if not errors else 1

if __name__ == '__main__':
    sys.exit(main())
