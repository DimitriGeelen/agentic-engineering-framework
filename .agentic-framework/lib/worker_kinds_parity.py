#!/usr/bin/env python3
"""T-1946 — Worker-kinds parity check helper.

`fw doctor` cross-validates that `VALID_WORKER_KINDS` is identical
between `lib/resolver.py` and `lib/workflow_lint.py`. T-1734 closed
a 5-month silent drift between these two tables; the doctor check
is the runtime witness that prevents recurrence.

Extracted from inline `$(python3 - <<PYEOF ... PYEOF)` at bin/fw:1911
per L-332 / L-408: the last remaining heredoc-in-cmd-sub in bin/fw
goes out — bin/fw becomes 100% clean of the self-lockout pattern.

Output (machine-readable, parsed by bash):
  OK|<sorted-list>            — sets agree
  WARN|drift detected — ...   — sets diverge
  FAIL|<reason>               — cannot import either module

Args:
  argv[1]  FW_LIB_DIR — path to lib/ where resolver.py and
                        workflow_lint.py live. Inserted into
                        sys.path[0] so the import resolves.

Exit code: always 0 — bash parses the prefix to decide severity.
"""
import sys


def main() -> int:
    if len(sys.argv) != 2:
        print("FAIL|usage: worker_kinds_parity.py <FW_LIB_DIR>")
        return 0
    fw_lib_dir = sys.argv[1]
    sys.path.insert(0, fw_lib_dir)
    try:
        from resolver import VALID_WORKER_KINDS as resolver_set
    except Exception as exc:
        print(f"FAIL|cannot import lib/resolver.py: {exc}")
        return 0
    try:
        from workflow_lint import VALID_WORKER_KINDS as lint_set
    except Exception as exc:
        print(f"FAIL|cannot import lib/workflow_lint.py: {exc}")
        return 0
    only_lint = lint_set - resolver_set
    only_resolver = resolver_set - lint_set
    if not only_lint and not only_resolver:
        print(f"OK|{sorted(lint_set)}")
    else:
        diff_parts = []
        if only_lint:
            diff_parts.append(f"only in lib/workflow_lint.py: {sorted(only_lint)}")
        if only_resolver:
            diff_parts.append(f"only in lib/resolver.py: {sorted(only_resolver)}")
        print(f"WARN|drift detected — {'; '.join(diff_parts)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
