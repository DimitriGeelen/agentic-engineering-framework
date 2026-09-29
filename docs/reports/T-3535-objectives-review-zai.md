I'll start by reading the draft, the design doc, and the task file.
The task file isn't under active with that prefix; let me find it, and list the arcs.
Globs may need absolute paths; retrying.
Found the task file. Now reading it plus the primary cited sources in parallel.
Now reading the cited sources: 001-Vision, 005-DesignDirectives, T-010, T-3557.
Now reading T-3558, T-3563, decisions.yaml D-662, and CLAUDE.md.
Now let me pull D-662 from decisions.yaml, and check CLAUDE.md sections.
The draft cites "CLAUDE.md §Release-Train Branch Model" — I don't see that heading; checking, and reading the first batch of arc YAMLs.
Reading the next batch of arcs.
Last batch of arcs.
All 20 arcs read. Now verifying the measure claims: do the cited commands, files, and test paths actually exist, and does the 2026-09-27 audit name the same five stale arcs?
The audit directory listing looked different than expected — checking for the dated audit file and stale arc flags.
Audit matches the draft's five stale arcs exactly. One last check — where the "3–5 objectives" limit in doubt 2 comes from.
The "3–5 limit" has no source anywhere else in the repo — noted. Let me characterize the ewcr initiative briefly since doubt 6 questions whether it deserves an objective.
One final verification — that no arc has a non-empty `supports:` field, and confirming the Release-Train section content for O-4's citation.
All sources verified. Here is the review.

```
VERDICT: amber

FIDELITY:
  Checked every objective against its cited sources: 001-Vision.md (§Problem/§Vision quotes
  exact), 005-DesignDirectives.md (AD-002/009/010, D4), T-010 (audience, out-of-scope items
  1/2/5, "<1 minute" success), T-3557 (353 open / 11 tier-0 figure, IW-1, IW-2), T-3558
  (segment 2 verbatim, F-3 23.6h, OBS-567/574), T-3563 segment 2, decisions.yaml D-662,
  CLAUDE.md (Core Principle, Authority Model, Enforcement Tiers incl. T-2742 command-string
  scope, Consumer-Facing Command Hygiene, Release-Train Branch Model at CLAUDE.md:1297,
  Execution Model, Sub-Agent Dispatch Protocol), all 20 arc YAMLs, the 2026-09-27 audit
  (names exactly the five arcs the draft marks stale), and existence of both bypass logs,
  both dispatch ledgers, the three cited bats files, and `fw metrics` / `fw review-queue` /
  `fw reviewer surface`. All quoted numbers (325; 353/11; 0 of 2416; 0 of 20 `supports:`,
  confirmed empty in every arc) match their sources. Three findings: (a) doubt 2's "3–5
  limit" exists nowhere in the repo — it is the drafter's constraint, not a ruling or
  design decision; (b) doubt 3 mis-attributes the headline's "humans deciding only what
  matters": 001-Vision says "Humans retain sovereignty" (humans decide, full stop) — the
  "only" is T-3557's 2026-09-29 risk-only ruling; the headline itself is faithful to
  current intent, the provenance line is wrong; (c) T-010 out-of-scope item 4
  (non-technical users) is silently dropped while items 1, 2 and 5 are imported — minor,
  no conflict with anything, noted not corrected.

CORRECTIONS:
  - target: out_of_scope
    replace_with: |-
      add as a sixth entry:
        "Multi-repo orchestration — one repo, one framework instance (T-010 §Out of Scope
        item 3). SUPERSEDED by T-3558 (operator 2026-09-29: circuit model applies across
        agent, session, project, hub, machine); listed only to record the supersession."
    why: objectives.yaml is the durable artifact — the reversal of a stated out-of-scope
      item must be visible where future agents read, not only in §3 of a report that rots
      (superseded-kept-marked is this repo's own pattern from T-3563).
  - target: O-3 (via §3.2)
    replace_with: >-
      In doubt 2, replace "that would make six objectives, over the 3–5 limit" with
      "no recorded rule caps the objective count; splitting is legitimate if the operator
      prefers a sixth objective over a compound O-3".
    why: the 3–5 limit is unsourced and must not masquerade as a constraint on the
      operator's choice.
  - target: headline (via §3.3)
    replace_with: >-
      In doubt 3, replace "It combines 001-Vision §The Vision's four bullets and T-010's
      primary audience" with "It combines 001-Vision §The Vision (three of four bullets),
      T-010's primary audience, and T-3557's risk-only review ruling ('humans deciding
      only what matters')".
    why: the "only" is T-3557's, not 001-Vision's; the operator should know the headline's
      strongest clause is one week old, not project-old.

AUTHOR'S DOUBTS:
  1. Correct call, incomplete record: T-3558 is operator-verbatim and arc-020/arc-011 build
     it, so the newer ruling governs — but write the supersession into objectives.yaml
     (correction 1); do not just ask.
  2. Keep O-3 compound: all three clauses share one observable (where operator attention
     goes), and declinability needs the ranking and decline machinery together; but the
     3–5 limit is invented (correction 2).
  3. Headline is faithful; fix the attribution (correction 3).
  4. Agree, NONE stands: O-2 is not repeating witnessed *failures*; routing by recorded
     *success* is a different mechanism. If the operator wants efficient model use it is a
     new objective — no source states it at project level (arc-003 defers cost-aware
     routing to T-1637, horizon:later), so it is correctly surfaced, not missing.
  5. Agree, NONE stands: the arc's outcome is invocation transport (MCP vs Bash;
     sovereignty verbs stay shell-only), so no objective's world-state changes; stale +
     NONE is exactly the IW-5 audit signal working. Widening O-4 to agent runtimes would
     restate D4 as an outcome — don't.
  6. Agree on both: designer-corpus serves 832's designer; the ewcr packet is an advisory
     handoff ("no local arc/task creation or implementation authority"); neither is a
     stated direction of this project — NONE unless the operator declares an
     evaluate-external-initiatives objective, which nothing sources.
  7. Half disagree: arc-grooming → O-3 is not thin — `fw arc abandon` plus the 30-day
     stale WARN (live in the 2026-09-27 audit) *is* O-3's declinability machinery;
     horizon-axis → O-2 is genuinely thin but defensible as a resume-correctness slice —
     both keep, none go to NONE.
  8. Measures are honest: every cited command, ledger and test exists; the two admitted
     gaps (silent bypasses, uninstrumented repeat-failures/pickup) are stated as
     not-computable rather than silently proxied — that is the standard the O-2 proxies
     should keep.
  9. Verified: the 2026-09-27 audit names exactly the five stale arcs claimed; using
     001-Vision §Current State (2026-02-14) for intent only is acceptable and disclosed.

OVERALL: Fit to show the operator — sources, mappings, NONEs and measures all survive
checking; apply the three corrections so the one durable artefact records the T-010
supersession it depends on and cites the true provenance of its headline.
```
