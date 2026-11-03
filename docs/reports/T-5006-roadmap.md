# Roadmap: outside contributions and GitHub as the place we work (arc github-contributions)

Operator, 2026-11-03: "focus on getting him set up so he can start working", "all the agents start tracking our
issues and changes in GitHub", "we switch our remote", "we need a road plan; that should be the focus".

The order follows one rule: nothing merged on GitHub may be lost, so the remote switch comes before any merge of
code. The role chain (T-5021..T-5028) keeps running for the hard parts of phase 2.

**Status as of 2026-11-03.** Target dates are estimates; a date moves when a dependency moves, and the reason is
written next to it.

| Phase | Status | Target |
|---|---|---|
| 0 Mehdi can start | Nearly done: branch rules outstanding | 2026-11-04 |
| 1 GitHub becomes the source | Switched; release proof and audit alarm outstanding | 2026-11-06 |
| 2 All agents track issues in GitHub | Waiting: step-1 sign-off, then role-chain steps 2-8 | 2026-11-27 |
| 3 Quality floor for code PRs | Partly started (T-5008 shipped in part) | 2026-11-14 |
| 4 Open up | After the pilot holds | December 2026 |

## Phase 0 — Mehdi can start

| # | Step | Who | Task | Status | Target |
|---|---|---|---|---|---|
| 0.1 | Send Mehdi the draft plan | Operator | — | Done 2026-11-03 | — |
| 0.2 | GitHub's Test workflow green; runs for PRs to `bleeding-edge` | AEF | T-5045 | Done 2026-11-03 (run 41625817184) | — |
| 0.3 | Nothing merged on GitHub can be lost | AEF | T-5044 | Done 2026-11-03 (by the switch, phase 1) | — |
| 0.4 | Contributor documents (CONTRIBUTING, PR template, SECURITY) | AEF | T-5047 | Done 2026-11-03 | — |
| 0.5 | Pinned tracking issue for Mehdi | AEF | #114 | Done 2026-11-03 | — |
| 0.6 | Mehdi reviews the documents; comments in #114 or a PR | Mehdi | — | Waiting for Mehdi | 2026-11-07 |

## Phase 1 — GitHub becomes the source

| # | Step | Who | Task | Status | Target |
|---|---|---|---|---|---|
| 1.1 | `origin` = GitHub, OneDev a mirror; OneDev's force-push job off | AEF | T-5044 | Done 2026-11-03 | — |
| 1.2 | Branch rules on GitHub: no force push or deletion on `bleeding-edge` and `master` | Operator | T-5044 | Open | 2026-11-04 |
| 1.3 | Release train, mirror and `fw issues` follow the new origin | AEF | T-5044 | Done 2026-11-03: `v1.8.16-be.28` on GitHub and OneDev, same commit | — |
| 1.4 | Audit alarm for outside commits that did not arrive through an operator-merged PR | AEF | T-5049 | Done 2026-11-03 (fw audit, fw doctor, operator pending; author-based, forgery residual noted) | 2026-11-06 |

## Phase 2 — all agents track issues and changes in GitHub

| # | Step | Who | Task | Status | Target |
|---|---|---|---|---|---|
| 2.0 | Design through the role chain: step 1 sign-off, then steps 2-8, then the go/no-go | Operator + AEF | T-5021..T-5028, T-5006 | Step 1 awaiting sign-off | 2026-11-13 |
| 2.1 | Relay: peers send bugs and requests to AEF, AEF files them on GitHub, cleaned | AEF | T-5007 | Waiting on 2.0 | 2026-11-20 |
| 2.2 | Secondary account (not a collaborator), one classic token per trusted peer | Operator + AEF | new | Waiting on 2.0 | 2026-11-20 |
| 2.3 | Fixed-form direct verdicts, after-posting scan, sidecar confirmation | AEF | new | Waiting on 2.0 | 2026-11-24 |
| 2.4 | Duplicate linking, reopen on FAILS, ask the source to check | AEF | new | Waiting on 2.0 | 2026-11-27 |
| 2.5 | `fw pickup send` for bugs and features routes to the new path | AEF | new | Waiting on 2.0 | 2026-11-27 |

## Phase 3 — quality floor for code PRs

| # | Step | Who | Task | Status | Target |
|---|---|---|---|---|---|
| 3.1 | Own isolated test hosts for deeper tests (code PRs wait for this) | AEF + operator | T-5009 | Not started; next after phase 1 | 2026-11-13 |
| 3.2 | Third review vendor seat, so high-risk PRs can be reviewed | AEF | T-4997 | Open | 2026-11-14 |
| 3.3 | Seats run as a dedicated unprivileged user | AEF + operator | T-5008 | Process isolation shipped (be.26); seat user open | 2026-11-12 |
| 3.4 | Release channels: weekly pre-release, monthly stable after 2 weeks | AEF | T-5041 | Model decided 2026-11-02 | first pre-release 2026-11-10; first stable 2026-12-01 |

## Phase 4 — open up

| # | Step | Who | Task | Status | Target |
|---|---|---|---|---|---|
| 4.1 | PR 2 (#106) runs the whole circuit | Mehdi + AEF + operator | — | Waits for 3.1 | 2026-11-17 |
| 4.2 | CI re-verification check (task, criteria, ticks, Verification) on every PR | AEF | new | After 4.1 | 2026-12-01 |
| 4.3 | Contributors beyond Mehdi | Operator | — | After the pilot holds | December 2026 |
| 4.4 | Organisation move, on its own merits | Operator | T-5030 | Deferred | — |
