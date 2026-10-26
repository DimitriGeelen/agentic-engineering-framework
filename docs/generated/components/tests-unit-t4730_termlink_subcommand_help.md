# t4730_termlink_subcommand_help

> T-4730 — every `fw termlink` subcommand that parses options answers --help/-h with usage naming every option its parser accepts, and exits 0.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4730_termlink_subcommand_help.bats`

## What It Does

T-4730 — every `fw termlink` subcommand that parses options answers --help/-h with
usage naming every option its parser accepts, and exits 0. Origin: the dispatch gate
(check-agent-dispatch.sh) names `fw termlink dispatch --task --name --prompt`, but
`fw termlink dispatch --help` died with "Unknown option: --help" (TermLink T-2981 2b).
The subcommand list and each option list are read from termlink.sh itself, so a new
subcommand parser, or a new flag without a usage line, fails here.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4730_termlink_subcommand_help.yaml`*
*Last verified: 2026-10-25*
