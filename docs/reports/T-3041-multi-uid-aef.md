# T-3041 — AEF under multiple uids: de-rooting the framework's shared state

**Status:** inception, in progress
**Filed:** 2026-08-16
**Trigger:** a non-root Codex agent could not reach the TermLink hub on its own host,
while a *remote* host over TCP authenticated in fine.

---

## 1. The observation that started this

The framework was built, and has run for its entire life, as `root`. Every
assumption about who can write what has been true by accident: there is only one
principal, and it can write everything.

That assumption broke visibly today. A Codex agent running as `dimitri-mint-dev`
hit `Permission denied (os error 13)` on `channel.list` against the local hub.
The agent's own diagnosis was "the hub's channel authorization/ownership
boundary" — reasonable, and wrong. The truth was one `ls`:

```
srwxr-xr-x 1 root root  /var/lib/termlink/hub.sock
```

Connecting to a Unix domain socket requires the **write** bit. Only `root` had it.

**The inversion is the tell.** A machine on the other side of the network could
authenticate into that hub with the fleet secret, while a process on the same
box, owned by the operator, could not. Any time remote access is easier than
local access, the local path is not using the auth model — it is using something
else. Here that something else is the filesystem.

## 2. Why this is structural and not a chmod

TermLink carries **two authorization models**, and only one is principal-based:

| Transport | Allowed if | Basis | Agnostic? |
|---|---|---|---|
| TCP `:9100` | you hold the fleet secret | HMAC | yes — any host, any uid |
| Unix socket | your uid can write the socket file | POSIX mode | **no** — uid-coupled |

Nothing reconciles them. So the answer to "who may talk to the hub locally" is
decided by whichever uid started the hub and what umask it had.

### The fragmentation is emergent, not accidental

A client that cannot reach an existing hub does not fail loudly — it starts its
own. That is why this box now has **three**:

| PID | User | Runtime dir | Serves |
|---|---|---|---|
| 3093442 | root (systemd) | `/var/lib/termlink` | the fleet, TCP 9100 |
| 3869961 | root (this session) | `/var/lib/termlink` — hijacked the pidfile+socket | local root CLI |
| 4086784 | dimitri-mint-dev | `/tmp/termlink` | local Codex CLI |

Nobody misconfigured anything. **Fragmentation is the default outcome the moment
two agent runtimes run as different users** — which is now the normal case.
OBS-296 recorded the split-brain; this task records *why* it is inevitable
rather than unlucky.

## 3. Inventory of uid-coupled surfaces

The socket is the one that bit. It is not the only one.

| # | Surface | Coupling | Failure when a non-root agent arrives |
|---|---|---|---|
| 1 | TermLink hub socket | mode 755 root | cannot connect; starts a rival hub |
| 2 | `/var/lib/termlink` | `StateDirectoryMode=0700` | cannot traverse to the socket at all |
| 3 | Repo tree `/opt/999-…` | root-owned files | cannot write `.tasks/`, `.context/` |
| 4 | Git object store | objects owned by writer | `safe.directory` refusal; objects unwritable both ways |
| 5 | `.context/working/*` | single-writer files | focus, counters, budget cache collide |
| 6 | Aggregates rewritten temp+`mv` | `mv` replaces ownership | second writer locked out after first write |
| 7 | Append-only JSONL | — | **safe**: `O_APPEND` atomic under `PIPE_BUF` |
| 8 | Cron | per-user crontab | root's jobs invisible to the other principal |
| 9 | `/tmp/tl-dispatch/*` | root-owned worker dirs | cannot read its own dispatch result |
| 10 | Credentials | `/root/.git-credentials`, `~/.ssh` | per-user by design; needs an explicit story |
| 11 | Watchtower | runs as root, writes `.context/` | same as 3/5 |

Rows 5, 6, 9 and 11 are **inferred from the write pattern, not yet verified per
site** — that is IW-3, and the table should not be read as evidence until it is.

Row 7 is verified and matters. The append-only logs (`dispatches.jsonl`,
`dispatch-outcomes.jsonl`) are already multi-writer safe, and `lib/outcome.py`
documents the `O_APPEND` property explicitly. It was written for concurrent
*tasks*, not concurrent *uids*, but the property transfers unchanged.
**The parts of the framework designed for concurrency survive de-rooting for
free; the parts that assumed a single writer are exactly the parts that break.**

## 4. The precedent already in-tree (T-3038)

This session solved the same shape one layer up. Focus was per-project global
state, so a dispatched worker calling `fw context focus` stole the parent
session's focus and locked it out. The fix was not a lock — it was a split:

- **shared** file for the common case (`focus.yaml`, unchanged, still tracked)
- **per-principal** file when isolation is on (`focus.<key>.yaml`, gitignored)
- a **single shared resolver** (`fw_focus_file()`) so writer and reader cannot
  disagree, pinned by a test
- reader **falls back** to the shared file, so a principal that never set its own
  inherits rather than fails

The uid problem is the same problem with `uid` as the key instead of `session`.
Worth stating plainly: the design is not speculative, it has a working instance.

## 5. Candidates

### A. Shared POSIX group + setgid + umask — *substrate*

Group `aef`; every agent runtime user joins. Then `chgrp -R` the repo and
`/var/lib/termlink`; `chmod -R g+rwX`; **setgid every directory** so new files
inherit the group; `umask 0002` for all agent processes (systemd `UMask=`, shell
profile, hook wrapper); `git config core.sharedRepository=group`;
`StateDirectoryMode=0770` and the socket `chgrp`'d to the group.

- **Pros:** standard Unix answer; no framework code changes; fixes rows 1-4, 11.
- **Cons:** does **not** fix rows 5/6. **Measured — see §5c.** The spike confirmed
  the direction and then found something worse than this bullet originally
  claimed: for row 6, A **does not even deliver the shared write it is trading
  safety for.** `mktemp` hard-codes mode `0600` and `rename(2)` preserves it, so
  the aggregate lands `0600` owned by whichever principal wrote last and the other
  is locked out on its *next* write — whether or not the temp file was created
  inside the setgid tree. Setgid sets the group correctly and the mode denies it;
  `umask 0002` cannot help, because `mktemp` never offers a bit to clear.

  The original wording of this bullet — "today a second principal gets a clean
  `EACCES`" — was **overstated and is corrected in §5c**. It holds only for an
  unprivileged principal writing *uncontended*. Under real concurrency 82% of
  those failures are already torn reads, and when the second principal is `root`
  (the actual AEF situation) today's behaviour is *already* the silent lost
  update, because root bypasses DAC. A does not create the silent-loss mode; it
  generalises an existing one to both directions. Still a strict worsening, but
  not the clean loud→silent conversion this document first asserted.

  **Scope note:** this verdict is about applying A to the *repo tree*. It says
  nothing about **A-minimal** — `chgrp`+`chmod 0770` on `/var/lib/termlink/hub.sock`
  — which is a socket, not a read-modify-write file, and has no lost-update shape
  to worsen. A-minimal remains the correct unblock (row 1) and is unaffected.

### B. Per-principal state split — *framework*

Generalise T-3038: `.context/working/` becomes principal-scoped; shared
aggregates become append-only or per-principal shards merged on read.

- **Pros:** removes the contention instead of permitting it. Fixes 5/6.
- **Cons:** many call sites; needs a migration for existing state.

### C. Uniform auth in TermLink — *upstream*

Authorize local clients by `SO_PEERCRED` inside the hub, or drop the Unix socket
and have local clients use loopback TCP with the same HMAC.

- **Pros:** makes TermLink genuinely system-agnostic; kills rival-hub
  fragmentation at the root.
- **Cons:** **not ours to write.** Per gap-homing (T-1333) this belongs in the
  TermLink repo; filing it here creates a zombie entry nobody who could fix it
  will read.

### E. Make rows 5/6 look like row 7 — *change the data model, not the permissions*

The observation that reframes everything: **row 7 is already safe, and it is safe
for a reason that has nothing to do with permissions.** `dispatches.jsonl` and
`dispatch-outcomes.jsonl` are append-only event logs. Two writers cannot lose
each other's updates because neither ever reads-then-writes.

So the fix for the dangerous set is not to permit concurrent mutation more
politely (A) nor to partition it (B) — it is to **stop mutating**. Convert the
shared read-modify-write aggregates to append-only logs plus a derived view:

- `learnings.yaml`, `decisions.yaml`, `patterns.yaml` become
  `learnings.jsonl` (append) + a rebuilt-on-read or cron-materialised view.
- Writers only ever `O_APPEND` one record. Multi-writer safety is then a
  property of the format, not of the filesystem, the group, or a lock.
- Readers that want the aggregate get it from the derived view, which any
  principal may rebuild because rebuilding is idempotent and needs no lock.

**Pros:** correct under *any* uid arrangement, and under containers, remote
agents, and future principals we have not thought of. Needs no group, no setgid,
no umask discipline, and no `fw doctor` rail to detect drift — there is no drift
to detect. It also makes the aggregates auditable (who added what, when) which
they currently are not, and it composes with B rather than competing.
**Cons:** touches the read path of everything that consumes those aggregates;
needs a migration and a compatibility window. Larger than A, smaller than a
service.

### F. Single-writer state service — *one process owns the files*

All mutation goes through one daemon (Watchtower, or a new `fw stated`); agents
call an API. Uid-coupling disappears for rows 3, 5, 6, 11 because there is
exactly one writing uid.

**Pros:** eliminates the class outright; gives every mutation a caller identity.
**Cons:** a new SPOF, and it contradicts the framework's own premise — FRAMEWORK.md
sells a *file-based, CLI-capable* system whose portability (D4) rests on plain
files readable without a running service. A daemon that must be up before `fw
task update` works is a different product. **Recommend against** unless IW-1
comes back "fully non-root, containerised", where it becomes competitive.

### G. Per-principal worktrees — *isolate at the git layer*

`fw worktree create` already exists and the trunk-based flow already documents
fan-out-on-worktrees / fan-in-via-integrate. Give each principal its own
worktree; files are owned by whoever created it, so nothing is shared.

**Pros:** reuses machinery that is already built and already the documented flow
for parallel work.
**Cons:** solves the *working tree*, not `.context/working/` runtime state, and
pushes YAML aggregate contention into merge conflicts — which is arguably worse,
since a silent lost update becomes a noisy conflict on every close. Complementary
to E, not a substitute.

### D. Stay root-only

- **Pros:** zero work.
- **Cons:** every additional non-root agent fragments the substrate *silently*.
  The failure mode is not an error — it is a second hub, a second copy of state,
  and messages that vanish. That cost was already paid once today.

## 5c. Measured evidence (IW-2 spike, 2026-08-16)

Full report: `docs/reports/T-3041-lost-update-spike.md`. Two real uids (`root`,
`dimitri-mint-dev`), 200 iterations each, wall-clock barrier so the window is
genuine contention, 4 replications. Every number below is measured on this host.

| Exp | Shape | Config | Writes OK | Lost | Errors |
|---|---|---|---:|---:|---|
| E1 | in-place RMW (row 5) | group+setgid+umask | 50–216/400 | **file unparseable in 3 of 4 runs** | torn reads only, **0 `EACCES`** |
| E2 | temp+`mv` (row 6) | group+setgid+umask | **400/400** | **exactly 200, every run** | **none** |
| E3 | append-only JSONL (row 7) | *no group at all* | **400/400** | **0** | **none** |
| E4b | in-place RMW, no group | root writes dimitri's file | 290/400 | 90 | **none — 0 `EACCES`** |
| E4c | temp+`mv`, no group | root writes dimitri's file | 400/400 | **200** | **none**, then lockout |

Four findings, in order of how much they change the recommendation:

1. **E3 is the headline.** The append-only control was flawless with **no shared
   group, no setgid, no umask, no lock** — 400/400 lines, zero torn, zero lost,
   every line valid JSON. This is not an argument that E works; it is a
   measurement that E *already works*, in-tree, today. Candidate E is not a
   proposal to build something new. It is a proposal to apply the one shape the
   framework has already proved.

2. **Row 6's loss is silent, total, and exact.** 400/400 writes *succeed*. No
   error, no corruption, a file that parses cleanly — and one principal's entire
   200-write history simply absent. The `witness` map contained only the winner's
   key; the loser left no trace at all. This is the worst possible failure shape:
   indistinguishable from success at every observable surface.

3. **The problem is not hypothetical and does not wait for Candidate A.** E4b and
   E4c show today's un-grouped framework *already* losing 90 and 200 updates
   silently, because root's DAC bypass means it never sees `EACCES` on anyone's
   file. E4c then ends `0600 root:root` and locks the other principal out of every
   subsequent write. **Row 6's ownership-flip lockout is current behaviour**, not
   a side-effect of a change we are considering. Half the multi-uid matrix is
   already silently lossy with zero configuration.

4. **Root breaks the symmetry.** Any reasoning that treats "the second principal"
   as interchangeable will mispredict half the cases. The failure matrix is
   asymmetric because one principal bypasses the permission system entirely.

**Honest limits.** The spike's harness fails loudly on a torn read; the real call
sites do not — `agents/context/lib/pattern.sh` pipes through `awk`, which
processes a truncated file and exits 0. So E1's error counts are an **upper bound
on how loud the framework actually is**. Where the spike reports a parse error,
the framework reports nothing. Separately, both principals here were root plus one
unprivileged user; a two-*unprivileged*-principal case was not run (creating users
exceeded the scratch-only constraint). Probes P2/P3 exercise the decisive
group-mediated path directly, so the Candidate A verdict does not rest on the
missing case — but the E4b/E4c asymmetry findings are specifically *about* root
and do not generalise.

**What this changes.** E moves from "the better-shaped candidate" to "the only
candidate with a measured pass". A is now disqualified for rows 5/6 on evidence
rather than argument, and disqualified twice over — it fails to prevent the loss
*and* fails to grant the access. Row 5 is promoted from inferred to measured, and
upgraded: it **corrupts**, it does not merely lose.

## 5d. Sizing evidence (IW-3 static inventory, 2026-08-16)

Full report: `docs/reports/T-3041-write-site-inventory.md`. Two variable-resolving
scanners over `lib/`, `agents/`, `bin/`, `web/` and the hook scripts, then per-site
code reading. Every classification cites `file:line`.

| Category | Count |
|---|---:|
| **Dangerous — shared + read-modify-write, unprotected** | **27** |
| Per-principal RMW/truncate (different failure: wrong-agent state) | 27 |
| Already-safe append-only | 29 (28 clean + 1 interleaving exception) |
| Lock-protected (`flock` / `mkdir` test-and-set, shown not assumed) | 7 |
| Undetermined — listed as gaps rather than guessed | 11 |

**27 is the size of step 2.** That is the number E has to move, and it is
tractable — not the "everything under `.context/`" that the un-sized version of
this recommendation implied.

Three findings change more than the count:

1. **The `L-493` comment sweep is a false-safety surface — and it is the single
   biggest execution risk to this work.** ~24 sites carry
   `# T-100190/T-100191: same-dir temp + os.replace — atomic write (L-493 class)`.
   The origin (`agents/audit/audit.sh:5938-5940`) is explicit that the problem
   solved was *a cron audit killed mid-write*. That is **crash-atomicity**.
   `os.replace` guarantees a reader never sees a half-written file; it guarantees
   nothing about a lost update. Every one of those comments is true about crashes
   and silent about concurrency. Anyone triaging the dangerous set by grepping for
   that string will skip exactly the sites that need fixing. Registered **OBS-301**;
   the comment should be amended in place to *"crash-atomic; NOT concurrency-safe"*
   before any de-rooting work starts, not after.

2. **One of the 27 is a live single-uid bug and does not belong to this inception
   at all.** `lib/spawn.py:216-258` (`update_outcome_row`) reads all of
   `dispatches.jsonl` and `os.replace`s the whole file. A row appended by
   `lib/resolver.py:813` in that window is **erased**, not un-updated — violating
   the invariant `lib/outcome.py:177` documents and depends on. The framework runs
   up to 5 concurrent workers plus cron dispatchers, so the window is routinely
   open **today, as root, with no second principal involved.** The blast radius is
   the evidence base itself: CLAUDE.md's measured dispatch table is computed from
   this file. Registered **OBS-300**; needs its own task per one-bug-one-task.

3. **The safe multi-writer pattern is already in-tree and complete.**
   `lib/bus.sh:120-137` + `:198-204` — `mkdir` atomic test-and-set for id
   allocation, same-dir temp + `os.replace` for the payload — is a working
   multi-writer design written in ~2 dozen lines of shell for exactly this reason
   (T-605). So the dangerous set is not a design gap the framework has to solve
   from scratch. It is 27 sites that predate or bypassed a pattern that already
   works here.

Two smaller findings worth carrying into the build slices: `learnings.yaml` has an
**unguarded id race** (`corpus_max_id` read at `learning.sh:74`, `L-NNN` written at
`:139`, no lock — two principals mint the same id), and `bvp-weight-history.yaml`
is **documented append-only at `lib/bvp.sh:1434` but implemented as full
read-modify-write** — a doc/impl divergence that will cause it to be mis-triaged
as already-safe.

**Honest limit of the inventory.** 11 paths are undetermined and were listed as
gaps rather than guessed — including `.context/message-archive/**` (no in-repo
writer found, yet actively changing), and two SQLite DBs whose safety depends
entirely on journal mode and `busy_timeout`, neither of which is set in the code
read. The recall-telemetry file was left unclassified with the note that *"the
file name is not evidence"*. Those need runtime probes, not more static reading.

## 5e. IW-1 answered — and it invalidates this document's own title

**Operator, 2026-08-16 (verbatim):**

> *"in teh end state some agents might run as root but not per see as
> "principal" just because ist practical and tehy are isolated with elevated
> right like foir isntance ring20 amanger"*

Root stays as an **execution context**, not as an identity. Some agents will run
as root because it is practical and they are isolated with elevated rights —
ring20-manager being the concrete case.

**This is a stronger answer than either branch the question anticipated.** IW-1
offered "root stays a principal" or "no agent runs as root". The real answer is
that **root was never a principal**, and neither is any other uid:

> **uid ≠ principal. Several distinct principals will share uid 0.**

Three consequences, in increasing order of how much they change the work.

**1. Candidate A is now dead categorically, not just empirically.** §5c
disqualified A on measurement — it loses updates and does not even grant the
access it trades for. This is the deeper reason: POSIX can only distinguish
*uids*. If several principals share uid 0, then no permission model built on
uids and groups can tell them apart **even in principle**. A was answering a
question the system does not ask. A-minimal survives untouched, because it is not
an identity mechanism — it is one `chmod` on one socket.

**2. The evidence was already in hand, and I misread it.** §5b cites this
session's collision — an auto-dispatcher (`origin: systemd:unlabeled-unit`)
spawning a worker onto T-1719 while a human session was mid-edit on the same
files — as proof that AEF needs a principal model. **Both of those ran as root.**
Same uid, two principals, converging write set, nothing able to tell them apart.
The document is titled "under multiple uids" and the one live instance of the
failure it describes is *same-uid*. The uid problem is a **symptom of the missing
identity model, not its cause** — which is what the operator's answer says, and
what the trigger bug obscured by arriving as a permission error.

**3. IW-7 is promoted from deferred to load-bearing, and its scope is now
determined.** It was deferred pending IW-1 for scope. IW-1 has now supplied it:
the principal key **cannot be the uid**, so AEF must carry its own principal
notion — there is no filesystem answer available to fall back on. Note that
T-3038 already got this right by accident: it keyed focus isolation on *session*,
not uid. That is the correct axis, and it is the working template.

**What does not change: the recommendation.** E is append-only, and append-only
does not care who writes — that property holds across uids, across containers,
across principals sharing a uid, and across principals we have not invented yet.
Choosing E over A on §5c's evidence turns out to have been robust to this answer
arriving afterwards. B does change shape: "per-principal state" must be keyed on
the principal identity of step 4, **not** on uid — so B now depends on step 4
rather than running beside it.

**Terminology note.** "multi-uid" in this document's title and throughout §1-§4 is
a misnomer, kept because the artefact is cited by task and commit history. Read it
as **multi-principal** everywhere. The uid case is one instance.

## 5b. The identity question underneath all of this

Every candidate above treats the symptom. The cause is that **AEF has no concept
of an agent principal.** It has, instead, four ad-hoc ones that grew separately:

| Existing notion | Where | What it identifies |
|---|---|---|
| OS uid | everywhere, implicitly | who may write a file |
| `sender_id` fingerprint | TermLink (`d1993c2c3ec44c94`) | who posted a message |
| `origin` | `dispatches.jsonl` (`systemd:unlabeled-unit`) | what launched a dispatch |
| session / focus key | T-3038 `focus.<key>.yaml` | which session holds focus |

These four never reconcile. Today's collision proves it: an auto-dispatcher with
`origin: systemd:unlabeled-unit` spawned a worker onto T-1719 while a human
session was mid-edit on the same files, because *nothing in the system could tell
that those were two principals with a converging write set.* That is the same
defect as the uid problem, one layer up — and no amount of POSIX group work
touches it.

**The uid problem is a forcing function, not the problem.** Whatever we build for
file access should be an instance of one principal model, not a fifth ad-hoc
identity. Concretely: a principal has an id, an OS uid it runs as, a home for its
per-principal state, and it appears in dispatch rows, bus messages, focus keys,
and audit entries as the *same* id.

This is worth its own slice, and it is the piece most likely to be skipped
because the socket fix feels like the whole job.

## 6. Recommendation

**GO — E as the spine, A-minimal as the unblock, B where E does not reach;
C upstream; F rejected unless IW-1 says "fully containerised".**

Revised after writing §5b and §5E. The first pass recommended A+B, which
anchored on permissions because the triggering bug was a permission. That framing
was too narrow: A and B both *manage* concurrent mutation, while E *removes* it.
Row 7 is already multi-writer safe with no group, no lock and no rail — the goal
should be to make the dangerous set resemble row 7, not to make the filesystem
tolerate it.

**Now confirmed by measurement (§5c), with one correction.** The IW-2 spike ran
and A is disqualified for rows 5/6 on evidence: temp+`mv` under group+setgid
silently discarded exactly 200 of 400 updates in every run, with 400/400 writes
reporting success — and it did not even grant the shared write it was trading
that safety for (`mktemp` hard-codes `0600`; `rename(2)` preserves it). The
append-only control passed 400/400 with zero loss and **no group at all**.

The correction is to this document's own claim. "A alone converts hard failures
into silent ones" is too strong: E4b/E4c show the framework is *already* losing
updates silently today, whenever root is the writer, because root bypasses DAC. A
does not create that mode — it generalises it to both directions. Still a strict
worsening, and A-full for the tree is still rejected; but the honest statement is
that **we are not protecting a working system, we are fixing one that is already
silently lossy in half the matrix.** That raises the urgency of E rather than
lowering it.

1. **A-minimal now** — group + socket + `/var/lib/termlink` mode. Unblocks Codex
   today. Deliberately *minimal*: enough to restore local hub access, not the
   full-tree chgrp, because A-full's value drops sharply once E lands.
2. **E** — convert the dangerous set (shared + read-modify-write, per the IW-3
   inventory) to append-only + derived view. This is the spine.
3. **Principal model (§5b, §5e)** — one identity spanning `sender_id`, `origin`,
   the T-3038 focus key and the OS uid. **Promoted ahead of B by IW-1's answer**
   (§5e): since several principals share uid 0, "per-principal" has no meaning
   until there is a principal key, and it cannot be the uid. T-3038 keyed on
   *session* rather than uid and is the working template. Still the piece most
   likely to be skipped — and now the one that blocks the next step if it is.
4. **B** — per-principal split for what is genuinely per-principal (focus,
   counters, budget cache). Small once E has taken the shared aggregates out, but
   it now **depends on step 3** rather than running beside it: it needs the key.
5. **Rail** — `fw doctor` checks for whatever of A survives, plus an assertion
   that no *shared* aggregate is read-modify-write. Note that E shrinks this rail
   rather than needing it: the more of the dangerous set becomes append-only, the
   less there is to detect drift in.
6. **C** — file in the TermLink repo, referencing this artifact.

**Evidence gate — resolved, both legs.** IW-2 (§5c) did *not* show zero lost
updates, so the branch where A becomes attractive is closed: **E is not optional.**
IW-3 (§5d) sizes it: **27 sites**, against an in-tree pattern (`lib/bus.sh`) that
already works. Step 2 is bounded work, not open-ended.

Two things jump the queue ahead of step 1, because they are true today with a
single uid and get worse the longer they sit:

- **Amend the ~24 `L-493 class` comments** to say *crash-atomic; NOT
  concurrency-safe* (OBS-301). This is nearly free and it is the difference
  between the 27-site sweep being done correctly and being done by grep.
- **Fix `lib/spawn.py:216-258`** (OBS-300) — it is erasing dispatch rows now, in
  the ledger this framework's own dispatch guidance is measured from. It is not a
  de-rooting task and should not wait for one.

Step 5 is what makes this antifragile rather than a one-time cleanup — but the
better outcome is a design that needs less of it.

## 7. Open questions

Filed as IW-1..IW-5 on T-3041. IW-1 (which users are principals; is `root` one of
them) is operator-only and forks everything downstream, so it is not guessed.

---

## Dialogue Log

**2026-08-16 — operator, verbatim:** *"ok so here we learn somethin new::: WE are
now working under root, all our session are whole aef has been build with full
root prm, we now move away from that and we find agents that dont run from root
account , this is such a case. how do we make this strucvturally work ?!"*

The operator generalised from a single instance and rejected the framing of it as
a permissions accident. Prior to this the agent had treated the socket mode as a
local fix to hand over. The reframe *is* the substance: the finding was not "the
socket is 755", it was "the framework has a single-principal assumption baked in
everywhere and is now leaving that world".

**Earlier in the same session:** the operator pushed back repeatedly on friction —
classifier blocks on `chmod`, then on writing the allow rule that would have
permitted the `chmod`. Relevant as evidence for IW-4: a design that *requires*
the agent to provision host state is already known to fail in practice, because
the agent could not perform either action and had to hand both to the operator.

**Correction recorded against the agent:** earlier in this session the agent told
the operator the peer-message loss was caused by a missing `framework:pickup`
topic. That was incomplete — the cause was the hub split-brain (OBS-296), which
is itself a symptom of the uid-coupling described here. The agent verified its
"fix" against the hub peers cannot reach, which is why the verification passed
and the problem persisted.
