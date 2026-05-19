# BVP Scoring Rubric

**Filed under:** T-1921 (arc-006, value-prioritisation)
**Source artefact:** `docs/reports/T-1915-bvp-inception.md`
**Handoff:** `.context/handoffs/HANDOFF-value-prioritisation-2026-05-15.md` §7 T-NEW-6
**Risk mitigations:** R2 (rubric bias), R9 (rubric reversibility)

This document is the rubric the TermLink BVP estimator (T-1922) preloads. It is also the human reference for `fw bvp confirm` (T-1924). When this document changes, **the estimator's outputs change** — see R9 reversibility note at the end.

## How to read this rubric

For each of the four protected directives (D1–D4) and for free drivers added via `fw bvp driver --add`, score each task on a 0–5 scale per the criteria below.

| Score | Meaning |
|-------|---------|
| **0** | The task has no connection to this driver. |
| **1** | Touches the driver only incidentally; no structural effect. |
| **2** | Improves the driver locally (one site, one consumer). |
| **3** | Improves the driver at component/subsystem level. |
| **4** | Changes the driver at framework level (cross-cutting). |
| **5** | Changes the *class* of behavior the driver protects against (new structural mechanism). |

**Calibration rule:** If your gut says "this is roughly a 3", look for evidence of the level-4 signal. Most tasks score 0–3 on most drivers; 4–5 should be rare and well-evidenced.

**Determinism statement:** Two independent scorers reading the same task body at low temperature must produce scores within **±1 on every driver** for the rubric to be considered calibrated. Drift > ±1 across multiple tasks is a rubric defect to fix, not a scorer defect to tolerate.

---

## D1 — Antifragility (weight: 9)

> *System strengthens under stress; failures are learning events.* (CLAUDE.md Directive 1)

The work fixed a symptom or it strengthened the system's capacity to detect and prevent the *class* of failure.

### Score criteria

| Score | Antifragility signal |
|-------|---------------------|
| **0** | No connection — pure additive feature, no failure-class context. |
| **1** | Patches one local bug, no learning capture. |
| **2** | Fixes a bug *and* captures a learning entry pointing at the failure pattern. |
| **3** | Adds a regression test / lint / audit check that catches the same class going forward, within one component. |
| **4** | Adds a structural gate that catches the failure class at framework level (Tier 1 hook, fw doctor check, audit FAIL, completion gate). |
| **5** | Changes the *class* of failure the framework can have. New mechanism for converting incident → standing protection (e.g., new gate type, new ordering invariant, new sovereignty boundary). |

### Worked examples

- **T-1730** (focus-drift gate on `check-active-task`) — **D1: 4**.
  Reason: structural gate at framework level. The drift class that caused multiple cross-task contamination incidents now has a PreToolUse refusal with named bypass mechanisms. Catches the class, not the instance. The same fix at lib-level only would score 3.

- **T-1671** (Default-to-OPEN agent-gate on `fw arc close`) — **D1: 5**.
  Reason: introduced a new authority class — closure-decision sovereignty. Not "fix this bug" but "make this class of premature closure structurally impossible from agent sessions". Cited 4 prior pushback incidents as evidence; a new gate type entered the framework's vocabulary.

- **T-1550** (RCA gate + `## RCA` template for bug-class tasks) — **D1: 5**.
  Reason: structural enforcement of root-cause capture. Without this, 99% of bug-class tasks shipped without RCA; with it, RCA absence blocks `--status work-completed`. Converted a folklore norm into a gate.

### Common mis-scorings

- ❌ "Wrote a unit test for the fix" → that's D2 (reliability), not D1, unless the test specifically targets the failure *class* not the instance.
- ❌ "Added defensive code" → defensive code without a test/gate is at most D2:2.
- ✅ "Added test + ## RCA + link to learning" → D1:3 (component-level antifragility).

---

## D2 — Reliability (weight: 7)

> *Predictable, observable, auditable execution; no silent failures.* (CLAUDE.md Directive 2)

The work made behavior more deterministic, more visible, or removed a silent-failure mode.

### Score criteria

| Score | Reliability signal |
|-------|--------------------|
| **0** | No connection — purely cosmetic or scoped to a single one-off command. |
| **1** | Adds a log line or one error message. |
| **2** | Makes one specific code path observable (telemetry, audit entry, structured output). |
| **3** | Removes a silent-failure mode in one component (return codes, error propagation, audit FAIL). |
| **4** | Adds an audit check or fw doctor signal that surfaces the silent-failure class across the whole framework. |
| **5** | Removes a silent-failure *class*. After this work, the framework cannot regress into the failure class without a structural change. |

### Worked examples

- **T-1771** (cron-registry sync — audit-summary visibility + verification AC) — **D2: 4**.
  Reason: 3 days of silent cron drift (deployed crontab ≠ registry) produced no signal. Added fw doctor FAIL + cron-touching-task verification AC. Now the registry → generated → deployed chain is observable at audit boundary AND at task-close.

- **T-1550** (RCA gate) — **D2: 4**.
  Reason: also scores high on reliability — silent skip of RCA capture is now visible as a completion-gate refusal. Hand-in-hand with the D1 antifragility framing.

- **T-1850** (`tags:[arc:*]` → `arc_id` migration) — **D2: 3**.
  Reason: one-shot data migration removing the silent ambiguity of two parallel arc-membership representations. Cleanup, not new structural reliability mechanism.

### Common mis-scorings

- ❌ "Made the function return a status code" → that's D2:1 unless something downstream now checks and reacts to the code.
- ❌ "Added try/except" → silently swallowing exceptions is *negative* reliability; D2:0 or below.
- ✅ "Audit FAIL on the registry-vs-deployed mismatch" → D2:4.

---

## D3 — Usability (weight: 5)

> *Joy to use/extend/debug; sensible defaults; actionable errors.* (CLAUDE.md Directive 3)

The work made the developer/agent's experience clearer, faster, or less surprising.

### Score criteria

| Score | Usability signal |
|-------|------------------|
| **0** | No human/agent-facing surface touched. |
| **1** | Error message text improved (one site). |
| **2** | Sensible default added or surprising default removed. |
| **3** | Discoverability improved at component level (new `--help`, clear listing, predictable column layout). |
| **4** | A class of friction removed at framework level (copy-pasteable commands, single entry point, golden-path command). |
| **5** | A new collaboration mode introduced (mechanic enabling new way of working). |

### Worked examples

- **T-609** (copy-pasteable commands rule) — **D3: 4**.
  Reason: codified the discipline that every command in human-facing instructions must be single-line, prefixed with `cd`, and chain with `&&`. Friction class removed at framework level — not just one error message, but a writing rule.

- **T-1257** (context-aware `fw` path) — **D3: 4**.
  Reason: same friction class. The agent was telling consumers `bin/fw` (which doesn't exist) instead of `.agentic-framework/bin/fw`. Documented + structurally enforced.

- **T-679** (Recommendation block + `fw task review` for human approvals) — **D3: 5**.
  Reason: introduced a new collaboration mode. Before: agent dumps raw CLI for human to execute. After: agent posts a structured recommendation in the task, human reviews in Watchtower, decides. A mechanic was added, not a message improved.

### Common mis-scorings

- ❌ "Renamed a variable" → not usability unless it was user-facing.
- ❌ "Added a code comment" → not usability for the user; might be D3:1 for future contributors.
- ✅ "Added `fw <cmd> --help`" → D3:3 (component-level discoverability).

---

## D4 — Portability (weight: 3)

> *No provider/language/environment lock-in; prefer standards.* (CLAUDE.md Directive 4)

The work made the framework work across more environments, machines, providers, or users.

### Score criteria

| Score | Portability signal |
|-------|--------------------|
| **0** | No connection — locked to local environment, single provider. |
| **1** | Removes one hard-coded path or local-only assumption. |
| **2** | Makes one component work across a class of environments (e.g., handles missing toolchain). |
| **3** | New abstraction over a previously-locked-in concept (MCP, LSP, OpenAPI). |
| **4** | Cross-machine or cross-project semantics that previously required local-machine knowledge. |
| **5** | Framework class becomes provider-neutral or environment-neutral at a layer that previously was not. |

### Worked examples

- **T-1633** (`fw upgrade` without local-path knowledge) — **D4: 5**.
  Reason: the upgrade command previously assumed the developer's filesystem layout (`/opt/999-Agentic-Engineering-Framework`). It now works from any consumer with no developer artefacts. A class of consumer-facing flows moved from "works for the framework dev only" to "works for everyone". Plus a structural test (`upgrade_fresh_machine_simulation.bats`) guards the class.

- **T-1542** (`fw upgrade` from inside a consumer crashes — detect bare-from-consumer case) — **D4: 3**.
  Reason: removes a class of environment-confusion errors. Strong component-level portability improvement but doesn't introduce a new abstraction layer.

- **T-1144** (auto-push from session-end protocol) — **D4: 2**.
  Reason: makes work survive across machine boundaries (no unpushed-locally state). One component, big practical win, but no new portability abstraction.

### Common mis-scorings

- ❌ "Switched from `bash` to `sh`" → portability *intent* but D4:1 unless a real environment class was unblocked.
- ❌ "Removed one hard-coded port" → D4:1 unless the port resolution becomes provider-neutral (then D4:3).
- ✅ "Added a `fw_config` lookup so the value is per-project" → D4:3.

---

## Free drivers — general criteria

Drivers added via `fw bvp driver --add` (T-1920) inherit the same 0–5 scale but the meaning is *the driver's stated purpose*. Free drivers are added via `--rationale ≥30 chars` so the rationale is the rubric until the driver is documented here.

When a free driver is added, the human (per M6, D8) is expected to:

1. Run `fw bvp driver --add "..." --weight N --rationale "..." --i-am-human`.
2. Add a section to this file describing what scores 0–5 mean for the driver.
3. Run the estimator (T-1922) on a sample of completed tasks and confirm via `fw bvp confirm` whether the proposed scores feel right.

If steps 2–3 are skipped, the driver still works but its outputs are not calibrated.

---

## R9 — Rubric reversibility

This document carries weight. Once published and referenced by the estimator (T-1922), every score in `bvp_scores_proposed:` across all tasks is implicitly endorsed by this rubric. Changing the rubric retroactively changes what those scores meant.

**Discipline:** when revising the rubric:

1. Run the estimator on a sample of recently-scored tasks both *before* and *after* the change.
2. If the average delta per driver is > 1.0, document the change as a recalibration event in `.context/bvp-rubric-history.yaml` (file does not exist yet; first revision creates it).
3. Decide whether existing `bvp_scores_proposed:` need to be re-run.

Worked examples should be revised first; criteria second. Worked examples anchor the criteria; without them, criteria drift becomes invisible.

---

## R2 — Rubric bias

Worked examples in this document are drawn from the framework's own completed tasks. **Two failure modes:**

- **Self-flattery bias:** an example that scores high because we want it to.
- **Self-criticism bias:** an example that scores low because we're being humble.

Both are wrong if they don't reflect the deliverable's actual structural effect. The Human AC on T-1921 ([REVIEW], load-bearing) is the standing check against this — the rubric is reviewed by a human reading the worked examples and asking "does this match what I would have scored?". If systematic over- or under-scoring is detected, **the rubric is revised before the estimator runs in earnest**, because the estimator inherits the rubric's biases.

---

*End of rubric. See `docs/reports/T-1915-bvp-inception.md` §2 for the full risk register.*
