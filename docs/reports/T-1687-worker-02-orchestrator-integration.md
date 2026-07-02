# T-1687 Worker 02 — Escalation-Triage Workflow ↔ Orchestrator Integration

Investigation of how `escalation-scan-v0.5.py` and the `escalation-triage` workflow
integrate with the `lib/resolver.py` dispatch substrate (T-1687 arc, orchestrator v1).

## 1. How escalation-scan-v0.5.py dispatches to the orchestrator

`tools/escalation-scan-v0.5.py` is a per-candidate LLM-augmentation pass that runs
after the heuristic v0 scan. It does NOT talk to litellm directly through the
resolver — it uses the resolver only to build/capture the dispatch envelope, then
makes its own HTTP call.

- Imports `lib/resolver` and `lib/outcome` directly (`sys.path.insert(0, ROOT/"lib")`,
  lines 41-44).
- For each candidate task (bug-class, completed, no `## RCA`, within the scan
  window), it builds a `task_context` dict from `resolver.load_task_frontmatter(short_id)`
  plus synthetic fields (`TASK_ID`, `TASK_TYPE=escalation-triage`, `TASK_NAME`,
  `ACCEPTANCE_CRITERIA=(none)`, and `CANDIDATE_BODY` = the truncated task body,
  lines 420-427).
- Calls `resolver.resolve(short_id, "escalation-triage", task_context, dry_run=args.dry_run)`
  (line 430) — this is the actual orchestrator touch-point. `resolve()` loads the
  `escalation-triage` workflow, assembles the prompt, selects a variant, and
  captures a dispatch row to `.context/dispatches.jsonl` + a prompt blob under
  `.context/dispatch-blobs/`.
- The script then extracts `dispatch_id` and `rendered_prompt` from the returned
  envelope (lines 443-444) and — rather than handing execution back to the
  orchestrator's worker-kind machinery — makes its own direct `urllib` POST to
  litellm's `/v1/messages` endpoint (`call_litellm()`, lines 199-240), using the
  same wire path `ollama-tool-loop.py` uses. This is explicitly documented in the
  module docstring: "executes the LLM call via direct litellm POST ... same path
  ollama-tool-loop.py uses" (lines 6-9).
- After the call, it parses the fenced-YAML verdict envelope
  (`parse_verdict_envelope()`, with a regex fallback for sloppy/unquoted output,
  T-1748) and back-props the result via `outcome.backprop_outcome(short_id, {...})`
  (lines 496-502), which appends one row per matching `dispatch_id` to
  `.context/dispatch-outcomes.jsonl`.

So the integration is: **resolver for envelope/telemetry capture, but the script
itself is the worker** (it does not shell out to `fw resolver run`, TermLink, or
a `claude -p` subprocess). This makes `escalation-triage` a `worker_kind: ollama-loop`
workflow where the orchestrator's job is bookkeeping (dispatch row + prompt blob +
outcome back-prop), not process spawning.

## 2. Workflow file for escalation-triage

Two files define the workflow:

- **`.context/project/workflows/escalation-triage.yaml`** — the workflow
  definition `lib/resolver.py:load_workflow()` reads (`WORKFLOWS_DIR / "<task_type>.yaml"`):
  ```yaml
  task_type: escalation-triage
  worker_kind: ollama-loop
  model: claude-3-5-sonnet-hermes3
  effort: low
  prompt_template: prompts/escalation-triage.md
  allowed_tools: [Read]
  cost_cap_usd: 0.0
  cwd: $PROJECT_ROOT
  env:
    ANTHROPIC_BASE_URL: http://localhost:4000
    ANTHROPIC_API_KEY: sk-litellm-local-dev
  ```
  Notes captured in the file's trailing comments: this is "G-064 first real
  consumer" of the orchestrator substrate; `allowed_tools: [Read]` enforces the
  classifier mutates nothing (verdict-emission only); `cost_cap_usd: 0.0` pins it
  to the local ollama model (no cloud fallback) — per L-355 the 7-8B local ceiling
  is ~76-79% accuracy, judged tolerable for an advisory queue.

- **`prompts/escalation-triage.md`** — the actual prompt template referenced by
  `prompt_template:` above. It instructs the LLM to classify one completed task
  as `real_symptom_fix`, `false_positive`, or `defer`, using `$TASK_ID`,
  `$TASK_TYPE`, `$TASK_NAME`, `$TASK_DESCRIPTION`, and `$CANDIDATE_BODY`
  placeholders (resolver's `assemble_prompt`/`_assembled_substitute` performs the
  `$VAR` substitution — `prompt_strategy` defaults to `assembled`). Output
  contract is a single fenced `yaml` block with `verdict`, `rationale`,
  `confidence` (0.0-1.0). Includes explicit calibration examples for all three
  verdicts and a "when in doubt, prefer real_symptom_fix" bias (false positives
  are cheap, false negatives make the systemic gap invisible).

## 3. How dispatch envelopes are created and what parameters are passed

`lib/resolver.py:resolve()` (lines 562-605) is the end-to-end entry: workflow
lookup → prompt assembly → variant selection → `capture_dispatch()`. For the
escalation-triage caller specifically:

- **Workflow lookup**: `load_workflow("escalation-triage")` → primary
  `.context/project/workflows/escalation-triage.yaml` (Q12 fallback to
  `default.yaml` only if the primary is missing). Rejects `inline: true`
  workflows (ADR-0002) and validates `worker_kind` against
  `VALID_WORKER_KINDS = {"Task", "TermLink", "pi", "ollama-loop"}`.
- **Prompt assembly**: `assemble_prompt()` substitutes `$VAR` tokens in
  `prompts/escalation-triage.md` from the `task_context` dict the script built
  (`TASK_ID`, `TASK_TYPE`, `TASK_NAME`, `TASK_DESCRIPTION`, `ACCEPTANCE_CRITERIA`,
  `CANDIDATE_BODY`).
- **Variant selection**: `select_variant()` — no `variants:` block is declared in
  escalation-triage.yaml, so this always returns `None`.
- **Dispatch capture** (`capture_dispatch()`, lines 455-542): mints a UUID
  `dispatch_id`, timestamps it, writes the rendered prompt to
  `.context/dispatch-blobs/<yyyy-mm>/<dispatch_id>/prompt.txt`, and appends a row
  to `.context/dispatches.jsonl` containing: `schema_version`, `ts`,
  `dispatch_id`, `task_id`, `parent_dispatch_id` (null here), `task_type`
  (`escalation-triage`), `workflow_id`, `workflow_sha` / `template_sha` (git blob
  SHAs of the workflow YAML and prompt template, for provenance), `prompt_strategy`
  (`assembled`), `worker_kind` (`ollama-loop`), `model`
  (`claude-3-5-sonnet-hermes3`), `effort` (`low`), `variant_id` (null),
  `blob_dir`, and `outcome: "pending"`.
- The **envelope** returned to the caller additionally carries: `prompt`
  (fully rendered text), `allowed_tools: [Read]`, `strict_mcp_config` (defaults
  True), `cost_cap_usd: 0.0`, `cwd` (resolved `$PROJECT_ROOT`), `env`
  (the `ANTHROPIC_BASE_URL` / `ANTHROPIC_API_KEY` pair pointing at the local
  litellm proxy on `:4000`), and `blob_dir`.
- `escalation-scan-v0.5.py` reads `envelope["dispatch_id"]` and
  `envelope["rendered_prompt"] or envelope["prompt"]` back out (line 444) and
  uses those two fields to drive its own `call_litellm()` — everything else in
  the envelope (allowed_tools, cwd, strict_mcp_config) is unused by this
  particular consumer since it isn't spawning a `claude -p` process.

`--dry-run` short-circuits before the litellm call: the resolver still mints a
`dispatch_id` and writes the dispatch row (`resolver.resolve(..., dry_run=args.dry_run)`
still passes `write=not dry_run` down to `capture_dispatch`, so dry-run actually
skips the JSONL append/blob mkdir per the `write` flag) and the script records a
`verdict: DRY-RUN` candidate row without calling the LLM.

## 4. Where outcomes get recorded

`.context/dispatch-outcomes.jsonl` — append-only, one row per matching
`dispatch_id` (a task can have multiple prior dispatches; `find_dispatch_ids()`
returns all of them and `backprop_outcome()` writes one outcome row per match,
which is why the tail of the file shows 2-3 near-duplicate rows per `task_id` for
some candidates).

- Row shape: `{schema_version, ts, dispatch_id, task_id, outcome: {evaluator,
  verdict, rationale, confidence}}`.
- Written via `outcome.backprop_outcome(short_id, {...})` (`lib/outcome.py:172-209`),
  called from `escalation-scan-v0.5.py` in two places: on LLM-call failure
  (`verdict: "ERROR"`, lines 471-479) and on successful parse (lines 496-502,
  `evaluator: "escalation-scan-v0.5"`).
- `backprop_outcome` never touches `dispatches.jsonl` itself — read-side joins
  happen via `outcome.read_dispatch()` / `list_outcomes_for_task()`, which merge
  the two JSONL files by `dispatch_id`.
- The script also writes its own summary/report file,
  `.context/working/escalation-drift-LATEST-v0.5.yaml` (atomic tmp+replace,
  `write_output()`), independent of the outcomes log — this is the
  human/dashboard-facing artifact (`generated`, `v0_corpus_total`,
  `v0_h1_flagged`, `window_days`, `model`, `dispatched`, `skipped_idempotent`,
  `errors`, and the per-candidate `candidates:` list). Confirmed live: the file
  on disk (generated `2026-07-01T03:33:02Z`) shows `v0_corpus_total: 2157`,
  `v0_h1_flagged: 340`, `dispatched: 0`, `skipped_idempotent: 5` for that run —
  candidates within the 7-day idempotency window are skipped and their prior
  verdict is carried forward rather than re-dispatched.
- `tools/g064-readiness.py` (referenced in the cron registry description) reads
  `.context/dispatches.jsonl` filtered to this cron's window as the primary
  closure-gauge for G-064 (orchestrator substrate adoption).

## 5. Cron job

Yes — registered in `.context/cron-registry.yaml` and confirmed **deployed** in
`/etc/cron.d/agentic-audit-999-agentic-engineering-framework` (verified live on
disk, not just registry-declared):

```
23 5 * * * root cd "/opt/999-Agentic-Engineering-Framework" && python3 tools/escalation-scan-v0.py 2>&1 | logger -t agentic-cron
33 5 * * * root cd "/opt/999-Agentic-Engineering-Framework" && python3 tools/escalation-scan-v0.5.py --window-days 30 --limit 200 2>&1 | logger -t agentic-cron
```

Two registry entries:

- `escalation-drift-daily` (id, origin T-1555) — `23 5 * * *` — runs v0 (pure
  heuristic, no orchestrator involvement): scans `.tasks/completed/` for H1
  (bug-class w/o RCA), H2 (repeated learning-IDs across 3+ tasks/30d), H3
  (bug-class w/o RCA AND no learning). Writes
  `.context/working/escalation-drift-LATEST.yaml` +
  `docs/reports/T-1549-escalation-scan-v0.md`.
- `escalation-scan-v0-5` (id, origin T-1727) — `33 5 * * *`, 10 minutes after v0
  — runs the resolver-integrated LLM augmentation pass described above.
  `status: active` in both the registry and the deployed crontab file (verified
  content match — registry is in sync with the deployed cron line, no drift).

Both jobs use `flock`-free plain invocation (unlike some sibling entries, e.g.
mirror-sync, which wrap in `flock -n`) — daily cadence at low collision risk
given the ~10 minute stagger between the two.

## Summary of the integration chain

```
cron (05:33 UTC daily)
  → tools/escalation-scan-v0.5.py
      → collect_candidates()            [walks .tasks/completed/, same H1 rule as v0]
      → resolver.load_task_frontmatter()
      → resolver.resolve("escalation-triage", task_context)
          → load_workflow()             [.context/project/workflows/escalation-triage.yaml]
          → assemble_prompt()           [prompts/escalation-triage.md, $VAR substitution]
          → capture_dispatch()          [.context/dispatches.jsonl + dispatch-blobs/]
      → call_litellm()                  [direct POST to :4000/v1/messages — bypasses
                                          orchestrator's own worker-spawn machinery]
      → parse_verdict_envelope()
      → outcome.backprop_outcome()      [.context/dispatch-outcomes.jsonl]
      → write_output()                  [.context/working/escalation-drift-LATEST-v0.5.yaml]
```

The resolver's role here is narrower than a full "spawn and manage a worker"
orchestrator — it is the **envelope-assembly and telemetry-capture** primitive
(workflow resolution, prompt templating, dispatch-row/blob persistence,
outcome back-prop), while `escalation-scan-v0.5.py` remains the actual HTTP
caller and result parser. This is consistent with the workflow's own
`worker_kind: ollama-loop` classification (as opposed to `Task` or `TermLink`,
which would imply the resolver or a downstream `fw resolver run` spawns an
external process) — the script docstring explicitly frames the resolver here as
a G-064 "second autonomous consumer of orchestrator substrate", not a full
execution handoff.
