---
id: T-3430
name: "Component Fabric card quality: fill purpose/subsystem from the source's own
  docstring at register+enrich time (refuse, never guess), add an under-populated
  class to drift, and a cron that sweeps TODO cards — 792 of 1314 cards carry the
  template TODO (OBS-464)"
description: >
  Component Fabric card quality: fill purpose/subsystem from the source's own docstring
  at register+enrich time (refuse, never guess), add an under-populated class to drift,
  and a cron that sweeps TODO cards — 792 of 1314 cards carry the template TODO (OBS-464)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-09-22T11:54:03Z
last_update: '2026-09-22T12:00:33Z'
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
cost_estimate_proposed:
  - ts: '2026-09-22T12:00:12Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=317,acs=9)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-22T12:00:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-3430: Component Fabric card quality: fill purpose/subsystem from the source's own docstring at register+enrich time (refuse, never guess), add an under-populated class to drift, and a cron that sweeps TODO cards — 792 of 1314 cards carry the template TODO (OBS-464)

## Context

Measured on this repo, 2026-09-22: **1,314 component cards; 792 (60%) still
carry the template `purpose: "TODO: describe what this component does"`;
564 have `subsystem: unknown`; 187 have no edges.** `fw fabric register`
writes both placeholders (`agents/fabric/lib/register.sh:264,302`) and
`fw fabric enrich` (`agents/fabric/lib/enrich.py`) fills edges only — no
verb, hook or cron ever fills the two fields a human reads. `fw fabric
drift` has no under-populated class, so the 60% is invisible to the only
health check. No cron entry touches the fabric at all. Origin: 1409-sprind
field report + correction (OBS-458 → OBS-464); the operator has observed
the same TODO pollution repeatedly and wants it fixed with better
instructions and a regular sweep, because the descriptions are what any
index of the fabric would carry.

**Design — derive, and refuse rather than guess (1409-sprind's pattern).**
`purpose` and `subsystem` are DERIVED from the file itself, in this order,
and the source is recorded on the card as `purpose_source:` so every
sentence is traceable:
1. the file's own docstring / header comment (Python module docstring;
   bash `# <description>` block under the shebang; the first `#` paragraph
   of a `.md`/`.yaml`),
2. the `created_by:` task's title and its `docs/reports/T-XXXX-*.md`
   artefact,
3. nothing — the card keeps `TODO` and the run PRINTS the refusal
   (`<path>: describes itself nowhere — write a header comment`).
Never a vector-store nearest-neighbour: a plausible near-miss written into
`purpose` is indistinguishable from a real description once on the card.
`subsystem` derives from the path against `.fabric/subsystems.yaml` and
the watch-pattern groups; `unknown` only when no rule matches, printed.

**Surfaces.** (a) `register` derives at creation, so new cards stop being
born as skeletons; (b) `enrich` gains `--describe` (default on) that fills
`purpose`/`subsystem` on cards that still carry the placeholders — never
overwriting a human-written sentence; (c) `drift` gains an
**under-populated** class (purpose contains `TODO`, `subsystem: unknown`,
or zero edges) with counts and the first N ids; (d) a cron entry
`fabric-describe-daily` runs `fw fabric enrich --describe` and the audit
structure section WARNs when under-populated > 0, so the number is seen
without anyone running drift; (e) `fw doctor` mirrors the count.

**Index.** Verify whether `web/search.py` (the Watchtower `/search` index)
ingests `.fabric/components/*.yaml`. If it does, re-index after a describe
run; if it does not, say so in the report — the operator's assumption is
that card descriptions feed the search/vector layer, and the answer either
way belongs in writing.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `agents/fabric/lib/describe.py` (new): `derive_purpose(path) -> (text, source)|None` (docstring → header comment → created_by task title/report → None), `derive_subsystem(path) -> str|None` (subsystems.yaml + watch-pattern groups); unit tests cover a Python module docstring, a bash header block, a Markdown first paragraph, a YAML `#` header, a task-title fallback, and the refusal case
  - Evidence: `agents/fabric/lib/describe.py` (a5df7f0a0); `tests/unit/test_t3430_describe.py` — 30 tests green, covering all six required cases plus the task-report fallback, header-beats-task precedence and six refusal shapes.
- [x] `register.sh` calls the deriver so a freshly registered file with a docstring gets a real `purpose`, a `purpose_source: docstring`, and a resolved `subsystem`; a file with none keeps `TODO` and the register output prints the refusal line
  - Evidence: `agents/fabric/lib/register.sh` (41b6b8b21); `tests/unit/t3430_fabric_register_describe.bats` — 8 tests green. Live: `fw fabric register agents/fabric/lib/describe.py` → `purpose_source: docstring`, `subsystem: component-fabric`.
- [x] `fw fabric enrich --describe` (default on; `--no-describe` to skip) fills placeholders only, never overwrites non-placeholder text, writes `purpose_source:`, and prints `described N, refused M (listed)`; `--dry-run` honoured
  - Evidence: `agents/fabric/lib/enrich.py` (fa7ded85d); `tests/unit/test_t3430_enrich_describe.py` — 11 tests green, driven through the CLI. Live run printed `described 760, refused 32` with all 32 named.
- [x] `fw fabric drift` reports an `under-populated:` class (TODO purpose / unknown subsystem / zero edges, each counted, first 10 ids) alongside unregistered/orphaned/stale; `tests/` pin a fixture card of each kind
  - Evidence: `agents/fabric/lib/drift.sh` + `agents/fabric/lib/underpopulated.py` (6b6fe8a68); `tests/unit/t3430_fabric_drift_underpopulated.bats` — 10 tests green, one fixture per sub-class plus the clean-card control.
- [x] Cron entry `fabric-describe-daily` in `.context/cron-registry.yaml` (own `flock`, `origin_task: T-3430`, off the audit minute), `fw cron generate` + `fw cron install` run, doctor "Cron registry in sync"; `fw audit --section structure` WARNs `Fabric: N under-populated card(s)` when N>0 and PASSes at 0; `fw doctor` mirrors
  - Evidence: registry entry at `26 4 * * *` with its own lock; generate + install run; `fw doctor` → `OK Cron registry in sync`. Live audit (dirty corpus) → `[WARN] Fabric: 838 under-populated card(s) / TODO purpose: 792, unknown subsystem: 564, no edges: 189`. Live doctor → the same three lines. PASS-at-0 wording pinned by `tests/unit/t3430_fabric_audit_doctor.bats` (10 tests green).
- [x] Live on this repo: one `fw fabric enrich --describe` run — before/after counts of TODO purposes and unknown subsystems recorded here (expected: a large drop, and a refusal list naming files that genuinely describe themselves nowhere), plus the index verdict (does `web/search.py` ingest cards: yes/no, with the line)
  - Evidence: commit 78b83cc2b. TODO purpose **792 → 32**; unknown subsystem **564 → 3**; no-edges 189 → 189 (untouched by design); under-populated total **838 → 209**. 760 purposes written (408 header-comment, 343 docstring, 11 markdown). Index verdict below.
- [x] Vendored copies synced (`bin/fw vendor self --check` clean); fabric cards for the new module and tests; help-router parity lint green if `bin/fw` changed
  - Evidence: all nine edited framework files byte-identical under `.agentic-framework/` (see Verification). Cards registered for `describe.py`, `underpopulated.py`, `fabric_doctor_facts.py` and all four test files. See Updates for the one file `vendor self` withheld — another worker's uncommitted edit, not mine.

#### Index verdict — YES, the search index ingests the cards

`web/search_utils.py:100` lists `(".fabric", "components")` in `AUTHORED_DIRS`,
and `:92` sets `INDEXED_SUFFIXES = (".md", ".yaml", ".yml")` — so every card's
full body, `purpose` included, is indexed by the Watchtower `/search` index
(`web/search.py:build_index` → `collect_files()`).

There is no re-index verb to run, and none is needed: `web/search.py:23`
`STALE_SECONDS = 60` makes `get_index()` rebuild whenever the cached index is
more than a minute old. Confirmed live after the describe run — searching for a
purpose this run wrote (`"WSGI entry point for Watchtower."`) returns
`.fabric/components/web-wsgi.yaml`.

The operator's assumption was therefore correct, and it is the reason the
refuse-never-guess rule matters rather than being fastidiousness: a fabricated
purpose would not merely sit on a card, it would be retrievable text competing
with real descriptions in the index.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

## Verification

# T-3430. Every line rehearsed under `bash -c 'set -o pipefail; <line>'`.
# Counts are deliberately NOT pinned (T-3326): the corpus moves, so each line
# asserts a property — the tests pass, the class is reported, the refusal
# happens, the cards parse — not a number that was true this afternoon.

timeout 600 python3 -m pytest tests/unit/test_t3430_describe.py tests/unit/test_t3430_enrich_describe.py -q > /tmp/.t3430-v1.out 2>&1 && grep -q "passed" /tmp/.t3430-v1.out
timeout 900 bats tests/unit/t3430_fabric_register_describe.bats tests/unit/t3430_fabric_drift_underpopulated.bats tests/unit/t3430_fabric_audit_doctor.bats > /tmp/.t3430-v2.out 2>&1 && ! grep -q "^not ok" /tmp/.t3430-v2.out
test "$(grep -c '# skip' /tmp/.t3430-v2.out)" -eq 0

# The rule the whole task turns on: a file that says nothing gets a refusal,
# not a sentence. /dev/null is the smallest file that describes itself nowhere.
python3 agents/fabric/lib/describe.py /dev/null > /tmp/.t3430-v3.out 2>&1 && grep -q "describes itself nowhere" /tmp/.t3430-v3.out

# drift reports the new class. The count is whatever it is; that there IS one
# is the invariant.
timeout 900 bin/fw fabric drift --summary > /tmp/.t3430-v4.out 2>&1 && grep -qE "^under-populated: [0-9]+$" /tmp/.t3430-v4.out

# Cron chain, verbatim from CLAUDE.md §Cron-touching tasks (registry→generated
# AND generated→deployed; doctor output is ~33KB, inside the 64KB pipe buffer).
out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "Cron registry in sync" && ! echo "$out" | grep -q "Cron registry edited but not generated"

# No card carries a derived-purpose provenance AND a placeholder purpose — the
# shape that would mean the pass claimed a sentence it did not write.
python3 -c "import glob,sys,yaml; bad=[p for p in glob.glob('.fabric/components/*.yaml') for d in [yaml.safe_load(open(p))] if d and d.get('purpose_source') not in (None,'none') and 'TODO' in str(d.get('purpose',''))]; print(bad[:5]); sys.exit(1 if bad else 0)"

# Every card the run rewrote is still parseable YAML — the base64 bridge and
# the yaml.dump round-trip both have to hold across the whole corpus.
python3 -c "import glob,yaml; [yaml.safe_load(open(p)) for p in glob.glob('.fabric/components/*.yaml')]"

# Index verdict, pinned rather than asserted in prose alone.
grep -q '(".fabric", "components"),' web/search_utils.py

# Vendored copies of every framework file this task edited are byte-identical.
bash -c 'set -eo pipefail; for f in agents/fabric/lib/describe.py agents/fabric/lib/underpopulated.py agents/fabric/lib/register.sh agents/fabric/lib/enrich.py agents/fabric/lib/drift.sh agents/fabric/fabric.sh agents/audit/audit.sh bin/fw lib/fabric_doctor_facts.py; do cmp -s "$f" ".agentic-framework/$f"; done'

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Evolution

### 2026-09-22 — the refusal list is the product, not the leftover

- **What changed:** The plan treated refusals as a residue — files the pass
  couldn't help, printed for completeness. Running the pass over the live
  corpus inverted that. The first dry run said `described 746, refused 46`,
  which looked like a fine result and was wrong twice over: a 64 KB read cap
  made `ast.parse` fail on every Python module above it (so `enrich.py` itself
  was reported as describing itself nowhere), and a docstring opening on its
  own line produced an empty first paragraph. Both bugs were invisible in the
  count and obvious in the list.
- **Plan impact:** `--list-refusals` stopped being a debug flag and became the
  way the pass is read. The final numbers (760/32) came from fixing what the
  list showed, not from tuning the deriver against fixtures.
- **Triggered:** Two derivation fixes inside the enrich commit rather than
  follow-ups; `--list-refusals` documented in `fw fabric help`.

### 2026-09-22 — subsystem routing belongs in data, not in a case statement

- **What changed:** The spec said subsystem "derives from the path against
  `.fabric/subsystems.yaml` and the watch-pattern groups". Neither file
  actually carried path→subsystem rules: `subsystems.yaml` had no paths at all,
  and `watch-patterns.yaml` declares `expected_type`, not subsystem. The only
  routing that existed was a hard-coded `case` block inside `register.sh` that
  covered ten prefixes and nothing else — which is most of why 564 cards said
  `unknown`, 391 of them under `tests/`.
- **Plan impact:** Rather than extend the case block, `paths:` was added to
  `subsystems.yaml` and the case block deleted. Adding a directory is now a
  data edit. Five subsystems the corpus had been using for months but the
  registry never declared (`tests`, `tests-playwright`, `docs`, `governance`,
  `termlink-integration`) were written down, which is the reason 561 of the 564
  resolved.
- **Triggered:** Nothing filed. The three paths still unrouted (a top-level
  `.md`, two vendored designer builds) are correctly unrouted — they are not
  ours to classify.

### 2026-09-22 — a whole-corpus rewrite is a comment-destroying operation

- **What changed:** `save_card` round-trips through `yaml.dump`, which cannot
  carry comments. That was already true, but it only ever touched the handful
  of cards that gained edges. This pass rewrote 771, which turns a latent
  property into a corpus-wide event.
- **Plan impact:** Audited the diff for lost comment content before committing
  rather than after. The damage was three stock template comments (no loss) and
  exactly one authored line — the `# T-1754 — by-design orphan, no framework
  imports` note explaining `standalone: true` on one card.
- **Triggered:** Restored as `standalone_reason:`, a key that survives the next
  rewrite. Recorded in Decisions as the general rule: rationale that has to
  outlive an enrich run belongs in a key, not a comment.

## Recommendation

**Recommendation:** GO

**Rationale:** Every Agent AC is ticked with evidence, the five surfaces the
spec asked for are live, and the pass has been run on this repo with the
before/after measured rather than projected. The mechanism and its effect are
in separate commits so the two can be reviewed apart. The design constraint
that mattered — refuse rather than guess — is enforced in code, covered by six
refusal fixtures, and demonstrated on the live corpus by 32 files that kept
their TODO instead of acquiring a plausible sentence. There are no Human ACs on
this task.

**Evidence:**
- TODO purpose 792 → 32; unknown subsystem 564 → 3; under-populated total
  838 → 209 (commit 78b83cc2b). 760 purposes written, each tagged with its
  source: 408 header-comment, 343 docstring, 11 markdown.
- 59 new tests green (30 + 11 pytest, 8 + 10 + 10 bats), including the control
  legs that separate "fires correctly" from "always fires": a fully-populated
  card that must NOT be flagged, and the PASS-at-0 audit wording.
- Live `fw audit --section structure` → `[WARN] Fabric: 838 under-populated
  card(s)` with the three sub-counts; live `fw doctor` → the same three lines;
  `OK Cron registry in sync` after generate + install.
- Index verdict answered in writing and pinned by a Verification line:
  `web/search_utils.py:100` indexes `.fabric/components`, so the card
  descriptions do feed the search layer — which is why a fabricated purpose
  would have been retrievable text, not just a bad card.
- Two derivation bugs were found by reading the refusal list rather than the
  count, and fixed before the live run (64 KB read cap; leading-blank
  docstrings). Both are pinned by regression tests.

## Decisions

### 2026-09-22 — `paths:` lives in subsystems.yaml, not in a new rules file

- **Chose:** Add a `paths:` list to each subsystem in `.fabric/subsystems.yaml`
  and route by longest-matching pattern.
- **Why:** It makes the vocabulary and the routing one operator-editable file,
  so a subsystem cannot be routed to unless it is declared. Longest-match means
  declaration order carries no meaning and `tests/playwright/*` beats `tests/*`
  without anyone having to keep the file sorted.
- **Rejected:** A separate `.fabric/subsystem-rules.yaml` (register.sh already
  looks for one and it has never existed here) — a second file to keep in step
  with the first. Also rejected: extending the hard-coded `case` block, which
  is the thing that produced 564 unknowns.

### 2026-09-22 — the purpose crosses python→bash base64-encoded

- **Chose:** `describe.py --emit-shell` prints `FW_PURPOSE_B64=<base64>` and
  `register.sh` decodes it, then escapes for a YAML double-quoted scalar.
- **Why:** A docstring containing `"`, `$`, a backtick or a backslash is
  ordinary, and the card has to stay parseable YAML. Every shell-quoting
  scheme eventually mangles one of those; base64 has no such edge. Pinned by a
  fixture whose docstring contains all four.
- **Rejected:** `eval` of a quoted assignment (an arbitrary docstring reaching
  `eval` is an injection surface); printing raw and quoting in bash (the case
  this would get wrong is the case that matters).

### 2026-09-22 — `--describe` defaults ON

- **Chose:** On by default, `--no-describe` to opt out.
- **Why:** The pass cannot overwrite anything a human wrote, so there is no
  failure mode to opt into; and the placeholders are the entire problem, so a
  default-off flag would have left the 792 exactly where they were, behind one
  more thing nobody runs.
- **Rejected:** Default off with `--describe` opt-in — the shape that produced
  the situation this task exists to fix.

### 2026-09-22 — enrich does not write `purpose_source: none` on a refusal

- **Chose:** `register.sh` writes `purpose_source: none` on a refusal (the card
  is being created, so every field is being written anyway); the enrich pass
  writes nothing at all when it derives nothing.
- **Why:** Keeps the pass idempotent and its diff honest — a run that changed
  nothing touches no file. A card with no derived sentence has no provenance to
  record.
- **Rejected:** Writing `none` from enrich too, for symmetry: it would dirty
  832 cards to record an absence already visible in the `TODO` purpose.

### 2026-09-22 — rationale that must outlive an enrich run goes in a key

- **Chose:** Move `# T-1754 — by-design orphan, no framework imports` from a
  trailing YAML comment into `standalone_reason:`.
- **Why:** `save_card` round-trips through `yaml.dump`, which drops comments.
  Restoring the comment would have restored something the next describe run
  deletes again — a fix that looks like a fix for exactly one run.
- **Rejected:** Teaching `save_card` to preserve comments (ruamel.yaml
  round-trip mode) — a dependency and a rewrite of the card I/O for one line of
  prose in the whole corpus.

### 2026-09-22 — the under-populated scan is its own module

- **Chose:** `agents/fabric/lib/underpopulated.py`, shared by `drift`, `audit`
  and `doctor`; JSON flattening in `lib/fabric_doctor_facts.py`, shared by the
  last two.
- **Why:** The scan needs `describe.py`'s placeholder predicates, and a heredoc
  inside `$()` has no `__file__` to import relative to — besides being the
  canonical bin/fw self-lockout shape (L-332/L-408, the reason
  `lib/cron_dry_run.py` exists). Sharing the helper is also what keeps the
  audit and doctor wordings from drifting apart.
- **Rejected:** Duplicating the counting logic in each of the three surfaces —
  three places for the definition of "under-populated" to diverge.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-22T11:54:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3430-component-fabric-card-quality-fill-purpo.md
- **Context:** Initial task creation

### 2026-09-22T00:00:00Z — vendor-self withheld one file (not ours)

- **Action:** Ran `FW_VENDOR_ONLY="<the nine framework files this task edited>"
  bin/fw vendor self`, then `bin/fw vendor self --check`.
- **Output:** All nine of this task's files are byte-identical under
  `.agentic-framework/`. The global `--check` still exits 1 with
  `would sync 1 agents/ file(s)`.
- **Context:** The one file is `agents/task-create/update-task.sh`, carrying
  another worker's uncommitted T-3432 edit in this shared working tree.
  `vendor self` correctly withheld it (`withheld: agents/task-create/update-task.sh`)
  rather than shipping someone else's unfinished work under this commit. It is
  not ours to sync or commit. The Verification block therefore asserts the
  byte-equality of this task's own nine files rather than the global
  `--check` — pinning the global check would make this close depend on a third
  party's uncommitted state, which is the mutable-anchor failure T-3326 names.

### 2026-09-22T00:00:00Z — pre-existing red in the fabric baseline (not ours)

- **Action:** Captured the fabric suites before starting.
- **Output:** `tests/unit/fabric_coverage_single_source.bats` test
  `T-2735 severity: fully-carded project PASSes` was already failing, and still
  fails on a re-run.
- **Context:** The test greps for `PASS. Fabric drift: all 1 watched file(s)
  registered`. `audit.sh:2351` now emits that check through `pass_over`, which
  prints `Fabric drift: all watched files registered — examined 1 watched
  file(s)`. The wording changed under the test (T-3105's `pass_over`
  refactor) and the assertion was never updated. Unrelated to T-3430 and
  deliberately not fixed here — one bug, one task. The other fabric suites are
  green: 66 pytest passed; the two bats skips in the baseline
  (`# skip audit lock held by a concurrent run`) are the shared audit lock
  under a concurrent worker, not a defect.
