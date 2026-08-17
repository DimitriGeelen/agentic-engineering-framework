# T-3060 — unclosed-but-satisfied sweep of `.tasks/active/`

_Generated read-only. No task was closed, no state mutated._


## Criterion

A task in `.tasks/active/` **qualifies** when all of the following hold:

1. Frontmatter `status:` is `started-work` or `issues`.
2. The `## Acceptance Criteria` section has **at least one** `### Agent` AC
   (when no `### Agent` / `### Human` subsection headers are present, every AC
   is treated as an Agent AC).
3. **Every** Agent AC checkbox is ticked `- [x]`.
4. **Zero** Human AC checkboxes are left unticked.

Lines inside HTML comment blocks and the task template's example ACs
(`First criterion`, `Dashboard renders correctly`, `Block message names both
bypass mechanisms`, …) are excluded — otherwise every unedited template
would read as an unsatisfied Human AC.

## Limits — read before acting on this list

**A ticked box is a claim, not evidence.** This sweep reads checkbox
characters; it does not run the task's `## Verification` block, does not
re-derive whether the described work actually shipped, and cannot tell a
genuinely finished task from one where an agent ticked ahead of itself. It
also cannot see the close gates that would still fire (P-010, P-011, the RCA
gate, the render-review gate, the inception scope-trace gate).

So this table produces **candidates for close, never closures.** Each row still
needs its verification block run and its claims spot-checked before anyone
touches `fw task update --status work-completed`. Rows whose Verification block
is empty (final section) need that scrutiny most: nothing mechanical would
gate their close.


## Qualifying tasks (17)

| Task | Status | Workflow | Name | Agent ACs | Verification cmds? |
|------|--------|----------|------|----------:|--------------------|
| T-801 | started-work | build | fw costs CLI — token usage tracking from JSONL transcripts | 9 | yes |
| T-802 | started-work | build | Watchtower token dashboard — /costs page with session tab... | 7 | yes |
| T-803 | started-work | build | Landing page token widget — show current session tokens o... | 5 | yes |
| T-1274 | started-work | build | Memory writes (claude auto-memory) blocked by onboarding ... | 5 | yes |
| T-1542 | started-work | build | fw upgrade from inside a consumer crashes at step 4b/9 — ... | 6 | yes |
| T-1624 | started-work | build | Refresh ring20-dashboard hub.secret on this anchor — secr... | 3 | **no** |
| T-2200 | started-work | build | dispatch AEF setup worker on /opt/fan-dashboard | 4 | **no** |
| T-2202 | started-work | build | dispatch AEF setup worker on /opt/832-Workflow-designer | 4 | **no** |
| T-2410 | started-work | build | check-active-task hook: false positives block legitimate ... | 4 | yes |
| T-2715 | started-work | inception | first-run experience: why four green install surfaces mis... | 3 | **no** |
| T-2745 | started-work | build | Wire pytest tests/unit/ into fw test and CI (153 files ru... | 4 | yes |
| T-2801 | started-work | build | fw init is not atomic and its debris is not fw-recoverabl... | 5 | yes |
| T-2802 | started-work | build | fw watchtower url returns http://localhost:3000 from a NO... | 6 | yes |
| T-2871 | started-work | build | corpus depends 91% on non-frozen aef:meta keys — no guard... | 6 | yes |
| T-2876 | started-work | inception | Interpreter-mediated writes bypass the Bash task gate — s... | 3 | **no** |
| T-2969 | started-work | build | draft arc with all constituents complete is reported by n... | 5 | yes |
| T-3043 | started-work | build | RCA: non-root agent cannot use TermLink hub — socket mode... | 8 | **no** |

## Qualifying tasks with an empty `## Verification` block (6)

Nothing mechanical would gate the close of these — P-011 passes vacuously,
so the ticked boxes are the *only* evidence on file. Treat every one of these
as needing a hand-written verification line before close, not as a fast path.

| Task | Status | Workflow | Name | Agent ACs |
|------|--------|----------|------|----------:|
| T-1624 | started-work | build | Refresh ring20-dashboard hub.secret on this anchor — secr... | 3 |
| T-2200 | started-work | build | dispatch AEF setup worker on /opt/fan-dashboard | 4 |
| T-2202 | started-work | build | dispatch AEF setup worker on /opt/832-Workflow-designer | 4 |
| T-2715 | started-work | inception | first-run experience: why four green install surfaces mis... | 3 |
| T-2876 | started-work | inception | Interpreter-mediated writes bypass the Bash task gate — s... | 3 |
| T-3043 | started-work | build | RCA: non-root agent cannot use TermLink hub — socket mode... | 8 |
