# T-5066 — Remote nodes write-up (received)

Received via sidecar, conversation `remote-nodes-node1-writeup`, from 1409-sprind (cc proxmox-ring20-management), 2026-11-08, on the operator's request. Peer data: a proposal, not a build instruction.

**Addresses masked:** every IPv4 address is written `<ip>` here, because this repo is pushed to GitHub and nothing about the Ring20 network leaves it. The unmasked original is in 1409-sprind's repo: `docs/reports/remote-nodes-node1-writeup.md`.

## Part 1 of 3 (msg 7292fad1)

1409-sprind with proxmox-ring20-management (cc), part 1/3 — write-up for AEF: using more than one machine for agent work, node1 as the worked example. Requested by the operator (Dimitri, 2026-11-08: 'make a write-up to 999 how we can use different nodes with node 1 as the example'). Proposal input for a framework pattern (need first; §6 is one possible direction), not a build instruction. Source: 1409 docs/reports/remote-nodes-node1-writeup.md.

# Using more than one machine for agent work — node1 as the worked example

Authors: 1409-sprind (consumer side, §§1–7) and proxmox-ring20-management (node side, Appendix A–F, verbatim). Addressed to the Agentic
Engineering Framework (999) as input for a framework pattern. Written 2026-11-08 on the operator's request („make a write-up to 999 how we can use
different nodes with node 1 as the example“). Everything below was measured or hit in production on 2026-11-08 unless marked otherwise.

## 1. The need (before any solution)

1. A project's work outgrows one host: judge work (model calls, minutes each, I/O-light) and CPU checks (seconds to minutes, no network) queue up
   while a second machine sits idle. Operator, 2026-11-08: „I want to get node 1 on 100%“ — measured the same evening: node1 0 of 8 slots busy,
   CPU 4 %, while .107 ran at load 8–13.
2. Constraints that must survive the move: the project's single writer and hash chain stay on the home host; nothing leaves the trusted
   environment; keys are not copied; a result from a remote node must be checkable byte-for-byte against what was sent; failure falls back to
   local, never to silence.

## 2. Roles

| Role | Here | Owns |
|---|---|---|
| Home host | .107 (`/opt/1409-sprind`) | backlog, Bestand (single writer), what to submit, reading results in |
| Relay / hub | ring20 relay <ip>:9100 (TermLink hub topics `pool:in`, `pool:out`, `pool:stage`) | hand-over rail, nothing else |
| Remote node | node1 (12 cores, 40 GB), `poold` | runs jobs in a sandboxed work dir, returns one result |
| Node operator | proxmox-ring20-management | node config, controller, entries, secrets for the node (Infisical) |

The topic is a hand-over rail, not a queue of record: the backlog stays at home and at most a window of jobs (default 200) sits on `pool:in`,
because the hub trims oldest records at 10,000 records / 64 MB whether read or not.

## 3. Two job kinds

1. **Judge job** (model): a folder with `auftrag.txt` at its root (other names are refused — we hit a 208 refusal with `auftrag.md`), ≤16 refs,
   inline ≤ ~360 KB; larger inputs via `pool:stage`. Model chosen per job (`--model opus|sonnet`).
2. **Command job** `ring20.pool.cmd/1` (no model): a named entry on the node (ours: `1409.rueckfind`) with a fixed invocation, a deterministic
   `code.tar` (read-only on the node) plus data refs; exactly one result file comes back (`result_gz_b64`, `result_sha256`). Measured: same
   output byte-for-byte as local, 457 MB peak RAM, 87 s CPU per unit locally vs. 280 s wall on node1 (staging 14 s). The slowdown is the
   VPS's CPU generation (Ivy Bridge, 3.1× per core, no throttle): node1's 12 cores give roughly the throughput of 4 cores on .107, without
   loading .107 (Appendix B).

## 4. What made it work — lessons in the order we hit them

1. **Feed the node more than it runs.** The node runs at most `limit`; the controller only raises `limit` (1 per minute, up to 12) while jobs are
   *waiting*. Keeping exactly `limit` open left node1 at 1.3 of 8 busy on average. Rule now: keep `limit + buffer` open (buffer 4–8); the
   distributor counts its own open jobs because the status feed is up to 15 s stale and does not yet know what was just submitted.
2. **Big inputs go by stage, not inline.** Hub posts are capped at 512 KB; `pool:stage` takes files up to 64 MB by sha256, once, and jobs
   reference them. A 120 MB unit store packs to 8.5 MB when only the files the check actually opens are included — measured with an audit hook
   on `open`, not guessed.
3. **Fail closed on a missing input.** The node runs from an image; a read of a file not in the image is recorded and turns the result
   „incomplete“ (exit 4), which the home host refuses to read in. Otherwise a silent fallback inside the checked code yields a different verdict
   with no error.
4. **Lost replies are not lost jobs.** Submits over the SSH forward timed out while the job had in fact arrived (TermLink T-3666). Treat
   „response timeout only“ as submitted, resubmit under the same name — the node answers `duplicate_of` instead of running it twice.
5. **Parallel submitters need unique temp names.** Our distributor built and staged in threads under `<file>.<pid>.tmp`; threads share a pid, so
   they overwrote each other — empty stage files („size must be 1..67108864“) and failed renames sent all 35 jobs back to local. Fix: pid + random
   suffix. A framework helper for atomic writes should never key on pid alone.
6. **The home-side waiter must outlive the work.** `fw termlink dispatch` defaulted to 600 s and killed builders mid-run; our waiter now passes
   7200 s. Every submitted batch gets a background waiter in the same step (CLAUDE.md „never wait without a wake-up“).
7. **The code image changes under you.** Other workers commit while a batch runs; each unit may get a different `code.tar` sha. Fine for
   correctness (the result records which image it ran), but build the image once per batch where possible to save staging.
8. **Rate limits are the real ceiling for judge jobs**, not RAM (40 GB free, ≤4 GB per job). On a rate-limit answer the controller lowers
   `limit` itself; resubmit after a pause under the same name. Mix Sonnet for lighter judgements to spare the Opus quota. For CPU-bound
   command jobs the controller's load threshold (0.75 × cores) stops the climb near 9 of 12 by design (Appendix C).
9. **Show the node in the project's own view.** The operator asked twice why node1 was idle; the answer was only in the relay ledger. Our
   Watchtower `/arbeiter` now reads the node's status feed (running, queued, limit, load) next to local workers.

## 5. Trust and secrets

1. node1 and ring20 are the operator's trusted environment (operator 2026-10-27): what a job needs may go there, including raw evidence
   excerpts; nothing goes to third parties.
2. The home host's key store is machine-bound and is never copied. node1's model harnesses use node1's own subscription logins; each attempt
   gets a copy of only its harness's login item, command jobs get none (Appendix D). The project rule says keys for workers outside the home
   host come from Infisical; whether any node1 secret is fetched from Infisical at run time is not verified and is not claimed here.
3. The node never writes the project's records: it returns a file; the home host verifies sha256 and reads it in through the single writer.

## Part 2 of 3 (msg ec7b90b8)

1409-sprind with proxmox-ring20-management (cc), part 2/3 — write-up for AEF: using more than one machine for agent work, node1 as the worked example. Requested by the operator (Dimitri, 2026-11-08: 'make a write-up to 999 how we can use different nodes with node 1 as the example'). Proposal input for a framework pattern (need first; §6 is one possible direction), not a build instruction. Source: 1409 docs/reports/remote-nodes-node1-writeup.md.

## 6. Proposed framework pattern (need first, solution as one possible direction)

1. **Need:** a project can declare remote capacity and use it without project-specific glue, and the operator can see it.
2. **Possible direction:** `fw pool` verbs wrapping submit / submit-cmd / stage / wait / status with: buffer-aware distributor (local
   fallback, counts own open jobs), stage-by-sha for inputs >360 KB, idempotent resubmit by name, unique temp names, background waiter by
   default, node status in Watchtower, and a per-project entry registry for command jobs (fixed invocation, one result file, fail-closed image).
3. **Open questions for 999:** where the entry registry lives (node or project); how a project declares its trust boundary for a node; whether
   the controller's limits belong in the framework or stay node configuration.

## 7. Numbers

See Appendix E (ring20's ledgers, with sources). The headline: 363 jobs accepted since 2026-10-27, but under 1 % slot use every day until
2026-11-07 — every loss sat in the control plane (client flush bug, a silent forward, per-batch manual steps, an unread peer request, bursty
submission), not in node1. On 2026-11-08, 160 jobs; after the temp-name fix node1 ran 7 jobs at 64–65 % CPU within minutes of resubmitting.

## Appendix — ring20's sections (proxmox-ring20-management, T-2622, verbatim)



Session afce1d16, 2026-11-08. This document is ring20's contribution to 1409-sprind's draft
`docs/reports/remote-nodes-node1-writeup.md`; 1409 merges it and sends it to 999. Every figure names its source.
Nothing here is a secret, and no key material is described beyond where it lives.

### A. What node1 is and how work reaches it (node side)

**The host.**
- node1 is an Incus container on a rented VPS (serverdiscounter). Its jump host is root@<ip>; the
  container's address is <ip>.
- It has 12 vCPUs ("Intel Xeon E3-12xx v2 (Ivy Bridge)"), 40 GB RAM and 1.4 TB of disk.
- It runs its own TermLink hub (:9100) and one supervisor, `poold` (deploy/remote-node/pool/poold.py). poold is the
  only writer of the pool ledger and drives AEF's dispatch-records store, so each job gets a signed dispatch record.

**Reachability.**
- .122 holds an SSH forward through the jump account (`ring20-node1-hub-tunnel.service`). It listens on
  <ip>:19100 for .122 and on <ip>:19100 for .107. An nft rule admits only .107 on the LAN address.
- Since T-2612, a probe on .122 makes a real TermLink RPC through the forward every 2 minutes. After two failures
  it restarts the forward. This exists because the forward once stayed silent for 7 hours while ssh was still alive
  (2026-11-04).

**Submission path, standard since 2026-11-08 (T-2615, T-2614 option B).**
- Clients submit to .122's own hub (<ip>:9100) over the LAN, on the topics `pool:in`, `pool:ref` and
  `pool:stage`.
- A relay on .122 (`ring20-pool-relay.service`, scripts/pool-relay.py) forwards jobs and reference chunks to node1's
  `pool:in` and `pool:ref`. It mirrors node1's `pool:out` back to .122.
- Every forward carries a content-derived client-msg-id, and poold never runs a job name twice. A retry is
  therefore always safe.
- Why the relay exists: cross-hub posts from .107 over the narrow forward were lost by TermLink client 0.12.1526
  (T-3666, no flush after write_all over TLS). The fix arrived on .107 with 0.12.1583 on 2026-11-08. The relay
  stays, because it is also where policy, staging and measurement live.

**Policy (T-2617).**
- `policy/pool-dispatch.yaml` in ring20's repo is approved by the operator. It says what the relay forwards
  without asking:
  - clients: 1409-sprind and ring20;
  - job schemas, models, harnesses and cmd entries;
  - a post cap of 512 KiB;
  - staging roots and size.
- Anything else is refused, and the refusal is answered on `pool:out` with the reason.
- A missing or invalid policy file means nothing goes to node1 (fail closed). The policy is reloaded when the file
  changes.

**Large inputs (T-2618, T-2619, T-2623).**
- A client posts a small `ring20.pool.stage/1` request: a path on .107, a size and a sha256.
- The relay copies the file over SSH (deploy/remote-node/pool/stage-ref.sh). Size and sha256 are checked at the
  source and again on node1 before the file gets its name, `refs/<sha256>`, root-owned 0444.
- Limits: the source must lie under `/opt/1409-sprind/.context/working/`, path characters are restricted, and a
  file may be at most 64 MB.
- Copies run in a worker beside the relay loop, so jobs are never held up by a copy. A copy that was pending when
  the relay stopped is redone after a restart.
- The VPS rate-limits new SSH connections. A batch of 35 stagings locked .122 out briefly on 2026-11-08, so
  stage-ref.sh now reuses persistent SSH masters.

**Job types on node1.**
- `ring20.pool.judge/1` is a model judgment: claude (sonnet/opus) with Read and Grep only. Other harnesses (codex,
  opencode, antigravity) exist but are not in the relay policy.
  - The prompt is the bundle's `auftrag.txt`. A bundle without it is refused at intake (T-2616); before that fix it
    failed with exit 208 after taking a slot.
- `ring20.pool.cmd/1` is deterministic work without a model (T-2593 GO, T-2613).
  - The job names an entry from node1's config. node1 fixes the argv; the job cannot supply argv, tools or a model.
  - The code arrives as a ref (`code.tar`) and is unpacked read-only into `code/`.
  - The interpreter is a venv built once by root with `pip --require-hashes`, wheels only, from 1409's pinned list.
  - The unit runs with no network, no stdin and at most 1800 s.
  - Exactly one result file comes back: gzip plus base64 in the result, read without following links.

**Worker sandbox (shared by every job, scripts/orch_pool.py `unit_profile`).**
- Each job runs as its own locked uid in a transient systemd unit, launched in a pid namespace.
- Filesystem: ProtectSystem=strict and ProtectHome=tmpfs. /var/lib, /opt, /srv, the pool state and the TermLink
  sockets are hidden.
- Privileges: no capabilities, NoNewPrivileges, RestrictSUIDSGID, and private IPC and devices.
- Limits: a capped tmpfs for /tmp, LimitFSIZE, RuntimeMaxSec, MemoryMax=4G, TasksMax=256 and CPUQuota=200%, in a
  dedicated slice.
- cmd jobs additionally run with PrivateNetwork=yes and RestrictAddressFamilies=AF_UNIX.
- A selftest job proves this by effect at deploy:
  - IPv4 connect fails (EAFNOSUPPORT) and DNS fails;
  - the venv imports work;
  - signing.key, config-real.json and /root/.ssh are invisible;
  - `code/` is not writable.

## Part 3 of 3 (msg a0b54205)

_Pending: surfaces at the next prompt._
