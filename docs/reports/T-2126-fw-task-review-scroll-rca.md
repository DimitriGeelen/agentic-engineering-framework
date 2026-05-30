# T-2126: fw task review output: URL scrolls off-screen above QR — repeat below for terminal-reliable handoff

## Problem Statement

User screenshot (2026-05-30): the output of `bin/fw task review T-2123 2>&1 | head -30` shows QR + Artifacts + "Scan QR or open link above" + CLI line — but the URL (and the "Inception Review: T-2123" header line) **is not visible** in the frame.

The label tells the user to "open link above" — but on any terminal shorter than ~37 visible rows, the URL has scrolled off-screen by the time the QR finishes rendering.

**For whom:** the human deciding inceptions and partial-completes. Every handoff produces a card the operator scrolls past; they then either (a) scroll back up to copy the URL, or (b) re-run `fw task review` and crop the top — both are friction taxes paid on every decision.

**Why now:** sibling of [[T-2125]] (which discovered the agent was typing the wrong URL in chat). Even with the correct URL, the *CLI rendering* of that URL is unreliable at terminal heights below ~37 rows. The "always shell out to `fw task review`" rule from T-2125 only works if the shelled-out output reliably presents the URL.

## Assumptions

- **A1:** The output is exactly 37 lines (header + URL + 16-row QR + artifacts + CLI + bottom separator + review marker). Validated below.
- **A2:** Typical operator terminal height is 24–40 rows. (Standard `tput lines` on most workstation/SSH sessions.)
- **A3:** Repeating the URL below the QR + adding a one-line footer is print-only — no behavioural change, no test surface broken.
- **A4:** Anyone scanning the QR is operating from a phone close to the terminal; anyone clicking the URL needs it copy-pasteable from the visible frame.

## Investigation (RCA)

### Step 1 — Count the lines

```
$ bin/fw task review T-2123 2>&1 | cat -An | wc -l
37

Line layout:
  L1     blank
  L2     ══ top separator
  L3     "  Inception Review: T-2123"
  L4     "  1/1 checked"
  L5     blank
  L6     "  http://192.168.10.107:3000/inception/T-2123"  ← THE LINK
  L7     blank
  L8-23  QR code (16 rows)
  L24-25 Artifacts block
  L26    blank
  L27    "  Scan QR or open link above"  ← refers to L6
  L28    blank
  L29-31 CLI block (3 continuation lines)
  L32    blank
  L33    ══ bottom separator
  L34    blank
  L35    Review marker created: …
  L36    (unblocks fw inception decide …)
  L37    blank
```

### Step 2 — Terminal-height math

- 24-row terminal (legacy default): visible rows ~L14–L37 → header AND URL gone.
- 30-row terminal (common workstation/SSH): visible rows ~L8–L37 → URL gone.
- 40-row terminal (large monitor): URL visible.

The label `Scan QR or open link above` at L27 is **misleading on ≤36-row terminals**: there is no link "above" in the visible frame.

### Step 3 — Why the QR can't shrink

`lib/review.sh:185` uses `qrcode.QRCode(border=1, box_size=1)` — already at minimum density. A URL of ~46 characters needs ≥ version-3 QR which is 29×29 modules + 2-cell border ≈ 32 rows wide × 16 rows tall (each row prints two QR rows via half-block characters). 16 rows is the floor without dropping QR encoding fidelity.

### Step 4 — The defect is order + redundancy, not size

Two independent print-only fixes recover terminal-reliability without removing the QR:

1. **Repeat the URL below the QR.** One additional `echo "  ${review_url}"` after the QR + before "Scan QR or open link above". The URL is then either in the visible frame at L6 (if terminal is tall) or below the QR around L24 (always visible because that's the bottom of the frame on short terminals).
2. **One-line footer after the bottom separator.** A definitive `→ Decide at: <url>` line *after* the ═ separator, after the review marker — the very last thing scrolled to. Guaranteed visible because terminals scroll to end on output.

### Root Cause

`lib/review.sh:emit_review` was authored under the assumption that the operator sees the WHOLE output frame. On any terminal shorter than the output, the URL — the single most important artifact — scrolls past while the label still points at it. **Output ordering put the QR (visually dominant, 16 rows) ABOVE the artefact it's encoding (the URL), inverting the priority that scroll behaviour will preserve.**

This is the same class of defect as [[T-2125]] (agent typed wrong URL) and the broader §ACD-at-handoff cluster ([[T-2118]], [[T-2122]], [[T-2123]]): the framework's handoff surfaces optimise for the *agent emitting* the artefact, not the *operator consuming* it.

## Technical Constraints

- Output must remain a single `stdout` text stream (used by SSH sessions, tmux panes, log files, copy-paste workflows).
- QR rendering depends on `python3-qrcode` (already optional via the ImportError fallback at `lib/review.sh:189`).
- ANSI colour codes must not break copy-paste of the URL (already true — URL line uses no escapes).
- No new dependencies. Pure print-order change.

## Scope Fence

**In scope:**
- `lib/review.sh:emit_review()` print order + content
- Add URL echo below QR (Option A)
- Add one-line footer after bottom separator (Option C)
- Optional terminal-height detection to skip QR when `tput lines` < 37 (Option D — defer to follow-up)

**Out of scope:**
- QR encoding library swap or shrinking (already at floor)
- Watchtower web UI rendering (separate surface)
- Wholesale redesign of `fw task review` CLI shape
- Cross-cutting changes to other CLI outputs (`fw inception status`, `fw review-queue`, etc.) — file siblings if same pattern reproduces

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Remediation Options

### Option A — repeat URL below QR (mandatory)

After the QR block, add:

```sh
echo ""
echo -e "  ${BOLD}Open:${NC} ${review_url}"
```

Cost: 2 LoC. Benefit: URL visible at the bottom of the frame on any terminal ≥ ~22 rows.

### Option C — single-line footer after the bottom separator (mandatory)

At the very end of `emit_review`, after the review marker block, add:

```sh
echo -e "  → ${BOLD}Decide:${NC} ${review_url}"
```

Cost: 1 LoC. Benefit: terminals scroll to the end of output; this line is guaranteed visible regardless of frame height.

### Option D — terminal-height-aware QR skip (deferred follow-up)

If `tput lines` < 30, skip QR entirely and print only URL + CLI block. ~6 LoC; defer until A+C demonstrate insufficient because QR has independent mobile-scan value.

### Option E — fix the label, not the layout (rejected)

Change "Scan QR or open link above" → "Scan QR or open link below" and just move the URL after the QR. Equivalent to Option A but loses the top-of-frame URL for tall-terminal users. Strictly worse than A.

## Go/No-Go Criteria

**GO if:**
- A 2-LoC change (Option A) puts the URL below the QR
- A 1-LoC change (Option C) prints a definitive footer after the bottom separator
- Neither change breaks `lib/review.sh` callers (`fw task review`, `fw inception status`, `fw review-queue`)
- No test surface depends on exact line count of `emit_review` output

**NO-GO if:**
- A downstream parser greps the output by line-number anchor (would need to find such a parser first)
- QR positioning has a documented requirement other than "above the URL" — would block reordering

**DEFER if:**
- Wider redesign of `emit_review` is happening soon (no signal it is)

## Verification

# RCA findings — pinned mechanically. Build slice gets its own Verification with
# the post-fix shape (URL appears twice + footer line present).
out=$(bin/fw task review T-2123 2>&1); echo "$out" | wc -l | xargs -I{} test {} -ge 30
out=$(bin/fw task review T-2123 2>&1); echo "$out" | grep -q "Scan QR or open link above"
out=$(bin/fw task review T-2123 2>&1); echo "$out" | grep -q "http://.*/inception/T-2123"

## Recommendation

**Recommendation:** GO

**Rationale:**

RCA: emit_review prints header+URL+QR+artifacts+'Scan QR or open link above'+CLI in a 37-line block; QR alone is 16 rows. On any terminal under ~37 visible rows the URL at line 6 scrolls off, but the label still tells the user to look 'above'. Verified by cat -An on bin/fw task review T-2123 output. Structural fix: ~3-line lib/review.sh change repeating the URL below the QR plus a one-line footer after the bottom separator. Bounded, idempotent, print-only blast radius — GO.

**Evidence:**

- `bin/fw task review T-2123 2>&1 | wc -l` → 37 (RCA Step 1)
- `cat -An` layout shows URL at L6, QR at L8–L23, "Scan QR or open link above" at L27 — URL is 21 lines and a 16-row QR above its referring label (RCA Step 1)
- User screenshot 2026-05-30: visible frame shows QR + Artifacts + "Scan QR or open link above" + CLI line; header and URL not in frame (RCA Step 2)
- `qrcode.QRCode(border=1, box_size=1)` already at minimum density — QR shrinking not an option (RCA Step 3)
- Sibling class: [[T-2125]] (agent-side URL typo), [[T-2118]], [[T-2122]], [[T-2123]] — §ACD-at-handoff across decision classes

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommended Build Slice (on GO)

**T-NEW-A+C**: single build task editing `lib/review.sh:emit_review`:
1. After QR rendering: `echo ""; echo -e "  ${BOLD}Open:${NC} ${review_url}"` (Option A)
2. After review-marker block / last echo: `echo -e "  → ${BOLD}Decide:${NC} ${review_url}"` (Option C)
3. Verification: `out=$(bin/fw task review T-2123 2>&1); echo "$out" | grep -c "inception/T-2123" | xargs -I{} test {} -ge 3` (URL must appear ≥3 times: original L6, post-QR repeat, footer)
4. No template/blueprint touch — pure CLI rendering change

Estimated effort: 15 minutes. Reversible. Zero blast radius outside `lib/review.sh`.

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
