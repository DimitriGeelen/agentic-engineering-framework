# known_cwd

> tests/unit/helpers/known_cwd.bash — classify commands from a KNOWN cwd (T-4429).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/helpers/known_cwd.bash`

## What It Does

tests/unit/helpers/known_cwd.bash — classify commands from a KNOWN cwd (T-4429).
Since T-4409, is_bash_safe_command judges git by the shell's starting cwd
(_fw_initial_git_cwd, agents/context/lib/safe-commands.sh): the hook payload's
cwd, else $PWD only when it IS PROJECT_ROOT, else unknown — and an unknown cwd
makes the git arm fail closed. A real hook always carries the payload cwd. A
test that sources the library bare carries neither, so its verdict depended on
whoever ran bats (green from a worker shell with PROJECT_ROOT=$PWD, red from
cron or /tmp). These helpers give the test the context a hook has.
load helpers/known_cwd
setup() { known_cwd_setup; ... }       teardown() { known_cwd_teardown; }

---
*Auto-generated from Component Fabric. Card: `tests-unit-helpers-known_cwd.yaml`*
*Last verified: 2026-10-19*
