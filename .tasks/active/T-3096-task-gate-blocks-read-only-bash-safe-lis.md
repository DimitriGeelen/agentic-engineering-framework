---
id: T-3096
name: "Task gate blocks read-only Bash: safe-list is an enumerated allowlist, misses
  sed/timeout/termlink and any script"
description: >
  Task gate blocks read-only Bash: safe-list is an enumerated allowlist, misses sed/timeout/termlink
  and any script

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
created: 2026-08-20T00:58:42Z
last_update: '2026-08-20T01:00:15Z'
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
  - ts: '2026-08-20T01:00:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=202,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-20T01:00:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3096: Task gate blocks read-only Bash: safe-list is an enumerated allowlist, misses sed/timeout/termlink and any script

## Context

Three read-only Bash commands were blocked by the task gate in one session, each with a
block message asserting a modification that did not happen:

| Command | Block | Message claimed |
|---|---|---|
| `cat .context/working/.budget-status; echo …; timeout 30 termlink agent inbox \| head -30` | work-completed focus | "Cannot modify files under a completed task" (P-002) |
| `sed -n '152,262p' agents/context/check-active-task.sh` | G-020 placeholder ACs | "Build tasks require real acceptance criteria before **editing source files**" |
| `./agents/context/checkpoint.sh status 2>&1 \| tail -5` | work-completed focus | P-002 |

None of the three writes anything. `has_bash_write_pattern` correctly returns *no write*
for all three — the block comes from the **second** question the gate asks, not the first.

`agents/context/lib/safe-commands.sh:188` decides safety by matching the segment's base
command against an **enumerated allowlist** of ~50 names. `sed`, `awk`, `timeout`,
`termlink`, `jq`, `sort`, `diff`, `bats` and every `./script.sh` are absent, so they are
"not recognised" — and "not recognised" is then reported to the agent as "you tried to
modify a file". A compound is safe only if *every* segment is safe (correct, conservative,
T-2834), which means one unenumerated segment gates the whole line.

The enumeration is not the accident; it is load-bearing. `has_bash_write_pattern` is a
syntactic scan and cannot see that `./build.sh` or `python3 deploy.py` writes — the same
scope boundary Tier 0 has (CLAUDE.md §Enforcement Tiers, T-2742). So the allowlist must
stay a *positive* assertion and this task must NOT replace it with "no write pattern →
allow". The defect is that the list has grown one entry per incident — its own comments
name T-2052, T-2054, T-2462, T-2878, T-2410, T-1908, T-2834, T-2887, T-2888, T-2936,
T-2988 — and T-2888 already established the fix for exactly this, but applied it only to
`git` sub-verbs: derive the set from the corpus instead of remembering it.

Two further defects visible in the same code:

- **`timeout` is a prefix-transparent wrapper**, not a command. `timeout 30 termlink …`
  extracts base `timeout`. This is the *third* recorded instance of a positional token
  reader meeting a prefix nobody taught it about — the file's own comments name the other
  two (T-1908 env-var prefixes, T-2988 grouping punctuation) and call it a class.
- **The block message is not merely unhelpful, it is false.** It names a modification for
  a command that modifies nothing, and offers a remedy ("write real ACs", "resume a task")
  aimed at a problem the agent does not have. A gate whose stated contract does not match
  its behaviour is the T-1890 / L-399 failure shape: the agent routes around it.

## Acceptance Criteria

### Agent
- [x] The gated set is **derived, not remembered** (T-2888 precedent): every base command
      appearing in this repo's own `.sh`/`.py`/`.bats`/task-file verification lines is run
      through `is_bash_safe_command` with `has_bash_write_pattern` false, and the ones that
      come back gated are tabulated in `## Decisions` with a per-command keep/add verdict
- [x] Transparent wrappers (`timeout N`, `nohup`, `nice`, `stdbuf …`, `command`) are
      stripped and the **inner** command is judged, in the same stripper family as the
      T-1908 env-prefix loop — not added to the allowlist as if they were commands
- [x] `sed` without `-i` classifies safe; `sed -i` still gates (already caught by
      `has_bash_write_pattern`, so this must be verified as an interaction, not assumed)
- [x] `termlink` is verb-scoped like `git` and `fw` — read verbs allowed, mutating verbs
      (`inject`, `spawn`, `dispatch`, `signal`, `clean`, `send`, `post`) still gate
- [x] A Bash block message distinguishes "this command writes" from "this command is not
      recognised as read-only", and in the second case names the specific unrecognised
      segment — no Bash block may claim a modification when `has_bash_write_pattern` is false
- [x] The commands from the Context table are each disposed with a stated verdict, pinned
      as regression tests. **Corrected from "all three classify safe" after measuring:**
      the first two do; the third (`./agents/context/checkpoint.sh status | tail -5`)
      stays gated *deliberately* — a command string cannot see what a script does, so
      executing a file is never provably read-only (Tier 0 scope boundary, T-2742). What
      changes for it is the message, not the verdict. An AC demanding all three pass would
      have been satisfiable only by allowlisting arbitrary script execution
- [x] Nothing that previously gated now passes except by explicit verdict in the Decisions
      table — verified by running the pre-fix and post-fix predicate over the same derived
      corpus and diffing, with the diff reproduced in Decisions
- [x] Mutation check recorded: removing the wrapper-stripper turns the `timeout` test red,
      and removing the message split turns the message test red

### Human

- [ ] [REVIEW] The widened read-only set is an acceptable blast-radius trade for this repo and its consumers

  **Why you and not the agent:** this loosens a security predicate, and it ships to every
  consumer project through `.agentic-framework/` vendoring. The agent can prove the tests
  pass and the differential is accounted for; it cannot rule that the *trade* is worth it.
  That is a sovereignty call (CLAUDE.md §AC Classification Guidance, criterion 4).

  **Steps:**
  1. `git show 715737171 --stat && git show a87b86a99 --stat`
  2. Read `## Decisions` D-2 (what was gated), D-4 (what was deliberately NOT adopted) and
     D-6 (the 65 / 17 differential, both buckets enumerated in full) in this task file
  3. Skim the derived evidence: `docs/reports/T-3096-fw-verb-classification.md` — the
     `## Deliberately excluded` section is the one that matters, it lists the 20 MIXED
     and 4 UNKNOWN pairs that stayed gated
  4. Decide on the one judgement the agent flagged as yours: **stdout-only filters**
     (`sed`, `awk`, `sort`, `jq`, `diff`, …) are now allowed on the argument that their
     only write route is a redirect, and redirects are caught one layer up by
     `has_bash_write_pattern`. That argument is sound for the forms tested. It rests on
     `has_bash_write_pattern` staying correct — a single regression there now widens
     further than it used to.

  **Expected:** you agree the trade is right, or you name a specific entry to pull back
  (each is a one-line `case` arm in `agents/context/lib/safe-commands.sh`).

  **If not:** say which entry and why; removing one is a one-line edit plus flipping its
  test from `-eq 0` to `-ne 0`. The wrapper stripper and the block-message split are
  separable from the filter set — they can stay even if the filters come out.

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

out=$(bats tests/unit/t3096_safe_commands_wrappers.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/context_safe_commands.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/safe_commands_chain.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/safe_commands_env_prefix.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/test_safe_commands_git_commit.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/drift_gate_not_shadowed_by_safelist.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
bash -n agents/context/lib/safe-commands.sh
bash -n agents/context/check-active-task.sh
# the block message must never claim a modification for a command that has no write pattern
bash -c 'source agents/context/lib/safe-commands.sh; eval "$(sed -n "/^_bash_gate_reason() {/,/^}/p" agents/context/check-active-task.sh)"; BASH_CMD="./x.sh status | tail -5"; _bash_gate_reason' > /tmp/.t3096-msg.out 2>&1 && grep -q "writes nothing the gate can detect" /tmp/.t3096-msg.out && ! grep -q "matches a file-write pattern" /tmp/.t3096-msg.out
# the prescribed port-resolution idiom (CLAUDE.md §Watchtower Port) must classify safe
bash -c 'source agents/context/lib/safe-commands.sh; is_bash_safe_command "curl -sf \"\$(bin/fw watchtower url)/config\" -o /tmp/x"'
# the derivation report the READ set was taken from must exist and carry its counts
grep -q "^| READ |" docs/reports/T-3096-fw-verb-classification.md
# G-084 is registered and the register still parses
python3 -c "import yaml,sys; d=yaml.safe_load(open('.context/project/concerns.yaml')); sys.exit(0 if any(c['id']=='G-084' for c in d['concerns']) else 1)"

## RCA

**Symptom.** Three read-only Bash commands were refused in one session, each told it had
attempted a file modification. None writes.

**Why (1)** — the gate asks two questions but every block message is phrased for the
first. **Why (2)** — because when the two questions were joined, the second one's failure
mode ("not recognised") had no message of its own, so it inherited the first one's
("you wrote something"). **Why (3)** — because the second question was expected to answer
YES almost always: the allowlist's own header cites 7,920 measured invocations and claims
it "catches the safe 98.6%". **Why (4)** — because that measurement was taken once, at
T-650, and the list has been maintained by patching since: eleven incidents are named in
its own comments, each adding the one entry that had just blocked someone.
**Why (5)** — because nothing re-derives the list against what the repo actually runs. The
98.6% claim was never re-measured, and it is now wrong by a wide margin — 50 of 52
read-only shapes this repo's own tooling uses classify GATED.

**Class.** A coverage claim that decays silently. The list did not get worse; the repo
grew around it, and the one artefact that would have shown the drift — a re-derivation —
was never run twice. Same shape as T-2888 (git sub-verbs, four incidents before anyone
derived the set) and as T-3094's proxy-metric drift, one layer up: a measurement taken
once and then trusted as a property.

**Why it went unreported for so long.** The failure presents as friction, not as an error.
An agent that hits it re-spells the command, splits the chain, or reaches for a different
tool — and succeeds. Nothing is logged, no gate records a false positive, and the agent
that worked around it has no reason to file anything. The message telling it that it had
modified a file is precisely what made the diagnosis unavailable: it named a cause that
was not worth investigating because it was not true.

**Prevention, not mitigation.** Three legs, and only the first is the symptom fix:
(1) the derived set + wrapper stripper — the entries that were missing;
(2) `_bash_gate_reason` — the class of false positive that *cannot* be eliminated
(script execution) is now reported truthfully, so the next occurrence is diagnosable in
one read instead of invisible;
(3) G-084 registered with a `trigger_check` that names the exact predicate pair to
evaluate, so the next instance is recognised as this gap rather than re-derived from
scratch. Leg 2 is the one that makes the gap self-reporting; without it, leg 1 would just
reset the clock on the same silent decay.

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Recommendation

**Recommendation:** GO

**Rationale:** The eight agent ACs and all twelve Verification lines pass, 30 new tests are
green, all five pre-existing safe-command suites stay green, and four mutations go red.
What is left is a single judgement I should not make on my own: this loosens a security
predicate and ships to every consumer through vendoring.

The defect is real and was measured, not inferred. 50 of 52 read-only shapes this repo's
own tooling uses classified GATED, and 92 of 120 READ `fw` pairs were unreachable —
including `fw watchtower url`, which CLAUDE.md prescribes as *the* way to avoid
hard-coding port 3000. A rule that has been violated 371 times across 277 tasks had its
sanctioned alternative refused by a different gate.

I want to be explicit about what this does and does not fix, because the framing matters
for the review. Widening the allowlist stops *some* false positives. It cannot stop all of
them: executing a script is not provably read-only from a command string, and that is the
Tier 0 scope boundary, not an oversight. The half that is fixed unconditionally is the
**message** — a Bash block no longer claims a modification when no write pattern matched,
and it names which segment of a chain was unrecognised. That is what makes the next
occurrence diagnosable instead of invisible, and it is why I would keep leg 2 even if you
pull entries out of leg 1.

Two things I deliberately did not do, both toward gating: I excluded `orchestrator improve`
although the derivation classified it READ (a stub that prints is a temporary property, not
a contract), and I narrowed nothing that was previously allowed even where the derivation
proposed it — narrowing `integrate` or `resume` would re-open a deadlock this file has been
patched four times to close. Both exclusions are pinned by tests so they are not quietly
reversed later.

**Evidence:**
- `tests/unit/t3096_safe_commands_wrappers.bats` — 30/30, every relaxation paired with a
  negative that must stay red (`termlink inject`, `fw config set`, `env ./x.sh`, `yq -i`,
  script execution, `fw reviewer T-XXX`)
- Pre-existing suites green: `context_safe_commands` (48), `safe_commands_chain` (21),
  `safe_commands_env_prefix` (10), `test_safe_commands_git_commit` (12),
  `drift_gate_not_shadowed_by_safelist` (11)
- Mutations I/J/K/L all red (Decisions D-7), including one near-miss where my own guard
  tripped on correct output and was fixed rather than loosened
- Differential over 20,222 corpus lines with **both** non-trivial buckets enumerated in
  full, not sampled — 65 GATED→SAFE all real verification lines, 17 SAFE→GATED all English
  prose (Decisions D-6)
- Derived evidence with file:line per verdict: `docs/reports/T-3096-fw-verb-classification.md`
- A pre-existing hole closed, not opened: `env ./anything.sh` used to classify SAFE on the
  strength of the word `env`
- G-084 registered in `.context/project/concerns.yaml` **before** the fix, with a
  `trigger_check` naming the exact predicate pair, so the next instance is recognised
  rather than re-derived

## Decisions

### D-1: keep the positive allowlist; the enumeration is not the bug

The obvious fix — "no write pattern detected, therefore allow" — is wrong, and stating
why is the point of this decision. `has_bash_write_pattern` scans a command *string*. It
cannot see inside `./build.sh` or `python3 deploy.py`, which is the identical scope
boundary Tier 0 has and which CLAUDE.md already documents (§Enforcement Tiers, T-2742).
Dropping the allowlist would make every script invocation read-only by default.

So the allowlist stays a positive assertion. What changed is how its contents are
obtained: **derived from the corpus, not remembered incident by incident.** That method
is not new here — T-2888 established it for `git` sub-verbs after four consecutive
incidents patched the same function — it had simply never been applied to the base-command
list or to `fw`'s own surface.

### D-2: measured gap — 50 of 52, and 92 of 120

| Scope | Measured |
|---|---|
| Read-only shapes used by this repo's tooling that classified GATED | **50 of 52** |
| `fw` (command, sub-verb) pairs total | 299 |
| ... classified READ | 120 |
| ... READ *and* reachable through the old allowlist | 28 |
| ... **READ and unreachable** | **92** |

The worst single instance: CLAUDE.md §Watchtower Port prescribes
`curl -sf "$(bin/fw watchtower url)/page"` as *the* way not to hard-code port 3000 — and
`fw watchtower url` gated. A rule violated 371 times across 277 tasks (T-2732) had its
sanctioned alternative refused by another gate.

### D-3: `timeout` is a prefix, so it belongs in a stripper, not the allowlist

Adding `timeout` to the list would have been the fourth patch of one symptom. The file's
own comments already name the class twice — T-1908 (env-var prefixes) and T-2988 (grouping
punctuation), both "a positional token reader meeting a prefix nobody taught it about" —
and this is its third instance. The stripper generalises to `nohup`, `nice`, `stdbuf`,
`command`, `env` and `flock` at once.

It also **closes a hole rather than opening one**. `env` sat in Category 5 as
unconditionally safe, so the base extracted as `env` and `env ./anything.sh` classified
SAFE on the strength of the word `env`. After stripping, that line is judged on
`./anything.sh` and gates. Pinned by a test.

`xargs` is excluded: its command is assembled from stdin at runtime, so there is nothing
static to judge. Every parse failure in the stripper — an unrecognised option, a missing
duration, an empty remainder — leaves the base as the wrapper name, which matches no arm.
The failure direction is always toward BLOCKING.

### D-4: two departures from the derived READ set, both toward gating

The classification worker (`docs/reports/T-3096-fw-verb-classification.md`, file:line
evidence per verdict) proposed a set I did not adopt wholesale.

- **`orchestrator improve` excluded** though classified READ. It is a v2 stub that
  currently prints. A stub is a temporary property, not a contract, and the verb's name
  declares an intent to act — the day it is implemented the gate would silently permit
  it. A test now pins the exclusion so a later author does not "fix" the omission.
- **Nothing already allowed was narrowed.** The derivation proposed scoping `integrate`
  to `check|classify` and `resume` to `quick`. Both are whole-command allows today for
  stated reasons — T-2471: integrate runs from a worktree whose Bash-hook PROJECT_ROOT
  resolves to the main repo, so focus is null. Tightening them would re-open a deadlock
  this file has been patched four times to close.

`yq` is excluded from the filter set for the mirror of the reason `sed` is included:
`sed -i` is caught by a dedicated rule in `has_bash_write_pattern`, and `yq -i` is caught
by nothing. Verified in both directions rather than assumed.

### D-5: the message defect is the half that costs the gate its authority

The predicate change stops *some* false positives. It cannot stop all of them — executing
a script is not provably read-only and never will be. What can be fixed unconditionally is
what the agent is *told*: a Bash block now distinguishes "this matches a write pattern"
from "this is not recognised as read-only", and in the second case names the offending
segment of a chain.

This is not cosmetics. A gate that names a cause the agent knows to be false teaches the
agent that the gate's stated contract is unreliable, and the documented consequence is
that the agent routes around it — L-399 / T-1890, where one broken leg of a bypass
contract produced three weeks of silent circumvention. Emitted from `_blocked_subject` so
all eight block sites inherit it with no new call site to forget.

### D-6: differential over 20,222 corpus lines — every transition accounted for

| Transition | Count | Disposition |
|---|---:|---|
| GATED → GATED | 14,986 | unchanged |
| SAFE → SAFE | 4,165 | unchanged |
| WRITE → WRITE | 989 | write classification untouched |
| **GATED → SAFE** | **65** | intended |
| **SAFE → GATED** | **17** | not commands |

Both non-trivial buckets were read line by line, not sampled:

- The **65** are real verification lines from real task files — `diff -q A B`,
  `cmp -s A B`, `awk '...' file`, `curl … | awk`. Exactly the target.
- The **17** are English prose. The corpus is built from task-file `## Verification`
  sections, which contain commentary as well as commands, and every one of the 17 is a
  sentence beginning with the word `command` or `env` ("command failure. It therefore
  slips both guards…"). They used to classify SAFE *because* `command` and `env` were
  unconditionally safe base words — so this bucket is not a regression, it is the D-3
  hole becoming visible from the other side. Prose is never executed, so the change is
  inert in production.

Corpus caveat stated rather than buried: it is task verification text, so it contains
non-commands. That inflates all five counts equally and does not affect the two buckets
the verdict rests on, both of which were enumerated in full.

### D-7: mutations — four applied, four red

| # | Mutation | Result |
|---|---|---|
| I | wrapper case arm never matches (stripper disabled) | **RED** — tests 1, 3, 5, 20 |
| J | `_bash_gate_reason` always reports a write | **RED** — tests 23, 24 |
| K | name the whole command line instead of the offending segment | **RED** — test 24 |
| L | add `yq` to the filter list (the excluded case) | **RED** — test 15 |

One near-miss worth recording: the first version of test 24's leak-guard grepped the whole
output for `cat f`, which line 1 legitimately echoes back — so it failed against correct
behaviour. Fixed by restricting the guard to the line that names the offender. A guard
that trips on the correct output is the same defect class as a gate that fires on a read.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-20T00:58:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3096-task-gate-blocks-read-only-bash-safe-lis.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-75b97e53
- **Timestamp:** 2026-08-20T01:24:42Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
