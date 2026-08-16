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
- **Cons:** does **not** fix rows 5/6, and makes them worse in a specific way —
  today a second principal gets a clean `EACCES`; group-writable, it gets a
  *successful* write that silently discards the other's state. Setgid inheritance
  also does not apply to files moved in from outside the tree, which is exactly
  how the temp+`mv` aggregates are written.

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

A is the unblock and is cheap. B is the correctness fix and is the one that
matters, because **A alone converts hard failures into silent ones**. Shipping A
without B would be a net reduction in observability, which is the antithesis of
Reliability (D2). That is the single most important sentence in this document.

1. **A-minimal now** — group + socket + `/var/lib/termlink` mode. Unblocks Codex
   today. Deliberately *minimal*: enough to restore local hub access, not the
   full-tree chgrp, because A-full's value drops sharply once E lands.
2. **E** — convert the dangerous set (shared + read-modify-write, per the IW-3
   inventory) to append-only + derived view. This is the spine.
3. **B** — per-principal split for what is genuinely per-principal (focus,
   counters, budget cache). Small once E has taken the shared aggregates out.
   T-3038 is the working template.
4. **Principal model (§5b)** — one identity spanning uid, `sender_id`, `origin`
   and focus key. Its own slice; the piece most likely to be skipped.
5. **Rail** — `fw doctor` checks for whatever of A survives, plus an assertion
   that no *shared* aggregate is read-modify-write. Note that E shrinks this rail
   rather than needing it: the more of the dangerous set becomes append-only, the
   less there is to detect drift in.
6. **C** — file in the TermLink repo, referencing this artifact.

**Gate on evidence before committing to the size of step 2.** The IW-3 inventory
and the IW-2 spike are running now. If the spike shows zero lost updates under
setgid, A becomes far more attractive and E can be scoped to the few genuinely
contended files. If it shows what §5A predicts, E is not optional.

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
