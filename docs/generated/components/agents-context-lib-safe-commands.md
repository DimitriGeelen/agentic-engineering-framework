# safe-commands

> Allowlist of safe bash commands for task gate bypass — git status, ls, cat, grep etc. that dont need an active task.

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/lib/safe-commands.sh`

## What It Does

Safe-command allowlist for Bash task gate (T-650, T-630)
is_bash_safe_command() returns 0 if the command is read-only/diagnostic
and should be allowed without an active task.
Design evidence: 7920 Bash invocations analyzed from real session data.
Only 1.4% are file-writing operations. This allowlist catches the safe
98.6% for fast-path bypass.
Categories (27 patterns):
1. Git read-only (8 patterns)
2. File reading (7 patterns)
3. Searching (4 patterns)

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (20)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-active-task](/docs/generated/agents-context-check-active-task) | called_by | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [context_safe_commands](/docs/generated/tests-unit-context_safe_commands) | called_by | Unit tests for context safe_commands (35 tests) |
| [context_safe_commands](/docs/generated/tests-unit-context_safe_commands) | tests_by | Unit tests for context safe_commands (35 tests) |
| [safe_commands_env_prefix](/docs/generated/tests-unit-safe_commands_env_prefix) | called_by | TODO: describe what this component does |
| [safe_commands_env_prefix](/docs/generated/tests-unit-safe_commands_env_prefix) | tests_by | TODO: describe what this component does |
| [test_safe_commands_git_commit](/docs/generated/tests-unit-test_safe_commands_git_commit) | called_by | TODO: describe what this component does |
| [test_safe_commands_git_commit](/docs/generated/tests-unit-test_safe_commands_git_commit) | tests_by | TODO: describe what this component does |
| [capture_verbs_nulltask](/docs/generated/tests-unit-capture_verbs_nulltask) | called_by | TODO: describe what this component does |
| [capture_verbs_nulltask](/docs/generated/tests-unit-capture_verbs_nulltask) | tests_by | TODO: describe what this component does |
| [safe_commands_chain](/docs/generated/tests-unit-safe_commands_chain) | called_by | TODO: describe what this component does |
| [safe_commands_chain](/docs/generated/tests-unit-safe_commands_chain) | tests_by | TODO: describe what this component does |
| [t2936_bootstrap_quoted_redirect](/docs/generated/tests-unit-t2936_bootstrap_quoted_redirect) | called_by | TODO: describe what this component does |
| [t2936_bootstrap_quoted_redirect](/docs/generated/tests-unit-t2936_bootstrap_quoted_redirect) | tests_by | TODO: describe what this component does |
| [t2988_grouped_command_classification](/docs/generated/tests-unit-t2988_grouped_command_classification) | called_by | TODO: describe what this component does |
| [t2988_grouped_command_classification](/docs/generated/tests-unit-t2988_grouped_command_classification) | tests_by | TODO: describe what this component does |
| [t3221_commit_exemption_clause](/docs/generated/tests-unit-t3221_commit_exemption_clause) | tests_by | Pins the commit-checkpoint exemption in the Bash task gate. Both exemption branches (T-2054 null-focus, T-3179 partial-complete) once admitted any command whose raw text CONTAINED "git commit" — so a trailing `; rm -rf` rode through, a `\| tee` write the gate had already flagged was admitted anyway, and an unknown binary passed because a quoted argument said the words. This suite probes the SHIPPED hook through its real stdin JSON contract rather than re-implementing the predicate, and carries two controls that decide whether a green run means anything: a mutation control that rebuilds the pre-fix hook from live source (so reverting the fix reddens the suite), and a 16-command no-widening sweep asserting the fixed hook admits nothing the pre-fix one blocked. |
| [t3222_fetch_writes_file](/docs/generated/tests-unit-t3222_fetch_writes_file) | tests_by | Pins that curl and wget are admitted by the Bash safe-list only when they do not write a file. Both sat in the list unconditionally, so `curl -o FILE` and `wget -O FILE` — which write with no shell redirect, and are therefore invisible to has_bash_write_pattern — ran with no active task. Covers 22 spellings in both directions, including the stdout forms (`-o -`, `-O -`) that must stay safe and the framework's own documented verification idiom `curl -sf "$(bin/fw watchtower url)/page"`. Two legs carry the design decision: one asserts a commit whose MESSAGE mentions `curl -o` is still admitted (why the check is clause-scoped rather than in the whole-string write scanner), and one asserts a commit chained to a fetch-write is now refused with no change to the T-3221 commit predicate. Mutation control restores the unconditional arm from live source; a no-widening sweep asserts the fix admits nothing the pre-fix version blocked. |
| [t3245_trailer_quote_strip](/docs/generated/tests-unit-t3245_trailer_quote_strip) | tests_by | TODO: describe what this component does |
| [t3221_commit_exemption_clause](/docs/generated/tests-unit-t3221_commit_exemption_clause) | called_by | Pins the commit-checkpoint exemption in the Bash task gate. Both exemption branches (T-2054 null-focus, T-3179 partial-complete) once admitted any command whose raw text CONTAINED "git commit" — so a trailing `; rm -rf` rode through, a `\| tee` write the gate had already flagged was admitted anyway, and an unknown binary passed because a quoted argument said the words. This suite probes the SHIPPED hook through its real stdin JSON contract rather than re-implementing the predicate, and carries two controls that decide whether a green run means anything: a mutation control that rebuilds the pre-fix hook from live source (so reverting the fix reddens the suite), and a 16-command no-widening sweep asserting the fixed hook admits nothing the pre-fix one blocked. |
| [t3222_fetch_writes_file](/docs/generated/tests-unit-t3222_fetch_writes_file) | called_by | Pins that curl and wget are admitted by the Bash safe-list only when they do not write a file. Both sat in the list unconditionally, so `curl -o FILE` and `wget -O FILE` — which write with no shell redirect, and are therefore invisible to has_bash_write_pattern — ran with no active task. Covers 22 spellings in both directions, including the stdout forms (`-o -`, `-O -`) that must stay safe and the framework's own documented verification idiom `curl -sf "$(bin/fw watchtower url)/page"`. Two legs carry the design decision: one asserts a commit whose MESSAGE mentions `curl -o` is still admitted (why the check is clause-scoped rather than in the whole-string write scanner), and one asserts a commit chained to a fetch-write is now refused with no change to the T-3221 commit predicate. Mutation control restores the unconditional arm from live source; a no-widening sweep asserts the fix admits nothing the pre-fix version blocked. |

---
*Auto-generated from Component Fabric. Card: `agents-context-lib-safe-commands.yaml`*
*Last verified: 2026-03-28*
