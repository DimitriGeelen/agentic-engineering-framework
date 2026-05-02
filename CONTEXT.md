# Agentic Engineering Framework

The framework's domain language. Captured during the orchestrator-as-triage architectural rethink (T-1687 / forthcoming arc). Add terms only when they have been explicitly resolved during a grilling session — do not pre-populate from speculation.

## Language

**Agent**:
The parent Claude Code session running the project's CLAUDE.md. Authoritative for (1) task lifecycle — create, ensure-updates, close-with-guards — and (2) work that requires extensive mid-stream operator interaction (inception, grilling, design dialogue). All other substantive work is routed to Workers via dispatch. The Agent does as little of (3) — non-interactive substantive work — as possible.
_Avoid_: Main agent, parent agent, framework agent (all redundant — there is only one Agent in a session). Also avoid framing the Agent as a general reasoning engine — that overstates its role; substantive reasoning on dispatchable work belongs to Workers.

**Orchestration**:
The Agent's responsibility to (a) match incoming work to a Workflow, (b) compose a Delegation envelope from that Workflow's defaults, (c) dispatch the Worker. A verb, not a noun-entity. The Agent does NOT make ad-hoc inline-vs-delegate calls on substantive work. The decision rule is structural: **interactive** work stays inline with the Agent because Workers have no efficient operator-interaction channel; **non-interactive** substantive work dispatches.
_Avoid_: Routing (too narrow — orchestration includes envelope composition, not just lookup), Dispatch (only the last step), Reasoning (overstates — orchestration is mostly table-driven).

**Workflow**:
A named, human-curated configuration that maps a task_type to a Delegation envelope template. Stored as **one YAML file per workflow** in `.context/project/workflows/<task_type>.yaml` — same one-file-per-entity pattern as `.context/arcs/<id>.yaml` and `docs/adr/000X.md`. v1 schema per file (six required fields, plus `worker_kind` and `inline`):
```yaml
# .context/project/workflows/build.yaml
task_type: build
worker_kind: TermLink          # Task | TermLink | pi
model: sonnet                  # alias or full name
effort: medium                 # low | medium | high | xhigh | max
prompt_template: prompts/build.md
allowed_tools: [Read, Edit, Bash, Grep]
cost_cap_usd: 1.50             # optional
cwd: $PROJECT_ROOT
env:                           # optional; redirect endpoint per workflow
  ANTHROPIC_BASE_URL: http://localhost:8000  # e.g. proxy in front of ollama
```
```yaml
# .context/project/workflows/cheap-research.yaml
task_type: cheap-research
worker_kind: pi                # use pi for subscription-backed inference
provider: anthropic-pro        # pi-specific: which pi-backend
model: claude-sonnet-4-6
prompt_template: prompts/research.md
cost_cap_usd: 0                # subscription quota, $0/call
cwd: $PROJECT_ROOT
```
```yaml
# .context/project/workflows/inception.yaml
task_type: inception
inline: true                   # Agent does this; never dispatched
```
```yaml
# .context/project/workflows/complex-build.yaml — Tier 3 (meta-prompted)
task_type: complex-build
worker_kind: TermLink
model: sonnet
effort: high
prompt_template: prompts/build.md
prompt_strategy: meta-prompted   # static | assembled | meta-prompted (default: assembled)
meta_model: haiku                # smaller than worker model; required when prompt_strategy=meta-prompted
meta_template: prompts/meta/build.md
allowed_tools: [Read, Edit, Bash, Grep]
cost_cap_usd: 2.50
outcome_evaluator: scripts/eval/build-outcome.sh   # optional; scores quality post-dispatch
variants:                        # optional A/B/C; default = no variants
  A: { weight: 0.5, prompt_template: prompts/build.md }
  B: { weight: 0.5, prompt_template: prompts/build-v2.md }
cwd: $PROJECT_ROOT
```
Additional fields (`mcp_config`, `add_dirs`, `system_prompt_mode`, `permission_mode`, `disallowed_tools`) graduate into the schema only when a real Worker pattern demands them — no speculation.

**Prompt strategy (Q10, 2026-05-03) — three tiers, declared per workflow:**

| Tier | `prompt_strategy` | Construction | Cost | When |
|------|-------------------|--------------|------|------|
| 1 | `static` | Pure file, no variables | $0 | Trivial workers |
| 2 | `assembled` | `$VAR` substitution + resolver-side context selection from `dispatches.jsonl`, `patterns.yaml`, frontmatter | $0 | **Default** — most workflows |
| 3 | `meta-prompted` | LLM call (cheaper meta-model) composes/refines the prompt before dispatch | small extra LLM call | Quality-sensitive, high-value dispatches where prompt-construction leverage > meta-cost |

The resolver, not the template language, is where prompt quality is constructed in Tier 2. It populates variables from sources beyond task frontmatter (last-N dispatch outcomes for the task_type from `dispatches.jsonl`; matched healing patterns from `patterns.yaml`; few-shot examples from `prompts/examples/`). It also wraps optional sections so empty values don't leave dangling headers. Self-improving prompts (an agent that mines `dispatches.jsonl` and rewrites templates over time) is **deferred to v2** — but v1 wires the substrate so the v2 loop has data to learn from (see Resolver section below). The Agent reads the workflow file on every dispatch. **Fallback (Q12, 2026-05-03):** if `.context/project/workflows/<task_type>.yaml` is missing, the resolver reads `.context/project/workflows/default.yaml`; if `default.yaml` is also missing, that is a framework install bug and the Agent hard-errors. There is no magic-string default in code — just one file lookup with one fallback step. The framework ships a baseline set: `default.yaml` (TermLink + sonnet + medium + standard tools), plus `inception.yaml` / `grilling.yaml` / `design-dialogue.yaml` pre-marked `inline: true` so the structural cut from ADR-0002 is encoded in shipped files rather than operator memory. The dispatch log (`dispatches.jsonl`) records both the original `task_type` and the resolved `workflow_id` so default-routed dispatches don't blur into one telemetry bucket.
_Avoid_: Profile, Preset, Recipe (all imply UI-decoration; Workflow is load-bearing config).

**Worker**:
A dispatched executor that runs a Delegation envelope. Three wired flavours in v1, each with distinct trade-offs:

- **`Task`** — Claude Code's Task tool sub-agent. In-session, shares context with the Agent. Cheapest to spawn; expensive in parent context budget. Best for quick read-only research within the active session.
- **`TermLink`** — Claude (or any Anthropic-protocol-speaking endpoint) via `claude -p` spawned through TermLink. Full Claude Code ecosystem: MCPs, plugins, all built-in tools, permission modes. Per-workflow `env:` redirects via `ANTHROPIC_BASE_URL` (binary-confirmed: 52 references in claude 2.1.126) — points at Anthropic API directly OR at a proxy (`litellm --anthropic_api_format`, `claude-code-router`, `claude-bridge`) that fronts ollama / OpenAI / OpenRouter / etc. LM Studio has native Anthropic-API-compat. **This is the default Worker path** for any work that benefits from the full Claude ecosystem.
- **`pi`** — `pi` (Pi mono coding-agent, github.com/badlogic/pi-mono) spawned in RPC mode (LF-delimited JSONL stdin/stdout). 23+ providers via API keys, plus **subscription-backed inference** (Anthropic Pro/Max, OpenAI Plus/Pro, GitHub Copilot — zero per-token cost on subscription quotas). Built-in tools only (read/write/edit/bash/grep/find/ls), no native MCP. Best for cost-optimized non-interactive work where subscription quota matters more than tool ecosystem.

The choice between `TermLink` and `pi` for non-Claude work is a trade-off between full Claude Code ecosystem (`TermLink` + proxy) and subscription-cost optimization (`pi`). Workflow files set `worker_kind` per task_type.

Always strictly downstream of the Agent. Workers do the substantive reasoning the Agent intentionally does not. **Envelope fidelity is full only for `TermLink` (with Anthropic-protocol endpoints)**: `allowed_tools`, `mcp_config`, and `permission_mode` map cleanly there. For `pi`, those reduce to its built-in toolset; `mcp_config` is silently ignored unless a pi extension supplies MCP. This asymmetry is intentional and surfaced in workflow validation.
_Avoid_: Sub-agent (ambiguous — Claude Code's "sub-agent" concept conflates Task tool and TermLink), Specialist (overloaded with TermLink's specialist registry).

**Delegation envelope**:
The structured input to a Worker. Composed by the Agent from a Workflow plus the live task context. v1 expansion of a Workflow entry: `worker_kind` (Task | TermLink | provider), `model`, `effort`, `prompt` (template rendered with task context), `allowed_tools`, `cost_cap_usd`, `cwd`, plus the `dispatch_id` that ties the dispatch to its `dispatches.jsonl` record and `.context/dispatch-blobs/<YYYY-MM>/<dispatch-id>/` blob directory (full prompt text, meta-prompt text if Tier 3, worker artifacts). Workers always launch with `--bare` (skip hooks/plugins/auto-memory/CLAUDE.md auto-discovery) — that's a Worker invariant, not a per-workflow knob. The Agent may pass an `overrides` map to apply chat-time user instructions on top of the Workflow defaults. The unit of dispatch.
_Avoid_: Job, Request, Task (collides with the framework's Task concept, T-XXX).

**Resolver**:
The Agent-side function that turns a Workflow + live task context into a Delegation envelope. Three responsibilities:
1. **Workflow lookup** — read `<task_type>.yaml`, fall back to `default.yaml` per Q12.
2. **Prompt construction** — execute the workflow's `prompt_strategy` (static / assembled / meta-prompted). For `assembled`, populate `$VAR` slots from frontmatter + `dispatches.jsonl` (last-N outcomes for the task_type) + `patterns.yaml` (matched healing hints) + `prompts/examples/` (few-shot), wrapping optional sections so empty values omit headers. For `meta-prompted`, run the meta-model with the meta-template against the assembled context, take its output as the worker prompt.
3. **Variant selection** — if the workflow declares `variants:`, pick one weighted-randomly; record the variant ID.
4. **Telemetry capture** — every dispatch gets a unique `dispatch_id`, a row in `dispatches.jsonl`, and a `.context/dispatch-blobs/<YYYY-MM>/<dispatch-id>/` directory. v2 self-improvement reads from these; v1 only writes. See "v2-readiness" below.

## Relationships

- The **Agent** runs on a model configured per-project (default `opus`, key `AGENT_MODEL` in `.framework.yaml`). The configured model is *the* orchestration model — there is no separate orchestration tier.
- The **Agent**'s job has three slices: (1) **task management** — create, ensure-updates, close-with-guards — done by the Agent, authoritatively; (2) **interactive work** — inception, grilling, design dialogue, anything where operator interjection mid-stream is essential — done by the Agent because Workers cannot efficiently solicit operator input; (3) **dispatch** — all other substantive work, routed to Workers.
- The **Agent** consults **Workflow** files in `.context/project/workflows/<task_type>.yaml` to compose **Delegation envelopes**. The human curates these files (one per task_type); the Agent does not invent envelopes from scratch.
- A **Delegation envelope** is the only artefact a **Worker** sees from the **Agent**.
- The **Agent** observes Worker outcomes (success/failure, cost, duration) and writes them to two artifacts: `route_cache.json` (sparse aggregates per provider+model+task_type, used by the resolver — no info loss but lossy by design) and `dispatches.jsonl` (append-only per-dispatch log; rich schema below). Cache feeds future dispatches; log feeds telemetry / auto-improvement / healing batch jobs. Log rotates monthly to `dispatches-YYYY-MM.jsonl`. Routing memory does NOT override `workflows.yaml` — the human-curated table wins.

## v2-readiness (the wiring v1 must ship)

Self-improving prompts are deferred to v2, but the v2 loop can only learn from data that exists. v1 commits to capturing every byte v2 will need so retrofit is unnecessary. The architectural test for any v1 design choice on the dispatch path: **"if v2 wants to learn whether prompt-revision X improves outcome Y, can the loop read enough from `dispatches.jsonl` + blobs + episodic to answer that?"**

**`dispatches.jsonl` rich schema (v1).** Many fields nullable in v1; all reserved:
```
ts, dispatch_id, task_id, parent_dispatch_id, workflow_id, workflow_sha,
prompt_strategy, prompt_template, prompt_template_sha, prompt_blob_ref,
meta_model, meta_template, meta_template_sha, meta_prompt_blob_ref,
variant_id, worker_kind, model, effort, allowed_tools,
cost_usd, duration_ms, exit_code,
verification_passed, ac_satisfied, human_accepted, task_completion_outcome,
artifact_blob_refs, override_applied, retry_of_dispatch_id
```

**`.context/dispatch-blobs/<YYYY-MM>/<dispatch-id>/`** stores `prompt.txt`, `meta-prompt.txt` (Tier 3 only), `artifacts/` (worker output files). Same inline-vs-blob threshold as `fw bus` blobs (T-1063): <2KB inline in the JSONL row, ≥2KB blob-referenced. Rotation aligned with the JSONL.

**Template versioning at dispatch time.** Resolver computes `git rev-parse HEAD:.context/project/workflows/<task_type>.yaml` and `:prompts/<template>.md` and records both SHAs. Falls back to file-mtime hash if uncommitted, flagged in the record so v2 can exclude unstable rows.

**Outcome enrichment hook.** Workflows declare an optional `outcome_evaluator` script. After Worker exit, the resolver runs it; output (`{verification_passed, ac_satisfied, quality_score, notes}`) goes into the dispatch record. Default evaluator: did `## Verification` pass + are all `### Agent` ACs ticked. Custom evaluators can score quality.

**A/B variant slot.** Workflow files support optional `variants:` map (A/B/C, weights). Resolver picks per dispatch, records the variant ID. Default: no variants — operators opt in by editing the workflow file. v1 enables A/B without code changes; v2 automates variant generation.

**Quality-signal back-propagation.** When a task transitions to `work-completed` (or `issues`) AFTER a dispatch ran for it, the resolver back-fills the dispatch record's `task_completion_outcome` field. Without this, the loop sees only short-horizon outcomes.

**`fw orchestrator improve` command stub.** Reserved namespace, exits with "v2: not yet implemented; data is being captured at .context/dispatches.jsonl and .context/dispatch-blobs/". Visible to operators, locks in the CLI surface.

**What v1 does NOT build:** analysis tools, learning logic, template rewriting, auto-variant generation, meta-prompt optimization, cross-task generalization. v1 records; v2 learns.

## Example dialogue

> **User:** "Run the orchestrator audit refactor."
> **Agent (mentally):** Triage — this is a substantive build. Delegate? Yes — different model class needed for the implementation than for triage. Compose envelope: TermLink worker, model=sonnet, prompt=<crafted>, context_pack={CLAUDE.md fragment scoped to build-task, MCPs limited to read+edit+test, tools={Read, Edit, Bash, Grep}, cwd=this repo}. Dispatch.
> **Worker:** runs the build, writes results, exits.
> **Agent:** observes outcome, updates route_cache, reports to user.

## Flagged ambiguities

- "Framework agent" was used informally to refer to (a) the parent Claude Code session, (b) a hypothetical separate orchestrator entity. **Resolved 2026-05-02**: there is no separate orchestrator. The Agent (singular) does orchestration as one of its responsibilities. "Framework agent" should be retired in favour of "Agent."
- "Orchestrator" was used as a noun-entity in early drafts of the rethink. **Resolved 2026-05-02**: orchestration is a verb the Agent performs, not a separate entity. Speak of "orchestration" (the responsibility), not "the orchestrator" (the thing).
- "Agent reasons inline" was an early framing of how the delegation moment works. **Resolved 2026-05-02 (Q5)**: the Agent does NOT make case-by-case inline-vs-delegate decisions on substantive work. The cut is structural — interactive work (inception, grilling, design dialogue) stays inline because Workers can't efficiently ask the operator questions; everything else dispatches via Workflow lookup.
- "What happens when a task_type has no workflow file?" was open during Q11. **Resolved 2026-05-03 (Q12)**: fall back to `default.yaml` (also a real workflow file), with shipped baseline workflow files for the interactive task_types so missing-file ≠ silent dispatch of inception/grilling. No magic-string default in code; missing `default.yaml` is treated as a framework install bug.
- "Plain $VAR vs jinja2 vs dynamic generation" (substrate framing) was the wrong question. **Resolved 2026-05-03 (Q10)**: prompt construction is a per-workflow choice across three tiers — `static` / `assembled` (default) / `meta-prompted`. The substrate is plain text + `$VAR`, but the resolver does context selection (not just substitution) — populating variables from `dispatches.jsonl`, `patterns.yaml`, `prompts/examples/`. Tier 3 spends tokens on a meta-LLM step for quality-sensitive dispatches. **Self-improving prompts deferred to v2**, but v1 wires the data substrate (rich `dispatches.jsonl` schema, blob storage, template SHAs, A/B variant slot, outcome evaluator hook, quality-signal back-propagation, reserved `fw orchestrator improve` namespace) so v2 needs no retrofit. See ADR-0003.
- "How does the framework handle pi being missing on the host?" was open after Q11 introduced pi as a Worker. **Resolved 2026-05-03 (Q13)**: `fw doctor` reports "pi not installed; workflows declaring `worker_kind: pi` will fail" with the install command. No auto-install at claude-fw startup — installing an external dependency from the wrapper boot path silently mutates the user's machine; matches the existing pattern (TermLink is also doctor-warned, not auto-installed). Operator runs the install command consciously.
- "Are workflow files validated before they run?" was open after Q12 introduced workflow files as load-bearing config. **Resolved 2026-05-03 (Q14)**: `fw doctor` lints all `.context/project/workflows/*.yaml` for schema correctness — required fields per tier, `worker_kind` in enum, `prompt_template` resolves to an existing file, `meta_model` set iff `prompt_strategy=meta-prompted`, `inline:true` exclusive of dispatch fields, soft warning if `default.yaml` missing. Same pattern as `fw audit` checking task frontmatter. The first dispatch is not the first time the schema is checked.
