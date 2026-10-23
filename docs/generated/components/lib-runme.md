# runme

> lib/runme.sh — operator command handoff as ONE line (T-3675, operator ruling 2026-10-01).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/runme.sh`

## What It Does

lib/runme.sh — operator command handoff as ONE line (T-3675, operator ruling 2026-10-01).
When the operator has to run something, the agent does not paste a multi-line block.
It writes .context/runme/<name>/runme.sh, prints `bash /abs/path/runme.sh`, and then
watches .context/runme/<name>/run.log. The script tees every line, timestamped, to
that log and brackets it with START / EXIT <code> markers, so the agent can read
exactly what happened without the operator copying output back.
fw runme new <name> [--desc "..."] -- <command> [<command> ...]
each <command> is one shell line; a single '-' reads lines from stdin
fw runme watch <name> [--timeout SECS] [--until start|exit]   (default 86400 / FW_RUNME_WATCH_TIMEOUT;
waits for START, then EXIT or STOPPED; --until start returns 0 at START so you can say "it began", then re-arm for exit)

### Framework Reference

**Operator ruling 2026-10-01, standing:** whenever the operator has to run something —
a command, a sequence, a script, an approval that needs a shell — the agent does NOT
paste a block. It wraps the whole thing in a logged script and hands over **one line**:

---
*Auto-generated from Component Fabric. Card: `lib-runme.yaml`*
*Last verified: 2026-10-01*
