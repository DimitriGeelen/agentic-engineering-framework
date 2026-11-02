# T-5006: Outside contributions through GitHub pull requests

Inception research artefact. Arc: `github-contributions` (draft). Status: exploration.

## How this inception runs: the design role chain

**Corrected 2026-11-02.** The operator asked for the long-form inception: ring20-manager's **design role chain** (their T-2222, v0.3), which AEF used for T-4017 (arc-001) and T-4123. The work passes from one role to the next; each role has a card, produces one document, and hands back to the operator with the decisions needed before the next step.

Chain (from T-4123 §1): **1 requirements collector** → threat modeler → security floor and phasing → architect → evidence → pseudo-code → external panel → planner. The interactive steps run in this session with the operator.

Cards held locally: `_common` and `requirements-collector` only (`docs/reports/T-4123-inputs/02b-ring20-manager-role-cards.txt`, 2026-10-12). The rest, and T-2222 itself, were requested from ring20-manager on 2026-11-02 (sidecar conversation `inception-role-chain`). Embedding the chain as AEF's standard workflow is T-3935 (captured, deferred since 2026-10-08).

**Step 1 starts now:** requirements collector, interview mode, for T-5006 and T-5007 together (one arc). Stakeholders: the operator, Mehdi (outside contributor), the peer projects (senders of requests). The answers already given in T-5007's Dialogue Log are carried in as the first answers. The two review seats dispatched on T-5007 before this correction ran ahead of the chain (an external panel belongs near the end); their findings are kept as input to step 1, not as the panel.

## Proposal as received (2026-11-02, verbatim)

> Hi Dimitri,
> As promised, here is a proposal for how outside contributions could work. It is meant to be light: you stay the
> only one who merges, and nothing here needs a new tool.
>
> What I checked first (bleeding-edge 02586a1):
> - CONTRIBUTING.md says "branch from main" and "open a PR against main", but there is no main branch. Your own
>   PRs (#76 to #84) all target bleeding-edge.
> - .github/workflows/test.yml runs only on push and pull_request to [main, master], so a PR to bleeding-edge
>   runs no tests at all.
> - There is no pull request template.
> - The commit-msg hook requires a T-XXX that exists in .tasks/. An outside contributor has no task in your
>   registry.
>
> Proposal:
> 1. Branches. Fork, branch from bleeding-edge, open the PR against bleeding-edge. Branch name:
>    fix/<issue>-<keyword> or feat/<issue>-<keyword> (e.g. fix/106-upgrade-preview). master keeps receiving
>    fast-forwards at release time, as today.
> 2. One PR, one issue. Every PR links its issue ("Fixes #106"). No PR without an issue, except documentation.
>    The approach is agreed in the issue before the code is written, the way your intake already comments.
> 3. Task reference in commits. Your intake already creates a task per issue (#104 became T-4935). Simplest
>    option: the contributor uses that task id plus the issue number, "T-4935 (#104): ...". The hook stays as it
>    is; you only need to have the task file on bleeding-edge before the PR. If you prefer another way (issue
>    number alone, or a task created in the fork), tell me and I will follow it.
> 4. Pull request template (.github/pull_request_template.md), short:
>    - Issue and task
>    - Approach, and the class of defect it closes (not only the instance)
>    - Evidence: the commands run and their output
>    - Tests: a test that fails before the change and passes after; fw audit; the tests touched
>    - fw doctor: green, or the list of components absent by choice (#98)
>    - What was not tested
> 5. CI. Add bleeding-edge to the branches in test.yml, so every PR is tested before you look at it. For a
>    first-time contributor GitHub may ask you to approve the run: one click.
> 6. Review. You approve and merge; your agents run the change through the usual loop before the release. When
>    you refuse something, a one-line reason in the PR is enough.
> 7. History. Protecting bleeding-edge against force-push (branch protection, "allow force pushes" off) would
>    avoid what happened to #76, #77 and #79 (PR #80). Only if it fits your workflow.
> 8. Licence. Contributions under Apache-2.0, same as the project (section 5 of the licence); no CLA unless you
>    want one.
>
> How I would start:
> - PR 1, no code: CONTRIBUTING.md updated with the points above, the PR template, and bleeding-edge added to
>   test.yml.
> - PR 2, a small fix from one of my open issues, to run the whole circuit once (for example #106, the empty
>   fw upgrade preview), after checking it on the latest pre-release.
> - Later, the CI check we talked about on 28/10 (re-verify task, ACs, human ticks and Verification on every
>   PR), once the circuit works.
>
> Does this fit how you want to work? Anything you would change before I open PR 1?
> Mehdi

## Claims checked (2026-11-02)

| Claim | Holds? | Evidence |
|---|---|---|
| CONTRIBUTING says branch from / PR against `main`; no `main` exists | Yes | `CONTRIBUTING.md:79`, `:87`; remotes carry only `master` and `bleeding-edge` |
| Our PRs #76 to #84 target `bleeding-edge` | Yes | `gh pr list`: #76, #77, #79, #80, #81, #84 all base `bleeding-edge` |
| `test.yml` ignores PRs to `bleeding-edge` | Yes | `.github/workflows/test.yml:3-7`: `branches: [main, master]` |
| No PR template | Yes | `.github/` holds only `ISSUE_TEMPLATE/` and `workflows/` |
| Commit hook needs an existing T-XXX | Yes | the commit-msg hook (P-002) |

## What the proposal does not cover

**GitHub is not the source repo.** `origin` is OneDev; GitHub is a mirror that OneDev pushes to (and `fw mirror sync` fast-forwards). A merge done on GitHub exists only on the mirror until someone brings it back. PRs #76, #77 and #79 were merged on GitHub and then lost when the mirror's history was rewritten from OneDev; PR #80 re-landed them. Branch protection on GitHub (point 7) would stop the force push, but would then also stop the mirror from updating. This is IW-1 and IW-5, and it has to be settled first: every other point assumes a merge on GitHub sticks.

## Findings per open question

(filled as the exploration runs)

## Dialogue Log

### 2026-11-02 — operator opens the inception
- The operator asked for this proposal to become an arc with several tasks, run as a full inception with the usual roles.
- In the same message the operator raised a second, related question: moving cross-project pickup requests from the sidecar to GitHub. That is a separate question, so it gets its own inception in the same arc.
