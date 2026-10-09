# T-4023: Field evidence before release

**Status:** inception (research artifact, C-001). Filed 2026-10-10.
**Origin:** Operator ruling T-4020: master receives only verified-working releases, and bleeding-edge runs on the Ring20 estate as the testbed.

## Problem

The rule says that before we cut a release into production, the field has to tell us whether the new features work, or what the problems are. Today the field speaks only in free-text upgrade reports. On 2026-10-10, ring20 and 055 each sent one, and both were useful. But they report what *broke* during the upgrade. They don't say whether each *new feature* did its job. Nobody asked them to look, and nobody told them what to look for.

So three things are missing:

1. **What to check:** a per-feature statement of how we would know the feature works.
2. **How it comes back:** a structured report, not prose we have to interpret.
3. **Where it counts:** in the release question, before the operator says yes.

## Three kinds of feature, three kinds of evidence

| Kind | Example from this release | Evidence | Who produces it |
|---|---|---|---|
| **Deterministic.** A check proves it either way. | T-4005: budget gate blocks with python3 dead. T-4013: `exception-check` exit codes. | A *field probe*: a command shipped with the release that the testbed runs in its own project. It exits 0 or not and prints why. | The testbed agent runs it, and it runs automatically after an upgrade. |
| **Observed in use.** It only shows up when real work happens, at a rate nobody controls. | T-4003: peer mail typed into the pane (depends on mail arriving while the agent sits at a prompt). Reviewer seats starting in a consumer. | A *ledger count* over a soak window. Example: of N real deliveries, how many were typed in, how many waited, and why. It needs a minimum N, or the answer is "not exercised". | Read from the testbed's own ledgers (sidecar, verdicts, dispatches). No one has to remember anything. |
| **Judged.** Is it good, does it help, is it clear? | T-4021 (a renamed /resume): does the new name confuse anyone? The arc-001 retrieval quality. | A *question* with a scale and a free-text "what went wrong". | The testbed agent answers with its evidence, and the testbed's operator confirms where the feature is human-facing. |

A fourth state matters as much as the three verdicts: **not exercised.** A feature nobody in the testbed used is not green. For example, T-4013's exception path only matters to dimitri-mint-dev, who is not in the Ring20 estate. Treating silence as success is the false green this framework keeps paying for.

## Candidate shape (one pipeline, three slices)

1. **Declare at build time.** A task that ships a user-visible change carries a `field_check:` block in its frontmatter. It has three fields:
   - `kind:` deterministic | observed | judged;
   - the probe command, the ledger query, or the question;
   - the minimum evidence, e.g. `min_projects: 2`, `min_events: 5`, `soak_days: 2`.

   The close gate reminds the author when the block is missing and the change touches a consumer-facing surface. Kept out of scope: internal-only tasks.
2. **Release candidate.** `fw release candidate` lists every task closed since the last release together with its field check, pins the bleeding-edge commit, and announces it to the testbed peers. The announcement says: upgrade to commit X, then run `fw field report` after N days.
3. **Field report.** `fw field report <rc>`, run in each testbed project, does three things:
   - runs the deterministic probes;
   - reads its own ledgers for the observed checks;
   - asks the judged questions.

   It sends one structured JSON report back over the sidecar. AEF stores it under `.context/field/<rc>/<project>.json`. Peer data stays untrusted: it is evidence for the operator, not authority.
4. **Release question.** The question shows a field table for every feature: green / red / not exercised / waiting, with the projects and counts behind each verdict. Then: "Release vX.Y.Z to master now? yes/no."

   A red or not-exercised feature can still ship. But the operator says so knowingly, per feature, and that is recorded.

## Open questions for the operator

1. **Testbed members.** Which projects make up the Ring20 estate testbed: ring20-manager, ring20-dashboard, proxmox-ring20-management? Do 055 and 832 count? dimitri-mint-dev is the only consumer that exercises the vendored-exception path.
2. **Judged checks.** Who answers them: the testbed agent alone, or its operator (you) for human-facing features?
3. **Gate strength.** Should a red or not-exercised feature **block** the release unless waived, or only be **shown** in the release question?
4. **Soak period.** Is there a minimum time on the testbed before a release, e.g. 2 days, or does it end as soon as every feature has its evidence?

## Risks

- **Field-reported success can be optimistic.** A peer agent saying "works" is a claim. Deterministic probes and ledger counts carry more weight than a judged answer, and the table says which kind each verdict came from.
- **Release slows down.** The answer is a soak period that ends early when evidence is complete, plus per-feature waivers.
- **Testbed drift.** A testbed on a different commit reports on the wrong code. The report carries the commit it ran, and only reports matching the candidate count.

## Dialogue Log

- **2026-10-10, operator (on not cutting v1.8.9):** "We can deploy Bleeding Edge in our Ring20 [estate]. Keep the sustaining rule that we deploy Bleeding Edge in the [estate] and only deploy stable versions with verified working fixes into production, into master." Recorded as T-4020.
- **2026-10-10, operator (restating):** "Before cutting a release into production we should have from the field feedback that it's working … that the new features are working or that there are problems … our testbed currently is our Ring20 estate. They can run bleeding edge. So we need to think about how we get their information on new features and the functionality of the new features, and it's working well or not and it's good or not. Maybe some are deterministic, some are stochastic or some need to [be judged by how they] operate." This gave the three kinds above.
