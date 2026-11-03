# Roadmap: outside contributions and GitHub as the place we work (arc github-contributions)

Operator, 2026-11-03: "focus on getting him set up so he can start working", "all the agents start tracking our
issues and changes in GitHub", "we switch our remote", "we need a road plan; that should be the focus".

The order follows one rule: nothing merged on GitHub may be lost, so the remote switch comes before any merge of
code. The role chain (T-5021..T-5028) keeps running for the hard parts of phases 1 and 2.

## Phase 0 — Mehdi can start (days)

| # | Step | Who | Task |
|---|---|---|---|
| 0.1 | Send Mehdi the draft plan (`T-5006-draft-plan-for-mehdi.pdf`): "go ahead with PR 1, documentation only" | Operator | — |
| 0.2 | Make GitHub's Test workflow green again (red on every run since 2026-10-20) and run it for PRs to `bleeding-edge` | AEF | new |
| 0.3 | A safe interim merge: while OneDev is still the source, a PR merged on GitHub is pulled into OneDev at once and the mirror sync may never overwrite GitHub history | AEF + operator | new |
| 0.4 | Mehdi opens PR 1 (CONTRIBUTING with `master`, PR template, `test.yml`); AEF reviews; operator merges | Mehdi, AEF, operator | — |

## Phase 1 — GitHub becomes the source (1-2 weeks)

| # | Step | Who | Task |
|---|---|---|---|
| 1.1 | Switch `origin` to GitHub on every working copy and agent; OneDev mirrors GitHub | Operator (runme) + AEF | new |
| 1.2 | Branch rules on GitHub: no force push or deletion on `bleeding-edge` and `master`; merge needs green checks and the AEF review check | Operator (settings) | new |
| 1.3 | Release train, mirror cron and consumer upgrade source point at the new origin | AEF | new |
| 1.4 | Audit alarm for outside commits that did not arrive through an operator-merged PR | AEF | new |

## Phase 2 — all agents track issues and changes in GitHub (2-4 weeks)

| # | Step | Who | Task |
|---|---|---|---|
| 2.1 | Relay: peers send bugs and requests to AEF, AEF files them on GitHub, cleaned, project id stamped | AEF | T-5007 |
| 2.2 | Secondary account (not a collaborator), one classic token per trusted peer | Operator + AEF | new |
| 2.3 | Fixed-form direct verdicts, after-posting scan, sidecar confirmation before any state change | AEF | new |
| 2.4 | Duplicate linking with fabric, vector and keyword search; reopen on FAILS; ask the source to check | AEF | new |
| 2.5 | `fw pickup send` for bugs and features routes to the new path | AEF | new |

## Phase 3 — quality floor for code PRs (in parallel, high priority)

| # | Step | Who | Task |
|---|---|---|---|
| 3.1 | Own isolated test hosts for deeper tests (code PRs wait for this) | AEF + operator | T-5009 |
| 3.2 | Third review vendor seat, so high-risk PRs can be reviewed | AEF | T-4997 |
| 3.3 | Seats as a dedicated unprivileged user | AEF + operator | T-5008 |
| 3.4 | Release channels: weekly pre-release, monthly stable after 2 weeks | AEF | T-5041 |

## Phase 4 — open up (after the pilot holds)

PR 2 (#106) runs the whole circuit; then the CI re-verification check (28 October); then contributors beyond Mehdi.
Later, on its own merits: the organisation move (T-5030).
