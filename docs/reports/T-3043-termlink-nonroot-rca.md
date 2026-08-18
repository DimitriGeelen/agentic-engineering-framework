# T-3043 — RCA: a non-root agent cannot use the TermLink hub

**Task:** T-3043 · **Date:** 2026-08-16 · **Host:** the AEF origin box
**Reporter:** a Codex agent running as `dimitri-mint-dev` (uid 1000)
**Related:** T-3041 (multi-principal inception), OBS-296 (hub split-brain), OBS-297 (unreachable `fw-approve`)

---

## 0. Summary

A Codex agent running as uid 1000 cannot perform channel RPC against the TermLink
hub on its own host. Over the session the symptom **changed twice**, and each
change was diagnostic:

| Stage | Symptom | What it proved |
|---|---|---|
| 1 | `Permission denied (os error 13)` | `connect()` refused — filesystem, before any protocol |
| 2 | `Permission denied (os error 13)` after `chgrp` | group set, but write bit still absent |
| 3 | **`Connection reset by peer (os error 104)`** at mode `770` | `connect()` **succeeded**; the hub dropped the peer *after* accept |

Stage 3 is the real finding. **Two distinct defects were stacked**, and fixing the
first exposed the second:

- **Defect A (filesystem, workaroundable here):** the hub socket is created
  `0755 root:root`. Connecting to a Unix socket requires the **write** bit, so
  every non-root uid is refused at `connect()`.
- **Defect B (hub-internal, upstream):** with the write bit present, a uid-1000
  client connects and is then **reset by the hub**, while a uid-0 client running
  the identical RPC against the *same socket, same hub, same second* succeeds.

Defect B is the one that matters. Defect A is a `chmod`; Defect B means local
authorization is uid-coupled *inside* the hub — the same structural fault T-3041 §2
describes, and it cannot be fixed from this repository.

**Verified 19:25:11, uid 0, against the live socket:**

```
$ termlink channel list
  agent-chat-arc  [messages:1000]
  broadcast-chat  [messages:5000]
  broadcast:global  [messages:1000]
  channel:learnings  [forever]
  framework:pickup  [messages:5000]
exit=0
```

The same class of call from uid 1000, seconds earlier: `Connection reset by peer`.

---

## 1. System state at time of failure

### 1.1 Three hub processes, one runtime directory

```
PID      USER              STARTED    COMMAND
3093442  root              14:24:44   termlink hub start --tcp 0.0.0.0:9100 --json
3869961  root              16:52:36   termlink hub start
4086784  dimitri-mint-dev  14:47:02   termlink hub start
```

- **3093442** is the fleet hub. It owns `LISTEN 0.0.0.0:9100` (confirmed by `ss`)
  and serves remote peers over TCP with HMAC.
- **3869961** was started *by this Claude session* at 16:52:36 and **took over the
  runtime directory** — `hub.pid` and `hub.sock` both carry mtime `16:52:37`,
  overwriting the 14:24 originals. The Unix socket therefore routes to this hub,
  not to the fleet hub.
- **4086784** is Codex's own hub, started when it could not reach an existing one.
  Its runtime dir is separate: `/tmp/termlink` (`drwxrwxr-x dimitri:dimitri`).

This is OBS-296's split-brain with the mechanism now visible: **the runtime
directory is a single unsynchronised slot, and the last `hub start` wins it.**
Nothing detects the takeover. The displaced hub keeps running and keeps serving
TCP, so from outside, everything looks healthy.

### 1.2 Ownership of the runtime tree

```
dimitri-mint-dev:dimitri-mint-dev 700  /var/lib/termlink
root:dimitri-mint-dev             755  /var/lib/termlink/hub.sock
dimitri-mint-dev:dimitri-mint-dev 700  /var/lib/termlink/sessions
dimitri-mint-dev:dimitri-mint-dev 775  /var/lib/termlink/bus
root:root                         644  /var/lib/termlink/hub.pid
root:root                         600  /var/lib/termlink/route-cache.json
root:root                         644  /var/lib/termlink/rpc-audit.jsonl
```

**Ownership is interleaved between two uids inside one directory.** The directory
and `sessions/` belong to uid 1000 at mode `700`; the socket, pidfile, route cache
and audit log belong to root. This functions today only because root bypasses DAC —
a root-owned hub is writing into a `0700` directory it does not own. Reverse the
roles and it fails immediately. There is no configuration in which this tree is
coherent; it is an artefact of two hubs having written into it in turn.

`hub.secret` is **absent** from this directory.

---

## 2. The connection sequence, and where it breaks

A local client reaching the hub over the Unix socket passes four gates. The two
reported errors map cleanly onto the first two.

```
  client (uid N)
      │
      │  ① resolve runtime dir  ─────────────────►  /var/lib/termlink
      │       (env / default; last `hub start` owns it)
      │
      │  ② connect(AF_UNIX, "/var/lib/termlink/hub.sock")
      │       KERNEL CHECK: needs WRITE permission on the socket inode
      │       └─ fails ⇒ EACCES (13) ....................... DEFECT A
      │
      │  ③ hub accept() + peer admission
      │       hub-internal; separates uid 0 from uid 1000
      │       └─ fails ⇒ peer closed ⇒ ECONNRESET (104) .... DEFECT B
      │
      │  ④ method dispatch (channel.list / agent.presence)
      ▼       reached only by uid 0 today
```

### Gate ② — why `0755` refuses every non-root uid

This reads as a surprise and is in fact the documented POSIX rule. For a Unix
domain socket, `connect(2)` requires **write** permission on the socket file. Read
and execute are irrelevant.

```
srwxr-xr-x   root  root
 │  │  └── others:  r-x   → no w → connect() = EACCES
 │  └───── group:   r-x   → no w → connect() = EACCES
 └──────── owner:   rwx   → w    → connect() = OK   (root only)
```

So `0755` is not "world-accessible" for a socket — it is **owner-only**, wearing
the mode bits of something that looks permissive. That mismatch between what the
mode *reads* as and what it *grants* is why the peer's first diagnosis ("the hub's
channel authorization/ownership boundary") was reasonable and wrong: the failure
surfaced through an RPC call, but occurred before a byte of protocol was exchanged.

Group membership confirms the group route is viable:

```
$ id dimitri-mint-dev
uid=1000(dimitri-mint-dev) gid=1000(dimitri-mint-dev)
groups=1000(dimitri-mint-dev),0(root),27(sudo),985(ollama),986(docker),…
```

### Gate ③ — the defect that survives the chmod

At mode `770` with group `dimitri-mint-dev`, gate ② passes: `connect()` returns
success. The client then receives `ECONNRESET` — the hub accepted the peer and
closed it. Meanwhile uid 0 completes the identical RPC.

`rpc-audit.jsonl` shows successful `channel.subscribe` calls throughout the same
window, all from sender `d1993c2c3ec44c94` (this session's root clients):

```
{"ts":1786901041767,"method":"channel.subscribe","from":"d1993c2c3ec44c94","peer_pid":3734556,"topic":"agent-chat-arc"}
{"ts":1786901101895,"method":"channel.subscribe","from":"d1993c2c3ec44c94","peer_pid":3739226,"topic":"agent-chat-arc"}
```

**No rejected uid-1000 connection appears in the audit log at all.** The peer is
dropped before it becomes an auditable RPC — so from the hub's own records the
failure is invisible. An operator reading `rpc-audit.jsonl` would conclude the hub
is healthy and that Codex never called.

---

## 3. The permission model, and why it has a hole by construction

TermLink carries **two authorization models**, and only one is identity-based:

| Transport | Admits you if | Basis | Principal-aware? |
|---|---|---|---|
| TCP `:9100` | you present the fleet secret | HMAC | **yes** — any host, any uid |
| Unix socket | your uid can write the socket inode | POSIX mode | **no** — uid-coupled |

Nothing reconciles them. The answer to *"who may talk to this hub locally"* is
decided by whichever uid ran `hub start` and what umask it had — not by any
credential, and not by anything an operator declared.

**The inversion is the tell.** A machine across the network authenticates into this
hub successfully, while a process on the same box, owned by the operator, cannot.
Whenever remote access is easier than local access, the local path is not using the
auth model — it is using the filesystem.

### 3.1 Why this guarantees fragmentation rather than merely permitting it

A client that cannot reach a hub does not fail loudly. **It starts its own.** That
is not a fallback anyone designed; it is the observed behaviour, and it produced
the three-hub state in §1.1. So the failure mode is not "an agent is blocked" — it
is "an agent silently forms a second, isolated fleet", which is strictly worse,
because from inside each partition everything appears to work.

With two uids present, fragmentation is the *default* outcome, not an unlucky one.

### 3.2 Why `chmod` cannot be the fix

Three independent reasons, in increasing severity:

1. **It does not survive socket recreation.** `hub start` recreates `hub.sock`
   under the starting process's umask. Every hub restart resets the mode.
2. **It was observed reverting within this session.** See §4.1 — the mode returned
   from `770` to `755` at 19:24:19 *without* the socket being recreated.
3. **It does not fix gate ③ anyway.** The decisive one. The `770` window proved
   that correcting the filesystem merely advances the failure from `EACCES` to
   `ECONNRESET`. The uid-coupling that matters is *inside the hub*.

---

## 4. The unresolved links — stated, not guessed

Two facts are not established. Both are recorded as open rather than filled with a
plausible story, because two confident root causes were already wrong earlier in
this incident (§6).

### 4.1 What reset the socket mode at 19:24:19

Measured:

```
mtime = 2026-08-16 16:52:37   (socket created — unchanged)
ctime = 2026-08-16 19:24:19   (metadata changed ~50s before observation)
```

`mtime` unchanged proves the socket was **not** recreated; only its metadata
changed. So an explicit `chmod` occurred at 19:24:19.

What is known:
- It was **not** `termlink hub status` — tested directly, ctime unchanged across it.
- It was **not** the reporting agent: only the file's owner (root) or a privileged
  process may `chmod` it. From uid 1000 the call returns `EPERM` without altering
  the inode.
- Therefore **a root process performed it**, during the window in which the peer
  ran `hub status && agent presence && discover`.
- It has not recurred; several root RPCs after 19:24:19 left ctime untouched, so it
  is not a per-connection re-assertion.

The candidate explanation is that some hub-side path re-asserts socket permissions
on a particular event rather than on every connection — but the hub's source is not
in this repository, so this is **not concluded**. Resolving it requires reading the
TermLink bind path, or watching the inode (`inotifywait -m /var/lib/termlink`)
across a reproduction.

### 4.2 What the hub checks at gate ③ — narrowed to one surviving explanation

**Updated after the operator applied `0770`.** With the mode corrected, gate ③
became reproducible on demand via `sudo -u dimitri-mint-dev`, which removed the
dependency on the peer reporting back and allowed the alternatives to be tested
against each other.

Reproduction (mode confirmed `770 root:dimitri-mint-dev`):

```
$ sudo -u dimitri-mint-dev termlink channel list
Error: Hub rpc_call failed
Caused by:
    0: I/O error: Connection reset by peer (os error 104)
exit=1
```

**Measurements that eliminate the alternatives:**

| Hypothesis | Test | Verdict |
|---|---|---|
| Secret-based handshake root can satisfy | `hub.secret` absent; root's env carries only `TERMLINK_RUNTIME_DIR`, no secret/token | **eliminated** — root holds no credential either, yet root succeeds |
| Group-based authorization | `id dimitri-mint-dev` → member of **gid 0 (root)**; still reset | **eliminated** — a gid check would admit this peer |
| Channel-specific authorization (peer's original theory) | `channel list` *and* `topics` both fail, and **neither produces an audit line** | **eliminated** — not method-specific; nothing reaches dispatch |

The surviving explanation is a **peer-credential check on uid equality** —
`SO_PEERCRED` at accept, admitting only the uid that owns the hub. It is the only
candidate consistent with all four observations simultaneously: rejection before
method parse (no audit record), uid 0 admitted, gid 0 membership insufficient, and
no credential material anywhere on the host.

**This is inference from behaviour, not from source.** Confidence is now high
rather than absent, but the claim that closes it is a read of the TermLink accept
path, which is out of scope here per gap-homing (T-1333). Recorded as narrowed,
not as resolved.

#### 4.2a RESOLVED — confirmed from source by the TermLink agent, 2026-08-18

Closed the same day, not by us reading their source but by asking. Put to the
TermLink agent on `agent-chat-arc` offset 102; answered at offset 105 (their task
T-2791) with citations:

```
server.rs:743   let owner_uid = libc::getuid()
server.rs:766   decide_unix_peer(PeerCredentials::from_tokio_stream(&stream), owner_uid)
                Reject => warn + refuse + continue
server.rs:813   same-uid => PermissionScope::Execute
tests    :1929  same uid accepts
         :1944  different uid rejects
         :1959  cred-extraction failure rejects (fail-closed, their T-2448)
```

Their words: *"You inferred a peer-credential check on uid equality with the hub
owner. That is exactly what it is."* All four eliminations in the table above held.
`connect(2)` succeeds because the kernel reads only the inode mode; the hub then
reads `SO_PEERCRED` and drops any peer whose uid is not its own.

**Two things this changes, both of which we had wrong:**

1. **`SO_PEERCRED` is already there** — since their T-1407, made fail-closed by
   T-2448. Our §7 recommendation to "add `SO_PEERCRED`" was a no-op and actively
   misleading; it would have sent an implementer to an existing line. The finding
   sharpens rather than dissolves: the hub identifies its peer precisely, and
   `peer_uid == owner_uid` **is the entire policy** — no allowlist, no principal
   table, no policy surface. One uid admissible, every other refused, nothing
   between. The gap is a policy surface, not a syscall.
2. **Our ECONNRESET observation is version-dated.** Their T-2772 replaced the bare
   `continue` with a structured `AUTH_DENIED` envelope written to the refused party;
   the comment at `server.rs:783-789` names our exact symptom as what it fixed. But
   T-2772 sits among 338 commits on a branch never merged to `main`, and
   `/opt/termlink` serves `main`.

| | Version | Behaviour |
|---|---|---|
| What we measured | 0.11.693 (`/usr/local/bin/termlink`, per T-1438 heartbeat) | silent reset, nothing written |
| Their working tree | 0.11.1537 | structured `AUTH_DENIED` |
| **What this host runs** | **`main`** | **without T-2772** |

So the observation is accurate for the binary anyone here would hit, and inaccurate
against current upstream source. Both halves matter: reproduce it and you see it;
read their source and you do not. **Our share of that** — we reported observed
behaviour without recording the binary's version, leaving the upstream agent to
establish the dating for us. Captured as **L-626**: the version stamp is part of the
evidence, not metadata about it.

**Also disqualifies option 1 a second time, independently.** `server.rs:813` grants
every admitted Unix peer full `PermissionScope::Execute`, and `hub.secret` is no
better because the client mints its own scope from it (`auth.rs:453`). A "narrow
socket ACL" is not narrow — there is no narrow grant available to give. Our own
rejection was on measured lost updates; theirs is on scope. Neither depends on the
other.

### 4.3 The client masks the failure — a finding, not a footnote

Discovered while testing 4.2, and it changes how this whole incident reads.

**As uid 1000, `termlink topics` printed `No event topics found.` and exited 0 —
while producing zero lines in `rpc-audit.jsonl`.** The RPC never reached the hub.
An empty result and an unreachable hub are rendered identically.

Control, same socket, seconds apart:

```
root:  termlink channel list → exit 0, audit gains
       {"method":"channel.list","from":"d1993c2c3ec44c94","peer_pid":3996231}
uid1000: termlink topics, channel list → audit unchanged (411 → 411)
```

Worse, most commands never touch the hub at all. Classified by whether they
require RPC:

| Command | uid 1000 result | Actually reaches hub? |
|---|---|---|
| `hub status` | `Hub: running (PID 3869961)` | **no** — reads `hub.pid` |
| `list` | full session table | **no** — reads `sessions/` |
| `doctor` | mostly green | **no** — filesystem checks |
| `whoami` | lists candidate sessions | **no** — reads `sessions/` |
| `topics` | `No event topics found.` | **no** — *and says nothing about it* |
| `channel list` | `Connection reset by peer` | **yes** — the only honest one |

**So a non-root agent sees a fully working TermLink** — hub running, sessions
enumerated, doctor green — while its hub communication is uniformly zero. This is
precisely how the peer arrived at *"current runtime permissions are now correct for
this user… the remaining fault is inside the running hub's channel RPC handling"*:
that conclusion was drawn from `hub status`, `presence` and `discover`, and **every
one of those was a filesystem read.** The diagnosis was reasonable given the
evidence available, and the evidence available was misleading by construction.

Same false-green class as the port-3000 verification lines (CLAUDE.md §Watchtower
Port): a check that cannot fail is indistinguishable from one that passes.
Registered as **OBS-302**; homed upstream per T-1333.

**Mechanism, supplied upstream 2026-08-18 (their T-2791) — one line.**
`discovery.rs:81-87` `all_sessions_dirs()` filters `.filter(|d| d.is_dir())`,
doc-commented as avoiding noisy `read_dir` errors. `Path::is_dir()` returns **false
on EACCES**, so to uid 1000 a `0700` root-owned runtime dir is indistinguishable
from one that does not exist. With `TERMLINK_RUNTIME_DIR` set, `all_runtime_dirs()`
returns exactly that dir (`discovery.rs:44-47`, exclusive override), the filter
drops it, zero sessions are probed, and `events.rs:1220-1230` prints the bare
`No event topics found.` with `Ok(())`.

**The structured surface is worse than the human one.** Their partial-inventory
fields count *probe* failures, not *discovery* failures, so JSON mode emits
`{"ok":true,"total_topics":0,"sessions_probed":0,"sessions_skipped":0}` — a positive
assertion that the inventory is complete and empty. Anything automated against that
surface is told with more confidence than a human is told. Fix in progress upstream
under T-2791.

This is the sharpest available statement of the false-green class: the same call
returns a *more* trustworthy-looking answer the *more* machine-readable it gets.

---

## 5. Why the framework allowed this (G-019)

The mechanical fault is TermLink's. The reasons it went undetected for the length
of this session are ours.

1. **A compound one-liner was handed off and its result never verified.** The
   unblock was issued as `chgrp … && chmod …`. The first half applied, the second
   did not. The agent then treated *"the operator ran it"* as *"the socket is
   fixed"* and reported it unblocked without re-reading the mode — a `stat` costing
   nothing. The peer was left to rediscover the same failure.
   **A handed-off command is not done until its post-state is read back.**

2. **`fw doctor` has no probe for the substrate this framework dispatches
   through.** It checks that the `termlink` binary exists (`fw termlink check`). It
   does not check that the hub is reachable, that exactly one hub owns the runtime
   directory, or that the socket is connectable by the uids expected to use it.
   Every fact in this RCA came from ad-hoc `stat`, `ps` and `ss` — none of it is
   surfaced by any routine health check, which is why the three-hub state persisted
   for over four hours with no signal.

3. **The hub's own audit log makes the failure invisible.** Rejected peers are
   dropped before they become RPC records, so `rpc-audit.jsonl` shows only
   successes. The log an operator would reach for confirms health *during* the
   outage. Same false-green class as the port-3000 verification lines (CLAUDE.md
   §Watchtower Port): a check that cannot fail is indistinguishable from one that
   passes.

4. **`.context/message-archive/**` has no in-repo writer** (T-3041 IW-3 §5,
   undetermined). Peer messages arrive through a substrate the framework neither
   monitors nor can introspect — which is why message loss across these hubs was
   first attributed to a missing topic before being traced to split-brain
   (OBS-296).

---

## 6. Corrections to earlier diagnoses in this incident

Recorded because the pattern — a confident root cause that fits the visible symptom
and is wrong — recurred three times, and the sequence is itself evidence.

| # | Claimed | Actual |
|---|---|---|
| 1 | "Messages lost because the local hub had no `framework:pickup` topic" | Hub split-brain. The "fix" was verified against a hub peers could not reach — which is exactly why verification passed while the problem persisted (OBS-296). |
| 2 | *(peer)* "The hub's channel authorization/ownership boundary" | A filesystem permission on the socket inode, surfacing through an RPC call. Reasonable from the error text, and wrong. |
| 3 | *(this agent)* "`chgrp` + `chmod` unblocks it" | Only `chgrp` applied; and once `chmod` did apply, the failure moved to gate ③ rather than clearing. The unblock was necessary and **not sufficient** — asserted without test. |

The common thread: **each diagnosis explained the error text and none tested the
layer below it.** The discipline that would have caught all three is the same one —
after any fix, read the post-state directly instead of inferring it from the
absence of the previous error.

---

## 7. Recommendations

Ordered by whether they can be done here.

### Ours

1. **`fw doctor` gains a TermLink substrate probe.** Assert: exactly one hub owns
   the runtime directory; `hub.pid` matches a live process; the socket is
   connectable; the runtime tree is not split across uids. Any of those failing is
   a WARN today, and would have surfaced the three-hub state at 14:47 rather than
   19:25. **Highest-value item in this document** — every other finding here was
   invisible to routine tooling.
2. **Never hand off a compound `&&` privileged one-liner without a read-back.**
   Either issue one command at a time, or append the verification (`… && stat -c
   '%a %U:%G' <path>`) so the operator's terminal shows the post-state. Applies to
   any Tier-0-adjacent handoff.
3. **Do not conclude "fixed" from the disappearance of an error.** A *changed*
   error is progress, not resolution. Assert the positive: run the operation that
   was failing, as the principal that was failing.

### Upstream (TermLink repo — gap-homing T-1333)

4. **Give the accept path a policy surface.** *(Corrected 2026-08-18 — see §4.2a.
   The original wording, "`SO_PEERCRED` at accept", was wrong: it is already there,
   `server.rs:767`, since their T-1407.)* The hub identifies its peer exactly right
   and then has one predicate to apply — `peer_uid == owner_uid`. What is missing is
   an allowlist / principal table, i.e. somewhere for the answer "which uids are
   admissible" to be *expressed*. Alternatively drop the Unix socket and have local
   clients use loopback TCP with the same HMAC the fleet already uses, which reuses a
   policy surface that already exists instead of inventing one — now the stronger of
   the two. Either removes gate ②'s uid-coupling *and* gate ③'s asymmetry. This is
   Candidate C in T-3041.
5. **Refuse to steal an owned runtime directory.** `hub start` should detect a live
   hub via `hub.pid` and either attach or fail loudly. Silent takeover is what made
   §1.1 possible.
6. **Audit rejected peers.** A dropped connection should produce a record carrying
   the peer's uid/pid and the reason. Without it the hub's log actively misleads
   during exactly the failure it should explain. *(Partially addressed upstream
   already: their T-2772 writes a structured `AUTH_DENIED` envelope to the refused
   party. It is on an unmerged branch, so it is not in what this host runs — §4.2a.
   The recommendation stands for the audit **log**, which T-2772 does not touch.)*

### Operator, immediate

The current unblock, with verification attached rather than assumed:

```
sudo chmod 0770 /var/lib/termlink/hub.sock && stat -c '%a %U:%G %n' /var/lib/termlink/hub.sock
```

Expect `770 root:dimitri-mint-dev`. **This restores gate ② only.** Gate ③ will
still reset uid-1000 clients, so expect `Connection reset by peer` rather than
success — that is the upstream defect and is not fixable from here.

**Applied and confirmed 2026-08-16 19:37.** Mode is now `770 root:dimitri-mint-dev`
and the predicted outcome held exactly: `sudo -u dimitri-mint-dev termlink channel
list` → `Connection reset by peer`. The chmod is correct and insufficient, as
stated. Its real value was diagnostic — it made gate ③ reproducible locally (§4.2),
which is what allowed the secret, group and channel-authorization hypotheses to be
eliminated against each other rather than argued about.

**Interim workaround until the upstream fix lands.** Since the barrier is uid
equality with the hub owner, a non-root agent can be given a hub it owns:

```
TERMLINK_RUNTIME_DIR=/tmp/termlink termlink hub start      # as the agent's own uid
```

This is what Codex's hub (PID 4086784) already is. It works, and it is **exactly
the fragmentation described in §3.1** — an isolated second fleet that looks healthy
from inside. Use it only as a deliberate, time-boxed stopgap, never as the
arrangement, and never for anything that must reach the fleet hub on `:9100`.

---

## 8. Evidence index

| Claim | Command | Result |
|---|---|---|
| Socket refuses non-root at connect | `ls -l /var/lib/termlink/hub.sock` | `srwxr-xr-x root dimitri-mint-dev` — no group `w` |
| Mode changed without recreation | `stat -c '%y %z'` | mtime `16:52:37`, ctime `19:24:19` |
| `hub status` did not reset the mode | ctime captured across the call | unchanged |
| Root succeeds on the same socket | `termlink channel list` | 5 channels, `exit=0` |
| Group route is viable | `id dimitri-mint-dev` | member of gid 1000 |
| Three hubs live | `ps -eo pid,user,lstart,args` | 3093442 / 3869961 / 4086784 |
| Fleet hub owns the TCP port | `ss -tlnp \| grep 9100` | `pid=3093442` |
| Runtime dir split across uids | `stat -c '%U:%G %a'` | dir+sessions uid 1000; socket/pid/audit root |
| No rejected peers audited | `tail rpc-audit.jsonl` | successes only, all from root sender |
| `hub.secret` absent | `ls -l …/hub.secret` | `No such file or directory` |
