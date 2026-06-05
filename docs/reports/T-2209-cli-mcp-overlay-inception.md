# T-2209 — Capability-overlay arc: MCP subsystem + CLI route for agent-callable framework primitives

**Status:** inception, exploration phase, no decision yet (filed 2026-06-05 with `Recommendation: DEFER` pending operator input on IW-1..IW-5)

**Why this artifact exists:** C-001 enforcement — the research trail IS the artifact. Conversations are ephemeral; this file is permanent. Updated incrementally as spikes produce findings; committed after each segment.

---

## §0. Filing context

The operator directive that triggered this inception, verbatim from chat:

> *"proceed as seen fit, prioritize High value / low cost BCP tasks, continue until context is at 300k, apply framework governance !!! use termlink whwre sensible and possible ->> check messages --> focus on new MCP subsystem & CLI arc"*

Filing was per G-020 — the directive describes >3 new files, new subsystem (MCP server process), new CLI route (overlay), potential secret handling (per-client auth tokens). Build was prohibited until inception decide.

A prior in-conversation reference to `HANDOFF-cli-mcp-overlay-2026-06-02 v3` was found absent from disk on 2026-06-05 verification (grep across `.context/handoffs/`, `inbox/`, pickup processed archive, full-repo `*.md`/`*.yaml`/`*.txt` returned zero matches). That handoff is treated as a memory phantom unless/until a real source file appears. **This inception is grounded in the directive above, not in the phantom.**

---

## §1. Problem framing (mirror of T-2209 §Problem Statement)

The framework already speaks MCP — the running Claude Code session has `claude-in-chrome`, `context7`, `skills`, and `termlink` MCP servers loaded. The framework's own surface (`bin/fw …`) is shell-only; agents reach it via `Bash` tool calls.

**The arc question:** should the framework expose its own primitives — `fw task review`, `fw inception start`, `fw arc create`, `fw bvp`, `fw reviewer`, `fw cron`, `fw handover`, etc. — through:

1. **An MCP server** (typed tool schemas, JSON returns, capability discovery), and/or
2. **A "CLI route" overlay** (structured JSON output on top of existing verbs, idempotent invocation, request IDs)

**For whom:** every agent that today shells out to `bin/fw <verb>` and screen-scrapes ANSI-coloured output, every cross-machine TermLink worker that today serialises requests as shell command strings, every Watchtower frontend that today builds POST payloads matching CLI argv shape.

---

## §2. Spikes (planned — output rendered below as they complete)

| # | Title | Time-box | Output anchor |
|---|-------|----------|---------------|
| 1 | Surface inventory: every fw verb, Sovereignty/agent-auth/read-only classes | 30 min | §3 |
| 2 | Existing-MCP-surface inventory + overlap map | 20 min | §4 |
| 3 | Authentication design candidates | 30 min | §5 |
| 4 | Headline-mechanic candidates (3-5 wire-level demos for operator pick) | 20 min | §6 |
| 5 | Arc-shape candidates (MCP-only, CLI-only, both-as-siblings) | 10 min | §7 |

**Total budget:** ~2 hours of read-only research. No source edits during exploration. All `bin/fw` source remains untouched until `fw inception decide T-2209 go` lands an explicit GO.

---

## §3. Spike 1 — Surface inventory

*(pending — to be filled by Spike 1 execution)*

## §4. Spike 2 — Existing MCP surface overlap

*(pending)*

## §5. Spike 3 — Auth candidates

*(pending)*

## §6. Spike 4 — Headline-mechanic candidates

*(pending — operator must name the chosen headline mechanic before §ACD GO is honest)*

## §7. Spike 5 — Arc shape candidates

*(pending)*

---

## §8. Open Questions (mirror of T-2209 §Open Questions)

- **IW-1: MCP server vs. CLI-route overlay vs. both?** → DEFERRED, needs operator
- **IW-2: Verb scope — all ~70 or curated 10-20?** → DEFERRED, depends on IW-1
- **IW-3: Auth model — env inheritance / token / handshake?** → DEFERRED, Sovereignty-bound
- **IW-4: Headline mechanic (G-062 §ACD)?** → DEFERRED, operator names it
- **IW-5: Existing-surface overlap with `skills` MCP server — federate or sibling?** → DEFERRED, Spike 2 input

Per [[feedback_defer_for_evidence_not_confidence]] discipline: each DEFER above is genuine evidence-gap, not hedge. The arc's shape (single-deliverable vs multi-slice, MCP-vs-CLI vs both, scope of verbs) cannot be answered from the artifact alone; the operator's preference materially changes the candidate space.

---

## §9. Dialogue log

### 2026-06-05 — Initial filing
- **Operator directive:** *"focus on new MCP subsystem & CLI arc"* (verbatim above)
- **Agent response:** Filed as inception T-2209 per G-020 (new subsystem + CLI route triggers fire). `Recommendation: DEFER` set at filing time per T-1716 gate, honest about evidence-gap on IW-1..IW-5.
- **Surface check:** No handoff file on disk; prior memory reference (`HANDOFF-cli-mcp-overlay-2026-06-02 v3`) corrected as phantom in [[project_t2204_completed_4_of_4_plus_cron]] sibling memory.
- **Next:** spikes 1-5 (read-only), then `fw task review T-2209` to surface candidates to operator for IW-1..IW-5 disposition.

*(further entries to be appended as exploration proceeds and operator feedback lands)*

---

## §10. Recommendation evolution

| Date | Recommendation | Rationale |
|------|----------------|-----------|
| 2026-06-05 (filing) | DEFER | Five open questions, all needing operator input or read-only spike completion. Honest evidence-gap (not hedge). |
| *(future)* | *(GO / NO-GO / refined DEFER)* | *(updated after Spikes 1-5 land in §3-§7 and operator returns disposition on IW-1..IW-4)* |
