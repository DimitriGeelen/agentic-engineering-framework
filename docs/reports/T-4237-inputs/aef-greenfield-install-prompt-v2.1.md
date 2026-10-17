# AEF Greenfield Install — Instrumented Run (v2.1)

<!-- v2.1, 2026-10-17. Revised from v2 after three LIVE runs in /opt/0909-boot-into-timeshift-snapshots
     (dimitri-mint-dev T-121; runs aef-install-20261017T141820Z / T142628Z / T144241Z; 49 findings in run 3).
     Change per finding: docs/reports/T-121-greenfield-v2.1-changes-and-onboarding-evaluation.md.
     v2 (review-only, T-118) is superseded. -->

**Bad-news-first rule.** If something fails, record it and keep evaluating every later step that can still run.
A run that stops at the first failure tests one step; the rest of onboarding stays untested.

You are setting up the Agentic Engineering Framework (AEF) in a NEW project, then helping me start building.
**This run has two mandates, not one.**

**Mandate A — install.** Work through the mechanical steps on your own. Stop and ask me only at [ASK] points, and
before anything destructive or irreversible.

**Mandate B — falsify.** This install also tests the framework, its docs and this prompt. Every friction point,
error, ambiguity, missing command, wrong instruction and surprise is a FINDING and must be recorded. **The finding
list is a deliverable of equal standing to the working project.** A run that installs cleanly and records nothing is
a suspicious run, not a good one.

Discover real command names with `fw help`, `fw <area> --help`, `termlink --help`. The verbs below were checked
against fw v1.8.10. **A verb that does not exist as written here is itself a finding: record it, then discover the
real one.** Never invent a command.

**Gates vs self-heal.**
- A *gate* is framework enforcement: a hook that blocks, or a refusal that names a policy (P-002, G-020, T-559, …).
  Never work around a gate; satisfy it the way its message says, and record the encounter.
- A *self-heal* is fixing your environment (PATH, a missing package, a busy port). It is allowed where this prompt
  says so, and it is always a finding.

**Where you start:** the PARENT directory of the new project, in a fresh Claude Code session. You will restart once,
inside the project, at STEP 3b.

**Paths:** your shell state does not persist between commands. Always use absolute paths. After STEP 2 use
`FW=<dir>/.agentic-framework/bin/fw` (the vendored copy), not a bare `fw`.

**Clean environment.** If your session was started by, or inside, another AEF project (a `claude-fw` session, a
TermLink dispatch worker), it carries that project's `FRAMEWORK_ROOT`, `PROJECT_ROOT`, `_FW_PATHS_DERIVED_BY`,
`FW_ROUTED_FROM` (and possibly `TASKS_DIR`, `CONTEXT_DIR`). The installer inherits them and initialises the wrong
place (fw v1.8.10: `<dir>/lib/init.sh: No such file or directory`). Until AEF fixes this (AEF T-4248):
- record `env | grep -E '^(FRAMEWORK_ROOT|PROJECT_ROOT|TASKS_DIR|CONTEXT_DIR|_FW_PATHS_DERIVED_BY|FW_ROUTED_FROM)=' | cut -d= -f1`
  in `run.yaml`;
- prefix every install and `fw` command with
  `env -u FRAMEWORK_ROOT -u PROJECT_ROOT -u TASKS_DIR -u CONTEXT_DIR -u _FW_PATHS_DERIVED_BY -u FW_ROUTED_FROM`;
- note that this does NOT clean the environment your harness passes to hooks; only the STEP 3b restart does that.

**Headless / dispatched runs (no human to answer [ASK]).** The orchestrator must put the answers into the prompt.
- Peer-consult checks: only `fw sidecar inbox --peek`. Plain `fw sidecar inbox` marks messages read, and in a fresh
  project it resolves to the host-shared identity: one run marked 198 other projects' messages read (AEF T-4252).
  Before the install there is no `fw` at all; skip the check and record it.
- A dispatch wrapper may write its own result files into the target (e.g. `.context/dispatch-results/`). Treat them
  as harness files, record them, and install anyway.

---

## STEP 0 — Findings harness (before anything else)

The harness exists before the install, because the most valuable findings come from installs that fail before a
project directory exists.

1. `RUN=aef-install-$(date -u +%Y%m%dT%H%M%SZ)-$(hostname -s)`.
2. [ASK] Confirm the staging root. Default: `/tmp/aef-findings/$RUN/`.
   - Why `/tmp`: after install, the framework's project-boundary hook only lets you write inside the project,
     `/tmp`, and `~/.claude`.
   - The record moves into the project at STEP 3 and becomes permanent there.
   - If the install fails, the record stays in `/tmp`; tell me so I can copy it out.
3. Create `run.yaml`:
   - run id, UTC start, host, OS + version, shell + version;
   - this prompt's version line (top of file);
   - the path of your own session transcript, if your tool keeps one (Claude Code: `~/.claude/projects/…/<session>.jsonl`);
   - target dir and provider once known.
4. Create `findings/` (one file per finding) and `commands.log`.
5. From here on, log **every command** in `commands.log` as one line: `UTC · command · exit code · path of saved
   output (if any)`. Save full output to a file only when it fails, warns, or is evidence for a finding. Your
   session transcript holds the rest.
6. Write the record to disk after every step. A long run can be cut by the context-budget restart; the record on disk
   is how you resume.

If you cannot create the staging root, STOP and tell me. Do not run uninstrumented.

### Finding record — schema

One file per finding: `findings/F-<nn>.yaml`.
**Field order is load-bearing: observation before interpretation, always.**

```yaml
finding_id: F-03
run_id: <RUN>
fingerprint: <step>:<surface>:<signature>     # recipe below
observed_at: <UTC>
step: STEP-2
surface: install.sh | fw doctor | fw watchtower | fw <cmd> | gate:<policy-id> | docs | this-prompt | termlink | environment
observation: |
  What happened. Verbatim. No interpretation, no cause, no fix.
command: <exact command>
exit_code: <n>
stderr_excerpt: |
  <trimmed, not paraphrased>
expected: |
  What this prompt / the docs / --help said would happen.
delta: |
  Documented vs actual, stated plainly.
class: framework-defect | doc-defect | prompt-defect | ux-friction | environment | unknown
severity: blocker | degraded | friction | cosmetic
workaround_applied: true | false
workaround: |
  <exactly what you did, or null>
reproducible_after_workaround: true | false | unknown
# --- everything below this line is UNRATIFIED PROPOSAL, not fact ---
diagnosis_proposal: |
  Best hypothesis for the cause. A hypothesis; may be wrong.
fix_proposal: |
  What you would change and where. Proposal only.
authority: none
```

**Fingerprint recipe** (stable across runs, so duplicates collapse): take the first error line. Replace paths with
`<path>`, numbers, ids and timestamps with `<n>`, and the run id with `<run>`. Then
`<step>:<surface>:<first 8 hex of sha1(normalised line)>`. For findings without an error line, hash the one-line
`delta`.

### Finding rules — read these twice

- **A successful self-heal does NOT close a finding.** If the documented path failed and you recovered, that is
  `severity: degraded`, `workaround_applied: true`.
- **`class: prompt-defect` is a real and expected outcome.** Record it against this prompt; do not quietly correct it.
- **Anything you had to guess is a finding.** If you needed `--help` because this prompt was unclear: `ux-friction`.
- **Every gate encounter is a finding,** even when the gate was right. Record whether its message alone told you
  what to do next.
- **Diagnosis and fix are proposals.** You observe and hypothesise; you do not certify. Never decide a finding is
  "not a real issue"; let `severity` carry your read.
- **You will NOT clone, edit, branch, commit to, or open a PR against the AEF framework repo** in this session.
  Research is not authorization.
- No `status` field. This record is append-only event data; status belongs to the receiver.

---

## STEP 1 — Prerequisites

Check and record in `run.yaml`:
- bash ≥ 4.4, git ≥ 2.20, python3 ≥ 3.8 (the installer checks these too; record both views);
- `python3 -c "import yaml"` (PyYAML, required by most `fw` commands);
- `python3 -c "import flask"` (Watchtower, needed in STEP 4).

Self-heal, ask first:
- **macOS bash 3.2:** `brew install bash`. Then remember its path as `BASH4` (e.g. `/opt/homebrew/bin/bash`) and use
  it in STEP 2. A plain `| bash` may still resolve to `/bin/bash` 3.2.
- **Missing git / python3 / PyYAML / Flask stack:** [ASK] before installing. On Debian/Ubuntu/Mint, system-wide
  `pip install` is refused (PEP 668, "externally-managed-environment"). Propose the platform package manager
  (e.g. `apt install python3-yaml python3-flask`) or a venv, and tell me what you did.

**Capture:** any prerequisite that had to be installed is a finding (`environment`, or `doc-defect` if the
requirement was not documented). A missing Watchtower dependency that no installer or doc mentions is
`doc-defect` / `framework-defect` — record which.

---

## STEP 2 — Install and initialise the project (one command)

[ASK] Confirm with me:
- (a) running a piped installer;
- (b) the directory name;
- (c) the provider: claude / cursor / generic.

The installer's **default provider is `generic`**: if you omit `--provider claude`, a Claude Code project silently
gets no pre-action hooks. Pick `claude` if you are Claude Code.

Before the installer, three checks (each one a finding if it needs action):
1. **Own git repository.** `git -C <dir> rev-parse --show-toplevel`. If it prints anything other than `<dir>`, or
   fails, run `git init <dir>` first. The v1.8.10 installer does not create a repo when an enclosing one exists
   (e.g. a repo rooted at `/`): task ids then continue from that repo's `.tasks`, its hook is written outside the
   project, and the first commit fails (AEF T-4251).
2. **Back up the PATH tools.** Copy `~/.local/bin/fw` and `~/.local/bin/claude-fw` (if present) to
   `/tmp/aef-findings/$RUN/preinstall-backup/`. The installer replaces them without a warning; the new `claude-fw` is
   a router that starts each project's own copy.
3. **Clean environment.** See "Clean environment" above.

    curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh \
      | env -u FRAMEWORK_ROOT -u PROJECT_ROOT -u TASKS_DIR -u CONTEXT_DIR -u _FW_PATHS_DERIVED_BY -u FW_ROUTED_FROM \
        "${BASH4:-bash}" -s -- <dir> --provider <choice> 2>&1 | tee /tmp/aef-findings/$RUN/install-stdout.log

**Do not trust the installer's last line.** fw v1.8.10 prints "Installation complete!" and exits 0 even after
`[x] Step 1/3 .framework.yaml not found` (AEF T-4248). Check it yourself: `<dir>/.framework.yaml` and
`<dir>/.agentic-framework/bin/fw` exist, and every `[x]` line becomes a finding.

What the installer does:
- fetches the framework to a temporary dir;
- vendors it into `<dir>/.agentic-framework/` and initialises the project;
- puts only `fw` and `claude-fw` into `~/.local/bin`;
- also *reads* `/opt` to list other vendored projects (list only; `--no-scan` skips it).

Self-heal:
- **Transient GitHub failure** (network / 5xx / rate limit): retry once, then stop and report.
- **`~/.local/bin` not on PATH:** that is expected (the installer only edits shell rc with `MODIFY_PATH=true`). Use
  absolute paths; record the PATH state as a finding only if the installer output did not tell you.
- **`<dir>` already has `.framework.yaml`:** STOP and ask.
- **Deterministic install failure:** record it, then run every later step you still can (doctor on whatever exists,
  docs checks, publish). Never install from a local clone or a framework development repo as a "fix": only the
  published installer is the thing under test.

**Capture:**
- the installer exit code (`PIPESTATUS`);
- `$FW version` output in `run.yaml` (the vendored copy has no git SHA; record that as well);
- any write to `$HOME` beyond `.local/bin/{fw,claude-fw}`: `framework-defect`, `degraded`.

---

## STEP 3 — Verify health, then move the record into the project

1. `$FW doctor` → save verbatim to `doctor-initial.txt` with its exit code.
   - A non-zero exit: show me, fix what is clearly fixable (PATH; `$FW git install-hooks --force`), re-run, and save
     `doctor-final.txt`.
   - Still failing: stop and report.
   - **Every warning on a fresh install is its own finding.** A fresh install that warns is either a framework
     defect or a doctor defect (checking something a new project cannot have yet).
   - Expect many warnings on a fresh v1.8.10 install (run 3: 31, e.g. vector index not built, host-wide TermLink
     DM backlog, cron registry not generated). Record each anyway; the receiver deduplicates by fingerprint.
2. **Onboarding gate.** `fw init` seeds onboarding tasks T-001..T-007, and gate T-532 blocks every
   non-onboarding write until they are done or skipped. [ASK] Work through them, or skip?
   - **Skip path that works on v1.8.10:** `$FW work-on T-001` → `$FW onboarding skip` → then your own task.
   - The gate message advertises `fw onboarding skip` but blocks it when run directly (AEF finding F-28).
   - Record the encounter.
3. Create your run task. Agent-owned, because a human-owned task with no Human ACs cannot be closed:
   `cd <dir> && $FW work-on "Greenfield install + findings $RUN" --type test --owner agent`
   Replace its placeholder acceptance criteria with real ones before any other edit (gate G-020).
   (Note: `fw work-on --help` prints no help; it treats `--help` as a task name. Read `fw help` instead.)
4. Move the record: `<dir>/.context/install-findings/$RUN/` (copy, verify, then remove the `/tmp` copy). Commit it:
   `$FW git commit -m "T-XXX: install findings $RUN (steps 0-3)"`.

## STEP 3b — Restart inside the project (governance becomes active)

Claude Code reads CLAUDE.md and hook settings at session start. Until you restart in `<dir>`, this session is **not**
governed by the project you just installed.

- Write the resume point to `<dir>/.context/install-findings/$RUN/RESUME.md`: next step = STEP 4, run id, task id.
- Tell me: "Please restart me in `<dir>` with `claude-fw`, and paste: *resume the greenfield run from RESUME.md*."
- After the restart: re-read this prompt and RESUME.md and continue.
- **The restart must not inherit another project's environment.**
  - Start the new session from a plain shell in `<dir>`, not from inside another project's `claude-fw`.
  - In run 3, hooks loaded mid-session before the restart, and every gate crashed with `missing-hook` (fail-open,
    nothing blocked); the cause was the inherited `FRAMEWORK_ROOT`.
- **Prove governance is active.**
  - Run `$FW doctor` and compare its hook-crash count with the pre-restart value: it must not grow.
  - The first gate that fires after the restart must block, not log `missing-hook`.
  - A session where gates fail open is not a governed session. Record it and tell me.
- Record as findings: whether the restart was needed (did a gate fire before it?), and whether `fw init` or the
  installer told you to restart.

---

## STEP 4 — Start Watchtower (it does not auto-start)

[ASK] Bind address. Watchtower binds **all interfaces (0.0.0.0) by default and has no login**. Default for this run:
local only.

    FW_HOST=127.0.0.1 $FW watchtower start      # or without FW_HOST if I choose LAN
    $FW watchtower status ; $FW watchtower port

- **Port:** v1.8.10 picks a free port itself if 3000 is busy and writes it into a tracked config file; read it with
  `$FW watchtower port`.
- **URL:** under a local-only bind, `fw watchtower url` still prints the LAN address, which is unreachable. Use
  `http://127.0.0.1:<port>` (AEF finding F-36).
- **Exposure:** under the default bind (0.0.0.0, no login), the dashboard includes a browser **terminal** page,
  reachable from the LAN. Say this to me when asking the bind question.

Self-heal: port busy → `$FW watchtower start --port <N>`. Missing Flask → back to STEP 1 (finding).

Give me the URL. Open each page in the navigation (discover them; do not assume names) and say what it shows on an
empty project.

**Capture:**
- "Does not auto-start" once, as a finding with a fingerprint.
- **Empty-state behaviour:** any page that errors, renders blank without explanation, or shows a stack trace on an
  empty project is `framework-defect`. Only a greenfield run can see this.
- The default bind (0.0.0.0, no auth) as a finding if no install output warned about it.

---

## STEP 5 — Guide me into building

In one short message, tell me:
- **The one rule:** nothing gets edited without an active task, and a build task needs real acceptance criteria
  before its first edit. You will hit gates if you skip this.
- [ASK] Which way I want to begin:
  - **Explore first:**
    `$FW inception start "<what we build>" --recommendation GO|NO-GO|DEFER --rationale "<evidence>"`
    Both flags are required when an agent files under Claude Code. Then, in this order:
    - `$FW work-on T-XXX`: `inception start` sets focus but not `started-work`, and the task gate blocks the first
      edit without it;
    - add at least one open question `**IW-1: …**` to the task file (gate G-067);
    - create the research artifact `docs/reports/T-XXX-*.md` before researching (rule C-001).

    You propose an architecture; **I** record go / no-go (`fw inception decide` is mine).
  - **Build now:** `$FW work-on "<first task>" --type build`, then replace the placeholder ACs and add
    `## Verification` before editing.

Once I choose: create the task, set focus, start. From here:
- every commit traces to a task;
- **Tier-0 commands** (force push, hard reset, `rm -rf` of roots, DROP TABLE, …) wait for my approval;
- the dashboard shows state.

**Capture:**
- **First gate encounter:** was the message alone enough to know what to do? If you needed `--help`, prior
  knowledge or this prompt: `ux-friction` (a first-time user would be stuck).
- **Onboarding cost:** record three times from STEP 2 start:
  - the first edit;
  - the first edit made while gates were provably active;
  - the first gate-authorised edit to a project file.
  (Run 3: 3 min 41 s / ~14 min / ~19.5 min.)

---

## STEP 6 — Publish findings (TermLink, optional transport)

**The files are the record; transport is transport.** A publish failure must never destroy or change the local
record.

1. Is `termlink` installed, and is a hub configured? The AEF installer does not install it. If not: degraded path
   (below); record it as a finding only if the docs promised it.
2. Discover the real verbs (`termlink --help`, then the help for channels / topics / posting). Do not assume shapes.
3. [ASK] Confirm the hub and the channel. Default name: `aef-install-findings`, retention unlimited if the hub supports
   it (findings are long-lived event data).
4. Post a run header (run id, host, versions, provider, counts by class and severity), then one message per finding
   in `F-nn` order. Never batch.
5. **Verify each post landed:** read the channel back and confirm every fingerprint. Record the offsets in
   `published.yaml`.
6. A post that fails: retry once. Then mark it `published: false` with the error, record the transport failure as a
   new finding (`surface: termlink`), and move on. No retry loops.
7. **Deliver to the AEF framework agents.** On a host with an AEF session, also send one pickup with the findings
   table:
   `$FW pickup send --remote <hub> --session <aef-session-id> --type bug-report --summary … --detail …`
   - Always pass `--remote` and `--session`. Without them the envelope is silently kept in YOUR inbox (AEF T-4243).
   - Look up the session id with `termlink list` right before sending; session ids change after a restart.
   - Put the header counts in last, after the final finding, so they cover all findings.

**Degraded path:** write `UNPUBLISHED` with the reason and the exact republish command, report it, continue.

**Portability:** the schema is transport-agnostic. Moving to GitHub Issues (`fw upstream report`) must be a change of
transport only: same files, same fingerprints. Never add a transport-specific field to the record; raise it with me
as a schema question.

---

## STEP 7 — Final report and session close

Report:
- project path · provider · `fw` version · dashboard URL + bind · tasks created;
- doctor warnings, each mapped to its finding id;
- **findings table:** id · step · surface · class · severity · one-line observation;
- counts by class and by severity · publish status · onboarding cost (STEP 2 → first authorised edit);
- **top 3 to fix first:** a ranked proposal with reasoning, explicitly unratified. I decide.

Then close the session the framework's way: commit the final record, `$FW handover --commit`.

---

## THROUGHOUT

- **Initiative, not authority.** Choose approaches freely; never approve your own work. `inception decide`,
  `tier0 approve` and closing human-owned tasks are mine. So is every decision about a finding.
- **Producer, not judge.** If you catch yourself deciding something is "not really an issue", record it and let
  severity say so.
- **Research is not authorization.** A framework defect found here authorizes recording it, nothing more.
- **The workaround is the finding.** Recovering silently is the one failure mode that makes this run worthless.
- Stop at every [ASK] and before anything destructive. When unsure, ask "y / n".
- If the harness breaks mid-run, stop and tell me. An uninstrumented install is a different task.
