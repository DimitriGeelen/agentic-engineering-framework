# T-2212 — IW-3 Spike: Auth model for the capability overlay (Sovereignty-aware)

**Parent inception:** T-2209 (capability-overlay arc — MCP subsystem + CLI route)
**Spike:** IW-3 — *"Auth model — env-inherit / per-client token / capability handshake / shell-only — which preserves §B-005 sovereignty?"*
**Worker:** spike-iw3 (TermLink-dispatched, read-only)
**Filed:** 2026-06-05 · time-boxed 30 min · Producer ≠ judge — this is a memo for the operator, not a decision.

---

## Question

Which authentication model for the framework's capability overlay (MCP server and/or CLI route)
preserves the §B-005 / Sovereignty posture **unchanged** — neither weakening the existing gates nor
adding a new secret surface that becomes a §B-005-class liability itself?

Front-of-mind crux (operator's framing): *"Can a misconfigured / hostile MCP client trip a
Sovereignty-bound verb under this auth model? If yes, which gate catches it?"*

---

## §A. The mechanism that decides this question (evidence first)

Two structurally different enforcement surfaces exist, and the candidate analysis turns entirely on
the distinction:

1. **Verb-level sovereignty gates fire on the `$CLAUDECODE=1` *environment variable*, inside the
   verb code** — independent of transport (shell, MCP, or CLI-overlay):
   - `lib/inception.sh:430` — `do_inception_decide` refuses when `[ "${CLAUDECODE:-}" = "1" ]` (unless `--i-am-human`/`--from-watchtower`).
   - `lib/arc.sh:671` and `lib/arc.sh:793` — `arc close` / driver-approve refuse on the same env check.
   - `lib/bvp.sh:66` — `bvp confirm` refuses when `os.environ.get('CLAUDECODE') == '1'`.
   - `lib/inception.sh:106` — filing-time recommendation gate (T-1715/T-1716) on the same signal.

   **Consequence:** any process that shells out to these verbs *while carrying `$CLAUDECODE=1` in its
   environment* trips the gate. The env var being **present** is what protects sovereignty — not its
   absence.

2. **B-005 is a PreToolUse hook on the Write/Edit *tools*, not on fw verbs** —
   `agents/context/check-active-task.sh:104-117` blocks any `Write|Edit` whose path matches
   `*/settings.json`. It is unconditional (`docs/reports/fw-agent-t629-01-deadlocks.md:382-387`:
   *"B-005 is UNCONDITIONAL — no task, no approval, no bypass … This is by design"*).

   **Consequence:** B-005 only sees the agent's **Write/Edit tool calls**. A process that writes
   `.claude/settings.json` *directly* (its own `open()`, or a shell `>`), rather than via the Write/Edit
   tool, is **never seen by B-005**. An MCP server is exactly such a process.

3. **The framework already learned that a single env signal is fragile**
   (`agents/context/check-active-task.sh:261-273`, T-1738): the focus-drift gate checks
   `CLAUDECODE=1` **OR** `AI_AGENT` **OR** `TOOL_NAME` because *"Single-signal CLAUDECODE check would
   silently degrade the drift gate."* Any auth model that leans on `$CLAUDECODE` should inherit this
   multi-signal posture, not a lone check.

4. **The de-facto neighbour auth model is already env-inherit with zero secrets.**
   `.mcp.json` carries **no** token/auth/secret of any kind (`grep -c "token\|auth\|secret" .mcp.json`
   → `0`). `context7`, `playwright`, and `skills` declare *no* `env:` block — they inherit the Claude
   Code parent environment verbatim. `termlink` adds only `TERMLINK_TASK_GOVERNANCE: 1`
   (`.mcp.json:25-27`). The `skills` server (`/opt/150-skills-manager/...`) could not be inspected —
   path-isolation boundary block (T-559), correctly enforced — but its descriptor proves the point:
   it authenticates by **nothing but inherited process environment**, the same as Candidate A would.

**The synthesis:** the sharpest sovereignty hazard is *not* the auth candidate at all — it is **verb
scope**. A sovereignty-bound verb that *mutates `.claude/settings.json`* (`fw hook-enable`,
`fw enforcement baseline`) exposed through any MCP transport would **bypass B-005**, because the MCP
server's filesystem writes never reach the Write/Edit PreToolUse hook. This is orthogonal to A/B/C/D
and is captured as Open Sub-Question OSQ-1. The curated overlay in T-2209 §3 already excludes these
verbs; the auth decision must not silently re-admit them.

---

## Candidates

### A. env-inherit
MCP server inherits `$CLAUDECODE=1` (and `AI_AGENT`/`TOOL_NAME`) from the spawning Claude Code
process. No explicit auth surface; trust rides the process boundary. Same model as `skills`,
`context7`, `playwright` today (`.mcp.json`, no `env`/token).

- **Steelman:** This is the *only* candidate that makes the existing sovereignty gates fire **for
  free and unchanged**. Because the verb-level refusals key on `$CLAUDECODE=1` (`inception.sh:430`,
  `arc.sh:671`, `bvp.sh:66`), an env-inheriting MCP server that shelled out to a sovereignty-bound
  verb would be **blocked by the same code path that blocks the agent's shell today** — zero new
  gate logic. It is the proven neighbour pattern (all three sibling servers use it), so it inherits
  their hardening and the operator's existing mental model. Cost is near-zero: no `.mcp.json` edit
  beyond the server declaration. The answer to the crux is clean: a hostile client **cannot** trip a
  sovereignty-bound verb, because (i) the curated overlay excludes them entirely (T-2209 §3) and
  (ii) even if reachable, the inherited `$CLAUDECODE=1` makes the verb refuse.
- **Strawman:** The protection is *contingent on `$CLAUDECODE` actually propagating and never being
  stripped.* The failure mode is inverted and silent: if the MCP server (or a future code path)
  **drops `$CLAUDECODE`** to "act as the operator," every sovereignty gate goes dark — the exact
  silent-degradation T-1738 warns about (`check-active-task.sh:261-273`). Env-inherit also conflates
  *"running under Claude Code"* with *"is an authorised agent"* (T-2209 §5, Candidate A "Weakest"):
  a misconfigured `.mcp.json` on a shared host could spawn the server under a different parent that
  also happens to set `$CLAUDECODE`. It carries no per-client revocation. **§B-005 hazard:** none
  *added*, but the whole model is one missing env var away from defeat — it must be paired with a
  hard contract that the server **never strips agent-control signals** and **never exposes
  settings.json-touching verbs**.

### B. per-client token
Each MCP client registers a capability token in `.mcp.json`; server validates on every call.
Precedent: TermLink's TOFU-pinned token / shared-secret model.

- **Steelman:** Explicit, auditable, per-client revocable. If the overlay ever grows to
  cross-machine dispatch, a scoped token per worker could express *which* worker may route *which*
  verb class — genuine orchestration-surface value (F-ORCH). TermLink proves the pattern is
  buildable in this fleet.
- **Strawman:** TermLink's TOFU/token exists to solve a **network-transport trust** problem — *"is
  this remote hub the hub I pinned?"* across machines (`docs/reports/T-1326-fleet-cert-instability.md`).
  The framework overlay is **local**: the MCP server is spawned by Claude Code on the same host via
  `.mcp.json`, in the same process tree. There is **no MITM surface** for a token to defend. So the
  token is **overkill for the threat that exists** — and **under-kill for sovereignty**, because a
  token proves *which client*, never *whether human*. Sovereignty gates are a human-vs-agent
  distinction (`inception.sh:430`), which a client token structurally cannot encode. Worse, the token
  store (`.context/working/.mcp-tokens.yaml` per T-2209 §5) becomes a **new secret = a new
  §B-005-class operator-only surface** — the model expands the very attack surface it claims to
  guard, and inherits TOFU's lived failure mode: stale-secret lockout went **fleet-dark** in T-1326
  (*"every client with stale secrets is dark to these hubs"*), and habitual `tofu clear` *"defeats
  the whole mechanism."* High lifecycle cost (rotation, revocation) for a local same-host call.

### C. capability handshake
First-call `initialize` exchange: client declares capabilities, server returns an opaque signed
session capability (LSP-`initialize` shape). Most surface, most flexibility.

- **Steelman:** The most *precise* model — per-tool authorisation, a signed manifest that declares
  exactly which verb classes a session may reach. LSP's `initialize` is a proven, portable standard
  (aligns with D4 / FRAMEWORK.md's "prefer standards: MCP, LSP, OpenAPI"). If the overlay's
  long-run goal is fine-grained, per-worker routable contracts, this is the only candidate that
  expresses them natively — highest F-ORCH ceiling.
- **Strawman:** Highest implementation cost and **novel code for the framework** (T-2209 §5,
  "High implementation cost; novel for the framework"). Novel auth code *is itself* a sovereignty
  risk — every line of bespoke capability-granting logic is a line that can be wrong, and it sits on
  the critical path of the gates. The signed-manifest key material is, again, a new secret surface
  (§B-005-class). For an arc whose §ACD headline mechanic is a single wire-level demo (T-2209 §6
  HM-A/HM-B), a full handshake is a cathedral where a shed is asked for — it cannot ship a clean
  small demo and pushes the sovereignty conversation into the most code-heavy corner (T-2209 §7:
  *"Shape-3 has the highest blast radius and is where the sovereignty-bound discussion would need to
  happen explicitly"*).

### D. shell-only (no MCP server)
No MCP server at all. CLI-route overlay only (`--json` output on existing verbs). Auth piggybacks on
filesystem permissions, existing `$CLAUDECODE=1` checks in the verbs, and the existing PreToolUse
hooks on the Bash/Write/Edit tools. Natural mate to IW-1 = "CLI-overlay-only."

- **Steelman:** **Lowest blast radius and the only candidate that adds *zero* new sovereignty
  surface.** There is no server process, so there is no MCP transport to bypass B-005, no env to
  strip, no token to leak, no handshake to misimplement. Every existing gate keeps firing through
  the **exact same path it fires today** — the agent still calls `bin/fw <verb>` via the Bash tool,
  so `check-active-task`, `check-tier0`, the focus-drift multi-signal gate, B-005, and the verb-level
  `$CLAUDECODE` refusals are all **untouched**. The only change is `--json` *output*, which is read-only
  formatting and cannot weaken a gate. The crux answer is trivial and total: *there is no MCP client*,
  so no MCP client can trip any verb. Highest D2 (reliability — gates provably unchanged), highest D4
  (portability — any language shells out + parses JSON). Matches the parent's standing lean (T-2209
  §5 *"Recommend candidate D first"*; §7 *"Shape-1 or Shape-4 … keep auth surface trivial (Candidate
  D)"*).
- **Strawman:** Loses the typed-tool ergonomics native MCP clients get — an MCP-aware agent still has
  to shell out and parse rather than calling `mcp__fw__review_queue()` directly (T-2209 §5,
  Candidate D "loses the typed-tool ergonomics"). If IW-1 lands on *"ship an MCP server"*, D alone
  cannot satisfy that shape — it would need to be the **mate** to A, not a standalone answer. It does
  not, by itself, advance the MCP-subsystem half of the arc's stated scope (T-2209 §1).

---

## BVP Scoring Matrix

Active drivers (`policy/value-drivers.yaml`): D1=9, D2=7, D3=5, D4=3, F-RECALL=6, F-ORCH=5.
F-AUTONOMY is carved/inactive (lines 171-195) → not scored. Scores 0-5; one-line reasoning per cell.

| Driver (weight) | A env-inherit | B per-client token | C handshake | D shell-only |
|---|---|---|---|---|
| **D1 Antifragility (9)** | 3 — reuses hardened neighbour pattern; failure (stripped env) is detectable via T-1738 multi-signal | 1 — new secret store = new brittleness; stale-token lockout (T-1326) | 2 — most precise long-run but novel bespoke auth code is fresh failure surface | 4 — adds nothing to break; piggybacks on already-hardened `$CLAUDECODE` checks |
| **D2 Reliability (7)** | 3 — deterministic *if* propagation guaranteed; silent-degrade risk on strip | 2 — rotation lifecycle is a real new failure mode | 2 — precise but untested novel code path | 5 — every gate fires through its existing, proven path; `--json` is read-only |
| **D3 Usability (5)** | 5 — zero config; uniform with shell `bin/fw` | 2 — token management is config burden | 3 — flexible but complex; LSP-init ergonomics for clients | 4 — `--json` solves scraping; slightly less native for MCP clients |
| **D4 Portability (3)** | 4 — MCP-standard env inheritance, no lock-in | 2 — token file is a secret; D4 tension (must not be committed) | 3 — LSP `initialize` is a standard | 5 — pure CLI+JSON; any language consumes it |
| **F-RECALL (6)** | 1 — auth choice builds no durable retrievable knowledge | 0 — none | 0 — none | 0 — none |
| **F-ORCH (5)** | 3 — env-inherit makes overlay trivially routable to TermLink workers | 3 — scoped per-worker tokens could express routable capability | 4 — per-tool signed contract = highest routable-surface ceiling | 3 — `--json` typed I/O contract (rubric L3) routable without a server |
| **Weighted total** (max 175) | **106** | **54** | **76** | **121** |
| **Normalised** (÷175) | 0.61 | 0.31 | 0.43 | **0.69** |

---

## Cost Estimates

`F8 = 0.6·blast_radius + 0.3·tier + 0.1·effort`. Effort via T-shirt (S=2/M=4/L=6/XL=8).

| Candidate | blast_radius | tier | effort | **F8** | Notes |
|---|---|---|---|---|---|
| **D shell-only** | 1 | 1 | 2 (S) | **1.1** | `--json` flag on curated verbs; no new process, no sovereignty exposure |
| **A env-inherit** | 2 | 2 | 4 (M) | **2.2** | new MCP server process, but reuses inherited env; no secret store |
| **B per-client token** | 4 | 3 | 6 (L) | **3.9** | new secret store + rotation/revocation lifecycle + `.mcp.json` token wiring |
| **C handshake** | 5 | 3 | 8 (XL) | **4.7** | novel signed-manifest protocol; key material; highest critical-path code |

D and A are the HV/LC corner; B and C are lower value at higher cost. D **dominates** (highest value
0.69 **and** lowest cost 1.1).

---

## Recommendation

**D (shell-only) as the opening auth posture, with A (env-inherit) as the *pre-approved mate* if and
only if IW-1 elects to ship an MCP server.**

Rationale, anchored in the deltas above: D is the unique HV/LC dominator (value 0.69 vs A's 0.61;
cost 1.1 vs A's 2.2) **and** the only candidate that adds zero new sovereignty surface — every gate
fires through its existing path because there is no MCP transport to bypass B-005 and no env to
strip (§A.1-2). B and C both manufacture a **new secret surface that is itself §B-005-class**, while
solving a network-trust threat (TOFU, T-1326) that a same-host overlay does not have — overkill for
the real threat, under-kill for the human-vs-agent distinction sovereignty actually needs. This is
not a hedge-DEFER: the evidence (verb-level `$CLAUDECODE` gates, B-005's tool-layer scope, the
zero-secret neighbour `.mcp.json`, the T-1326 token failure record) is sufficient to commit.

**Crux answer:** *Can a misconfigured/hostile MCP client trip a Sovereignty-bound verb?*
- **Under D:** No — there is no MCP client.
- **Under A:** No — the curated overlay excludes sovereignty-bound verbs (T-2209 §3), and even if one
  were reachable, the inherited `$CLAUDECODE=1` makes the verb-level refusal fire
  (`inception.sh:430`). The gate that catches it is the **same verb-level `$CLAUDECODE` refusal that
  catches the agent's shell today.**
- **Binding conditions on A** (must ship in the same slice, per L-399 producer/consumer parity): the
  server (i) **never strips** `$CLAUDECODE`/`AI_AGENT`/`TOOL_NAME` (adopt the T-1738 multi-signal
  posture, `check-active-task.sh:261-273`), and (ii) **never exposes any settings.json-touching verb**
  (`hook-enable`, `enforcement baseline`) — see OSQ-1.

---

## Open Sub-Questions

- **OSQ-1 (sharpest, auth-orthogonal — surface to operator):** B-005 is a PreToolUse hook on the
  **Write/Edit tools** (`check-active-task.sh:108`), not on fw verbs. *Any* MCP server (A/B/C alike)
  writes the filesystem in its own process and is therefore **invisible to B-005**. If the overlay
  ever exposes a verb that mutates `.claude/settings.json` (`fw hook-enable`, `fw enforcement
  baseline`), the MCP transport silently bypasses B-005. **Mitigation is a scope rule, not an auth
  rule:** the overlay allowlist must hard-exclude settings.json-touching verbs, and a test should
  assert the exclusion. This belongs in IW-2 (verb scope), but it is the single most important
  sovereignty finding of this spike — record it regardless of which auth candidate wins.
- **OSQ-2:** Does the framework's MCP server, when spawned via `.mcp.json`, actually receive
  `$CLAUDECODE=1`? The sibling servers carry no `env:` block yet are assumed to inherit it. This is
  an empirical 5-minute check (spawn a stub server, log `os.environ.get('CLAUDECODE')`) that would
  convert A's protection from *assumed* to *proven*. Cheap experiment; do it before any A build.
- **OSQ-3:** Cross-machine future — if the overlay later serves TermLink workers on *other* hosts,
  the local-only argument against B collapses and a scoped-token model may re-enter on its F-ORCH
  merit. Re-open B only when cross-host MCP routing is a real requirement, not before.

---

*Producer ≠ judge. No focus mutation, no task update, no commit, no `.mcp.json` edit, no Sovereign
acts performed. Read-only spike within `/opt/999-Agentic-Engineering-Framework`.*
