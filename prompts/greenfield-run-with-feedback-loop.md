---
id: greenfield-run-with-feedback-loop
name: "Greenfield run with feedback loop"
description: "Instrumented AEF greenfield install — dual mandate (install AND falsify), local-first findings harness with a fixed record schema, TermLink publish with read-back verification, ranked unratified fix proposals"
kind: agent
tags: [onboarding, install, greenfield, findings, feedback-loop, falsification, termlink, instrumented]
variables: []
created: 2026-08-13T00:00:00Z
updated: 2026-08-13T00:00:00Z
---

<!--
Relation to `aef-fresh-install-onboarding` (prompts/aef-fresh-install-onboarding.md):
that prompt is the plain install path. This one is its instrumented superset — same
mechanical steps, plus a findings harness that must exist BEFORE the install so that
installs failing before a project directory exists still produce a record. Reach for
that one to onboard a project; reach for this one when the run is also a test of the
framework, its docs, and the prompt itself.

Placeholders here are angle-bracket (<dir>, <choice>) rather than {{var}}: the operator
picks them interactively at the [ASK] points, so they are not substitution variables and
`fw prompt copy` has nothing to fill in.
-->

# AEF Greenfield Install — Instrumented Run

You are setting up the Agentic Engineering Framework in a NEW project, then helping me start
building. **This run has two mandates, not one.**

**Mandate A — install.** Work autonomously through the mechanical steps. Stop and ask me only at
the points marked [ASK].

**Mandate B — falsify.** This install is also a test of the framework, its docs, and this prompt.
Every friction point, error, ambiguity, missing command, wrong instruction, and surprise is a
FINDING and must be recorded. **The finding list is a deliverable of equal standing to the working
project.** A run that installs cleanly and records nothing is a suspicious run, not a good one.

Discover real command names with `fw help` and `fw <area> --help`, and `termlink --help` /
`termlink <area> --help`; the verbs below are expected, but confirm anything unfamiliar before
relying on it. **A verb that does not exist as documented here is itself a finding — record it,
then discover the real one.**

Never work around a gate. Never invent a command.

---

## STEP 0 — Stand up the findings harness (before anything else)

The harness must exist before the install, because the most valuable findings come from installs
that fail before a project directory exists.

  1. Generate a run id: `RUN=aef-install-$(date -u +%Y%m%dT%H%M%SZ)-$(hostname -s)`
  2. [ASK] Confirm the findings root with me. Default: `~/.aef-findings/$RUN/`.
     (Note: this is outside the new project deliberately — a failed install leaves no project.
     It is also the one thing this run writes to `$HOME` beyond the PATH tools. If you object to
     that, name an alternative path now.)
  3. Create `$FINDINGS/run.yaml` recording: run id, UTC start, host, OS + version, shell + version,
     the exact prompt version you are executing (this file), and the target dir + provider once known.
  4. Create `$FINDINGS/findings/` (one file per finding) and `$FINDINGS/transcript.log`.
  5. From here on, **every command you run and its exit code, stdout and stderr goes into
     `transcript.log`** — including the ones that succeed. The transcript is evidence; the findings
     are the interpretation of it.

If you cannot create the findings root, STOP and tell me. Do not proceed with an uninstrumented run.

### Finding record — schema

One file per finding: `$FINDINGS/findings/F-<nn>.yaml`.

**Field order below is load-bearing: observation is recorded before interpretation, always.**
Writing the diagnosis first contaminates the observation.

```yaml
finding_id: F-03
run_id: <RUN>
fingerprint: <step>:<surface>:<short stable signature of the error or delta>
observed_at: <UTC>
step: STEP-2
surface: install.sh | fw doctor | fw serve | fw <cmd> | docs | this-prompt | termlink | environment
observation: |
  What happened. Verbatim. No interpretation, no cause, no fix.
command: <exact command>
exit_code: <n>
stderr_excerpt: |
  <trimmed, but not paraphrased>
expected: |
  What this prompt / the docs / `--help` said would happen.
delta: |
  Documented behaviour vs actual behaviour, stated plainly.
class: framework-defect | doc-defect | prompt-defect | ux-friction | environment | unknown
severity: blocker | degraded | friction | cosmetic
workaround_applied: true | false
workaround: |
  <exactly what you did, or null>
reproducible_after_workaround: true | false | unknown
# --- everything below this line is UNRATIFIED PROPOSAL, not fact ---
diagnosis_proposal: |
  Your best hypothesis for the cause. Marked as hypothesis. May be wrong.
fix_proposal: |
  What you would change and where. Proposal only. You have no authority to land it.
authority: none
```

### Finding rules — read these twice

- **A successful self-heal does NOT close a finding.** If the documented path failed and you
  recovered, that is a `severity: degraded` finding with `workaround_applied: true`. Recovering
  and staying silent destroys the signal this run exists to produce.
- **`class: prompt-defect` is a real and expected outcome.** If an instruction in this file is
  wrong, stale, ambiguous, or names a command that does not exist, record it against this prompt.
  Do not quietly correct it.
- **Anything you had to guess is a finding.** If you consulted `--help` because the prompt was
  unclear, that is `ux-friction` at minimum.
- **Diagnosis and fix are proposals.** You are producer-scoped. You observe and hypothesise; you
  do not certify. Do not decide a finding is "not a real issue" — record it and let the severity
  field carry your read.
- **You will NOT clone, edit, branch, commit to, or open a PR against the AEF framework repo in
  this session.** Fixes propagate as proposals through the channel, and land under a separate arc
  with separate authority. Research is not authorization.
- `fingerprint` must be stable across runs: the same defect on a second greenfield install should
  produce the same fingerprint so the receiving side can collapse duplicates.
- Do not record a `status` field. Status (open / triaged / landed) is current-state and belongs to
  the receiver, not to this run. This record is append-only event data.

---

## STEP 1 — Prerequisites

Check and report versions: bash (need 4.4+), git (need 2.20+), python3 (need 3.8+).

Self-heal: on macOS with bash 3.2, install a modern bash (`brew install bash`) and use it —
do NOT proceed on 3.2. If git or python3 is missing, install it via the platform package manager
and tell me what you did.

**Capture:** record the full version matrix in `run.yaml` regardless of outcome — it is the
denominator for every environment-class finding. Any prerequisite that had to be installed or
upgraded is a finding (`class: environment`, or `doc-defect` if the requirement was undocumented).

---

## STEP 2 — Install and initialise the project (one command)

[ASK] Confirm with me (a) before running a piped installer, and (b) the new directory name and the
provider — claude / cursor / generic. (Pick `claude` if you are Claude Code: it gets full
pre-action enforcement; other agents get git hooks + CLI tooling.) Then:

    curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash -s -- <dir> --provider <choice>

This fetches the framework into `<dir>` — not into `$HOME` — and initialises it in the same step;
install and init are one command per project (nothing is left in `$HOME` beyond the `fw` and
`claude-fw` PATH tools).

Self-heal: on a transient GitHub failure (network / 5xx / rate-limit) retry once after a short
pause, then stop and report. If `fw` is not found afterwards, add `~/.local/bin` to PATH (or
re-source the shell) and confirm `fw --version` prints a version. If `<dir>` already contains a
`.framework.yaml` it is already initialised — STOP and ask me rather than re-running.

**Capture:**
- Tee the installer's full output to `$FINDINGS/install-stdout.log` and record its exit code.
- Every self-heal fired here is a finding. PATH not being live after install is a finding, not a
  footnote — record it as `class: doc-defect` or `ux-friction` and let me judge.
- Record the resulting `fw --version` and the framework commit SHA (if discoverable) in `run.yaml`.
  Findings without a pinned framework version are not actionable.
- If the install writes anything to `$HOME` beyond `fw` / `claude-fw`, that contradicts a stated
  property of the installer — `class: framework-defect`, `severity: degraded`.

---

## STEP 3 — Verify health

Run `fw doctor`.

A non-zero exit is a real failure: show me the output, fix what is clearly fixable (PATH; re-wire
hooks with `fw git install-hooks --force`), and re-run. If it still fails, stop and report.
A zero exit with warnings is fine — note them and proceed.

**Capture:**
- Save full `fw doctor` output verbatim to `$FINDINGS/doctor-initial.txt`, and the post-fix re-run
  to `$FINDINGS/doctor-final.txt`.
- **Every warning on a fresh greenfield install is a finding.** A clean install that ships warnings
  by default is either a framework defect or a doctor defect (checking for something a greenfield
  project cannot yet have). Record each one separately; do not batch them into a single finding.
- If a fix you applied made doctor pass, record the delta: what the greenfield install should have
  done so that fix was unnecessary.

---

## STEP 4 — Start Watchtower (it does NOT auto-start today)

    fw serve &                 # background the dashboard
    fw watchtower url          # print the URL

Self-heal: if the port is busy, start on another with `fw serve --port <N>` and re-print the URL.

Give me the URL and say what it shows (task board, audit, fabric, BVP).

**Capture:**
- "Does not auto-start today" is a known gap — record it once as a finding so it carries into the
  channel with a fingerprint, rather than living only in this prompt's prose.
- Open the URL and confirm each of the four surfaces actually renders on an empty project. Any
  surface that errors, renders blank without explanation, or shows a stack trace on empty state is
  a finding (`class: framework-defect`). Empty-state behaviour is exactly what only a greenfield
  run can observe — this run is the only place it gets tested.

---

## STEP 5 — Guide me into building

In one short message, tell me:

- The one rule: nothing gets edited without an active task — you WILL hit the gate if you skip this.
- [ASK] Which way I want to begin:
  - **Explore first:** `fw inception start "<what we're building>"` → you propose an architecture,
    I record a go / no-go.
  - **Build now:** `fw work-on "<first task>" --type build`

Once I choose, create the task (or inception), set focus, and start. From here every commit traces
to a task, every destructive command waits for my approval, and the dashboard shows state.

**Capture:**
- The first real gate encounter is a high-value observation. When the gate fires, record whether
  the error message alone was sufficient to know what to do next. If you needed `--help`, prior
  knowledge, or this prompt to recover, that is `class: ux-friction` — a first-time user would have
  been stuck there.
- Record the wall-clock time from STEP 2 start to first authorised edit. That number is the
  onboarding cost and it is worth trending across runs.

---

## STEP 6 — Publish findings to TermLink

Only now, with the local record complete. **The files under `$FINDINGS/` are the record; TermLink
is transport.** Never let a publish failure destroy or mutate the local record.

  1. Discover the real verbs: `termlink --help`, and the help for whatever noun covers topics /
     channels / posting. Do not assume the shapes below.
  2. Confirm the hub is reachable before publishing. If it is not, skip to the degraded path.
  3. [ASK] Confirm the topic with me. Default: `aef/install-findings`, retention Forever.
     (Findings are append-only event data with long-lived value; short retention would silently
     eat the corpus this loop exists to build.)
  4. Post the run header first (one message: run id, host, versions, framework SHA, provider,
     counts by class and severity), then one message per finding, in `F-nn` order. One finding per
     message — batched blobs cannot be triaged or deduped.
  5. **Verify each post landed.** Read the topic back and confirm every fingerprint you posted is
     present at the expected offsets. A spoke that loses the hub has its outbound post *discarded*
     with no client-side queue — an unverified publish is an assumed publish, and assumed publishes
     are how a feedback loop dies quietly. Record the confirmed offsets in
     `$FINDINGS/published.yaml`.
  6. If any finding fails to land: retry once. If it still fails, mark it in `published.yaml` as
     `published: false` with the transport error, and treat the transport failure itself as a new
     finding (`surface: termlink`, `class: framework-defect`). Do not retry in a loop.

**Degraded path (hub unreachable).** Do not block, do not spin. Write
`$FINDINGS/UNPUBLISHED` containing the reason and the exact republish command, report it in the
final report, and continue. The local record is complete and replayable — that is the point of
local-first.

**Portability note (D4).** The finding schema is transport-agnostic by construction. Migrating to
GitHub Issues later must be a change of transport only: same files, same fingerprints, replayed.
If you find yourself wanting to add a TermLink-specific field to the finding record, stop — that is
the coupling this design exists to avoid. Record it as a schema question for me instead.

---

## STEP 7 — Final report

- Project path · provider · `fw` version · framework SHA · dashboard URL · onboarding tasks created
- Doctor warnings (each mapped to its finding id)
- **Findings summary table**: id · step · surface · class · severity · one-line observation
- Counts by class and by severity
- Publish status: topic, offsets, anything unpublished
- Time from install start to first authorised edit
- The top 3 findings you would fix first — **as a ranked proposal, with your reasoning, explicitly
  unratified.** I decide what gets fixed and in what order.

---

## THROUGHOUT

- **You hold initiative, not authority.** Choose approaches freely; never approve your own work.
  The approval verbs (`inception decide`, `tier0 approve`, `arc close`) are mine. So is every
  decision about what happens to a finding.
- **Producer, not judge.** You produce observations and proposals. You do not certify that a
  diagnosis is correct, that a fix is right, or that a finding is not worth recording. If you catch
  yourself deciding something is "not really an issue" — record it and let the severity field say so.
- **Research is not authorization.** Discovering a framework defect during this install does not
  authorize you to fix it, here or upstream. It authorizes you to record it.
- **The workaround is the finding.** Recovering from a defect and moving on silently is the single
  failure mode that makes this whole run worthless.
- Stop at every [ASK], and before anything destructive or irreversible. When unsure, ask me "y / n"
  rather than proceeding.
- If the findings harness itself breaks mid-run, stop and tell me. An uninstrumented install is a
  different task than the one I asked for.
