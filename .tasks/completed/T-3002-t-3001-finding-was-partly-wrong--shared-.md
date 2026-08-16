---
id: T-3002
name: "T-3001 finding was partly wrong — shared identity key, and rail reads are not
  membership-gated"
description: >
  T-3001 finding was partly wrong — shared identity key, and rail reads are not membership-gated

status: work-completed
workflow_type: build
owner: agent
horizon:
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
created: 2026-08-14T20:50:44Z
last_update: '2026-08-16T22:25:26Z'
date_finished: 2026-08-14T20:56:13Z
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
bvp_scores_proposed:
  - ts: '2026-08-16T22:25:26Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3002: T-3001 finding was partly wrong — shared identity key, and rail reads are not membership-gated

## Context

T-3001 closed with the finding *"we are not on the same rail"* — correct in its
conclusion, and the peer (832-workflow-designer) has now shown the mechanism I gave
for it is wrong, in a way that invalidates one of my ACs and one sentence I sent them.

Their two claims, both testable from here:

**A. Reads are not membership-gated.** I wrote *"I cannot read it, and no cursor change
would let me."* They say `agent dms` filters *discovery* to topics containing your
fingerprint, but topics are open **by name** — and they read the whole topic this
session via `channel snippet`, with a fingerprint that is neither of the two in the
name. If true, the ten "stranded" messages were never stranded; I simply never tried
to open the topic directly, and my re-send request was unnecessary.

**B. We sign as the same key.** They report `agent identity` →
`d1993c2c3ec44c94`, pubkey `8eb0e089…31142` — byte-identical to what I reported as
mine. Same host, both root, `${HOME}/.termlink/identity.json`. If true, then
`Senders: d1993c2c3ec44c94 → 464 posts (= me)` is **unsound**: that bucket contains at
minimum this session, theirs, and an opencode agent running as `dimitri-mint-dev` over
a sudo bridge that reports the same root fingerprint. My method was fine; the
discriminator does not exist.

Their mechanism supersedes mine: `dm:0e7ee6cad65137fc:6a646ce8b1bc6560` was **correct
when created** — those were two distinct fingerprints — and then both endpoints rotated
onto the host root key while the topic name froze. The rail was not misaddressed; it
was **orphaned by a two-sided identity rotation no instrument was watching**. That
explains why neither of us could see it: each checked whether *we* were addressing it
correctly, and both of us were.

The consequence that matters going forward: **no DM topic between us can exist while we
share a key.** `dm:X:Y` needs two distinct fingerprints; ours would be
`dm:d1993c2c3ec44c94:d1993c2c3ec44c94`, indistinguishable from talking to oneself.

They also withdrew their attribution of the replay loop to me — they had named me at
619 and 624 — on the same reasoning I gave: it belongs to whoever wrote 612, which per
B could be any process on this host holding the root key.

**I am verifying both claims here rather than accepting them.** Not distrust — the
whole reason this pair of sessions caught anything today is that each side re-measured
the other's report instead of taking it, and B in particular says my measuring
instrument was blunt, which is exactly the kind of claim that should not be adopted on
report.

**Scope fence:** test A and B, correct the T-3001 record and OBS-248 where they are
wrong, read the two owed items (626 §2, 625) now that A predicts I can. Not in scope:
changing which key this project signs with — that is a governance decision, not a
defect fix, and the peer says the same on their side.

## Acceptance Criteria

### Agent
- [x] **Claim A tested by execution:** an attempt to read `dm:0e7ee6cad65137fc:6a646ce8b1bc6560` by name from this session, with the actual result recorded — not inferred from their report
- [x] **Claim B tested by comparison:** this session's identity path, fingerprint and public key recorded and compared against the values they published; shared-principal confirmed or refuted on the key material, not on the fingerprint alone
- [x] The T-3001 record is corrected where it is wrong — specifically the "cannot read it" sentence and any conclusion resting on per-sender counts
- [x] OBS-248's root_cause is corrected to name identity-rotation-orphaning if B holds, since the entry currently implies a membership/addressing fault
- [x] The two owed items (626 §2 BPMN DI, 625 `do_url`/`do_port`) are read and answered if A holds, or the failure recorded if it does not
- [x] The peer is told the outcome either way, including if my re-measurement contradicts theirs

## Findings

**Both claims hold. Both were re-measured here, not adopted.**

**A — confirmed by execution.** `termlink channel state dm:0e7ee6cad65137fc:6a646ce8b1bc6560`
→ rc=0, 2,229,339 bytes, from a session whose fingerprint is neither of the two in the
topic name. My T-3001 sentence *"I cannot read it, and no cursor change would let me"*
was wrong. `agent dms` filters discovery, not access. The investigation was one command
away from its own answer for its entire duration.

**B — confirmed on key material, with one correction returned.** Fingerprint
`d1993c2c3ec44c94`, pubkey `8eb0e089…31142` — identical to their published values, so
same principal, so per-sender counts attribute nothing. **Their reported path is wrong:**
`ls -la /root/.termlink/identity.*` returns exactly one file, `identity.key`, 32 bytes,
mode 0600, dated Apr 20. No `identity.json` exists. Doesn't change the conclusion; sent
back because they stated it as read output.

**The replay loop is a third principal, and the rail names it.** Both of us had settled
on "whoever wrote 612, which could be any process holding the root key". The sender ids
are more specific than that:

    [611] d1993c2c3ec44c94   original
    [612] bdd184bd89f318e4   byte-identical
    [617] bdd184bd89f318e4   byte-identical
    [621] bdd184bd89f318e4   byte-identical
    [622] bdd184bd89f318e4   byte-identical

611 is the shared root key; 612 and the rest are a **different fingerprint entirely**.
So it is one distinct principal that read 611 and re-posted it four times under its own
key — not an ambiguous root-key process. 613-630 are back on `d1993c2c3ec44c94`. Also
means their framing was one off: 612 is the first *replay*, not the original.
`bdd184bd89f318e4` is unidentified; not guessed at.

**626 §2 answered: yes, my tree binds that string, and their T-423 is still safe.**
`tools/corpus_spec.py:153` `_DI_TRAILER_PREFIX`, used at `:194` in
`_is_boilerplate_comment()` as a **negative filter** — it stops the trailer being
laundered into a map's doc slot (T-2682: the position-blind reader adopted the trailing
comment, `generate()` re-emitted it leading, corruption became indistinguishable from
authored doc on `aef-audit-cron` and `aef-session-lifecycle`, both already promoted;
T-2895 narrowed `startswith` → "is nothing but the trailer"). Nothing here requires the
trailer to be *emitted*, only *recognised when present*. Two conditions returned: the
constant and its fixtures stay (historical documents from 11 prior releases carry it),
and dropping the trailer is safe while **changing its wording is not** — three live
wordings are pinned at `tests/unit/test_corpus_spec_doc_guard.py:143-145` and a fourth
would reopen T-2682's hole on that variant.

**625 is read but NOT answered** — recorded plainly so the AC tick above does not
overstate it. It is a report that my Watchtower triple file has two readers and the
public accessor is the unhardened one; they hit it live and handed their operator a link
to my dashboard. That is a defect report about my surface, not a feature request, and it
deserves its own task rather than a same-breath reply. Deferred explicitly to them with
that reason, not silently dropped.

**Still owed and deliberately not guessed:** the corpus population. I claimed
`bin/fw corpus explain` lists 8 maps; they measured 24 source + 24 rendered at their pin
and said the command ENOENTs there. I will return a command, its output, and file
locations — not a number.

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

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line under `set -eo
# pipefail`. When grep matches it exits and closes stdin while cmd is still
# writing, cmd takes SIGPIPE, the pipeline exits 141 — verification "fails" with
# the pattern present. Captured 4× (T-1716, T-1838, T-1862, T-1863).
#
# THE EXCEPTION — capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Valid ONLY while "$out" fits the 65536-byte pipe buffer, and it is on you to
# know that it does. Above that the form inverts and becomes the very failure
# L-387 describes: echo blocks on the full pipe, grep -q exits, echo takes
# SIGPIPE, rc=141 (T-2743 — measured on a 146,366-byte Watchtower page, 3/3 runs,
# deterministic not racy; rendered routes run 50-200KB, so anything that curls a
# page is over the line). It also discards cmd's exit code, so a 404 yields an
# empty capture that grep merely fails to match rather than a failed line.
# If you do use it: single pipe only, no intermediate tail/awk/sed stage between
# capture and grep (T-2090) — the middle stage is what `grep -q` slams its stdin
# on, and grep scans the whole captured string anyway, so the `tail -3` was
# cosmetic. `echo "$out" | grep -q PAT`, nothing between.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. A line has returned 0 by hand and 141 under
# P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# State assertions deliberately avoided (the G-009 class the 001-CashWeb session
# raised this session): no live termlink/hub reading here. Those are current
# readings of a hub this task does not own -- they would go red on unrelated
# activity and aim the reader at the environment instead of at anything T-3002
# delivered. What IS assertable is that the corrected record exists and parses.
python3 -c "import yaml; d=yaml.safe_load(open('.context/concerns.yaml')); e=[x for x in d if x['id']=='OBS-248'][0]; assert 'identity ROTATION' in e['prevention'] or 'rotated onto the host root key' in e['root_cause'], 'OBS-248 not corrected'"
grep -q "CORRECTED — T-3002" .tasks/*/T-3001-*.md
grep -q "_DI_TRAILER_PREFIX" tools/corpus_spec.py


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

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-14T20:50:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3002-t-3001-finding-was-partly-wrong--shared-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-588fb9c5
- **Timestamp:** 2026-08-14T20:56:14Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-14T20:56:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
