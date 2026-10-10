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

## Second lens (operator, 2026-10-10): bleeding-edge releases, field telemetry, promotion per change

Five ideas the operator added:

- **We cut bleeding-edge *releases*, not just a branch tip.** A numbered pre-release (e.g. `v1.8.9-be.1`) is announced to field projects (peer agents and their frameworks), and they pull it in. Every report then names exactly what it ran.
- **Many changes fix issues the field reported.** For those, usage telemetry answers directly whether the fix worked. The symptom the field saw either stops recurring after the upgrade, or it doesn't. This is the strongest evidence available: the field defined the failure, and the field observes its absence.
- **Telemetry itself is either deterministic or stochastic.** A test run inside the vendored instance gives a hard positive or negative. Usage counts give rates.
- **What telemetry cannot measure, the field agent collects.** Each release carries an *evaluation brief*: instructions to the field agent saying what to run, what to read, and what to ask its user. The agent asks the user, collects the answers, and sends them back as part of the release evaluation.
- **Maturity is judged per change, and changes with positive field feedback go into a bucket to merge into master.**

### What this changes in the candidate shape

1. **Each fix carries its symptom signature.** A fix task records how the field saw the bug:
   - a ledger reason;
   - an error string;
   - an exit code;
   - a canary.

   The field report counts that signature before and after the upgrade. "0 recurrences in N days after, against M before" is a direct verdict on the fix.
2. **The release ships an evaluation brief.** It is generated from the per-task field checks. One part is machine work (probes, ledger counts); the other is questions for the user, which the field agent asks.
3. **Promotion per change is the hard part, technically.** Today master only fast-forwards from bleeding-edge. That is what guarantees the two can never diverge (§Release-Train). "Merge into master only the changes that earned it" breaks that guarantee unless it is done one of these ways:
   - **(a) Hold back by revert on a release branch.** Cut a release branch from the candidate, revert the changes that are not ready, and fast-forward master to it. Master stays linear, and bleeding-edge keeps everything. Cost: revert commits, and a later re-promotion has to revert the revert.
   - **(b) Cherry-pick the matured changes onto master.** This is the most literal reading of "a bucket", but it breaks the invariant. Commits for different tasks interleave, and one task's fix can silently depend on another's. It is the divergence the release train was built to prevent.
   - **(c) Feature switches.** Everything ships to master, and a change that has not matured stays switched off there until its evidence arrives. This only works for changes that can be switched. A fix to an existing bug usually cannot be (you want the fix, or the old bug).
   - **(d) The whole candidate is the unit.** It promotes when every change in it is mature, or is waived per change. Simplest, but one stuck change blocks the rest.

   Recommendation: **(d) with (a) as the escape hatch.** Normally the candidate promotes whole. When one or two changes are not ready, the release step reverts them on a release branch and says so in the release question. Per-change maturity is still the unit of judgement; the reverts are just how a "not yet" change stays out. Avoid (b).

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
- **2026-10-10, operator (second lens):** "We cut a Bleeding Edge release. We push it out to the field … projects pull it in. They have fixes for existing issues. We have telemetry based on usage, so we should get telemetry back whether the fix has worked … Some things cannot be measured through telemetry; then the project agent needs to ask the user and feed that back … telemetry can be stochastic and deterministic … you can run a test in a vendored instance, negative/positive … an instruction you can give an agent in the field to collect that data and send it back as part of release evaluation … assess the maturity of a Bleeding Edge release … changes that get positive feedback can be put in the bucket to merge into Master." This led to the second-lens section: bleeding-edge pre-releases, symptom signatures for fixes, the evaluation brief, and the per-change promotion options (a)–(d).
