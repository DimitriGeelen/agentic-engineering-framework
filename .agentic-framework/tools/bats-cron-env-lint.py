#!/usr/bin/env python3
"""
T-3790: Lint to ensure all .bats files that invoke cron operations set FW_CRON_INSTALL_DIR.

Rationale: cron operations that don't set FW_CRON_INSTALL_DIR will write to /etc/cron.d
in tests, which pollutes the real system and accumulates leaked files (26 files on
dimitri-mint-dev, each running fw docs --all daily — load 41 on 24 cores).

Check: any .bats file that runs a shell command containing 'schedule install' or 'cron install'
must have 'FW_CRON_INSTALL_DIR' in its setup or within the test itself.

Usage: bats-cron-env-lint.py [DIR ...]   (default: <repo>/tests/unit)
T-3791: wired into tests/lint/bats-cron-env-lint.bats, so a violation reddens the lint suite.

Exit: 0 if all checks pass, 1 if violations found.
"""

import re
import sys
from pathlib import Path

def check_bats_cron_env(dirs=None):
    if not dirs:
        dirs = [Path(__file__).resolve().parent.parent / "tests" / "unit"]
    violations = []

    for bats_file in sorted(f for d in dirs for f in Path(d).glob("*.bats")):
        with open(bats_file) as f:
            content = f.read()

        # Skip if file doesn't invoke cron operations
        if not re.search(r"(schedule install|cron install)", content):
            continue

        # Check if FW_CRON_INSTALL_DIR is set anywhere in the file
        has_cron_env = "FW_CRON_INSTALL_DIR" in content

        if not has_cron_env:
            # Only report if it actually runs the command (not just references it in comments)
            # Look for run commands that invoke cron operations
            run_patterns = [
                r'run.*schedule install',
                r'run.*cron install',
                r'"\$FRAMEWORK_ROOT.*schedule install',
                r'"\$FRAMEWORK_ROOT.*cron install',
            ]

            for pattern in run_patterns:
                if re.search(pattern, content):
                    violations.append(str(bats_file))
                    break

    if violations:
        print("FAIL: The following .bats files invoke cron operations without FW_CRON_INSTALL_DIR:")
        for v in violations:
            print(f"  {v}")
        print("\nFix: Add to setup() or before the run command:")
        print("  export FW_CRON_INSTALL_DIR=\"$TEST_TEMP_DIR/etc-cron.d\"")
        print("  mkdir -p \"$FW_CRON_INSTALL_DIR\"")
        return 1
    else:
        print("PASS: All .bats files that invoke cron operations set FW_CRON_INSTALL_DIR")
        return 0

if __name__ == "__main__":
    sys.exit(check_bats_cron_env(sys.argv[1:]))
