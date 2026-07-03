# Framework DOES instead of ASKS: `fw --help` and `/new-project` do heavyweight mutations unsolicited

**Source:** card-redirect (P-051) → couriered by termlink-agent → relayed into AEF inbox by termlink push-transport session (2026-07-03) | **Priority:** P1 (high) | **Origin date:** 2026-06-26

> Attribution chain preserved: filed by card-redirect, couriered verbatim onto
> `framework:pickup` (offset 76, pickup_id `TL-COURIER-cardredirect-P051`) which
> has no inbound AEF consumer (G-063 / PL-228). Relayed here into `.pickup/`.
> Courier note: instance (A) is a claude-shared-toolkit `/new-project` skill
> issue; instance (B) is a core `fw` bug. Splitting may warrant two tasks.

## Principle violated
Two instances where the toolchain persists/commits things the user never
requested — the opposite of the framework's own "[ASK] / human-in-the-loop by
risk" principle.

## (A) `/new-project` auto-runs `bd init` (beads) for EVERY project
claude-shared-toolkit `/new-project` Step 6 + "Important Rules" #2 run `bd init`
unconditionally, no opt-out. Effect: a plain Caddy-on-Cloudron infra project got
a SQLite task DB (`.beads/beads.db` + `-wal`/`-shm`, `config.yaml`,
`metadata.json`, `interactions.jsonl`) AND a bd-generated `AGENTS.md`, all
committed into git on the initial commit — unrequested and unrecognized by the
user. Compounding: `.beads/` is NOT gitignored → binary DB committed; bd itself
warns of "silent corruption when databases are copied between repositories."
**Fix:** make beads opt-in (prompt/flag); default OFF for infra/non-task project
types; if kept, gitignore `.beads/`; do not emit `AGENTS.md` unsolicited.

## (B) `fw <subcommand>` auto-inits an uninitialized CWD as a side effect — even on `--help`
Running `fw pickup --help` from an uninitialized dir triggered a full `fw init`
BEFORE printing help: created a git repo, vendored 26M into `.agentic-framework/`,
added `.tasks/ .context/ CLAUDE.md .claude/ .framework.yaml`, installed 3+ git
hooks. A `--help` (and any read-only verb) must NEVER write 26M or init a repo.
**Fix:** read-only/help verbs must not trigger init; gate init behind an explicit
`fw init` or a confirmation prompt.

**Tags:** pollution, new-project, beads, fw-init, help-side-effects, ask-dont-do
