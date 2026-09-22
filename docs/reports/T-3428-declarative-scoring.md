# T-3428 — Declarative scoring specs for BVP value drivers

**Task:** T-3428 · **Arc:** arc-006 (value-prioritisation) · **Date:** 2026-09-22
**Origin:** OBS-463 leg 2 (leg 1 = T-3427, leg 3 = the audit/doctor rail shipped here)

## The problem

Before this task, the BVP estimator scored a driver only if a Python function
existed for it in `_handler_table()`. The `rubric:` maps in
`policy/value-drivers.yaml` — the prose ladders that read, to any author, like
the definition of how a driver scores — were never read by anything. So:

- A **project** could not define a value driver that worked. It could name one,
  weight it, write a five-level rubric for it, and the estimator would ignore
  all of it.
- An **arc** could not either, even through the operator-approved
  `scoped_drivers:` path. Six such drivers exist in this repo today.
- The refusal message T-3427 shipped said so out loud — *"Writing `levels:` into
  policy/value-drivers.yaml changes nothing"* — and offered only
  `--allow-unscored`, i.e. reserve the slot and accept that it scores nothing.

T-3427 stopped the bleeding: an unscorable driver is omitted from the `scores`
map rather than scored 0, which keeps it out of `compute_bvp`'s normalisation
denominator. That fixed the *distortion* (a weight-8 driver scoring 0 on 46/50
tasks had been ranking every real task lower) but not the *capability*. The
operator's ruling on 2026-09-22 was to fix the capability now.

## The design

A driver entry — free, in `policy/value-drivers.yaml`, or arc-scoped, in
`.context/arcs/<slug>.yaml` `scoped_drivers[]` — may carry a `scoring:` block
the estimator interprets generically.

```yaml
scoring:
  kind: signals                # the one kind this slice ships
  strip_template: true         # default true — see §The template trap
  levels:                      # int 1..5 → any-of signals; highest match wins
    1: {keywords: ["finding"]}
    3: {keywords: ["evidence"], paths: ["docs/reports/*.md"]}
    5: {frontmatter: {workflow_type: build}, tags: ["audit"]}
```

Four signal kinds, deliberately few:

| kind | matched against |
|---|---|
| `keywords` | case-insensitive substrings of name + description + body + tags |
| `paths` | fnmatch globs over `components:` **and** every path-shaped token in the body (where ACs and Verification name files) |
| `frontmatter` | equality on frontmatter keys, compared as case-insensitive strings |
| `tags` | any tag equal, case-insensitively |

**Semantics.** A level matches when ANY of its signals matches. The score is the
highest matching level; lower levels also matching is normal and is reported,
not penalised. Evidence lists every matched signal as `L<level>:<kind>=<value>`.

**Zero is not the same as unscored.** A spec with no matching level scores `0`
with evidence `L0: no signal` — a *measured* zero, which stays in the ranking
denominator because the driver has a mechanism that ran and found nothing.
T-3427's `unscored` means no mechanism exists at all, and is kept out of the
denominator. Collapsing the two would re-introduce exactly the distortion
T-3427 removed.

**Dispatch order** in `estimate_task`:

```
inception VoI  →  handler by id  →  handler by name alias  →  scoring: spec  →  UNSCORED
```

A hand-written handler always wins. A spec attached to a handler-backed driver
is inert, and `fw bvp driver --explain` says so rather than letting its ladder
be mistaken for what the estimator used. The reason for that precedence: a
policy edit must not be able to silently displace the richer mechanism.

### The template trap

`strip_template` defaults to `true`, and this is the single most load-bearing
default in the design.

Every task file is created from `.tasks/templates/default.md`, which carries
several hundred lines of guidance prose — REHEARSING, PRODUCING, `CLAUDE.md`,
`.claude/settings.json`, the whole P-011 essay. A keyword drawn from that prose
is present in *every task in the corpus*, so the driver matches uniformly and
ranks nothing while appearing to work perfectly. Measured on consumer
1409-sprind. With stripping on, every line appearing **verbatim** in the
template is dropped before matching.

Stripping is line-exact rather than fuzzy on purpose: a line the author actually
wrote survives even when it quotes a template word, because it will not match a
template line character for character. Path extraction runs on the stripped body
too, for the same reason — the template names `.claude/settings.json` and
friends in prose every task carries.

One further filter, found by running the feature against this very task: a
body token carrying glob metacharacters (`*`, `?`, `[`) is a *pattern*, not a
path, and can only ever self-match. Task bodies quote their own spec, so
without the filter `paths: ["docs/reports/*.md"]` matched the sentence that
declared it and reported `docs/reports/*.md` as the file it found. Concrete
`components:` entries are unaffected.

## What stays hand-written, and why

D1–D4 and the `V_*` batch keep their Python handlers. This is not a migration
that stalled — it is the boundary of what signal matching can express.

- **D1 Antifragility** asks whether a change makes the system stronger *under
  stress*. Its ladder distinguishes "logs the failure" from "prevents the
  class" — a judgement about the relationship between a change and a failure
  mode, not the presence of a word.
- **D2 Reliability**, **D3 Usability**, **D4 Portability** are the same shape:
  constitutional directives whose rubrics grade *kind of contribution*.
- The `V_*` drivers (`V_PROMPT_QUALITY`, `V_CONTEXT_FABRIC`,
  `V_COMPONENT_FABRIC`) score topology and instruction-layer uplift, which
  their handlers reach by combining `components:` shape with body structure in
  ways a flat any-of ladder cannot.

The rule of thumb for an author: **if your rubric level can be stated as "this
task mentions / touches / is tagged X", it is a spec. If it can only be stated
as "this task does something of kind X", it wants a handler.** A spec that
needs `all-of` semantics, negation, or counting is a signal you are at the
boundary — those are deliberately absent from `kind: signals`, and `kind:` is
the extension point if a second kind ever earns its place.

## The rail (leg 3)

`lib/bvp-scorability.sh` is one fact function shared by `fw audit` (structure
section) and `fw doctor`, so the cron path and the on-demand path cannot
disagree. It classifies every ACTIVE free driver and every arc-scoped driver on
an arc whose status is not `closed`/`abandoned`:

- **no-mechanism** → `WARN BVP driver <id> has neither a handler nor a scoring spec`
- **invalid-spec** → its own WARN class, with the first validation error. A
  broken spec reads as a mechanism in the policy file and is none to the
  estimator, which is the exact divergence this task removes; folding it into
  "no spec" would hide it.

WARN-only at both sites. The remedy is an authoring decision — draft a spec, or
write a handler for a rubric that genuinely needs judgement — and must never
block a push. Silent when the project has no `policy/value-drivers.yaml`, so a
project that never bootstrapped BVP gets neither a nag nor a clean bill of
health it did not earn.

**Live finding on this repo at ship time:** six arc-scoped drivers across three
arcs have no mechanism — `identity-fidelity` and `provisioning-safety`
(arc-020), `Discard fidelity` and `Loop closure (conditional)`
(continuous-run), `unknown-input-safety` and `first-run-recoverability`
(onboarding-shape-detection). All six were approved by the operator with
substantive rationales distinguishing them from D1–D4. All six have been inert
since approval. Nothing said so until now. Giving them specs is each arc's own
work, not this task's.

## Authoring surface

```bash
# 1. check shape offline, before spending one of the five free slots
bin/fw bvp driver --validate-scoring policy/driver-scoring-example.yaml

# 2. try the DRAFT against a real task — nothing is written to policy
bin/fw bvp driver --explain F-RECALL T-3428 \
    --scoring-file policy/driver-scoring-example.yaml

# 3. attach it (a valid spec IS a scorer — no --allow-unscored needed)
bin/fw bvp driver --add "Evidence Quality" --weight 4 \
    --rationale "..." --scoring-file policy/driver-scoring-example.yaml

# 4. explain it later, on any task
bin/fw bvp driver --explain F-EXAMPLE T-XXXX
```

Step 2 is the one worth reaching for first, and it was added during the build
rather than specified: `--validate-scoring` only checks *shape*, and the
failure that actually matters is a level that never fires or one that fires on
every task. Neither is a shape error. Without a dry-run against a real task the
only way to discover either was to write the spec into live policy and see what
happened — which is what the `--add` refusal exists to prevent.

## Surfaces changed

| File | Change |
|---|---|
| `agents/termlink/bvp-estimator/estimator.py` | `load_scoring_spec`, `validate_scoring_spec`, `declarative_matches`, `score_declarative`, `_strip_template`, `_template_lines`, `_candidate_paths`, `_load_driver_specs`, `_arc_scoped_specs_for_task`; `_resolve_arc_data` hoisted out of `_arc_scoped_drivers_for_task`; `has_scorer` gained the spec path and an `entry=` argument; dispatch order in `estimate_task` |
| `lib/bvp.sh` | `--scoring-file` on `--add`; `--validate-scoring`; `--explain` (with draft mode); `_load_estimator` hoisted out of `_has_scorer`; refusal message now leads with the real fix |
| `lib/bvp-scorability.sh` | new — the shared fact function for both rails |
| `agents/audit/audit.sh` | `check_bvp_driver_scorability` in the structure section |
| `bin/fw` | doctor mirror |
| `policy/value-drivers.yaml` | §DECLARATIVE SCORING SPECS header; commented worked-example driver |
| `policy/driver-scoring-example.yaml` | new — a valid spec to copy, and the file the verbs above point at |
| `tests/unit/test_t3428_declarative_scoring.py` | new |
