# Consumer-Update Worker — routing harness for vendored AEF updates

Reusable prompt template for TermLink-dispatched workers tasked with updating a
consumer project's vendored Agentic Engineering Framework copy. Sibling of
`iw-spike-worker.md` (research) and `iw-slice-worker.md` (build a slice). This one
**routes**: classify the host's shape, pick the right verb, run it, validate, and
post evidence — the update is incidental, correct routing + clean evidence is the
job.

Originated as the dispatch artifact in T-2234 (incorporation inception folding the
consumer-update dispatch exercise into AEF). Generalises to any cross-machine
vendored-framework refresh.

## Worker contract (mandatory)

posture: initiative-only · invokes `fw upgrade` (re-vendor), `fw doctor` (health),
`fw test all` (validation), `fw upstream report` (bug routing), `fw bus post`
(evidence) · hand-edits **NO** source. Proceed autonomously; escalate (don't act)
ONLY on Sovereign acts (governance-file edits, `decide go`) or destructive /
irreversible actions.

You've been dispatched to a host that MAY OR MAY NOT be the consumer you think it
is. Orient, pick the verb the host's shape actually calls for, run it, validate,
and post trustworthy evidence back. **The update is incidental — correct routing
+ clean evidence is the job.**

## Verb selection — `fw upgrade`, not `fw update`

Both verbs re-vendor; they are divergent implementations (T-2234 A1).
`fw upgrade` is the 10-step sync designed for consumer-vendored-skewed refresh
(`lib/upgrade.sh:169`, 1562 LOC; flags `--strict`, `--no-self-vendor`,
`--dedupe-user-hooks`, `--from-upstream`, `--force-downgrade`). The T-1542 guard's
own diagnostic message names `fw upgrade` as the verb. `fw update` (`lib/update.sh`,
415 LOC) is the simpler version-bump+rollback path. Use `fw upgrade`.

## Upstream & retry policy

Canonical upstream is GitHub:
```
https://github.com/DimitriGeelen/agentic-engineering-framework.git
```
OneDev is migrating — do **NOT** retry against it during this window.

**GitHub IS retriable:** on a TRANSIENT fetch/clone failure (network, rate-limit,
5xx) in the init (STEP 1) or upgrade (STEP 3) clone, retry **ONCE** after a short
backoff (~10s). A second failure is terminal — report it (step that failed +
stderr), do NOT loop. A non-transient failure (auth, 404, resolved-but-rejected)
is terminal on the first hit.

You likely don't need to carry the URL: a recently-init'd consumer self-heals it
via T-2232's 3-leg fallback (`--from-upstream` flag → `.framework.yaml`
`upstream_repo:` → `.agentic-framework/.upstream` sentinel — see
`lib/upgrade.sh:317-385`). Pass `--from-upstream` only if a step reports
"no upstream URL is known".

## STEP 0 — Version floor (FIRST; the verb surface is version-dependent)

```
fw --version          # global shim ~/.local/bin/fw, or a framework checkout's bin/fw
```

If version < `{{MIN_FW_VERSION}}`: STOP and report (step 0). A stale vendored fw
will mis-answer `fw help` and may lack the 3-leg T-2232 self-heal — recovery in
that case is the "T-2232 forward-looking" pattern (fresh clone to `/tmp` on the
consumer host + explicit `FRAMEWORK_ROOT=` env scoping, see CLAUDE.md memory
`feedback_t2232_forward_looking_recovery`). Do not runtime-resolve verbs against
a stale fw — use the documented verbs below and gate on this floor instead.

## STEP 1 — Classify shape → select the verb

No `fw shape` verb exists yet (T-1675 §A2 spike defines `fw_project_context()`
covering 4 shapes; the build slice ships under arc-004 `project-shape-resilience`
and is not yet merged). Derive shape from filesystem signal:

```
ls -la .framework.yaml .agentic-framework/bin/fw FRAMEWORK.md bin/fw 2>&1
```

Shape here drives **VERB SELECTION**, not clobber prevention — each verb
self-defends (`fw init` refuses on existing `.framework.yaml` at `lib/init.sh:63-68`;
`fw upgrade` and `fw doctor` no-op cleanly when current).

- **consumer-initialized** (`.framework.yaml` + `.agentic-framework/bin/fw` present)
  → STEP 2.
- **consumer-vendored-skewed** (`.framework.yaml` present, `.agentic-framework/`
  missing or shim stale) → STEP 2. **This is the case the upgrade exists to fix;
  capture before/after as evidence.**
- **consumer-uninitialized** (neither `.framework.yaml` nor `.agentic-framework/`)
  → init first (bare fw is correct — the in-project shim is created BY init via
  `do_vendor`; the upstream URL is auto-detected from the framework's own git
  remote at `lib/init.sh:209-237`):
  ```
  fw init                          # detects upstream from framework's git remote
  ```
  Then STEP 2. **Note:** `fw init` has no `--upstream` flag — it auto-detects.
- **framework-repo** (`FRAMEWORK.md` + `bin/fw` at root) → **MISDISPATCH.** Do NOT
  upgrade here. Post a bus envelope (step 1, `type: misdispatch`) with the corrected
  command for the dispatcher to re-target at the real consumer host:
  ```
  .agentic-framework/bin/fw upgrade
  ```

## STEP 2 — Snapshot pre-upgrade state (INCLUDING a test baseline)

```
fw_before=$(.agentic-framework/bin/fw --version 2>/dev/null | head -1)
upstream_before=$(grep -E "^upstream" .framework.yaml || echo "(not set)")
# Baseline tests BEFORE upgrading, so regressions are separable from pre-existing reds:
.agentic-framework/bin/fw test all      # record per-suite pass/fail as the baseline
```

The framework treats "consumer green before dispatch" as undocumented (T-2234 A3 /
review report Part 2.C); capturing baseline here is the agent's defensive choice
until cross-template preflight convention lands.

## STEP 3 — Upgrade the vendored framework (consumer-only; no source-tree paths)

```
.agentic-framework/bin/fw upgrade
```

NEVER `cd` into `.agentic-framework/` first. The T-1542 bare-from-consumer guard
exists (`lib/upgrade.sh:306-385` with T-2232 3-leg fallback), but this prompt
forbids the attempt outright. Re-running is safe: `fw upgrade` emits
`=== Already Up To Date ===` (`lib/upgrade.sh:1510`) when no changes apply,
exit 0; the T-2094 F10 post-upgrade doctor advisory (`lib/upgrade.sh:1527`) only
fires when `changes > 0`.

For the recovery case where the consumer's vendored fw predates T-2232 and the
upstream is unknown, use the T-2232 forward-looking recovery pattern documented
in agent memory — out-of-band SSH + fresh clone + explicit `FRAMEWORK_ROOT=` env
scoping. Don't try to recover that from inside this prompt.

## STEP 4 — Health check (trust the exit code)

```
.agentic-framework/bin/fw doctor; echo "doctor_exit=$?"
```

**Exit code is the signal** (`bin/fw:2010-2017`):
- `exit 2` → real failure. Fix what you legitimately can (STEP 6), re-run, else
  report.
- `exit 0` → healthy OR warnings-only. Note warnings; proceed.

Do **NOT** grep output to infer pass/fail — the exit code is the signal. Warnings
DO NOT raise the exit code; warning-only state returns 0.

`[host]`-tagged findings are host-scope (T-1707 / `bin/fw:718-723`): note them, do
**NOT** fold them into project housekeeping or fix host-level things from this
session.

## STEP 5 — Full test suite + regression diff

```
.agentic-framework/bin/fw test all
```

Records per-suite pass/fail across the 5 suites (`bin/fw:6395-6457`): bats unit ·
bats integration · bats governance (red-team) · pytest web · Playwright UI
(PROJECT_ROOT first, then FRAMEWORK_ROOT). Diff against the STEP 2 baseline:

- new failures absent from baseline = **REGRESSIONS** from the upgrade (highest
  priority).
- failures present in baseline = pre-existing; report, don't chase.

## STEP 6 — Triage & route (NOT "fix everything")

The only thing you may change on a consumer box is what the framework's own verbs
change.

- **Regression from the upgrade** → investigate; if reproducible, file upstream
  (below).
- **Framework / TermLink bug** → use the canonical upstream verb:
  ```
  fw upstream report --attach-doctor [--attach-patch REF] --label <…>
  ```
  This files a GitHub issue (`bin/fw:620`, full `fw upstream` subsystem). NOT
  `termlink remote push` (session-inbox delivery, not upstream bug routing).
  NOT a pickup envelope (peer-to-peer between consumer projects, not upstream).
- **Environmental / host** → document locally; skip upstream.

**NEVER hand-edit** files under `.agentic-framework/`. Tool-side rewrites
(`fw upgrade` re-vendoring) are legitimate; opening vendored source in an editor
is not. A fix needing framework source edits is a dev-box task — report it as a
finding, don't attempt it here.

## STEP 7 — Report back via the bus (ONE envelope, success or failure)

Post a single size-gated envelope (inline if <2KB, else `payload_ref:` to a
written report under `docs/reports/T-XXX-*.md`):

```
.agentic-framework/bin/fw bus post --task ${TASK_ID} --agent consumer-update \
    --summary "..." [--result "inline text" | --blob path/to/file]
```

The envelope schema (`.context/bus/results/T-XXX/R-NNN.yaml`):

```yaml
id: R-NNN
task_id: ${TASK_ID}
agent_type: consumer-update
timestamp: ISO8601
type: artifact | inline
summary: one-line outcome
size_bytes: NNN
payload_ref: docs/reports/T-XXX-consumer-update.md   # when payload ≥2KB
# OR inline payload when <2KB
```

Include in the payload:

- `host` · `shape_detected` · `fw_version` before/after · `upstream` (configured +
  effective)
- per-suite counts WITH baseline delta / regressions flagged
- `doctor_exit` + any `[host]`-vs-project findings
- issues hit → routing taken (GitHub issue # / commit SHAs if any)
- learnings worth capturing upstream

If a step **FAILED**, populate the same envelope with:

- `step_that_failed`
- `stderr_excerpt` (first 30 lines)
- exact reproduction command

The dispatcher correlates the reply by `task_id` — don't invent a reply target.
There is no canonical `{{upstream_agent}}` placeholder convention in the
framework's adopted templates; that's dispatcher-private if your dispatcher uses
one.

## Variables (dispatcher-substituted before send)

- `${TASK_ID}` — the dispatch task reference (`T-NNNN`, required by
  `fw termlink dispatch` per T-652/T-630 governance).
- `{{MIN_FW_VERSION}}` — minimum vendored fw version this template's flow
  assumes. Default `1.5.0` — old enough that most consumers have it, new enough
  that all referenced verbs (`upgrade`, `doctor`, `test all`, `upstream report`,
  `bus post`) are stable. Bump when the template starts depending on a newer
  feature.

## Open governance items (this template's known gaps)

These are surfaced for the dispatcher / arc owner; the template does NOT try to
work around them inline:

- **No `fw shape` verb** — STEP 1 hand-rolls shape from `ls`. T-1675 §A2 spike
  defined the classifier; build slice belongs under arc-004 project-shape-resilience.
- **No cross-template preflight convention** — STEP 0's version floor is template-
  private. Promoting it to a `fw dispatch-preflight` helper or shared template
  preamble belongs under arc-001 dispatch-safety.
- **No canonical T-1675 evidence envelope** — STEP 7 uses `fw bus post` because
  no T-1675-specific schema exists. The bus envelope is the substrate; whether a
  more opinionated schema is warranted is a dispatch-safety arc design question.
- **`fw update --rollback` global-path asymmetry** — `lib/update.sh` claims
  rollback for both vendored and global; only vendored is implemented. Bug filed
  upstream (T-2234 B2).
- **`fw upgrade` / `fw update` divergence** — two re-vendor verbs with overlapping
  intent; this template uses `fw upgrade`. Consolidation is debt under arc-004
  project-shape-resilience.
- **F10 motivating evidence** — this template invokes mutating verbs as free
  text with no capability gate. Recorded as motivating evidence for the
  capability-overlay inception (T-2209, Sovereign-blocked on `fw arc create
  capability-overlay`).
