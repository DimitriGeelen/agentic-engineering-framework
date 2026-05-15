#!/usr/bin/env bash
# T-1451 regression test: revisit_at + revisit_evidence_needed are preserved
# across update-task.sh field mutations.
#
# Strategy: update-task.sh uses targeted `_sed_i "s/^X:..."` replacements on
# specific known fields (status, owner, horizon, workflow_type, tags,
# last_update). Any field not in that set is preserved by default. This test
# asserts revisit_at + revisit_evidence_needed are NOT in the mutation set.
#
# This is a structural assertion: it cannot regress without an explicit code
# change to update-task.sh that adds revisit_at to the sed patterns.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_SCRIPT="${SCRIPT_DIR}/../update-task.sh"

if [ ! -f "$UPDATE_SCRIPT" ]; then
    echo "FAIL: update-task.sh not found at $UPDATE_SCRIPT" >&2
    exit 1
fi

# Extract all "^X:" patterns that _sed_i targets (line-level frontmatter mutations).
mutated_fields=$(grep -oE '_sed_i "s/\^[a-z_]+:' "$UPDATE_SCRIPT" \
    | sed 's|_sed_i "s/\^||; s|:$||' \
    | sort -u)

# revisit_at and revisit_evidence_needed must NOT appear.
for field in revisit_at revisit_evidence_needed; do
    if echo "$mutated_fields" | grep -qx "$field"; then
        echo "FAIL: $field appears in update-task.sh sed mutations — preservation broken" >&2
        echo "      Mutated fields detected: $mutated_fields" >&2
        exit 1
    fi
done

echo "PASS: revisit_at + revisit_evidence_needed are preserved (not in mutation set)"
echo "      Currently-mutated frontmatter fields: $(echo $mutated_fields | tr '\n' ' ')"
exit 0
