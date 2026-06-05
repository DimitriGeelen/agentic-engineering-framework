# T-2216 — Orchestrator-routing integration lens for the mcp__framework__* overlay

**Parent:** T-2209 (capability-overlay arc). **Supplemental to:** T-2210..T-2214 (IW-1..IW-5), T-2215 (CLI error-pattern lens).
**Author:** or-lens-survey spike. **Type:** read-only research memo (producer ≠ judge).
**Filed:** 2026-06-05. **Time-box:** 45 min.

---

## Question

The 5 IW spikes scoped the overlay's *delivery shape* (MCP vs CLI vs both), *verb scope*,
*auth*, *headline mechanic*, and *overlap with `mcp__skills__*`*. None integrated the proposal
against the framework's **existing orchestrator-routing substrate** — the dispatch resolver,
the route_cache learner, the workflow declarations, and the MCP-tool drift-defense audit. The
operator caught the gap. This memo answers OR-1..OR-6: how do new `mcp__framework__*` tools
*land inside* the machinery the framework already runs to route, capture, learn from, and
police dispatched work.

The short version (see §Verdict): **the lens is ~80% absorbed into existing slices as
decisions, not new build.** The one genuine build leg is extending the drift-defense scan
(OR-2) plus its per-slice discharge convention (OR-6), both concentrated in Slice 1.

---

## Existing surface inventory

| Surface | File:line | What exists today |
|---------|-----------|-------------------|
| MCP-tool classification baseline | `.context/audits/orchestrator-mcp-baseline.yaml:1-50` | 246-tool source-of-truth, three classes: `gated` / `mutators_ungated` / `readonly_exempt`. Header documents 7 batches of convention-based additions (T-1755…T-2073). All tools are `termlink_*`. |
| Drift-defense audit | `agents/audit/orchestrator-mcp-scan.sh:55-81` | `probe_tools()` / `probe_gate_calls()` grep **only** `$TERMLINK_REPO/crates/termlink-mcp/src/tools.rs` (Rust). Emits WARN(exit 1) on unclassified-new, FAIL(exit 2) on a gated tool losing its gate. |
| Convention classifier | `orchestrator-mcp-scan.sh:119,131-160` | `CONVENTION_NAMESPACES = ('termlink_agent_', 'termlink_channel_')`. Anything outside those two namespaces → `'unknown'` → manual review. `--apply` writes auto-classifiable tools into the baseline. |
| Dispatch resolver | `lib/resolver.py:455-536` (`capture_dispatch`), `556-599` (`resolve`) | Builds an envelope, writes a row to `dispatches.jsonl`. Row carries `task_type`, `worker_kind`, `model`, `effort`, `allowed_tools`, `env`. Workers spawn `--bare` — "the dispatch envelope is the only governance channel they see" (`resolver.py:104-110`). |
| Dispatch capture log | `.context/dispatches.jsonl` | One row per *worker spawn* (TermLink / ollama-loop / pi). Sample rows are all `worker_kind: ollama-loop`, `model: claude-3-5-sonnet-hermes3`. |
| Outcome back-prop | `.context/dispatch-outcomes.jsonl`; `resolver.py:8` (consumed by T-1697) | `{dispatch_id, outcome:{evaluator, verdict, …}}` rows joined back to dispatches. |
| Route_cache learner | `agents/termlink/termlink.sh:52-83` (query), `145-200` (record); schema `tests/fixtures/termlink-route-cache-schema.json` | Keys `model_stats["<model>:<task_type>"] = {successes, failures, last_used}`. Resolution order `termlink.sh:106-118`: explicit `--model` → **route_cache best_model_for(tt)** → env-per-type → env-default. Learns **which LLM model** wins for a `task_type`. |
| Workflow declarations | `.context/project/workflows/*.yaml` | 8 files. Schema: `task_type`, `worker_kind` (∈ `{Task,TermLink,pi,ollama-loop}`, `resolver.py:59`), `model`, `effort`, `prompt_template`, `allowed_tools: [Read,Edit,Bash,Grep]`, `cost_cap_usd`, `cwd`, `env:`. **None declare any MCP surface.** |
| Arc value model | `docs/reports/T-1641-orchestrator-arc-reconsideration.md:118-132`; `T-1643-Q1-wire-evidence.md` | T-1641 W03: only **4 of 75** termlink MCP tools enforce `check_task_governance`; "New tools can silently skip governance with no signal" (W10) — the exact reason the baseline+scan exist. |

**Load-bearing fact for the whole memo:** the drift-defense audit was built (T-1641→T-1646)
because a new MCP tool can ship a mutator with no governance gate and *nothing notices*. A
**new framework MCP server is precisely a fresh instance of that risk surface** — so the
integration question is not academic; it is "does the existing immune system cover the new
organ?" Today it does **not** — the scan's probe physically cannot see PROJECT_ROOT tools
(`orchestrator-mcp-scan.sh:48-67` only reads `$TERMLINK_REPO`).

---

## OR-1 Classification entry

**How would new `mcp__framework__*` tools enter `orchestrator-mcp-baseline.yaml` today?**
They wouldn't, cleanly. Two independent breakages:

1. **Convention classifier is namespace-scoped and excludes them.** `classify_by_convention()`
   (`orchestrator-mcp-scan.sh:131`) returns `'unknown'` for any name not starting with
   `termlink_agent_` / `termlink_channel_` (`:119,:147-148`). Every `mcp__framework__*` tool →
   `'unknown'` → `still_unclassified` → WARN exit 1, **manual classification required per tool**
   (`:320-323`).
2. **The probe never emits them anyway.** `probe_tools()` greps `termlink_[a-z_]+`
   (`:57-58`). Framework tools are invisible to the scan, so manually adding them to the
   baseline would make every subsequent run report them as `REMOVED` (`:338-339`, "in baseline,
   not in current") — a permanent false WARN. **OR-1 cannot be solved without OR-2.**

**Failure mode if missed:** a Slice-N mutator (`mcp__framework__task_update`, `work_on`) ships
without a `check_task_governance`-equivalent gate. Because it is *absent from the baseline
entirely*, the scan emits at worst a WARN (unclassified), never a FAIL — and only if the probe
saw it, which today it doesn't. This is the T-1641-W10 "silently skip governance with no
signal" class, reproduced one repo over.

**Recommendation — manifest-declared classification, authored with the tool.** Unlike
`/opt/termlink` (outside PROJECT_ROOT, unreadable, forcing the grep-over-Rust hack and
"handler-level verification deferred" notes throughout the baseline header), **the framework
owns its MCP server source.** Exploit that: the server emits a build/start-time manifest, e.g.
`.context/audits/framework-mcp-manifest.json`:

```json
{"tools": [
  {"name": "mcp__framework__task_list",   "class": "readonly_exempt"},
  {"name": "mcp__framework__work_on",      "class": "mutators_ungated"},
  {"name": "mcp__framework__task_update",  "class": "mutators_ungated"}
]}
```

The tool author declares `class` at the point of writing the tool (the same place IW-1's
read-only/agent-authority/sovereignty split is already decided — see T-2209 §3 verb table).
The scan reads the manifest deterministically (no convention guessing, no language coupling).
This is strictly better than extending `CONVENTION_NAMESPACES` with `mcp__framework__`, because
fw-verb names don't carry a reliable action-verb suffix convention (`work_on` is a mutator,
`work_on` has no whitelisted verb; `doctor` is read-only but `note` is a mutator) — the
termlink verb-whitelist heuristic would mis-classify.

**Slice procedural-debt list:** every slice that lands tools appends manifest rows + commits
them; the `## Verification` line (OR-6) re-runs the scan and FAILs if a manifest tool is
missing its class or a source tool is missing from the manifest.

---

## OR-2 Scan probe extension

**Three discovery options for the PROJECT_ROOT server (language TBD, likely Python per IW-1):**

| Option | Mechanism | Pro | Con |
|--------|-----------|-----|-----|
| (a) static-analyse source | grep `@mcp.tool()` decorators / registry | no runtime dep | brittle to framework choice (FastMCP vs raw); re-derives the gating class the author already knows |
| (b) probe running `tools/list` | start server, call MCP `tools/list` | authoritative live surface | audit runs in **cron without the server up** (`agents/audit/audit.sh` schedule); start-per-audit is fragile and slow |
| (c) read build-time manifest | server writes `framework-mcp-manifest.json` on build/start | deterministic, in-repo, **readable** (no cross-repo isolation problem), carries author-declared class | manifest can drift from source if not regenerated — but that is itself a checkable drift (same shape as the cron-registry→generated leg, L-364) |

**Recommendation — (c) manifest, with a manifest-vs-source freshness check.** The cross-repo
constraint that forced `/opt/termlink`'s grep-over-Rust approach **does not apply here** — so
don't inherit its weakest property. The manifest gives the scan a clean second probe branch:

```sh
# new in orchestrator-mcp-scan.sh
FRAMEWORK_MCP_MANIFEST="$FRAMEWORK_ROOT/.context/audits/framework-mcp-manifest.json"
probe_framework_tools() { … read manifest, emit "<name>\t<class>" … }
```

The Python classifier block then merges framework tools into `current_tools` with their
declared class (no convention call), and the existing baseline diff logic (`:234-238`) works
unchanged. Add a `mcp__framework__` section to the baseline (or keep one baseline with the
three class-lists holding both `termlink_*` and `mcp__framework__*` names — they don't collide
by prefix). Add a freshness assertion: a source tool absent from the manifest, or a manifest
tool absent from source, → WARN (catches "author added a tool, forgot to regenerate manifest",
the registry→generated drift class).

**Extension PR shape (Slice 1):** ~40 lines in `orchestrator-mcp-scan.sh` (new probe fn +
manifest merge + freshness check), a `mcp__framework__` namespace note in the baseline header,
and the manifest emitter in the server build step. No change to exit-code semantics or the
`termlink_*` path.

---

## OR-3 Capture coverage

**Does `mcp__framework__task_update(...)` appear in `dispatches.jsonl`?** No — and it shouldn't.

`capture_dispatch()` (`resolver.py:455`) is reached only via `resolve()` (`:556`), which is the
**worker-spawn** path: workflow lookup → prompt assembly → envelope → JSONL row carrying
`worker_kind`, `model`, `effort`, `prompt_strategy` (`:485-505`). An MCP tool-call is a
different event class entirely: the primary agent (or a worker) calls a typed function
in-process. There is **no model selection, no prompt assembly, no worker_kind** — every field
that gives a `dispatches.jsonl` row meaning is null/absent for an MCP call. Forcing MCP calls
into `dispatches.jsonl` would (a) pollute the route_cache learner that tails it
(`resolver.py:335-363` `_recent_dispatches_summary`), and (b) inflate the substrate's
dispatch-count observability (`fw orchestrator status`) with non-dispatch events.

**Where state-changing MCP calls *are* already captured:** if the MCP server implements
agent-authority verbs by shelling to `bin/fw <verb>` (the cheapest implementation, and the one
IW-1 Shape-1/Shape-4 assumes via the shared `fw --json` underlay), then the **existing PreToolUse
governance hooks fire** — `check-active-task` (G-013), `check-inception-recommendation`
(T-2205), the focus-drift gate, the bypass log (`.context/working/.gate-bypass-log.yaml`).
Those hooks are the capture point for the governance-relevant subset, and they already exist.

**Recommendation — do NOT capture MCP calls in `dispatches.jsonl`.** If a per-call audit trail
is wanted (request IDs, the HM-A "idempotent invocation" property from T-2209 §6), the server
writes its **own** thin call log — `{ts, request_id, tool, task_id, result_class}` — analogous
to `/opt/termlink`'s `{ts, method, peer_addr}` production audit log (T-1641 W06). That is a
separate, optional observability surface, not a `dispatches.jsonl` extension. Minimum addition
if desired: one append-only `.context/audits/framework-mcp-calls.jsonl` writer in the server's
request handler. **Hook point: the MCP server request handler, not the resolver.**

---

## OR-4 Route_cache learning

**Does MCP-routed dispatch feed the route_cache learner? Should it?** No, and **exclude (option c).**

route_cache learns one thing: `model_stats["<model>:<task_type>"]` success/failure
(`termlink.sh:162`, schema `ModelStats.fields = [model, task_type, successes, failures,
last_used]`). Its entire purpose is answering "**which LLM model** should execute this
`task_type`" (`termlink.sh:106-118` resolution chain). An `mcp__framework__*` tool-call is a
**deterministic function** — there is no model variable to optimize, no success/failure that
reflects a *model's* fitness. Feeding it would create degenerate `model="":task_type` entries
or, worse, a synthetic `model="mcp"` that corrupts the comparison the learner exists to make.

**Subtlety that confirms exclusion is correct, not lossy:** when a *worker* spawned via the
dispatch path happens to call `mcp__framework__*` tools mid-task, the **outer dispatch** still
feeds route_cache normally — the worker's model still succeeded or failed at the `task_type`,
and that's the signal route_cache wants. The inner MCP calls are correctly invisible. So
excluding MCP calls loses **zero** learning signal: the thing route_cache measures (model
fitness per task_type) is already captured at the dispatch boundary that wraps them.

**Recommendation — exclude MCP tool-calls from route_cache entirely.** No parallel learner
either: there is no "best variant" choice in a deterministic typed tool. Document the null in
the OR-3 call-log if call-frequency analytics are ever wanted (that's usage telemetry, not
routing learning).

---

## OR-5 Workflow declaration

**Should workflows add `mcp_tools: [...]`, or is the MCP surface universal?** Neither a new
field nor universal — **reuse `allowed_tools`.**

Workers spawn `--bare` and see only the envelope (`resolver.py:104-110`). The envelope already
carries `allowed_tools` verbatim (`resolver.py:529 "allowed_tools": workflow.get("allowed_tools", [])`).
Claude-Code's permission model gates MCP tools by their full name (`mcp__framework__task_list`)
in exactly the same list that gates `Read`/`Edit`/`Bash`. So a worker can call a framework MCP
tool **iff** (a) the server is in the worker's `.mcp.json` and (b) the tool name is in
`allowed_tools`. That is a complete, already-built permission mechanism.

- **A separate `mcp_tools:` field would fork the permission model** — two lists to keep in sync,
  two places the dispatch-safety reviewer must check. Don't.
- **Universal availability is unsafe** — it would hand every cheap ollama-loop classifier
  (`escalation-triage.yaml`, `allowed_tools: [Read]`) the ability to call `work_on` /
  `task_update`. The closed-by-default `allowed_tools` posture is the correct safe default.

**Interaction with IW-3 auth (Candidate A env-inherit):** composes cleanly. Workflows already
carry an `env:` map (`escalation-triage.yaml:env: {ANTHROPIC_BASE_URL, ANTHROPIC_API_KEY}`,
surfaced in the envelope at `resolver.py:530`). The same map carries `$CLAUDECODE` / `$AI_AGENT`
to the worker, so the env-inherit auth signal travels the existing channel — **no new transport.**

**`worker_kind: mcp`?** No. "Use MCP" is **orthogonal** to `worker_kind`. A `TermLink` worker
and an `ollama-loop` worker could both call framework MCP tools if `allowed_tools` permits and
the server is wired; the worker_kind selects the *executor process*, not its tool surface.
Adding `mcp` to `VALID_WORKER_KINDS` (`resolver.py:59`) would conflate the two axes.

**Impact on existing 5 (8) workflow YAMLs: ZERO.** None list `mcp__framework__*` in
`allowed_tools`, so none can call the new tools — safe-closed by default. A workflow opts in
only when a worker genuinely needs a framework primitive (lands in Slice 3, see assignment).

---

## OR-6 Per-slice procedural debt

**Manual / CI-cron / Verification-block?** **Verification block (P-011), with the daily audit
cron as backstop** — mirroring the existing cron-touching rule already in CLAUDE.md (L-364).

Given OR-1's manifest + OR-2's scan extension, the discharge is mechanical: each slice that
lands tools must (1) append manifest rows with declared `class`, (2) include in its
`## Verification` section:

```
out=$(bash agents/audit/orchestrator-mcp-scan.sh 2>&1); echo "$out" | grep -q "=== orchestrator-mcp-scan (pass) ==="
```

P-011 runs this on `--status work-completed`; if a new tool is unclassified, missing from the
manifest, or a mutator lost its gate, the scan exits non-zero and **the slice cannot close**.
This is the earliest possible gate — same philosophy as the cron registry→generated→deployed
chain (CLAUDE.md §Verification Gate). The **daily `orchestrator-mcp-scan` audit cron** catches
anything that slips past task-close (post-hoc manifest edits, tools added outside a slice).

**Which slice introduces it:** **Slice 1.** Slice 1 is the read-only server scaffold (T-2209
Shape-2). It is the first slice to land tools, so it *must* carry the OR-2 probe extension and
the OR-6 Verification convention — otherwise its own 22 read-only tools are invisible to the
immune system. Slices 2..N inherit the convention for free (append manifest rows + the same
Verification line).

---

## BVP Scoring

Scoring the **recommended integration work** (the manifest + scan-extension + decisions above),
against the active v3 drivers (`policy/value-drivers.yaml`). This is the integration *substrate*,
not the overlay's user-facing capability (that is T-2209's core, scored on its own anchor).

| Driver | Wt | Score | Rationale |
|--------|----|-------|-----------|
| D1 Antifragility | 9 | 3 | Adds a drift-defense leg so a new framework mutator can't silently skip governance — the system gains an immune response to its own new organ. Defensive plumbing, not failure-as-learning, so mid-band. |
| D2 Reliability | 7 | 4 | Squarely "no silent failures": manifest+scan+freshness-check means an ungated/unclassified tool is a structural FAIL at task-close, not a latent gap. Strongest fit. |
| D3 Usability | 5 | 3 | Reusing `allowed_tools` instead of a new `mcp_tools:` field, and author-declared manifest class, keep the schema small and the author path obvious. |
| D4 Portability | 3 | 3 | Manifest is language-agnostic (survives the IW-1 Python-or-other choice); MCP + JSON are standards. Avoids re-inheriting /opt/termlink's grep-over-Rust coupling. |
| F-RECALL | 6 | 1 | Integration adds no positive-knowledge-accumulation surface. (The memo itself is recall; the build isn't.) |
| F-ORCH | 5 | 4 | Direct bullseye for the rubric's L3–L4: the manifest is "a clean typed I/O contract … so the framework can refuse-or-dispatch the step mechanically" (rubric 3) and it lets the new routable surface be policed by the orchestrator's drift defenses (rubric 4). Not a 5 — this lens wires the surface *into* the substrate; the surface *expansion* itself is T-2209's core. |

Weighted sum (integration leg): `9·3 + 7·4 + 5·3 + 3·3 + 6·1 + 5·4 = 27+28+15+9+6+20 = 105`.
**Headline:** F-ORCH + D2 are the load-bearing drivers, consistent with this being
orchestrator-substrate reliability work.

*(Estimator-proposed scores only — `bvp_scores:` is set by `fw bvp confirm`, operator-owned.)*

---

## Cost Estimate

F8 composite `0.6·blast_radius + 0.3·tier + 0.1·effort`, for the **incremental integration
work this lens adds** (rolls UP into the T-2209 arc total — this is not a separate arc):

| Component | Value | Basis |
|-----------|-------|-------|
| blast_radius | 3 | Touches `orchestrator-mcp-scan.sh` (one audit script), `orchestrator-mcp-baseline.yaml` (one data file, additive namespace), and the server build step (manifest emitter). No resolver.py change, no route_cache change, no workflow-schema change. |
| tier | 2 | Agent-authority build (Tier 1 standard ops) → numeric 2. No sovereignty surface (the new tools are read-only + agent-authority; sovereignty verbs stay shell-only per T-2209 §3). |
| effort | 3 | S–M: ~40 LoC scan extension + manifest emitter + per-slice Verification line. The decisions (OR-1/3/4/5) are zero-build. |

**F8 = 0.6·3 + 0.3·2 + 0.1·3 = 1.8 + 0.6 + 0.3 = 2.7** (T-shirt **S–M**). Folds into Slice 1's
cost; does not add a slice of its own beyond what Slice 1 already carries.

---

## Slice Assignment

| OR | Recommendation | Lands in | Build or Decision |
|----|----------------|----------|-------------------|
| OR-1 | Manifest-declared classification | **Slice 1** | Decision + manifest schema (small build: emitter) |
| OR-2 | `probe_framework_tools()` + manifest merge + freshness check in scan | **Slice 1** | **Build** (~40 LoC, the one real leg) |
| OR-3 | Do NOT capture MCP calls in `dispatches.jsonl`; optional separate call-log | **standalone** | Decision (null); optional micro-build deferred to IW-4 headline work |
| OR-4 | Exclude MCP calls from route_cache; no parallel learner | **standalone** | Decision (null) |
| OR-5 | Reuse `allowed_tools`; no `mcp_tools:` field; no `worker_kind: mcp` | **Slice 3** | Decision now; wiring (add tool names to one workflow's `allowed_tools`) only when a worker needs it |
| OR-6 | `## Verification` runs the scan; daily cron backstop | **Slice 1** introduces; **all slices** reuse | Convention (process), discharged per-slice |

---

## Verdict

**The orchestrator-routing lens is ~80% absorbed into the existing slice plan as decisions, and
adds one bounded build leg — it does NOT spawn a new arc or a new slice.**

- **Four of six questions are decisions with zero or near-zero build:** OR-1 (manifest schema —
  trivial emitter), OR-3 (explicit no), OR-4 (explicit exclude), OR-5 (reuse `allowed_tools`,
  no schema change to any of the 8 existing workflows).
- **One genuine build leg:** OR-2 — extending `orchestrator-mcp-scan.sh` so the framework's own
  MCP server is *visible* to the drift-defense immune system. This is non-optional: without it,
  Slice 1's own read-only tools are invisible to governance, reproducing the T-1641-W10 "silently
  skip governance" failure one repo over. **It lands in Slice 1** (the read-only scaffold slice),
  cost F8≈2.7 (S–M), rolling into the T-2209 arc total.
- **One process convention:** OR-6 — the per-slice `## Verification` line + daily cron backstop,
  introduced by Slice 1, inherited by all later slices at zero marginal cost.

The lens **sharpens** the existing arc rather than expanding it: it converts "ship an MCP server"
into "ship an MCP server *that the framework's drift defenses can see and police*," which is the
difference T-1641 spent ten workers establishing matters. Recommend the parent fold OR-2 + OR-6
into Slice 1's acceptance criteria and record OR-3/OR-4/OR-5 as decisions in the arc's design
log. No new build task beyond Slice 1's existing scope.

---

## Open Sub-Questions

1. **Manifest format/location** depends on IW-1's language choice (Python vs other) — the
   `framework-mcp-manifest.json` shape above is illustrative; finalize when the server stack is
   decided.
2. **Should the framework MCP server emit a per-call audit log** (request IDs, idempotency keys
   from HM-A)? Overlaps with IW-4 headline-mechanic and T-2215's CLI error-pattern lens — out of
   scope here; flagged in OR-3 as an optional micro-build.
3. **One baseline file vs two?** This memo assumes one `orchestrator-mcp-baseline.yaml` holding
   both `termlink_*` and `mcp__framework__*` names (they don't collide by prefix). If the
   operator prefers physical separation, a sibling `framework-mcp-baseline.yaml` + a second scan
   invocation is equivalent — a cosmetic call, not a structural one.
4. **If sovereignty-bound verbs are ever MCP-exposed** (explicitly out of the first arc, T-2209
   §3), OR-3/OR-4 may need revisiting — a sovereignty MCP call is still deterministic (route_cache
   exclusion holds), but the per-call audit log (OR-3) would become mandatory, not optional.
5. **Cross-repo convention reuse:** the `mcp__framework__*` manifest pattern is strictly better
   than /opt/termlink's grep-over-Rust probe. Worth a cross-link to the termlink baseline owners
   as a forward proposal (out of scope — path isolation; propose via TermLink, do not edit).
