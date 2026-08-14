# T-262 — Reviewer sweep over the partial-complete review queue

**Date:** 2026-07-27 · **Instrument:** `fw reviewer` (static scan v1.5, catalogue v1.3-seed,
15 anti-patterns + 4 escalation triggers — AEF-delivered, rail 234, shas 04f89678/7ebf939d)
**Scope:** all 57 tasks in `.tasks/active/` with `status: work-completed` and unchecked
Human ACs. Per-task verdicts written into each task body by the reviewer itself
(`## Reviewer Verdict (v1.5)` section). Zero Human-AC checkboxes were modified.

## Headline

| Verdict | Count | Meaning for the operator |
|---------|-------|--------------------------|
| PASS    | 38    | No structural findings — only your Human-AC judgment remains |
| CONCERN | 19    | Heuristic findings logged — see per-task notes below; none invalidate the work outright |
| FAIL    | 0     | — |

One task (T-115) additionally carries a Layer-1 **needs-human** escalation — assessed
below as a clear false positive.

## Clean set (38) — rubber-stamp candidates

Structurally clean; the only thing left on each is the Human [REVIEW] taste-check itself:

T-073 T-074 T-075 T-076 T-077 T-079 T-082 T-083 T-084 T-085 T-087 T-089 T-090 T-093
T-094 T-096 T-097 T-104 T-106 T-108 T-109 T-114 T-116 T-117 T-118 T-119 T-132 T-134
T-139 T-141 T-144 T-172 T-176 T-214 T-215 T-240 T-245 T-255

## Flagged set (19) — by pattern

### AC-verify-mismatch (16 tasks, 19 findings) — *narrow severity, heuristic*

T-098 T-099(×2) T-100(×2) T-107 T-115 T-127 T-136 T-137 T-164 T-165 T-166 T-167 T-168
T-178 T-204(×3)

An Agent AC names a concrete file path (screenshot, rendered map, source file) that no
`## Verification` line mechanically touches. **Read:** honest signal, low stakes. In
this corpus the cited paths are overwhelmingly *evidence artifacts* (e.g. T-100's
`.playwright-mcp/t100-nudge-shown.png`, read visually per the Visual-Verification
protocol) rather than deliverables whose existence went unproven — the deliverable
checks live in the harness legs the Verification blocks DO run. These do not block
review; they document a habit worth improving (add `test -f <path>` lines when an AC
cites a file).

### l387-sigpipe-risk (2) — T-081 (Verification line 14), T-197 (line 40)

**Real.** These Verification blocks contain the `streaming-cmd | grep -q` shape that
exits 141 under P-011's pipefail regime — the exact L-387 class. They passed at
completion time by luck of buffering. Worth converting to capture-then-grep next time
either task's file is touched; does not affect the shipped work itself.

### mock-only-integration (2) — T-095, T-258

AC promises integration behavior; Verification references only `tests/`-unit-looking
paths. **T-258 is a false positive** — `tests/test_t258_annotation_seam.py` drives the
REAL editor embedded in a real iframe host via CDP (full-loop integration; the "unit"
path heuristic misread it). **T-095** (clean-layout composite action): plausible —
worth a glance at whether the composite's end-to-end path had a live check.

### human-ac-mechanical-signal (1) — T-100 AC#3

Flags the `[REVIEW] Nudge is helpful, not naggy` AC as mechanically-verifiable.
**False positive** — the heuristic matched the substring `show n` in the Expected
clause; "helpful, not naggy" is genuine taste. Keep as [REVIEW].

### Layer-1 escalation: cross-project-blast (1) — T-115 (needs-human: yes)

Matched the phrase `all nodes` in the AC text. **False positive** — T-115 is
"horizontal spacing control"; "all nodes" means SVG diagram nodes, not fleet hosts.
No cross-project blast radius exists. No override filed (first sweep — leaving the
finding visible for the operator to see the FP class; file
`fw reviewer override add T-115 --pattern cross-project-blast --reason "SVG nodes, not fleet" --ttl 90`
if it should be suppressed).

## False-positive read (for AEF's catalogue-calibration ask, rail 234)

23 findings total across 19 tasks:
- **Real / useful:** 2 (l387-sigpipe ×2) + 19 AC-verify-mismatch as honest low-stakes
  signal (pattern self-declares narrow)
- **Plausible, needs eyeball:** 1 (mock-only on T-095)
- **False positives:** 3 (mock-only on T-258 — CDP integration misread as unit;
  human-ac-mechanical on T-100 — substring collision; cross-project-blast on T-115 —
  domain-term collision on "nodes")

Net: deterministic patterns fired zero (this corpus never used `--no-verify`,
tautologies, or skip-as-pass); every finding came from the heuristic tier, and the
heuristics behaved as advertised (CONCERN not FAIL). FP rate ≈ 3/23 on a foreign
corpus — reported to AEF on the rail.

## Operator guidance

1. The 38 clean tasks need only your taste-check; nothing structural is waiting.
2. Of the 19 flagged, none warrants withholding review; T-095 is the only one worth a
   second look before ticking.
3. T-115's needs-human flag is the FP described above — review it as normal.
