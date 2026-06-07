# IW Slice Worker — Bounded Build Slice + §ACD Headline-Mechanic Demo

Reusable prompt template for TermLink-dispatched workers shipping one evolutionary
build slice of a parent arc. Sibling of `iw-spike-worker.md` — that template
researches; this one **builds**. Originated as planned for T-2209 capability-overlay
arc Slice 1-4 dispatch (Path C 4-slice plan, see `docs/reports/T-2209-cli-mcp-overlay-inception.md` §12).

## Worker contract (mandatory steps)

When dispatched, you receive:
- `TASK_ID` — the slice build task (e.g. `T-NNNN` filed with `arc_id: <arc-slug>`)
- `PARENT_ARC` — the arc slug (e.g. `capability-overlay`)
- `SLICE_INDEX` — which slice (e.g. `1` of N)
- `SLICE_DEF` — bounded specification: deliverables, surface to touch, tests to add
- `HEADLINE_MECHANIC` — the §ACD wire-level deliverable this slice must demonstrate
  (e.g. *"fw --json status returns parseable JSON with schema_version=1"*)

You MUST:

1. **Read the parent arc** at `.context/arcs/${PARENT_ARC}.yaml` for the immutable axioms
   (headline_mechanic, scoped_drivers, in/out-of-scope guardrails). The arc's
   `headline_mechanic:` IS the demo your slice must move the system measurably closer to.

2. **Read the parent inception's research artifact** at
   `docs/reports/${PARENT_INCEPTION_TASK}-*.md` for the full slice plan (§12 or
   equivalent). Verify your `SLICE_DEF` matches the plan; if it has drifted, post a
   `BLOCK` envelope to the bus and stop. Producer ≠ judge — do not silently widen scope.

3. **Read the existing surface** the slice touches. Cite file paths + line numbers
   for every component you will modify. If the slice plan references files that have
   been refactored since planning, post a `BLOCK` envelope — operator triages whether
   to re-plan or proceed.

4. **Write Agent ACs into the task body BEFORE editing any source**. Each AC must be
   independently verifiable by a shell command. Categories:
   - **Surface change ACs** — "file X line Y now contains Z" (grep-pinnable).
   - **Contract ACs** — "verb V returns shape S" (parser-verifiable: pytest/jq).
   - **Headline-mechanic AC** — one AC that demonstrates the §ACD deliverable end-to-end.
   - **Verification block** — every AC has a one-line shell command in `## Verification`.

   The G-020 build-readiness gate will refuse Bash/Edit until real ACs exist. Treat the
   first-edit attempt as the gate-test — if it blocks, your ACs aren't real enough.

5. **Implement the slice minimally**. The slice IS the evolutionary increment — do not
   ship Slice K+1's deliverables under Slice K's ID. Cross-slice work surfaces as
   follow-up tasks (`bin/fw task create`), not silent scope creep. §ACD test: *can a
   reader of the slice's diff one month from now answer "what did this slice prove?"
   without reading the next slice's diff?* If no, the slice is too big.

6. **Write tests pinning the contract**. Mirror the patterns the framework uses for
   similar surfaces:
   - **CLI verb shape:** unit test that imports the verb's handler and asserts the
     return shape; integration test that subprocess-runs `fw <verb> --json` and
     parses the output.
   - **Hook/gate:** bats test that invokes the gate with allow/deny inputs and
     asserts exit code + stderr fragment.
   - **Render-surface:** Playwright test under `tests/playwright/` if the slice
     touches a Watchtower template (P-013 will require a `[REVIEW]` Human AC).
   - **Class invariant:** if the slice closes a class (e.g. widening 6 sites of a
     truncation class), assert no prior-shape instances survive — same pattern as
     T-2222's `test_tasks_error_render_widen.py:test_no_narrow_stderr_truncations_remain`.

7. **Run Verification + Reviewer**:
   - Manually walk `## Verification` block before calling `--status work-completed`.
     Capture each command's pass evidence inline in the task's progressive AC ticks.
   - `bin/fw reviewer ${TASK_ID}` — if CONCERN/FAIL with `human-ac-mechanical-signal`
     on a [REVIEW] AC, **rephrase the Expected clause** (per L-459); do not override.
   - If Verification trips a SIGPIPE risk (L-387 / T-2090), restructure to
     `out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"` (capture-first, single-pipe-only).

8. **Progressive AC ticking** (T-1831 C-4 discipline): tick each `[x]` AC checkbox
   the moment the corresponding work is in place — NOT after the close gate fires.
   The completion gate counts `[x]` markers, not body content. After-the-fact ticking
   is the exact antifragility class the gate exists to prevent.

9. **Bus post** the slice envelope:
   ```
   bin/fw bus post --task ${TASK_ID} --agent slice-iw \
     --summary "Slice ${SLICE_INDEX} ${PARENT_ARC} — <one-line deliverable>" \
     --blob <primary artifact path, e.g. tests/unit/test_*.py or web/blueprints/*.py>
   ```

10. **Demonstrate the headline-mechanic** at slice boundary. Capture wire-level
    evidence — a `meta.json`, screencast, stream-json log, live URL, or pytest run —
    that shows the headline-mechanic firing. Path: `docs/reports/${TASK_ID}-demo-evidence.md`
    (or `.json` / `.txt` for raw captures). Reference the path in `## Recommendation`.

11. **Close via partial-complete + handoff**:
    - If all ACs ticked + no [REVIEW] Human AC: `bin/fw task update ${TASK_ID} --status work-completed`. Task auto-moves to `completed/`.
    - If [REVIEW] Human AC remains: same command — framework detects unchecked Human AC and routes to partial-complete (owner=human, stays in active/).
    - Then `bin/fw task review ${TASK_ID}` to emit the handoff URL. Quote the URL verbatim
      in your final status report. Per `[[feedback_handoff_url_per_class]]`: the URL is
      class-dependent (`/review/<id>` for partial-complete; `/inception/<id>` for inception
      go/no-go; `/approvals` for Tier-0).

## Constraints

- **Source edits only within the slice's declared surface.** If you discover an
  adjacent fix is needed (e.g. a sibling truncation site, a related test gap), file
  a follow-up task — do NOT bundle it. T-2222 origin: OBS-049 was discovered during
  T-2219; closed as its own task (T-2221 + T-2222), not folded back.
- **Path isolation:** stay within `/opt/999-Agentic-Engineering-Framework`. Cross-repo
  proposals go to `bin/fw pending register` or a TermLink remote inject — never edit
  another repo's files from here.
- **§ACD hard rules:**
  - Substrate-in-place ≠ headline-mechanic fired. The slice's `## Recommendation` MUST
    cite the wire-level evidence path (step 10) — text-only "infrastructure shipped"
    framings fail the discipline.
  - "Forward work, not a closure blocker" is a §ACD violation phrase. If the slice
    can't ship the headline-mechanic end-to-end, file a Slice K+0.5 dedicated to
    closing the gap — do not declare done on incomplete substrate.
- **No Sovereign acts:** never call `fw inception decide`, `fw arc create`, `fw arc close`,
  `fw bvp confirm`, `fw bvp weight --set`, `fw arc approve-driver`, or edit
  `.claude/settings.json`. The arc close gate (T-1671) refuses under `$CLAUDECODE=1`
  by design — operator owns the decision.
- **No bypass without log:** if a structural gate blocks legitimate work
  (e.g. `[REVIEWER]` FP on a genuine static-scan finding), use the documented bypass
  flag (`--switch-focus`, `FW_SWITCH_FOCUS=1`, `--skip-rca`, etc.) — never `--no-verify`,
  never edit `.git/` directly. Every bypass writes a Tier-2 entry to
  `.context/working/.gate-bypass-log.yaml`.
- **Time-box:** 90 minutes worker time per slice. If you exceed, post the partial
  state with a `BLOCK` envelope citing remaining work — do NOT silently extend.
- **Commit cadence:** at least one commit per meaningful unit (per CLAUDE.md §Commit
  Cadence Rule). End every commit message with `Co-Authored-By: Claude Opus 4.7
  <noreply@anthropic.com>`.

## Closing checklist (before posting `--status work-completed`)

- [ ] All Agent ACs ticked `[x]` with progressive discipline (not retroactive)
- [ ] `## Verification` block walked manually; each command captured pass evidence
- [ ] `bin/fw reviewer ${TASK_ID}` returns `Overall: PASS`
- [ ] Headline-mechanic demo artifact path cited in `## Recommendation`
- [ ] `## Recommendation` block contains GO/NO-GO/DEFER + Rationale + Evidence (per
      CLAUDE.md §Presenting Work for Human Review — DEFER only for evidence gaps,
      not confidence gaps, per L-459 sibling)
- [ ] `## Evolution` entry added if slice surfaced learnings or scope refinements
- [ ] Bus envelope posted (`bin/fw bus manifest ${TASK_ID}` shows R-NNN)
- [ ] Follow-up tasks filed for any discovered adjacent gaps (not folded in)
- [ ] Memory writeup at `/root/.claude/projects/.../memory/project_<slug>.md` +
      MEMORY.md index line (one-line, < 200 chars)

## References

- Sibling template: `docs/dispatch-templates/iw-spike-worker.md` (research, not build)
- §ACD discipline: `CLAUDE.md` §Arc Completion Discipline + G-062 enforcement
- Inception discipline: `CLAUDE.md` §Inception Discipline
- Build readiness gate: G-020 (refuses placeholder ACs)
- Render-surface gate: P-013 (refuses work-completed on `web/blueprints/` without `[REVIEW]`)
- Bus protocol: `CLAUDE.md` §Result Ledger
- Sovereign refusal under `$CLAUDECODE=1`: T-1671 (arc close), T-1259/T-1260 (inception decide)
- AC routing ladder: T-1878 → T-1947 → T-2143 → T-2147 (check-shape, vocabulary, audience, reviewer backstop)
- Progressive AC ticking: T-1831 C-4 (origin S-2026-0514 errors 1-3)
- L-387 SIGPIPE safety: `## Verification` `out=$(cmd 2>&1); echo "$out" | grep -q PAT`
- L-458 (live-grep before scoping classes): captured T-2222
- L-459 (recast Expected vs override reviewer FP): captured T-2222
- Origin: planned for T-2209 capability-overlay arc Slice 1-4 dispatch (2026-06-05/06)
