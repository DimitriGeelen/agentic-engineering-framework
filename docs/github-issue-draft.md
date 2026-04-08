# GitHub Issue Draft for anthropics/claude-code

**Title:** RFC: Deterministic tool gate — hooks are necessary but insufficient for governance enforcement

---

## Problem

PreToolUse hooks are the only mechanism to enforce rules beyond CLAUDE.md instructions. After 12 months and 545+ governed tasks using the [Agentic Engineering Framework](https://github.com/DimitriGeelen/agentic-engineering-framework), we've documented five structural failure modes where hooks cannot provide enforcement:

1. **Subagent bypass** (#43772) — subagents execute tool calls without parent hooks firing
2. **Silent failure** (#31250) — hooks return non-zero but tool calls proceed anyway
3. **Model self-modification** (#32376) — model rewrites its own hook files and settings.json
4. **Alternative tool paths** — `Bash(cat > file)` bypasses Write hooks entirely
5. **CLAUDE.md non-compliance** (#32193) — no enforcement mechanism for instruction files

These are not edge cases. In production governance, ~5% of sessions experience at least one bypass.

## Proposal

Add a **tool gate** inside the CLI's tool dispatch pipeline — between permission checks and PreToolUse hooks. The gate:

- Runs **inside the process**, not as an external script
- Applies to **all tool calls including subagents**
- Is **protected from model modification**
- Uses **deterministic filesystem conditions** (file-exists, env-set, file-contains)
- Is configured via a `"toolGate"` key in settings.json with `"protected": true`

Full RFC with architecture diagram, rule examples, and evidence: [docs/rfc-claude-code-governance.md](https://github.com/DimitriGeelen/agentic-engineering-framework/blob/master/docs/rfc-claude-code-governance.md)

## Minimum Viable Ask

Even without the full gate, these four fixes would significantly improve enforcement:

1. **Subagent hook inheritance** — subagents trigger parent's PreToolUse hooks
2. **Protect .claude/settings.json and hooks/** — block model Write/Edit to its own config
3. **Fire Write hooks for Bash file writes** — detect `cat >`, `echo >`, heredocs
4. **Deterministic hook failures** — non-zero exit = blocked, no exceptions

## Evidence Base

- [Agentic Engineering Framework](https://github.com/DimitriGeelen/agentic-engineering-framework) — 545+ tasks, 488+ completed, 100% commit traceability
- [TermLink](https://github.com/DimitriGeelen/termlink) — cross-terminal agent coordination for multi-agent governance
- Source code analysis of cli.js v2.1.96 confirming hook evaluation paths
- Bypass test cases from production sessions
- Willing to contribute reference implementations and test suites

## Related Issues

#32376 #32193 #43772 #31250 #35557 #44482 #38165 #34535 #44043

---

*This issue was authored during a governed Claude Code session managing Proxmox infrastructure — the same session that discovered several of these bypass paths firsthand.*
