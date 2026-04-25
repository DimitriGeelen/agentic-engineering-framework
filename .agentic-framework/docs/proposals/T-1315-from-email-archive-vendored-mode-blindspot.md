# Pickup Request to Upstream Framework — "Vendored-vs-Repo Mode" Blind Spot

**From:** `/opt/050-email-archive` (vendored framework consumer)
**To:** `/opt/999-Agentic-Engineering-Framework` (framework repo)
**Via:** `.agentic-framework/bin/fw termlink dispatch --project /opt/999-Agentic-Engineering-Framework`
**Originating task:** T-1043 (this-side research; framework side should open its own inception)
**Type:** **Inception request** — please explore before building. This is a *proposal*, not a
spec; the framework-side agent should scope the problem, run spikes, and come back with a
recommendation before writing code.

## TL;DR

The framework has a single blind spot that caused **two separate incidents in the last 36
hours** in one vendored consumer. Agents operating in vendored projects follow framework
guidance that was written as if they were running inside the framework's own repo. That
guidance then either (a) sends agents to nonexistent paths (today's `bin/fw` miss), or
(b) lets stale environment variables from other projects go unchecked (yesterday's
`PROJECT_ROOT` leak that created stray tasks in the wrong repo).

Different symptoms, **same class of bug**: the framework does not structurally distinguish
its two installation modes and does not enforce mode-aware behavior.

## Incidents that prompted this pickup

### Incident A — `bin/fw` path miss (2026-04-18)

**What happened.** Agent dictated a copy-paste command
`cd /opt/050-email-archive && bin/fw inception decide T-1040 no-go --rationale "…"` to the
human. Command failed: `bash: bin/fw: No such file or directory`. In this vendored
consumer the binary lives at `.agentic-framework/bin/fw`. Human had to re-ask, agent had
to regenerate the command, friction.

**Why the agent did this.** `CLAUDE.md § Agent Behavioral Rules § Copy-Pasteable Commands
(T-609)` says, verbatim:

> **Use `bin/fw` not `fw`** — the global `fw` may resolve to a different install

The rule is stated as universal. An agent following it faithfully in a vendored project
produces a broken command every time.

### Incident B — `PROJECT_ROOT` env leak creating stray tasks (2026-04-17)

**What happened.** Agent resumed in `/opt/050-email-archive` with
`PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework` leaked from a previous session.
Agent ran `fw work-on "…"` twice. Each invocation obeyed the leaked env var, creating
T-1288 and T-1289 **in the framework repo** instead of in email-archive. Agent then
edited T-1289's acceptance criteria — still in the wrong repo — before the human caught
it. Those two task files still exist in the framework repo and need cross-repo cleanup.

**Why the agent did this.** No framework guidance says "verify `PROJECT_ROOT` against
`pwd`/`.framework.yaml` before using `fw`." The boundary hook (`check-project-boundary.sh`)
**uses** `$PROJECT_ROOT` to decide what to block — so it cheerfully allowed writes to the
"correct" repo according to the leaked env var. The guardrail was complicit.

### Shared root cause

In both incidents the agent was in **vendored mode** (a project that has pulled the
framework in under `.agentic-framework/`) but was following framework conventions that
assume **repo mode** (running inside `/opt/999-Agentic-Engineering-Framework`). Repo mode
has `bin/fw` and a stable `PROJECT_ROOT`; vendored mode has `.agentic-framework/bin/fw`
and inherits `PROJECT_ROOT` from whatever previously set it.

The framework has no mechanism to:
1. Detect which mode the agent is running in.
2. Adjust guidance text in CLAUDE.md accordingly.
3. Normalize the environment at session start (re-derive `PROJECT_ROOT` from `pwd`
   / `.framework.yaml`, not trust whatever the parent shell inherited).

## Proposed fix options

Three candidates, lowest-effort to highest-structural-value. Framework-side inception
should evaluate them on: effort, blast radius, how many future failure classes each
prevents, and interaction with existing tooling.

### Option 1 — Install-time `bin/fw` symlink (lowest effort)

**Change.** When `fw` is vendored into a project, the install step creates
`<project>/bin/fw` as a symlink to `<project>/.agentic-framework/bin/fw`.

**Effect.** The universal `CLAUDE.md` rule "use `bin/fw`" becomes true in every project.
Agents who follow it produce working commands.

**Pros.**
- ~10 lines of code in the vendor/install script.
- One-time migration across existing consumers (for-loop in a script).
- No change to agent behavior required.
- Backwards compatible — existing `.agentic-framework/bin/fw` callers keep working.

**Cons.**
- Fixes only Incident A. Does nothing for the env-leak class (Incident B).
- Adds a symlink that humans may be confused by (`git status` noise if not ignored).
- Doesn't address the "why is the guidance universal when the layout isn't" question —
  treats symptom not cause.

**Effort.** S. Half a session.

### Option 2 — Path-aware CLAUDE.md rule (medium effort)

**Change.** Rewrite the Copy-Pasteable Commands rule (and related ones) to teach agents
to resolve the path rather than assume it. Examples:

```
# Correct (path-agnostic):
cd <project> && "$(command -v fw || echo ./.agentic-framework/bin/fw || echo ./bin/fw)" <cmd>

# Or via a session-derived env var the agent reads at init:
cd <project> && $FW <cmd>   # where $FW is resolved by session preflight
```

Add a small preflight that every agent runs at session start:

```bash
export FW="$(./.agentic-framework/bin/fw --resolve-self 2>/dev/null || echo fw)"
```

Update CLAUDE.md language: *"Always use `$FW` in copy-paste commands; never hard-code
`bin/fw` or `fw`."*

**Pros.**
- Fixes the guidance, not the symptom — so new projects with different layouts (e.g.
  monorepo subproject with framework at a custom path) just work.
- No install-time side effects.
- Cascades to the env-leak problem: the same preflight can verify
  `PROJECT_ROOT` against `pwd`, warn if they disagree.

**Cons.**
- Requires agents to change habits; the CLAUDE.md rule has to be reread until internalized.
- Preflight script is new surface area to maintain.
- `$FW` in a copy-paste command is less immediately legible to humans reading the log —
  "what's `$FW`?" friction.

**Effort.** M. One session to draft + one to audit/update every CLAUDE.md copy-paste
example. Existing projects need their CLAUDE.md regenerated.

### Option 3 — Structural: session preflight owns environment + binary resolution (highest value)

**Change.** Introduce a single framework-owned session-preflight agent (call it
`fw session init` or make it part of the existing `fw context init`). At session start it:

1. Reads `.framework.yaml` from `pwd`. Fails loudly if absent.
2. Re-derives `PROJECT_ROOT` and `FRAMEWORK_ROOT` from the repo layout, **not** from
   inherited env. Exports them fresh.
3. Emits a shell-sourceable snippet that sets `$FW`, `$PROJECT_ROOT`, `$FRAMEWORK_ROOT`
   consistent with the current directory.
4. Writes a fingerprint to `.context/working/.session-env.yaml` so later hooks (notably
   `check-project-boundary.sh`, `check-active-task.sh`) can verify their env against
   the canonical one and refuse to run on mismatch.
5. CLAUDE.md becomes mode-aware: the relevant sections are rendered from a template
   whose inputs include the resolved `$FW` path, so copy-paste examples are always
   correct for the current project.

**Pros.**
- Prevents **both** incident classes (and likely others not yet seen, e.g. a
  `FRAMEWORK_ROOT` pointing at the wrong vendored copy if a project contains multiple
  nested framework installs).
- Makes the vendored-vs-repo distinction **structural, not conventional** — any future
  hook or agent can rely on `.session-env.yaml` as ground truth.
- Cleans up a pattern that already exists informally (several hooks already read
  `PROJECT_ROOT`; they'd all move to one canonical source).

**Cons.**
- Biggest change. Has to be rolled out to every framework consumer.
- Requires a one-time migration of existing CLAUDE.md files to the templated form.
- Risk of breaking edge cases where a project deliberately overrides env vars.

**Effort.** L. 2–3 sessions including migration and hook updates.

## Exploration plan for framework-side agent (suggested spikes)

These are *suggestions* — the framework-side agent should revise based on local
constraints.

- **FS1 — Audit how many existing consumers would be affected.** Enumerate projects
  that have pulled the framework in (grep for `.framework.yaml`). For each, check
  whether `bin/fw` exists. Estimate migration scope for options 1 and 3.
- **FS2 — Grep for hard-coded `bin/fw` in agent prompts / CLAUDE.md across the
  framework.** Establish the blast radius of a documentation-only fix (option 2 / 3).
- **FS3 — Review other hooks that use `$PROJECT_ROOT`.** Confirm whether option 3's
  session-env fingerprint would plug into each of them cleanly, or whether each hook
  needs bespoke rework.
- **FS4 — Check prior incidents in episodic memory** for evidence of this class of bug
  happening in other consumers. If it's only email-archive so far, that's a signal
  about priority. If multiple consumers have hit it, option 3 is more clearly warranted.
- **FS5 — Prototype option 1 as a single-commit spike** (symlink + install-script
  tweak). Even if option 3 is chosen for the full fix, option 1 can ship in parallel as
  immediate relief for today's command failures while option 3 is designed.

## Go/no-go criteria (for framework-side inception)

**GO the fix** if any of:
- At least one more consumer has hit either incident class (episodic memory search).
- The grep in FS2 finds >10 hard-coded `bin/fw` references across the framework (it's
  a real guidance problem, not a one-off).
- Option 1 can ship as a ~30-minute tactical fix without preventing option 3 later.

**NO-GO** if:
- No other consumer has hit this and the framework is about to undergo a larger
  restructuring that would obsolete the current paths anyway (fix becomes throwaway).
- The cost of migrating all existing CLAUDE.md files exceeds the expected friction
  savings over the next 3 months.

## Recommendation (from consumer side)

**Ship option 1 immediately** (tactical — unblocks copy-paste friction today), then
**plan option 3** as a scoped multi-session refactor. Option 2 by itself is a trap —
it fixes the guidance text but leaves the env-leak class untouched, so it solves half
the problem and gives false confidence.

## Evidence / artifacts referenced

- `/opt/050-email-archive/CLAUDE.md` — contains T-609 "Copy-Pasteable Commands" rule
  (line reference may drift; grep for the heading).
- `/opt/050-email-archive/.agentic-framework/agents/context/check-project-boundary.sh`
  — the hook that trusted the leaked `PROJECT_ROOT`.
- `/root/.claude/projects/-opt-050-email-archive/memory/feedback_env_mismatch_stop.md`
  — the consumer-side feedback memory written after Incident B.
- `/root/.claude/projects/-opt-050-email-archive/memory/feedback_fw_path_in_email_archive.md`
  — the consumer-side memory written after Incident A.
- `/opt/050-email-archive/.agentic-framework/docs/rfc-claude-code-governance.md` —
  the RFC describing failure modes of Claude Code hooks; Incidents A and B are both
  examples of FM5 (CLAUDE.md non-compliance through rules-vs-reality mismatch).

## What the consumer is not asking for

- Not asking for a quick patch pushed back to this repo. This is a framework-repo
  concern; fix it there and the fix will flow to all consumers via the next vendor sync.
- Not asking for either of the two stray framework-repo tasks (T-1288, T-1289) to be
  deleted. Those belong to a separate cleanup that only a framework-repo session
  should take.
- Not asking for a specific option to be picked. The framework-side agent owns that call.

---

*This pickup was generated with auto mode enabled, under task T-1043 in the
email-archive consumer repo. Human has approved sending it. The receiving agent
should treat this as a proposal, not a build spec.*
