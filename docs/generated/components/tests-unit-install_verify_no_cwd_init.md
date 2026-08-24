# install_verify_no_cwd_init

> Regression test (T-2799): runs the real install.sh end to end in an isolated HOME + empty cwd and asserts the cwd is untouched afterward. Guards against the installer's own verify() step silently auto-initialising a project wherever the user happened to invoke curl|bash from.

**Type:** script | **Subsystem:** testing | **Location:** `tests/unit/install_verify_no_cwd_init.bats`

**Tags:** `install`, `regression`, `onboarding`

## What It Does

T-2799: install.sh's own verify() step must never initialise a project in
the caller's cwd. Step 3 (`fw doctor`) used to run against the caller's
cwd; under a non-TTY pipe (`curl | bash`) that reaches bin/fw's auto-init
branch and silently seeds .agentic-framework/, .git, .tasks/, .context/
etc. wherever the user happened to be standing -- while still printing a
green "Step 3/3: fw doctor passes" checkmark. Measured live against GitHub
master, 2026-08-04: an empty cwd ended up with a complete initialised
project after nothing but the documented `curl | bash` one-liner.
Regression test: run install.sh --local end to end in an isolated HOME
with an empty, isolated cwd, then assert the cwd is untouched.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-install_verify_no_cwd_init.yaml`*
*Last verified: 2026-08-04*
