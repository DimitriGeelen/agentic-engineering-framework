# T-2800 — Should the `$HOME` framework install exist at all?

**Status:** exploration complete, awaiting operator go/no-go
**Date:** 2026-08-04
**Origin:** operator pushback during the fresh-install onboarding session that
produced T-2793, T-2796, T-2797, T-2798, T-2799.

---

## Problem Statement

D-377 (2026-08-04, operator) decided **total isolation**: everything a project
depends on is vendored into that project. T-2793 delivered this for the CLI —
`~/.local/bin/fw` is now a 5.5 KB router with no framework logic in it. But the
framework it falls back to, `$HOME/.agentic-framework`, was never removed.

That leftover is the common factor in most of what broke this session:

| Defect | Role of the `$HOME` install |
|---|---|
| T-2793 | global CLI executing against a project's vendored libs — the split brain |
| T-2796 | its version counter incomparable with the project's; 1.6.432 read as newer than 1.6.132 |
| T-2797 | onboarding Step 2 reads it, finds it present, recommends skipping the update |
| session-wide | it lagged master by 3 commits and nothing surfaced that |

It is also the source of the router's `no project found above … — using global
install at /root/.agentic-framework` line, which the operator saw repeatedly.

## Measurements (fresh install from GitHub master, isolated `HOME`, 2026-08-04)

| What | Where | Size |
|---|---|---|
| Router (`fw` on PATH) | `~/.local/bin/fw` | **5.5 KB** |
| Framework install | `~/.agentic-framework` | **352 MB** |
| Project's vendored copy | `<project>/.agentic-framework` | **28 MB** |

Breakdown of the 352 MB:

```
.git      169M      full commit history
docs       20M
vendor    7.6M
tests     6.0M
lib+web+agents  ~7M
```

**169 MB of git history is shipped to every user's home directory** so that a
28 MB vendor can be seeded from it. No argument was found for this; it is not
part of the design question, it is simply waste.

---

## Dialogue Log

Recorded because the reasoning matters more than the conclusion, and
conversations do not survive (C-001).

### Round 1 — the operator rejects the framing

Agent had written: *"Install ≠ init. The install went where it should:
`$HOME/.agentic-framework` plus the router on PATH — once per machine."*

Operator: *"i beg to differ, why does install go into \$home ????!!!! we said we
want total isolatzion in the instalaltion directory ???"*

**Course correction.** The agent was describing what the code does; the operator
was asking why it does it at all. The second is the better question, and D-377
had already answered it — the implementation just stopped halfway. Agent conceded
and filed this inception.

### Round 2 — operator states a position and asks to be argued with

Operator: *"LET INIT ALWAYS put the latest version from online, seems to make
most sense to be, no 352mb needed locally, in root, is pollution, and always
latest version that will be pulled, pleas eargemnet why i am wrong."*

Agent argued five objections. Operator answered each:

| # | Objection | Operator's answer | Outcome |
|---|---|---|---|
| 1 | "always latest" makes projects unreproducible | *"can we request to get an exact version?"* | **Dissolved.** `--ref <tag\|sha>` plus recording the resolved SHA (the `version_sha:` field already exists, T-2713) gives freshness *and* exact reproduction. |
| 2 | every new project becomes a canary for whatever landed minutes ago | *"well isnt that a good thing ???"* → then *"can we add a bleading edga and stable realease type of versioning?"* | **Resolved, better than the agent's proposal.** Two channels: `stable` default, `edge` opt-in. |
| 3 | offline init becomes impossible | *"can we add second or alternate remote if desired?"* | **Dissolved.** `.framework.yaml` already carries `upstream_repo:`; `--from <url\|path\|tarball>` covers LAN mirror and true offline alike. |
| 4 | GitHub rate limits / outages | *"same solution as three?"* | **Yes, and better than a `$HOME` cache** — a mirror is shared infrastructure, a cache is duplicated per machine. |
| 5 | bootstrap: nothing on a fresh machine can run `fw init` | *"please alborate"* | **Constraint, not refutation** — see below. |

### Round 3 — the bootstrap constraint

`fw init` is framework code (`lib/init.sh` and everything it sources). Under the
proposed model the framework exists only inside a project, *after* init. On a
fresh machine, in an empty directory, nothing can execute it — the 5.5 KB router
only finds a framework and hands off, and there is nothing to find.

Three exits:

- **(a) The installer performs the init.** `install.sh` is standalone (15 KB, no
  framework dependencies): it fetches the framework into the target directory and
  inits there. Afterwards `fw` finds the project's vendored copy normally.
- **(b) The router grows a bootstrap verb.** It then carries fetch, ref
  resolution and error handling — framework logic back in `$HOME`, just less of
  it. Rejected: it re-creates the thing being deleted.
- **(c) Keep a seed in `$HOME`.** Rejected by the operator (pollution).

**(a) is forced.** The significant consequence: *"no framework in `$HOME`"*
**requires** *"the installer sets up the directory you call it in"*. These are not
two independent preferences — the operator raised the second earlier in the
session (*"isnt that the intention, to install isolated in teh directory we call
the installer?"*) and the agent had treated it as a separate question. It is the
same decision.

What must change regardless: today that init happens as an unannounced side
effect of the installer's own self-test (`fw doctor` in the caller's cwd, output
swallowed by `&>/dev/null`, reported as `Step 3/3: fw doctor passes ✓`). Under
the new model it becomes the installer's declared purpose — prompted, documented,
and taking an explicit target directory. T-2799 fixes the side effect; that fix
is correct under every option here.

### Round 4 — the promotion gate

Agent's caveat on channels: *stable* only means something if something promotes a
commit into it. Our tags are cut mechanically (`v1.6.764` is 137 commits back,
nothing gated it). A channel that promises stability without gating for it is the
false-green shape this whole session has been about, wearing a friendlier name.

Three candidate gates were offered — (1) operator cuts it via `fw release`,
(2) green suite + N days, (3) dogfood soak across framework + one consumer.

**Operator chose (1).** *Stable* means the operator ran it and blessed it.

Rationale for starting there rather than (2): the suite has known reds and
orphaned files that no runner globs (OBS-145, T-2696). Gating on a green that
isn't measuring what it claims would repeat the session's central mistake.
(3) remains the target once consumer telemetry exists.

---

## Bootstrap spike — option (a) proven end to end

Run 2026-08-04 via TermLink (the project-boundary hook correctly refused a direct
`fw` invocation on a path outside this repo; the sanctioned path was used rather
than worked around).

**Setup.** A 28 MB vendored copy placed in an empty directory, and a `HOME`
containing the 5.5 KB router and **no framework at all**:

```
emptyHOME_has_framework=NO
vendored=28M
```

**Step 1 — can a vendored copy initialise a project with nothing in `$HOME`?**

```
env -i HOME=$B/emptyhome PATH=$B/emptyhome/.local/bin:... \
  $B/proj2/.agentic-framework/bin/fw init $B/proj2 --provider claude
→ rc=0
  Done! Governance is active.
  Onboarding tasks are ready — 5 tasks will guide you through setup.
```

**Yes.** This is the load-bearing claim of option (a) and it holds.

**Step 2 — is it a real project, or a vacuous pass?** Artifacts written:
`.agentic-framework .claude CLAUDE.md .context .framework.yaml .mcp.json policy
.tasks`, with **5 onboarding tasks seeded**.

**Step 3 — does the router close the loop afterwards?** Bare `fw`, still with an
empty `HOME`:

```
fw v1.6.135
Commit:    (none — vendored copy; VERSION file is the only identity)
Framework: /tmp/t2799/proj2/.agentic-framework
Mode:      vendored
Project:   /tmp/t2799/proj2
```

The full loop runs with **zero framework bytes in `$HOME`**.

### Two findings the spike surfaced

**1. The IW-2 refuse path already exists and reads correctly.** From a directory
with no project ancestor and an empty `HOME`:

```
fw: no framework found.

  Looked for a vendored copy walking up from: /tmp/t2800nw
  Looked for a global install at:             …/emptyhome/.agentic-framework

  Install one, then run 'fw init' here to vendor it into this project.
```

Shape is right and already shipped. It needs one change under the new
architecture — lead with the install one-liner rather than "install one", which is
T-2794's lesson applied to this message. The second "Looked for a global install
at" line disappears when there is no global to look for.

**2. The router is immune to the filesystem-root pollution.** `/.context` and
`/.tasks` exist on this host (T-2786-88), which made `/` resolve as a valid
project for the *hook* resolver (OBS-152). The router was not fooled: it keys on
`FRAMEWORK.md` + `bin/fw`, a strictly narrower predicate than `.tasks`. Worth
recording because it means the two resolvers disagree by design, and the narrower
one is the one on the bootstrap path.

### What is therefore still to build

Less than expected. Router refusal ✓ (wording aside), vendored-copy init ✓
(proven). The gap is entirely in `install.sh`:

- accept a target directory: `curl … | bash -s -- /opt/myproject`
- resolve a ref from the channel (`stable` → latest release tag, `edge` → master,
  `--ref X` → X)
- fetch **as a tarball, not a clone** — this is what turns 352 MB into 28 MB, and
  it is why `fw release` should publish a vendor-subset asset (the repo tarball is
  still ~183 MB; today's vendored copy is a subset: `agents bin docs lib web`)
- install the router if absent, then run `<project>/.agentic-framework/bin/fw init`
- write `channel:` alongside the existing `version_sha:` in `.framework.yaml`
- **copy `claude-fw` onto PATH instead of symlinking it** — added after the T-2803
  survey. `install.sh:259`/`:280` do `ln -sf "$INSTALL_DIR/bin/claude-fw"`, which
  is safe only while `INSTALL_DIR` is permanent. Delete the global and
  `~/.local/bin/claude-fw` dangles, silently disabling the auto-restart wrapper
  (T-179) on every migrated host. `$HOME` therefore holds **two** small files, not
  one. `bin/fw:1768`'s refresh advice (`bash ~/.agentic-framework/install.sh`)
  becomes false at the same moment and must change with it.

**Atomicity is a requirement, not a nicety.** OBS-157 (hit live in
`/opt/2345-test-install` this session) is an interrupted init leaving
`.agentic-framework/` present and `.framework.yaml` absent — a state where every
`fw` verb fails, so the tool cannot repair what it created. The new installer must
fetch to a temp path and move into place, so an interruption leaves either nothing
or a working project.

### One optimisation, and why it must stay opt-in

"After project one exists, seed project two from the nearest vendored copy" saves
a download and works offline. But an automatic version of that reintroduces the
exact defect this whole inception removes: the neighbour holds *its* pinned
version, which may be months old, and nothing would say so. That is the
stale-global bug wearing a new costume — and the T-2762 foreign-source class,
where a stale source silently governs a fresher consumer. Keep it as explicit
`--from <path>`; never a silent fallback.

---

## Resolved design

1. **`$HOME` holds the router and nothing else.** No framework, no cache, no
   `.git`. 352 MB → 5.5 KB.
2. **`fw init` fetches into the project**, defaulting to the `stable` channel.
3. **Two channels.** `stable` (default) and `edge` (master HEAD, opt-in), written
   to `.framework.yaml` as `channel:` so `fw upgrade` follows the same track.
4. **`stable` is cut by the operator** via `fw release`. Automated gating is a
   later step, not a launch requirement.
5. **Exact pinning** via `fw init --ref <tag|sha>`; the resolved SHA is recorded
   in `.framework.yaml` (`version_sha:`, already implemented).
6. **Alternate source** via `--from <url|path|tarball>` and the existing
   `upstream_repo:` field — covers LAN mirrors, air-gapped hosts and GitHub
   outages.
7. **Install and init become one command per project**, forced by (1). Bare `fw`
   outside any project refuses with instructions instead of falling back.

## Open risk — SURVEYED (T-2803, 2026-08-04)

**Resolved.** `docs/reports/T-2803-global-install-dependency-survey.md` enumerates
**12 references across 6 files** (`bin/fw`, `bin/fw-router`, `bin/fw-shim`,
`install.sh`, `lib/update.sh`, `lib/upgrade.sh`) — nothing in `agents/`, `web/`,
or any Python. Classified 6 must-migrate / 3 compat-shim-needed / 3 can-delete,
with an ordering constraint: **`install.sh` must be able to create a project
before the router's global fallback is removed**, because that fallback is the
only reason `fw init` works in a bare directory today.

Answer to *"does an existing install keep working untouched?"* — **existing
projects, yes** (the router finds them before ever consulting the global; proven
in the spike above). **Two host-level affordances break**: the dangling
`claude-fw` symlink, and `fw init` for the *next* project. Both are in-scope for
slice 1.

Original framing, kept for the record:

**IW-4 is deferred, deliberately.** Nobody has enumerated what depends on
`$HOME/.agentic-framework`. Known touch points: `fw upgrade` syncs to it (L-172),
`fw doctor` probes it, `bin/fw-router` falls back to it, `fw consumer-recover`
references it, and every existing consumer on this host was installed under the
current model. That survey bounds the migration cost and should run **before**
any build slice, not during one.

Existing installs must keep working — this is a change to how new projects are
created, not a demand that every current project be re-created.
