![agentic-engineering-framework](header.svg)
> A governance and continuity harness around AI coding agents. Tasks, memory,
> blast-radius foresight, value scoring, audit, and cross-agent coordination —
> wrapped around any CLI agent you already use. Coordinates, does not execute.

**▶ New here? Watch the instruction / explainer video first:** https://youtu.be/qyjFjMHLWxM

## Garbage in, garbage out?

It is true — for many input/output processes, in biological life and in
computer systems alike. And when working with LLMs: the better the prompt,
the better the context, the better the focus. The better the contextual
awareness, the better the outputs an LLM generates. Governing that practice
is what I have come to call **agentic engineering** — something I have been
doing over the last year.

Agentic engineering is about good guidance. This framework is an attempt to
provide it: to give capable agents the direction, context, and constraints
they need to do good work — automated as far as it can be, with the human
kept in the loop wherever judgment or risk demands it.

Agents here are coached — and where it matters, forced — to come back for
human feedback. Sometimes that is a matter of taste: *"Operator, do you like
how this looks?"* Sometimes it is a matter of consequence: *"Operator, I am
about to blow up the earth — y / n?"* The framework's job is to know which
moment is which, and to make sure the second kind never happens silently.

## One principle, two mechanisms

The core mechanics rest on one principle and two mechanisms.

**The principle is traceability: nothing gets done without a task.** Everything
that happens is captured — every conversation, every thought, every variant
raised and discarded, every reason behind a decision and the way it was
carried out, every document, task, and artefact. In my experience this is the
thing that matters most, and the thing most systems lose. The record of all
of it is the **Context Fabric**.

**The second mechanism is the Component Fabric — the map of how the pieces
relate.** A real service is never one piece of code working alone; it is a
moving, dynamic system. Touch one part and there is impact upstream and
downstream. The Component Fabric makes that blast radius visible before the
change, not after.

The principle is not new. In 25 years of enterprise IT governance —
transition management at Shell, operational readiness for infrastructure
programmes — the same structural requirements appear every time a powerful
actor operates in a shared environment: clear direction, awareness of
context, awareness of resource constraints, awareness of impact, capable
engaged actors. The domain changed from human operators to AI coding agents.
The principle did not.

## Get started — hand a prompt to your coding agent

Three entry paths. Paste the matching block into your coding agent (Claude
Code, Cursor, Aider, or any agent with shell access). Each is self-contained.

- **A — Greenfield:** you want to build something new. The agent installs and
  initialises the framework in a new directory, then guides you into starting
  an app.
- **A+ — Greenfield, instrumented run:** path A, plus a findings harness. Every
  friction point, error and wrong instruction becomes a structured finding, so
  the install also tests the framework. Revised from four live runs, three of
  them in throwaway containers.
- **B — Existing codebase:** you want to govern code you already have. The
  agent installs and initialises in place, ingests the codebase into the
  Component Fabric, audits and heals to a clean baseline, then guides you into
  a new feature.

Both encode the same discipline: the agent does the mechanical work
autonomously, but stops at the `[ASK]` points (the human-in-the-loop moments
— "do you like this?" / "are you sure?"), self-heals per step, and never
works around a gate or invents a command.

<details>
<summary><b>A — Greenfield: install AEF and start a new app</b></summary>

```
You are setting up the Agentic Engineering Framework in a NEW project, then helping me start
building. Work autonomously through the mechanical steps. Stop and ask me only at the points
marked [ASK]. If a step fails, try the self-heal in that step before stopping; if you cannot
recover, stop and show me the exact error and the command that produced it — never work around
a gate or invent a command. Discover real command names with `fw help` and `fw <area> --help`;
the verbs below are expected, but confirm anything unfamiliar before relying on it.

STEP 1 — Prerequisites
  Check and report versions: bash (need 4.4+), git (need 2.20+), python3 (need 3.8+).
  Self-heal: on macOS with bash 3.2, install a modern bash (`brew install bash`) and use it —
  do NOT proceed on 3.2. If git or python3 is missing, install it via the platform package
  manager and tell me what you did.

STEP 2 — Install and initialise the project (one command)
  [ASK] Confirm with me (a) before running a piped installer, and (b) the new directory name and
  the provider — claude / cursor / generic. (Pick `claude` if you are Claude Code: it gets full
  pre-action enforcement; other agents get git hooks + CLI tooling.)
  Before the installer: if `git -C <dir> rev-parse --show-toplevel` prints anything other than
  <dir> (or fails), run `git init <dir>` first, so the project gets its own repository and not an
  enclosing one. Then:
    curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash -s -- <dir> --provider <choice>
  Do not trust the installer's last line: confirm <dir>/.framework.yaml and
  <dir>/.agentic-framework/bin/fw exist, and show me every `[x]` line it printed.
  This fetches the framework into <dir> — not into $HOME — and initialises it in the same step;
  install and init are one command per project (nothing is left in $HOME beyond the `fw` and
  `claude-fw` PATH tools). Self-heal: on a transient GitHub failure (network / 5xx / rate-limit)
  retry once after a short pause, then stop and report. If `fw` is not found afterwards, add
  ~/.local/bin to PATH (or re-source the shell) and confirm `fw --version` prints a version. If
  <dir> already contains a .framework.yaml it is already initialised — STOP and ask me rather
  than re-running.

STEP 3 — Verify health
  Run `fw doctor`. A non-zero exit is a real failure: show me the output, fix what is clearly
  fixable (PATH; re-wire hooks with `fw git install-hooks --force`), and re-run. If it still
  fails, stop and report. A zero exit with warnings is fine — note them and proceed.

STEP 4 — Start Watchtower (it does NOT auto-start today)
    fw serve &                 # background the dashboard
    fw watchtower url          # print the URL
  Self-heal: if the port is busy, start on another with `fw serve --port <N>` and re-print the
  URL. Give me the URL and say what it shows (task board, audit, fabric, BVP).

STEP 5 — Guide me into building
  In one short message, tell me:
   - The one rule: nothing gets edited without an active task — you WILL hit the gate if you
     skip this.
   - [ASK] Which way I want to begin:
       • Explore first:  fw inception start "<what we're building>"  → you propose an
         architecture, I record a go / no-go.
       • Build now:      fw work-on "<first task>" --type build
  Once I choose, create the task (or inception), set focus, and start. From here every commit
  traces to a task, every destructive command waits for my approval, and the dashboard shows
  state.

THROUGHOUT
  - You hold initiative, not authority. Choose approaches freely; never approve your own work.
    The approval verbs (inception decide, tier0 approve, arc close) are mine.
  - Stop at every [ASK], and before anything destructive or irreversible. When unsure, ask me
    "y / n" rather than proceeding.
  - Final report: project path · provider · fw version · dashboard URL · onboarding tasks
    created · any doctor warnings.
```

</details>

<details>
<summary><b>A+ — Greenfield, instrumented run (v2.2.1): install AEF and record every finding</b></summary>

Use this when you want the install to double as a test of the framework, its docs and the prompt itself.
The agent keeps a findings record (one YAML file per finding, observation before interpretation) and
can publish it over TermLink. v2.2.1 is for fw v1.8.11: it was revised from a workstation run and three runs in
throwaway containers, and drops the v2.1 workarounds that v1.8.11 makes unnecessary. On v1.8.10, use v2.1
(docs/reports/T-4237-inputs/aef-greenfield-install-prompt-v2.1.md).

````markdown
# AEF Greenfield Install — Instrumented Run (v2.2.1)

<!-- v2.2.1, 2026-10-18: v2.2 aligned with the final v1.8.11 behaviour after AEF's review (T-2746, T-4298, T-4308/T-4312,
     T-4304, T-4307). v2.2, 2026-10-18. For AEF v1.8.11. Revised from v2.1 after run 4 on a workstation (dimitri-mint-dev T-125,
     46 findings) and three runs in throwaway containers (T-126 / T-127: 19, 26 and 32 findings).
     Change list: docs/reports/T-129-greenfield-v2.2-changes.md. On fw v1.8.10 use v2.1: its workarounds are still
     needed there. -->

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
against fw v1.8.11. **A verb that does not exist as written here is itself a finding: record it, then discover the
real one.** Never invent a command.

**Gates vs self-heal.**
- A *gate* is framework enforcement: a hook that blocks, or a refusal that names a policy (P-002, G-020, T-559, …).
  Never work around a gate; satisfy it the way its message says, and record the encounter.
- A *self-heal* is fixing your environment (PATH, a missing package, a busy port). It is allowed where this prompt
  says so, and it is always a finding.

**Where to run.** A greenfield claim needs a clean machine. Prefer a throwaway container or VM (for example the
`greenfield-testbed` runner). On a working machine:
- other projects, leaked environment variables and shared TermLink state show up as findings the install did not
  cause (run 4: 31 doctor warnings on a workstation against 6-8 in a clean container);
- the install changes that machine: `~/.local/bin/{fw,claude-fw}` and possibly the firewall (STEP 4).

Record which kind of machine this is in `run.yaml`.

**Where you start:** the PARENT directory of the new project, in a fresh Claude Code session. You will restart once,
inside the project, at STEP 3b.

**Paths and working directory — read twice.**
- Your shell state does not persist between commands; use absolute paths.
- **Run every `fw` command as `cd <dir> && .agentic-framework/bin/fw …`.** Never call fw by path from another
  directory.
  - Before v1.8.11, fw silently initialised a new AEF project in a non-project directory. Run 4: a read-only
    `fw sidecar inbox --peek` vendored 44 MB there and its hooks then blocked the real install.
  - v1.8.11 no longer does: without a terminal it exits 1 with `not in an AEF project: <dir>; run fw init ...`
    (AEF T-2746). A silent init is a `framework-defect`.
- **Never `cd` into another AEF project**, including an unpacked copy or test record. The hooks then treat it as your
  project, and you cannot `cd` back (AEF T-4317). If it happens, stop and ask me to type `! cd <dir>`.

**Inherited environment.** A session started by, or inside, another AEF project (a `claude-fw` session, a TermLink
dispatch worker) carries that project's `FRAMEWORK_ROOT`, `PROJECT_ROOT`, `_FW_PATHS_DERIVED_BY`, `FW_ROUTED_FROM`
(and possibly `TASKS_DIR`, `CONTEXT_DIR`).
- v1.8.11 ignores them (AEF T-4248); no `env -u` wrapper is needed any more.
- Still record which are set, in `run.yaml`:
  `env | grep -E '^(FRAMEWORK_ROOT|PROJECT_ROOT|TASKS_DIR|CONTEXT_DIR|_FW_PATHS_DERIVED_BY|FW_ROUTED_FROM)=' | cut -d= -f1`
- Expect exactly one installer line `Ignoring inherited environment for fw init (set in this shell): <VARS>`
  (AEF T-4298). The vendored fw warns about a stale FRAMEWORK_ROOT at most once per shell, never on hooks. No such
  line, or repeated warnings, is a finding.

**Headless / dispatched runs (no human to answer [ASK]).**
- The orchestrator must put the answers into the prompt.
- Peer-consult checks: plain `fw sidecar inbox` is safe in a fresh project on v1.8.11: summaries only, no cursor moved
  (AEF T-4252). Prefer `--peek` for routine checks anyway.
- Without TermLink, `fw sidecar inbox` prints `NOT CHECKED: termlink is not installed; the inbox cannot be read` and
  exits 3, also when a hub id is cached (AEF T-4308, T-4312). A traceback, or "no pending consults" with exit 0, is a
  finding.
- A dispatch wrapper may write its own result files into the directory it starts in. Start the run from the parent,
  not from the target.

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
   - run id, UTC start, host, OS + version, shell + version, machine kind (throwaway container/VM, or working machine);
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
fingerprint: <step>:<surface>:<8 hex>         # COMPUTED by the recipe below, never invented
fingerprint_source: |
  <the exact line the fingerprint was computed from: the first error line, else the one-line delta>
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

**Fingerprint recipe — compute it, do not write it by hand.** Fingerprints let the receiver match the same defect
across runs. Two runs of the same build (2026-10-18) matched almost nothing, because agents wrote descriptive slugs
instead of hashes.
- Take `fingerprint_source`: the first error line; for findings without an error line, the one-line `delta`.
- Normalise it: paths → `<path>`, numbers, ids and timestamps → `<n>`, the run id → `<run>`.
- The fingerprint is `<step>:<surface>:` plus the first 8 hex of the sha1 of the normalised line. Compute it with a
  command, for example:
  `printf '%s' "$NORMALISED" | sha1sum | cut -c1-8`
- `surface` uses exactly the values listed in the schema. No new spellings (`fw watchtower`, not `fw-watchtower`).

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
- **Never print or record credentials:** no `env`/`printenv` dumps, nothing from `~/.claude`.

---

## STEP 1 — Prerequisites

Check and record in `run.yaml`:
- bash ≥ 4.4, git ≥ 2.20, python3 ≥ 3.8 (the installer checks these too; record both views);
- `python3 -c "import yaml"` (PyYAML, required by most `fw` commands);
- `python3 -c "import flask, flask_socketio, markdown2"` (Watchtower, needed in STEP 4). On a clean machine
  `markdown2` and `flask_socketio` are missing and nothing installs them (AEF T-4304); record it here, not first in
  STEP 4. (v1.8.11's `watchtower start` then refuses with one line naming the missing modules and the apt command.)

Self-heal, ask first:
- **macOS bash 3.2:** `brew install bash`. Then remember its path as `BASH4` (e.g. `/opt/homebrew/bin/bash`) and use
  it in STEP 2. A plain `| bash` may still resolve to `/bin/bash` 3.2.
- **Missing git / python3 / PyYAML / Watchtower stack:** [ASK] before installing.
  - On Debian/Ubuntu/Mint, system-wide `pip install` is refused (PEP 668, "externally-managed-environment"), and
    stock python3 has no pip or venv.
  - Propose the platform packages, e.g.
    `apt install python3-yaml python3-flask python3-flask-socketio python3-markdown2`, and tell me what you did.

**Capture:** any prerequisite that had to be installed is a finding (`environment`, or `doc-defect` if the
requirement was not documented). A missing Watchtower dependency that no installer or doc mentions is
`doc-defect` / `framework-defect` — record which.

---

## STEP 2 — Install and initialise the project (one command)

[ASK] Confirm with me:
- (a) running a piped installer;
- (b) the directory name (it may not exist yet: the installer creates it);
- (c) the provider: claude / cursor / generic.

The installer's **default provider is `generic`**: if you omit `--provider claude`, a Claude Code project silently
gets no pre-action hooks. Pick `claude` if you are Claude Code.

Before the installer, record (no action needed on v1.8.11; each surprise is a finding):
1. **Repository state:** `git -C <dir> rev-parse --show-toplevel` (it fails if `<dir>` does not exist yet). v1.8.11
   creates the project's own repository when the directory is new, or when the enclosing repository is rooted at `/`
   or `$HOME` (AEF T-4251).
2. **PATH tools:** `sha256sum ~/.local/bin/fw ~/.local/bin/claude-fw` (if present). v1.8.11 backs up a CHANGED file
   as `*.bak-<timestamp>` and says so; an identical file is left as is, silently (AEF T-4248).

    cd <parent> && curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh \
      | "${BASH4:-bash}" -s -- <dir> --provider <choice> 2>&1 | tee /tmp/aef-findings/$RUN/install-stdout.log

**Check the result yourself.**
- v1.8.11 exits non-zero and prints "Installation FAILED" when a step reports `[x]` (AEF T-4248). Still verify:
  `<dir>/.framework.yaml` and `<dir>/.agentic-framework/bin/fw` exist, and
  `git -C <dir> rev-parse --show-toplevel` prints `<dir>`.
- Every `[x]` and `[!]` line becomes a finding.

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
- `$FW version` output in `run.yaml` (the vendored copy has no git SHA; record that as well, and the "Fetched <sha>"
  line of the installer);
- any write to `$HOME` beyond `.local/bin/{fw,claude-fw}` and their backups: `framework-defect`, `degraded`.

---

## STEP 3 — Verify health, then move the record into the project

1. `cd <dir> && .agentic-framework/bin/fw doctor` → save verbatim to `doctor-initial.txt` with its exit code and
   wall-clock time (v1.8.11: about 10-40 s; AEF T-3083).
   - A non-zero exit: show me, fix what is clearly fixable (PATH; `fw git install-hooks --force`), re-run, and save
     `doctor-final.txt`.
   - Still failing: stop and report.
   - **Every warning on a fresh install is its own finding.** A fresh install that warns is either a framework
     defect or a doctor defect (checking something a new project cannot have yet).
   - Record doctor's own count line (`N warning(s) (M host-level), no failures`, AEF T-4261). Expect about 6-8 on a
     clean machine, more on a working machine.
2. **Onboarding gate.** `fw init` seeds five onboarding tasks (T-001..T-005), and gate T-532 blocks every
   non-onboarding write until they are done or skipped. [ASK] Work through them, or skip?
   - **Skip:** `cd <dir> && .agentic-framework/bin/fw onboarding skip` works directly on v1.8.11 (AEF T-4265).
   - Look at `.context/bypass-log.yaml` afterwards: an agent-run skip is logged as `authorized_by: human`. Record it.
3. Create your run task. Agent-owned, because a human-owned task with no Human ACs cannot be closed:
   `cd <dir> && .agentic-framework/bin/fw work-on "Greenfield install + findings $RUN" --type test --owner agent`
   Replace its placeholder acceptance criteria with real ones before any other edit (gate G-020).
   (Note: `fw work-on --help` prints no help; it treats `--help` as a task name. Read `fw help` instead.)
4. Move the record to `<dir>/.context/install-findings/$RUN/`: copy, verify, then remove the `/tmp` copy. Then commit
   it. `fw git commit` leaves new untracked files out, so stage the directory first:
   `cd <dir> && git add .context/install-findings/$RUN && .agentic-framework/bin/fw git commit -m "T-XXX: install findings $RUN (steps 0-3)"`

## STEP 3b — Restart inside the project (governance becomes active)

Claude Code reads CLAUDE.md and hook settings at session start. Until you restart in `<dir>`, this session is **not**
governed by the project you just installed.

- Write the resume point to `<dir>/.context/install-findings/$RUN/RESUME.md`: next step = STEP 4, run id, task id.
- Tell me: "Please restart me in `<dir>` with `claude-fw`, and paste: *resume the greenfield run from RESUME.md*."
- After the restart:
  - re-read this prompt and RESUME.md;
  - run `fw work-on <run task>` again (focus is per session and does not survive the restart);
  - continue.
- **The restart must not inherit another project's environment.** Start the new session from a plain shell in
  `<dir>`, not from inside another project's `claude-fw`.
- **Prove governance is active.**
  - Run doctor again and compare its hook-crash line with the pre-restart value: it must not grow.
  - The first gate that fires after the restart must block, not log `missing-hook`.
  - A session where gates fail open is not a governed session. Record it and tell me.
- Record as findings: whether the restart was needed (did a gate fire before it?), and whether `fw init` or the
  installer told you to restart.

---

## STEP 4 — Start Watchtower (it does not auto-start)

[ASK] Bind address. Watchtower binds **all interfaces (0.0.0.0) by default and has no login**, and the dashboard
includes a browser **terminal** page. Default for this run: local only.

    cd <dir> && FW_HOST=127.0.0.1 .agentic-framework/bin/fw watchtower start      # or without FW_HOST if I choose LAN
    cd <dir> && .agentic-framework/bin/fw watchtower status ; cd <dir> && .agentic-framework/bin/fw watchtower port

- **Firewall (v1.8.11, AEF T-4297):**
  - A loopback bind (127.0.0.1, localhost, ::1) never changes the host firewall.
  - A LAN bind changes ufw only when the project has `fw config set WATCHTOWER_OPEN_FIREWALL 1`. Otherwise it prints
    the exact `sudo ufw allow PORT/tcp` command and changes nothing.
  - Record exactly what `start` printed about a firewall. **Any firewall change without that setting is a
    `framework-defect`, `degraded`.**
- **Port:** fw picks a port when none is configured and writes it into `.framework.yaml` (a tracked file; record
  it). If the start fails because the port is busy, use `--port <N>` and record it.
- **URL:** under a local-only bind, `fw watchtower url` may print nothing or an unreachable LAN address. Use
  `http://127.0.0.1:<port>`.
- **Missing modules** (`markdown2`, `flask_socketio`): v1.8.11 refuses to start with one line naming them and the apt
  command. Expect that line; a traceback is a finding. Then back to STEP 1 (finding).

Give me the URL. Open each page in the navigation (discover them; do not assume names) and say what it shows on an
empty project. **Stop Watchtower at the end of the run** (`fw watchtower stop`) so no orphan server stays up. On
v1.8.11, `stop` may report a failure although the server is gone (a zombie process, AEF T-4306): check that the port
is closed, and record it as that known issue, not as a new one.

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
    `fw inception start "<what we build>" --recommendation GO|NO-GO|DEFER --rationale "<evidence>"`
    Both flags are required when an agent files under Claude Code. Then, in this order:
    - `fw work-on T-XXX`: `inception start` sets focus but not `started-work`, and the task gate blocks the first
      edit without it;
    - add at least one open question `**IW-1: …**` to the task file (gate G-067);
    - create the research artifact `docs/reports/T-XXX-*.md` before researching (rule C-001).

    You propose an architecture; **I** record go / no-go (`fw inception decide` is mine).
  - **Build now:** `fw work-on "<first task>" --type build`, then replace the placeholder ACs and add
    `## Verification` before editing.

Once I choose: create the task, set focus, start. From here:
- every commit traces to a task;
- **Tier-0 commands** (force push, hard reset, `rm -rf` of roots, DROP TABLE, …) wait for my approval;
- the dashboard shows state.

Satisfy every completion gate the way its message says, never with a bypass. On v1.8.11 the render gate ignores
HTML comments in the task template (AEF T-4307), so a render-gate refusal on a non-web task is a finding.

**Capture:**
- **First gate encounter:** was the message alone enough to know what to do? If you needed `--help`, prior
  knowledge or this prompt: `ux-friction` (a first-time user would be stuck).
- **Onboarding cost:** record three times from STEP 2 start:
  - the first edit;
  - the first edit made while gates were provably active;
  - the first gate-authorised edit to a project file.
  (Run 3, workstation: 3 min 41 s / ~14 min / ~19.5 min. Clean container, 2026-10-18: first gate-authorised edit
  after ~5.5 min.)

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
   `cd <dir> && .agentic-framework/bin/fw pickup send --remote <hub> --session <aef-session-id> --type bug-report --summary … --detail …`
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
- project path · provider · `fw` version (and the installer's fetched sha) · machine kind · dashboard URL + bind ·
  tasks created;
- doctor warnings, each mapped to its finding id;
- **findings table:** id · step · surface · class · severity · fingerprint · one-line observation;
- counts by class and by severity · publish status · onboarding cost (STEP 2 → first authorised edit);
- **top 3 to fix first:** a ranked proposal with reasoning, explicitly unratified. I decide.

Then close the session the framework's way: commit the final record, `fw handover --commit`. Leave no uncommitted
files in the record.

---

## THROUGHOUT

- **Initiative, not authority.** Choose approaches freely; never approve your own work. `inception decide`,
  `tier0 approve` and closing human-owned tasks are mine. So is every decision about a finding.
- **Producer, not judge.** If you catch yourself deciding something is "not really an issue", record it and let
  severity say so.
- **Research is not authorization.** A framework defect found here authorizes recording it, nothing more.
- **The workaround is the finding.** Recovering silently is the one failure mode that makes this run worthless.
- **The working directory is part of the instrument.** `cd <dir> &&` before every fw call; never into another project.
- Stop at every [ASK] and before anything destructive. When unsure, ask "y / n".
- If the harness breaks mid-run, stop and tell me. An uninstrumented install is a different task.
````

</details>

<details>
<summary><b>B — Existing codebase: install, ingest, heal to a clean baseline, start a feature</b></summary>

```
You are installing the Agentic Engineering Framework INTO AN EXISTING codebase: bring it under
governance, get it to a clean baseline, then help me start a new feature. Work autonomously
through the mechanical steps. Stop at the [ASK] points. Self-heal per step; if you cannot
recover, stop and show me the exact error and command — never work around a gate or invent a
command. Discover real verbs with `fw help` / `fw <area> --help`; confirm anything unfamiliar
before relying on it.

STEP 1 — Prerequisites
  bash 4.4+ / git 2.20+ / python3 3.8+. Self-heal: macOS bash 3.2 → `brew install bash` and use
  it (do not proceed on 3.2); install any missing tool and report.

STEP 2 — Install and initialise IN PLACE (one command)
  [ASK] Confirm this is the right repo and the provider (claude / cursor / generic), then from
  the repo root:
    curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash -s -- "$(pwd)" --provider <choice>
  This fetches the framework into a temporary path, vendors it into THIS repo's .agentic-framework/
  (not $HOME), and initialises in the same step. fw init is ADDITIVE: it adds .tasks/, .context/,
  .fabric/, hook wiring, a CLAUDE.md, and onboarding tasks; it does not rewrite your source.
  Self-heal: retry once on a transient GitHub failure; if `fw` is not found afterwards, add
  ~/.local/bin to PATH and confirm `fw --version`. If already initialised (.framework.yaml
  present), STOP and ask — do not re-run. If init wants to overwrite an existing CLAUDE.md or
  agent settings, show me the diff and ask before touching it.

STEP 3 — Verify health
  Run `fw doctor`. Non-zero exit → show me, fix the clearly-fixable, re-run, else report. Zero
  with warnings → note and proceed.

STEP 4 — Ingest the codebase into the Component Fabric
  Goal: a topology card for every real component — no unregistered files, no orphaned cards.
  Discover the real path with `fw fabric --help` (expected: `fw fabric drift` to find
  unregistered/orphaned, `fw fabric register <path>` to add a component, `fw fabric overview`
  for coverage).
  Loop, bounded, checkpointing with me each pass:
    a. `fw fabric drift`  → list unregistered files and orphaned cards.
    b. Register the real components; fix or remove orphaned cards.
    c. Re-run drift. Repeat until drift is clean.
  [ASK] Before mass-registering a large tree, show me your proposed component grouping and let
  me confirm — do not impose a topology on my codebase without a y / n.
  Self-heal: if the tree is huge, ingest by subsystem in slices and report progress. Never loop
  unbounded — if drift is not converging after a few passes, stop and show me what will not
  resolve.

STEP 5 — Audit and housekeeping to a clean baseline
  Run `fw audit`. Work the findings down, classifying each as governance, codebase, or
  environmental:
   - Record fixes as patterns:  fw healing diagnose <id>  /  fw healing resolve <id> --mitigation "..."
   - Capture genuine gaps with `fw gaps` rather than papering over them.
  Re-run audit until it is green or only advisory warnings remain. Heal the loops until the
  fabric cards are clean AND the audit passes.
  [ASK] If a finding implies a change to my source beyond housekeeping (a refactor, a
  behavioural fix), do NOT make it silently — surface it as a proposed task for me to approve.

STEP 6 — Start Watchtower (it does NOT auto-start today)
    fw serve &
    fw watchtower url          # --port <N> if the default is busy, then re-print
  Point me at the fabric graph — now populated from my own codebase — plus the audit and BVP
  views, and give me the URL.

STEP 7 — Guide me into a new feature
  In one short message, then [ASK] which feature I want:
   - Start it under governance:  fw work-on "<feature>" --type build
   - Before editing, check impact:  fw fabric blast-radius HEAD  and  fw fabric deps <file> —
     the fabric you just built now tells us what a change touches.
   - Every commit traces to the task; destructive commands wait for my approval.

THROUGHOUT
  - You hold initiative, not authority. Choose approaches freely; never approve your own work —
    the approval verbs are mine.
  - Stop at every [ASK], and before anything destructive or irreversible. When unsure, ask
    "y / n".
  - Final report: repo path · provider · fw version · fabric coverage (registered / drift) ·
    audit result · dashboard URL · onboarding tasks · any doctor warnings.
```

</details>

## The five requirements, one harness

Each requirement is a layer. Each layer has structural mechanisms behind it.
This is what each looks like in a terminal.

### Clear direction — a task gate that cannot be ignored

Nothing happens without a task. The PreToolUse hook intercepts every file
modification and refuses if no active task is set. Real output, captured this
session when I tried to run a bash command under a task that still had
placeholder acceptance criteria:

```
BLOCKED: Task T-2274 is a build task with placeholder/missing ACs.

Build tasks require real acceptance criteria before editing source files.
This prevents unscoped building. (G-020: Scope-Aware Task Gate)

To unblock:
  1. Edit the task file: replace [First criterion] with real ACs
  2. Or change to inception:
     bin/fw task update T-2274 --type inception

Attempting to modify:
Policy: G-020 (Pickup message governance bypass prevention)
```

The gate is not a convention. It is a wall. The agent that wrote those words
above is the same agent writing this README — it tripped its own gate, fixed
the ACs, and proceeded.

### Awareness of context — three layers of memory that survive

A session that does not remember the last session re-debates every decision.
Three layers carry knowledge forward:

- **Working memory** — what is happening now (`.context/working/`)
- **Project memory** — patterns, decisions, learnings, gaps the project has
  accumulated (`.context/project/`)
- **Episodic memory** — condensed histories of every completed task, generated
  at completion (`.context/episodic/`)

```
$ fw recall "authentication timeout pattern"
Related knowledge:
  L-017: Hooks that block on network IO must be bounded. Auto-handover at … (from T-1277)
  L-367: Background subshell watchdogs (fork-and-sleep timeout pattern) leak … (from T-1687)
  L-412: Filed bugs can be symptoms of an upstream perf/timeout issue …      (from T-1955)
  L-013: Heredoc bodies stripped before pattern matching                     (from T-094)
  L-015: Reduced test_all_nav_routes from 11 routes to 3 …                   (from T-1014)
```

Matches are returned by meaning, not keyword — none of the surfaced learnings
literally say "authentication timeout pattern" but each is a timeout/blocking
class the next session can read in 30 seconds.

At session end, `fw handover --commit` writes a structured handover that the
next session reads on start. Compaction recovery via `fw resume status` works
when a session is compressed mid-stream.

### Awareness of resource constraints — a budget gate that auto-handovers

Context windows are finite. The budget gate reads the live transcript and
escalates: ok at < 75%, warn at 75–85%, urgent at 85–95%, critical above 95%.
At critical, Write/Edit to source files is blocked and only wrap-up actions
(`git commit`, `fw handover`, `fw task update`) are allowed.

```
══════════════════════════════════════════════════════════
  SESSION WRAPPING UP (~285000 tokens)
══════════════════════════════════════════════════════════

  Context is at ~95% of context window.
  Task files already have all essential state. Time to wrap up.

  ALLOWED: git commit, fw handover, reading files,
           Write/Edit to .context/ .tasks/ .claude/
  BLOCKED: Write/Edit to source files, Bash (except commit/handover)

  Action: Commit your work, then run 'fw handover'
══════════════════════════════════════════════════════════
```

*(Format from `agents/context/budget-gate.sh:132–145`; the token count varies
with the live transcript.)*

A long session ends gracefully with state captured, not abruptly with state
lost.

### Awareness of impact — a structural map of the codebase

Before changing a file, the agent can see what depends on it.

```bash
fw fabric deps agents/git/git.sh         # what depends on this file?
fw fabric blast-radius HEAD              # what does this commit affect downstream?
fw fabric drift                          # unregistered files, orphaned cards
```

Component cards are YAML files in `.fabric/components/`. The dashboard
renders the graph at `/fabric` for interactive exploration. The same signal
feeds Business Value Points (below) as the cost component of every task's
score.

### Capable engaged actors — a tiered authority model

```
Human     → SOVEREIGNTY  → can override anything, is accountable
Framework → AUTHORITY    → enforces rules, checks gates, logs everything
Agent     → INITIATIVE   → can propose, request, suggest — never decides
```

The agent may choose which task to work on. It may choose an implementation
approach. It may not approve its own work. The verbs that constitute approval
— `fw inception decide`, `fw arc close`, `fw bvp confirm`, `fw tier0 approve`,
`fw enforcement baseline` — refuse to run under agent control and route to a
human via the Watchtower dashboard. Initiative is not authority.

| Tier | Scope | Approval |
|---|---|---|
| **0** | Destructive commands (`--force`, `rm -rf`, `DROP TABLE`, `--no-verify`) | Human must approve via `fw tier0 approve` |
| **1** | All file modifications | Active task required |
| **2** | Situational exceptions | Single-use, logged in `.context/working/.gate-bypass-log.yaml` |
| **3** | Read-only operations | Pre-approved |

Every bypass is logged. Every approval is auditable.

## See it work in five minutes

```bash
# 1. Install AND initialise a project — one command, one step per project.
#    Fetches framework bytes into ./my-project (not $HOME) and inits it.
curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh \
  | bash -s -- my-project --provider claude

# 2. Try to commit without a task — the gate refuses
cd my-project
echo "hello" > hello.txt && git add -A && git commit -m "no task yet"
#    Refused: "No task reference found in commit message".
#    This one is git-level, so you see it whether you typed it yourself or
#    an agent did. The stronger gate — refusing the EDIT before it happens
#    (§Clear Direction above) — is an AI-agent hook and will not fire for
#    you at a terminal.

# 3. Create a task and start working
fw work-on "Add authentication" --type build

# 4. Run a compliance audit + open the dashboard
fw audit                  # 260+ checks across 26 sections
fw serve                  # Watchtower dashboard
fw watchtower url         # prints the URL to open
```

Four commands. The repo now has task-traced commits, structural enforcement,
continuous audit, persistent memory, and a dashboard. The dashboard does not
auto-start today — `fw serve` is one step. T-1611 is the active task to move
Watchtower to a service model so it surfaces automatically.

## What you actually get

The framework is six layers. Each is a real subsystem with shipped CLI verbs.

<details>
<summary><b>Govern</b> — task gate · Tier 0 · sovereignty · single-gate invariant</summary>

Structural enforcement of "nothing happens without a task." Pre-tool hooks
fire on every file edit and every Bash invocation. Tier 0 intercepts
destructive commands. Sovereignty-bound verbs (approve, decide, close, confirm)
refuse to run under an agent and require a human via Watchtower. The MCP
server facade preserves the same boundary — external callers shell out
through `bin/fw` rather than re-implement gate logic ("single-gate invariant").

</details>

<details>
<summary><b>Remember</b> — three-layer memory · handover · resume · semantic recall</summary>

Working, project, and episodic memory persist across sessions. `fw handover
--commit` bridges sessions; `fw resume status` recovers from compaction; `fw
recall "<query>"` searches across learnings, patterns, decisions, and
episodics by meaning.

```bash
fw context add-decision "Use YAML for configs" --task T-001 \
  --rationale "Human readable, comments supported"
fw context add-learning "Always set connection pool limits" --task T-001
fw decisions      # browse all architectural decisions with rationale
fw learnings      # browse all captured learnings
```

</details>

<details>
<summary><b>Map</b> — Component Fabric · blast-radius · drift</summary>

A live structural map of every significant file in the project. Each
component is a YAML card recording purpose, interfaces, depends_on, and
depended_by. `fw fabric blast-radius HEAD` computes downstream impact for
the current commit; `fw fabric drift` detects unregistered or orphaned
components.

```bash
fw fabric overview            # subsystem summary
fw fabric impact <path>       # full downstream chain
fw fabric register <path>     # add a new component card
```

The dashboard renders the dependency graph with subsystem filters at `/fabric`.

</details>

<details>
<summary><b>Organize</b> — tasks · arcs · inceptions · horizon</summary>

Tasks are Markdown files with YAML frontmatter — acceptance criteria,
verification commands, decisions, BVP scores. Workflow types: build, test,
refactor, decommission, specification, design, inception.

Arcs group related tasks under a single user-observable mechanic (the
"headline mechanic"). An arc closes only when a wire-level demo artefact
proves the mechanic fires — substrate is not closure. Ten arcs are
registered today: dispatch-safety, embeddings-strategy, orchestrator-rethink,
project-shape-resilience, arc-grooming, value-prioritisation, watchtower-redesign,
inception-review-loop, horizon-axis-hardening, capability-overlay.

Inception is a workflow type for exploring a problem before committing to
build. The agent cannot ship build artefacts under an inception task until a
human records GO / NO-GO / DEFER with rationale.

Horizon (`now` / `next` / `later`) is the priority field; the handover agent
sorts work in progress by it and excludes `later` from suggestions.

```bash
fw work-on "Fix login bug" --type build       # one-step: create + focus + start
fw arc list                                   # ten arcs and their states
fw inception start "Define caching strategy"  # explore before building
fw task update T-XXX --horizon later          # park work without losing it
```

</details>

<details>
<summary><b>Measure</b> — BVP · weighted directives · audit · reviewer · metrics</summary>

Business Value Points: directive-weighted scores
(Σ driver_weight × driver_score) over a composite cost
(0.6 × blast_radius + 0.3 × tier + 0.1 × effort). The four constitutional
directives are the protected drivers (D1 Antifragility, D2 Reliability, D3
Usability, D4 Portability) with weights 9, 7, 5, 3. Projects can add free
drivers and arcs can have arc-scoped drivers, both capped to keep the value
system explicit rather than sprawling.

```bash
fw bvp                           # rank all tasks by directive-weighted value
fw bvp --quadrant hv-lc          # high value, low cost — the actionable list
fw bvp T-XXX                     # per-driver detail for one task
```

Audit runs 260+ checks across 26 sections (structure, task compliance, git
traceability, enforcement, learning capture, episodic completeness, gaps,
graduation, fabric integrity, framework-mcp baseline, and more). Cron fires
every 30 minutes; the pre-push hook fires on every push.

The Reviewer agent performs decorrelated review — an isolated static scan
that flags anti-patterns the producing session cannot catch about itself
(`mock-only-integration`, `swallowed-errors`, `defer-as-hedge`, others).
`fw reviewer T-XXX --dispatch` runs the reviewer in a TermLink worker with
zero parent-session context cost.

</details>

<details>
<summary><b>Coordinate</b> — TermLink · bus · dispatch · pickup · MCP server · Watchtower</summary>

The framework wraps an external TermLink binary for cross-terminal, cross-host
worker sessions. Heavy parallel work runs in isolated processes and survives
parent compaction.

```bash
fw termlink dispatch --task T-XXX --name <worker> --project /opt/... \
  --prompt-file work.md --timeout 1800
fw bus manifest T-XXX               # what results has the worker posted?
fw bus read T-XXX R-001             # inspect a specific result
fw dispatch send --host dev-server  # SSH-route a bus envelope
fw pickup list                      # discover sibling projects
```

The Framework MCP server (just shipped) exposes 22 capabilities to external
agents (Claude Desktop, MCP-aware editors) — 16 read-only verbs plus 6
agent-authority verbs (state-changing, schema-gated on `task_id`). Five
sovereignty-bound verbs are deliberately **never registered** because external
callers bypass in-process enforcement. All agent-authority MCP tools shell
out through `bin/fw` so the same gates fire.

```bash
fw mcp emit-manifest    # write agents/mcp/framework-mcp-manifest.json
fw mcp start            # start the stdio server
fw mcp status           # 22 / gated: 6
```

Watchtower (Flask + 14 KB of vendored htmx, no build step, no node_modules)
is the human-review surface. Task board, BVP rankings, audit reports, fabric
graph, approvals queue, gap register, reviewer verdicts. Currently launched
manually with `fw serve`; auto-start at install is the goal of T-1611.

</details>

## Installation

Hand it to your agent first. The other strategies are there when you need a
different shape.

### Hand it to your agent (lead)

The fastest path is the two self-contained onboarding prompts at the top of
this README — **[§ Get started — hand a prompt to your coding
agent](#get-started--hand-a-prompt-to-your-coding-agent)**. Pick **A —
Greenfield** for a new project or **B — Existing codebase** to bring code you
already have under governance, paste the block into your agent's chat, and it
installs, initialises, verifies health, and guides you into your first task —
stopping at the `[ASK]` points for your decisions.

Everything below is for when you want a different install shape (curl,
Homebrew, vendored isolation, CI) or to run the steps yourself.

Use this when: you already have Claude Code, Cursor, Aider, or another CLI
agent open and want to try AEF on a real project without leaving the editor.

### Curl-pipe-bash (single-user)

```bash
curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash
```

This clones to `~/.agentic-framework`, installs `fw-shim` to `~/.local/bin/fw`
(the project-detecting router), links `claude-fw`, and runs `fw doctor`.

Use this when: you are installing for yourself and trust the pipe-bash idiom.

### Local-clone install

```bash
git clone https://github.com/DimitriGeelen/agentic-engineering-framework.git ~/.agentic-framework
bash ~/.agentic-framework/install.sh --local ~/.agentic-framework
```

Use this when: you want to read the install script before running it, or you
are offline.

### `fw init` per-project (after global install)

```bash
cd existing-project
fw init                              # auto-detect provider
fw init --provider claude            # or: cursor, generic
fw work-on "First task" --type build
```

Use this when: every project. This is the per-project verb after the
framework is on PATH.

### Vendored isolation (no global at all)

`fw init` copies `bin/`, `lib/`, `agents/`, `web/`, `docs/`, FRAMEWORK.md, and
the metric helpers into `.agentic-framework/` inside your project. The shim
at `~/.local/bin/fw` walks up from your CWD to find the project-local copy.
Each project pins its own framework version.

Use this when: you are working in a shared repo or production project and
want predictable version pinning per project.

### `fw upgrade` from inside a consumer

```bash
fw upgrade                           # syncs the consumer to the framework's current version
fw upgrade --dry-run                 # preview only
```

Use this when: routine version uplift. The framework retains backward
compatibility on the wire; the upgrade refreshes hooks and vendored scripts.

### Recover a legacy consumer (pre-T-2232 vendoring)

```bash
fw consumer-recover <host> [path] --apply [--via {ssh,termlink}]
```

Use this when: an older consumer was vendored before the durable in-consumer
upgrade landed and cannot self-upgrade in place.

### CI / GitHub Action

```yaml
# .github/workflows/audit.yml
- uses: DimitriGeelen/agentic-engineering-framework@v1
  with:
    fail-on-warnings: 'false'        # block PRs only on FAIL; warnings advisory
```

Use this when: you want CI to gate PRs on `fw audit` results.

### Homebrew (macOS / Linux)

```bash
brew install DimitriGeelen/agentic-fw/agentic-fw
```

Use this when: you prefer brew over curl-pipe-bash.

### Prerequisites

The installer checks these:

- **bash 4.4+** — macOS ships 3.2 by default; `brew install bash` gets a
  current version.
- **git 2.20+**
- **python3 3.8+** (PyYAML is optional; needed only for `fw serve` and a
  small number of helper scripts).
- **Node.js** is optional — recommended for TypeScript hooks; Python is the
  fallback.

## Maturity — shipped versus evolving

This is alpha software the author uses daily. Some pieces are stable. Some
are actively iterating. The maturity table is honest in both directions.

| Capability | Status |
|---|---|
| Task gate, Tier 0, sovereignty refusals, single-gate invariant | shipped, exercised daily |
| Three-layer memory (working/project/episodic), handover, resume | shipped, stable |
| Component Fabric, blast-radius, drift | shipped, stable |
| Task system, arcs, inceptions, horizon | shipped, stable (10 arcs registered) |
| BVP, weighted directives, audit (260+ checks), reviewer | shipped, stable |
| TermLink integration, bus, dispatch, pickup | shipped, stable |
| Watchtower dashboard | shipped (functional) |
| Framework MCP server (read-only + agent-authority facade) | shipped this week (T-2265); 22 tools registered; HM-A demo and Watchtower migration in flight |
| Embeddings strategy maturation (arc-002) | working, evolving |
| Watchtower auto-start at install (T-1611) | designed, not yet shipped |
| Multi-provider validation (Cursor, Aider, Devin) | designed, not validated — Claude Code is the tested provider |

A separate gap worth naming: deep-dive #17 (`why-bash-yaml-files.md`) flags
the bash enforcement layer as the part most needing structured bats
coverage. That is a real hole the author is open about.

## What this is not

The framework coordinates agents. It does not execute them.

It is not a chatbot, an agent runtime, a multi-app personal assistant, or a
multi-agent pipeline. Run OpenClaw for multi-app automation. Run LangGraph
for stateful agent orchestration. Run CrewAI for multi-agent pipelines. Run
Claude Code, Cursor, Aider, Devin, or any CLI-capable agent as your model
runtime. Run this inside the repos those agents touch — so nothing gets
committed without traceability and nothing gets destroyed without approval.

The model lives in your agent. The governance lives here.

## Self-governing

This framework develops itself under its own governance using Claude Code:
2,239 tasks created, 2,037 completed, 99% commit traceability across the
most recent 500 commits, every architectural decision recorded with
rationale, 263 audit emit-points across 26 sections firing on every push
and every 30 minutes. The framework is its own case study — or its own
most elaborate yak-shave, depending on your perspective.

A recent commit log line:

```
cca38ab8a T-077: Checkpoint handover S-2026-0609-0851
26bf03178 T-2200+T-2202: backfill OBS-053/054/055 text bodies (fw note "add" silent-swallow)
d4fcd724c T-2265: t9 — pin name-level parity between live MCP server and manifest
6d2fbb7f7 T-1687: fabric enrich — +2 edges across 2 cards
a74aad9bd T-2268: evidence README — add Operator Quickstart (3-step demo path)
043e3abcf T-2200+T-2202: workers exit 0; outcomes integrated + surfaced
```

Every commit traces to a task. Every task has acceptance criteria that were
verified. Every decision is recorded with rationale. The framework is the
evidence.

## Key commands

| Command | Purpose |
|---|---|
| `fw work-on "name" --type build` | one-step: create task, set focus, start work |
| `fw work-on T-XXX` | resume an existing task |
| `fw task update T-XXX --status work-completed` | close task (runs verification gate, AC gate, RCA gate where applicable) |
| `fw arc create <slug> --headline-mechanic "..." --anchor T-XXXX` | create a multi-task arc |
| `fw bvp` | rank all tasks by directive-weighted value over composite cost |
| `fw bvp --quadrant hv-lc` | high-value, low-cost shortlist |
| `fw recall "<query>"` | semantic search across project memory |
| `fw fabric blast-radius HEAD` | downstream impact of the current commit |
| `fw audit` | run all 260+ checks |
| `fw reviewer T-XXX [--dispatch]` | decorrelated static-scan review |
| `fw handover --commit` | end-of-session context handover |
| `fw resume status` | post-compaction recovery |
| `fw serve` | start Watchtower dashboard |
| `fw watchtower url` | print the dashboard URL |
| `fw inception decide T-XXX go --rationale "..."` | record an inception go/no-go (human-only) |
| `fw tier0 approve` | approve a blocked destructive command (human-only) |
| `fw mcp start \| status \| emit-manifest` | framework MCP server lifecycle |
| `fw help` | full command catalogue (≈ 60 verbs across 11 sections) |

For everything else: `fw <verb> --help` and FRAMEWORK.md.

## Documentation

- **[FRAMEWORK.md](FRAMEWORK.md)** — provider-neutral operating guide
- **[CLAUDE.md](CLAUDE.md)** — Claude Code integration and the full reference
- **[docs/articles/](docs/articles/)** — launch article and 19 deep-dive
  posts, each on one capability
- **Watchtower** — `fw serve`, then `fw watchtower url`

## Team usage

- Per-repo enforcement: `fw git install-hooks` installs the commit-msg and
  pre-push hooks per repo
- Shared dashboard: deploy Watchtower for team-wide visibility
- CI gating: see the GitHub Action snippet under §Installation
- Cross-machine coordination: TermLink + bus + dispatch (see §Coordinate)

## When to use, when not to

Use this when:

- AI agents work on your codebase regularly
- You need audit trails for agent actions
- Sessions span days and context is otherwise lost
- You want destructive actions to wait for human approval
- You want value-driven prioritisation rather than recency-driven backlog
- You want a wider harness — memory, structural awareness, audit, coordination —
  not just a gate

Skip this when:

- One-off prototypes
- Solo projects under a week
- You do not use AI coding agents

## Architecture and principles (contributor-facing)

<details>
<summary><b>Architecture</b></summary>

The framework runs as a CLI (`fw`) that routes to specialised agents.
Internally organised into 20 agent subsystems and 55 lib modules; you
interact with about 60 top-level commands and a dashboard.

```
bin/fw                  CLI entry point
bin/fw-shim             project-detecting router (~/.local/bin/fw)
agents/                 20 subsystems
  audit/                governance checks (260+, 26 sections)
  context/              memory, focus, budget gates
  fabric/               component topology, blast-radius
  git/                  task-traced git operations + hooks
  handover/             session handover generation
  healing/              error recovery, pattern recording
  mcp/                  framework MCP server (T-2265)
  metrics/              project metrics dashboard
  resume/               compaction recovery
  reviewer/             decorrelated static-scan review
  task-create/          task creation + update + verification
  termlink/             cross-terminal worker integration
  ... (and 8 others)
lib/                    55 shell modules (init, upgrade, vendor,
                        bvp, arc, inception, bus, dispatch,
                        consumer-recover, paths, ...)
web/                    Watchtower (Flask + htmx, no build step)
policy/                 value-drivers, capability-overlay tool-set
.tasks/                 task files (Markdown + YAML frontmatter)
.context/               working, project, episodic memory; arcs; audits
.fabric/                component topology cards
.claude/                provider config and hook wiring
```

</details>

<details>
<summary><b>Constitutional directives (in priority order)</b></summary>

1. **Antifragility** — the system strengthens under stress; failures are
   learning events
2. **Reliability** — predictable, observable, auditable execution; no
   silent failures
3. **Usability** — sensible defaults, actionable errors, minimal ceremony
4. **Portability** — no provider, language, or environment lock-in

Every architectural decision traces back to these four. They are also the
default value drivers in the BVP scoring rubric (weights 9, 7, 5, 3).

</details>

<details>
<summary><b>Authority model</b></summary>

```
Human     → SOVEREIGNTY  → can override anything, is accountable
Framework → AUTHORITY    → enforces rules, checks gates, logs everything
Agent     → INITIATIVE   → can propose, request, suggest — never decides
```

Initiative is not authority. A broad directive ("proceed as you see fit")
delegates initiative, not approval. When a structural gate blocks an action,
the gate wins.

</details>

<details>
<summary><b>The stack and why</b></summary>

Bash, YAML, plain files, Flask, cron, 14 KB of vendored htmx, no build step,
no database. Each choice traces to one of the four directives, especially
Reliability and Portability. The full argument — including the questions
this stack invites from experienced engineers — is in
[docs/articles/deep-dives/17-why-bash-yaml-files.md](docs/articles/deep-dives/17-why-bash-yaml-files.md).

The short version: governance infrastructure should be the simplest
technology that works, not the most sophisticated technology available.
Every layer of abstraction is a place where enforcement can silently fail.
Plain text files in git cannot silently lose data.

</details>

## License

Apache 2.0 — see [LICENSE](LICENSE).

Copyright 2025–2026 Geelen & Company

---

The principle holds: effective intelligent action requires clear direction,
context awareness, awareness of constraints and impact, and capable engaged
actors. This was true for Shell's global transitions. It is true for AI
coding agents. The domain changed. The principle did not.
