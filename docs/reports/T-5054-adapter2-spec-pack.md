# TermLink adapter/2 spec pack for AEF T-5054 (request P-44)

Source: TermLink commit 8b5e51fd0 (master; tag v0.12.6 at 8b5e51fd0 carries the matching sidecar). Extracted verbatim.

## Part 1: docs/design/interactive-agent-communication-04-architecture.md v0.4, section 17 (adapter contract)

## 17 The adapter contract `termlink.adapter/2` (R-47 as refined by CR-O2 and CR-O3), and neutrality

17.1 **What this section is.** The single statement of what a harness adapter reports to the receiver, written so
that a harness team (AEF for Claude Code, T-5054) can implement from it. TermLink owns it (16.1). It extends R-47.a
(READY, BUSY, NOT RUNNING, evidence of hand-over, the evidence-complete point, framing, vendor channels) with the turn
events and the prompt origin that O-2 and O-3 need. Version `termlink.adapter/2`; `/1` is R-47.a as ruled in REQ v0.5.
MUST, SHOULD and MAY are RFC 2119.
17.2 **Transport.** The adapter reports to the receiver serving the session (the TermLink sidecar's owner-only hook
socket, or AEF's receiver for the inboxes it serves) as one JSON object per event:
`{schema: "termlink.adapter/2", harness, harness_version, session_id, agent_id, event, at_ms, ...fields}`. `at_ms` is the
adapter's monotonic-anchored wall time; the receiver stamps its own receive time and uses that for deadlines (V-5). A
report the receiver cannot parse is ignored and counted; it never counts as READY, human or evidence.
17.2.a (changed in v0.4 by CR-4.15) **Ordering of reports.** Hook processes are short-lived and a wall clock can step
backwards, so `at_ms` does not order reports. Every report also carries `boot_id` (the host's boot identifier) and
`mono_ns`, a host-monotonic value (Linux `CLOCK_BOOTTIME`, macOS `mach_continuous_time` converted to ns). The receiver
orders reports of one session by `(boot_id, mono_ns)`: within one `boot_id` the higher `mono_ns` is later; a report
with a `boot_id` different from the last one seen is later than every report of the previous boot (the receiver
records the change). A report older than the newest one already applied for the same key (READY, `last_prompt`) is
ignored and counted. A report without these fields (adapters before this change) is ordered by the receiver's own
receive stamp, never by `at_ms`. `at_ms` stays for display and audit.
17.3 **R1 readiness (R-21.a, R-47.a) — MUST.** `event: "ready"` with `state: READY | BUSY | NOT_RUNNING`. READY at the
end of a turn (Claude Code: Stop); BUSY before a turn or tool (Claude Code: UserPromptSubmit, PreToolUse); NOT_RUNNING at
session end. The receiver keeps it as the session's READY flag with its age. A missing, unreadable or stale flag reads
as not ready. The flag gates the normal doorbell (6.9.1) and nothing else: the watchdog (6.9.7), the conversation
signal (6.14.4) and the lease (6.13) never read it. (changed in v0.4 by CR-4.2) A `ready` report whose state equals the
flag's current state refreshes the flag's age only; it is not activity for S2 (6.14.1). S2 (a) moves only on the turn
events of 17.4 and on a READY state change.
17.4 **R2 turn events (CR-O2a) — MUST.** `event` one of `session_start {transcript_path, interactive: bool}`,
`prompt_submit {origin}` (17.5), `tool_start {tool}`, `tool_end {tool}`, `turn_stop`, `session_end`. They feed S2 of
6.14 and the vendor-channel log (`tool_start` with a vendor tool, 6.10). `transcript_path` MAY be absent; then S2 uses
turn events only.
17.4.a (changed in v0.4 by CR-4.13) **Which process is the harness.** `session_start` MUST carry `harness_pid`, the pid
of the harness process that runs the hooks' session. The TermLink session records the process it launched
(`pty_launched`, its pid and executable) and, each tick, the process-group leader in the foreground of the PTY, so a
harness restarted inside the PTY (a new process group leader) is seen as a new harness instance and must report a new
`session_start` before it is rung. The registry of harnesses matches on `(exe_realpath, script_path)`: for a native
binary the resolved executable path; for a harness run by an interpreter (for example `node`) the interpreter's path
together with the resolved path of the script it runs (the first non-option argument). The foreground check of 6.9.2
and 6.9.7.b compares the PTY's foreground process-group leader against the recorded `harness_pid` and this registry
entry, never a process name (`comm`). On Linux the paths come from `/proc/<pid>/exe` and `/proc/<pid>/cmdline`; on
macOS from `proc_pidpath` and `ps -o args=` (or `sysctl KERN_PROCARGS2`) for the arguments.
17.5 **R3 prompt origin (CR-O3 (a)) — MUST.** Every `prompt_submit` carries `origin: human | automated | unknown` and
`basis`:
17.5.a `automated` MUST be reported when the adapter can tell the prompt did not come from a person: the prompt text is
a line the receiver typed (the doorbell line, recognisable by its fixed prefix and ids; basis `doorbell`); the session
is non-interactive (print mode, background or dispatched worker; basis `non-interactive`); the harness marks the prompt
as generated (scheduled wake-up, loop, timer, sub-agent; basis `harness-mark`); input that reached the PTY through
`inject` or `notify` rather than a client (basis `pty-input`).
17.5.b `human` MAY be reported with basis `pty-input` when the session runs under a TermLink PTY and the submitted
input came from the attached client (the session's per-source input counters, 6.14.1 S1); or with basis `inferred`
when the session is interactive, none of 17.5.a applies, and the harness gives no origin mark. `inferred` is accepted
and its share is measured (6.13.6); it is the weak point (AR-6).
17.5.e (changed in v0.4 by CR-4.3) **The receiver checks every `human` claim it can.** For a session under a TermLink
PTY, the receiver applies its own per-source input counters (6.14.1 S1) to every prompt reported `human`, whatever the
basis (`pty-input` and `inferred` alike): a prompt with no client bytes since the previous submit is downgraded to
`automated`, and so is a prompt whose submit follows a line the receiver typed (`notify`) with no client bytes after
it; terminal replies the session classifies as `client_auto` are not client bytes. The doorbell override needs no
`doorbell_ids` from the adapter: the receiver's own record of what it typed in the window is enough. The lease claim
carries the **receiver-checked** origin, the lower of the hook's report and the receiver's check (order `automated` <
`unknown` < `human`); when the receiver cannot be reached the hook sends `unknown`, never its own `human`.
17.5.c `unknown` when the adapter cannot decide. Receivers treat `unknown` as **not human** for the lease (no renewal,
6.13.1) and as **human** for the conversation signal (do not interrupt, 6.14.4.a): each fails toward the safer side.
17.5.d Whether Claude Code's hook input or transcript marks generated prompts is an **[A]** that AEF verifies in T-5054;
until verified, the Claude Code adapter uses `doorbell`, `non-interactive`, `pty-input` and `inferred` only.
17.6 **R4 evidence of hand-over and evidence-complete point (R-24.a, R-47.a (1), R-51.a) — MUST / SHOULD.**
`event: "evidence" {nonce, record_ref}` when a delivery nonce appears in a harness-written transcript record (MUST);
HANDED_OVER is written only from it, and no evidence within 90 s labels the message HANDOVER_UNCONFIRMED (6.9.4).
`event: "complete" {turn_boundary}` or `{exited: true}` (SHOULD); without it every crash in the window waits for the
operator (RR-17).
17.7 **R5 framing and the waiting-mail definition (R-50.a) — MUST.** The adapter frames peer content as untrusted data
(its own markers) when it surfaces it. A receiver that holds role mail computes the waiting-mail signal exactly as
6.13.5 defines it, so TermLink and AEF receivers raise the same signal for the same facts.
17.8 **R6 vendor channels (R-47.a (3), R-79) — MUST.** The adapter reports `tool_start` for vendor peer channels and
in-process sub-agents; disabling them is an operator configuration act (6.10.2), never done by the agent.
17.9 **Parity and acceptance (R-47.d, R-47.e).** TermLink ships the fixtures: one scenario file per report above,
run against every adapter per release, with negative controls (a doorbell line reported `human` fails; a missing READY
read as ready fails; evidence without the nonce fails). A harness without an adapter is unreachable by design, never
delivered (GP-8). AEF's Claude Code adapter replaces TermLink's W1 hooks only after it passes the fixtures and runs in
the field, with the operator's approval (NID).
17.10 **Neutrality (card 3.9).** The send and status API is a local socket with a JSON request format (ARCH),
harness-independent; the adapter is the only harness-specific part and this section is its whole contract. The
doorbell is a session RPC with ids only. Forwarding, revocation, blobs and the lease use hub RPCs over the existing
transport (Unix socket or TLS); the circuit (PH-5) is a second transport under the same delivery contract (R-46.a (3)).
Nothing depends on a vendor channel (R-79).
17.10.a (changed in v0.4 by CR-4.4) **Origin reporting is per harness.** Whether a receiver ignores claims with no
origin field is decided per harness (`harness` of 17.2), switched on by a recorded operator act after the harness's
adapter passes the 17.9 fixtures (6.13.1.a), never per project and never by a claim, so a harness without origin
reporting keeps renewing as before beside one that has it.


## Part 2: docs/design/interactive-agent-communication-06-pseudo-code.md v0.3, section 5.1 AL-1 (includes CR-6.24 ordering)

### 5.1 AL-1 — Adapter report intake and the READY flag (K-32 S2, K-18; ARC4 17.2..17.6; B-27, B-29)

5.1.a **SERVES:** R-21, R-47, R-20, SI-2, SI-14, SI-17; TH-7, TH-16; AFC-14, AFC-15.
5.1.b **PROBLEM:** the doorbell, the watchdog, the conversation signal and the lease all depend on what the harness
reports; a report can be malformed, reordered, lost, forged by another local user, or claim more than it may.
**APPROACH:** one intake routine on the owner-only hook socket parses strictly, keeps per session a READY record
ordered by the adapter's clock but aged on the receiver's, and checks the prompt origin against what the receiver can
see itself (its own ring log and the PTY input counters).
5.1.c **ALGORITHM:**
```text
on_report(raw, peer):                                   # one JSON object per connection, owner-only socket
 1  if peer.uid != owner_uid: close; return                           # SI-14 [B]; FCW-1
 2  if len(raw) > 65536: count("unparseable", "too-large"); return    # FCW-2
 3  obj = strict_json(raw)                       # 3.3; Err -> count("unparseable", reason); return  (FCW-2)
 4  require obj.schema == "termlink.adapter/2"   # exact, case-sensitive
    require obj.event in {ready, session_start, prompt_submit, tool_start, tool_end, turn_stop,
                          session_end, evidence, complete}
    require obj.agent_id == MY_AGENT; obj.session_id matches ^[A-Za-z0-9._:-]{1,128}$; obj.at_ms integer >= 0
    any failure -> count("unparseable", reason); keep last 16 reasons; return               # FCW-2
    ord = (obj.boot_id, obj.mono_ns) if both present and valid else ("rx", rx.mono)  # CR-6.24 (ARC4 17.2.a): never at_ms
 5  rx = (mono(), wall(), boot_id, sidecar_epoch)
 6  sess = sessions.get(obj.session_id)
    if none: if count(live sessions of MY_AGENT) >= 64: attention("session-table-full", coalesce=hour); return  # FCW-7
             sess = new(obj.session_id)
 7  with sess.lock:
      case obj.event:
       ready:
         require obj.state in {READY, BUSY, NOT_RUNNING} else count unparseable; return
         if older(ord, sess.ready.ord): count("ready-reordered"); goto 8                  # FCW-3; CR-6.24
         if ord == sess.ready.ord and sess.ready.state == BUSY and obj.state != BUSY: goto 8   # tie keeps BUSY
         changed = (obj.state != sess.ready.state)                                         # CR-6.3
         sess.ready = {state: obj.state, at_ms: obj.at_ms, ord, rx, seq: sess.ready.seq + 1}
         persist sess.ready (atomic_write)          # read back by the built R-44.e notice logic [B]
         if changed: sess.s2_at = sess.s2_report_at = rx.mono   # CR-6.3: a repeated ready, same state, is not activity
       session_start:
         sess.interactive = obj.interactive (bool, required)
         sess.harness_pid = obj.harness_pid (integer, required)                          # CR-6.19 (ARC4 17.4.a)
         sess.harness = registry_entry(proc_identity(obj.harness_pid))   # (exe_realpath, script_path); none -> FCW-24
         sess.harness_pgid = pgid(obj.harness_pid)
         sess.transcript = validate_transcript_path(obj.transcript_path)  # absent, or regular file, no symlink,
                                                    # under the harness's project directory; else none + count  (FCW-8)
       prompt_submit:
         (origin, basis) = check_origin(sess, obj)                        # below
         sess.last_prompt = {origin, basis, at_ms: obj.at_ms, ord, rx, doorbell_ids: valid_ids(obj.doorbell_ids)}  # CR-6.24
         persist sess.last_prompt with sess.ready (atomic_write)          # CR-6.23: survives a sidecar restart
         reply_extra = {origin_checked: origin}                           # CR-6.4: the hook claims with this (AL-11)
         ring_log.on_submit(sess, sess.last_prompt)                       # AL-7
       tool_start, tool_end: sess.tool = {name: obj.tool (<= 128 bytes), rx}
                              if obj.event == tool_start and obj.tool in VENDOR_TOOLS: vendor_log(sess, obj.tool)  # AL-39
                              # CR-6.34: VENDOR_TOOLS is exactly AL-39's matcher set (06a), one list
       turn_stop:   sess.turn_stopped = rx
       session_end: sess.ready = {state: NOT_RUNNING, at_ms: obj.at_ms, rx, seq: +1}; persist
       evidence:    deliver.evidence(obj.nonce, obj.record_ref, sess)     # AL-9; never sets READY or origin
       complete:    deliver.complete(obj.turn_boundary | obj.exited, sess) # AL-9
      if obj.event in {prompt_submit, tool_start, tool_end, turn_stop, session_start, session_end}:
          sess.s2_at = sess.s2_report_at = rx.mono                        # S2 (a): turn events only (CR-6.3);
                                                                          # ready only on a state change (above);
                                                                          # evidence and complete never
 8  reply {ok: true} + reply_extra

check_origin(sess, obj):                                   # CR-6.4 (ARC4 17.5.e): every human claim of a PTY session
 1  o = obj.origin; b = obj.basis
    valid = {human: {pty-input, inferred}, automated: {doorbell, non-interactive, harness-mark, pty-input},
             unknown: {absent}}
    if o not in valid or b not in valid[o]: count("origin-inconsistent"); return (unknown, absent)   # FCW-4
 2  if o == human and ring_log.typed_within(sess, TICK)
       and (obj.doorbell_ids intersects ring_log.ids(sess, TICK)
            or no client byte since the last line the receiver typed (AL-2; client_auto not counted)):
       count("origin-overridden"); return (automated, doorbell)                          # FCW-5; doorbell_ids not needed
 3  if o == human and sess.pty_launched:                    # basis pty-input AND inferred (CR-6.4)
       src = pty_last_source_before(sess, rx.mono)          # AL-2 counters; client_auto is ignored, never a source
       if src in {notify, inject}: count("origin-overridden"); return (automated, pty-input)    # FCW-5
       if no client byte since the previous submit of sess: count("origin-overridden"); return (automated, pty-input)  # FCW-195
       if src == unknown: return (human, inferred)          # the receiver cannot confirm pty-input
 4  return (o, b)
```
5.1.d **INVARIANTS:** (1) a report never makes a session READY, human or handed-over unless it parses, names this
agent and arrives on the owner-only socket; (2) per session the applied READY records have non-decreasing `at_ms` and a
strictly increasing `seq`; (3) the receiver never upgrades an origin (unknown never becomes human; automated never
becomes human); it only downgrades; (4) S2 moves only on valid reports, and among them only on turn events and on a
READY state change (changed in v0.3 by CR-6.3); a repeated `ready` with the same state, `evidence` and `complete`
never move it.
5.1.e **FAILS CLOSED WHEN:**
5.1.e.1 **FCW-1** [new; E-96] the reporting peer is not the socket's owner → the connection is closed, nothing is read.
5.1.e.2 **FCW-2** [AFC-14; E-16, E-84] the report is larger than 64 KiB, not strict JSON, not schema
`termlink.adapter/2` exactly, has an unknown event, a wrong type, or another agent's id → ignored and counted; it never
reads as READY, human or evidence.
5.1.e.3 **FCW-3** [new; ZR-1] a `ready` report is older than the applied one (changed in v0.3 by CR-6.24: ordered by
`(boot_id, mono_ns)`, or by the receive stamp when the adapter sends neither, never by `at_ms`) → dropped and counted; a
tie between BUSY and READY keeps BUSY.
5.1.e.4 **FCW-4** [AFC-15; E-16, ZR-1] origin and basis do not match the contract's table → the prompt is recorded as
`unknown` (not human for the lease, human for the conversation signal).
5.1.e.5 **FCW-5** [AFC-16; E-27, E-85, ZR-1] a prompt reported `human` carries ids of a line the receiver typed in the
last tick, or the session's input counters show the last input before it came from `notify` or `inject` → recorded
`automated`.
5.1.e.6 **FCW-6** [AFC-14; ZR-1] the READY record was received by another sidecar process (`sidecar_epoch`) or on
another boot → absent for the doorbell gate (AL-5) until the next report.
5.1.e.7 **FCW-7** [new; E-16 allocation cap] 64 live sessions of the agent already exist → a report for a new session
is refused with a coalesced needs-attention entry.
5.1.e.8 **FCW-8** [new; ZR-1] the transcript path is absent, a symlink, not a regular file or outside the harness's
project directory → S2 (b) is not used for that session (turn events only).
5.1.e.9 **FCW-195** [AFC-16; E-153] (changed in v0.3 by CR-6.4) a prompt reported `human` from a session under a
TermLink PTY, with any basis, has no client byte (`client_auto` excluded) since the previous submit, or follows a
line the receiver typed with no client byte after it → recorded `automated`, and the hook's lease claim carries
`automated`.
5.1.f **EDGE CASES:**
5.1.f.1 Forged: another local user cannot reach the socket (SI-14); a same-user process can (RR-2, BP-5) and can
forge READY or `human`; the doorbell's re-checks (AL-6) and the PTY-counter override are the remaining defence; the
residue is RR-7 and AR-6.
5.1.f.2 Replayed: a replayed old `ready` report is dropped by `at_ms`; a replayed `evidence` report is harmless (AL-9
writes HANDED_OVER once per attempt and checks the nonce against the transcript itself).
5.1.f.3 Clock: (changed in v0.3 by CR-6.24) reports are ordered by `(boot_id, mono_ns)` from the adapter (ARC4
17.2.a), which a wall-clock step does not move; an adapter that sends neither is ordered by the receive stamp. A new
`boot_id` orders after every report of the previous boot. `at_ms` is kept for display only. Ages use `rx.mono` only
(4.3).
5.1.f.4 Concurrency: two hook processes report at once (Stop and UserPromptSubmit in quick succession); `sess.lock`
serialises them; the `at_ms` rule makes the result independent of arrival order.
5.1.f.5 Crash table:

| Crash between | State after restart | Effect |
|---|---|---|
| 5 and 7 (report accepted, nothing applied) | previous READY record | the report is lost; the hook got no reply and does not retry (it cannot block a turn); a lost BUSY leaves a stale READY: AL-6's re-checks (foreground, veto, typing) and FCW-6 (new epoch after the restart) hold the doorbell; a lost READY leaves the session not ready: the watchdog bounds the wait |
| `sess.ready` set and persist | in memory only for this epoch; the new epoch reads absent (FCW-6) | the doorbell waits for the next report; the built notice logic reads the older persisted record |
| persist and reply | applied and persisted | none |

5.1.g **EXECUTION SEMANTICS:** intake has no effect outside the receiver; a report is applied at most once per
`(session, at_ms, event)`; duplicates of `ready` are dropped by the ordering rule; duplicates of other events move S2
twice, which changes nothing observable.
5.1.h **CRYPTOGRAPHY:** none; the boundary is the owner-only socket (SI-14). Reports are not signed (same host, same
user as the harness, ARC4 17.2).
**OBS:** OBS-1 counters `adapter_reports_unparseable`, `ready_reordered`, `origin_inconsistent`, `origin_overridden`
with the last 16 reasons; OBS-2 the per-session READY record `{state, at_ms, rx_mono, seq, sidecar_epoch}` in status
`activity`; OBS-3 the `last_prompt` record.


## Part 3: transport (crates/termlink-sidecar/src/hook.rs and api.rs headers)

//! Claude Code hook entry points run by `termlink-sidecar hook <event>` from the agent's settings.
//! C-11 Claude adapter: hook entry points (architecture note 6.2, 6.3, 6.4).
//!
//! `termlink-sidecar hook <event>` is what the agent's `settings.json` runs.
//! It reads Claude Code's hook input from stdin and talks to its own sidecar on
//! the send socket named by `TERMLINK_SIDECAR_SOCKET`.
//!
//! | event | does |
//! |---|---|
//! | `post-tool-use` | `pull`; prints the frame as `additionalContext` when one came back, then spawns a detached finalizer |
//! | `session-start` | `ready` (records the session; the transcript is found by the sidecar under its own HOME) |
//! | `vendor-channel` | PreToolUse for `SendMessage`, `Agent`, `Task` (P-26, AL-39, K-20): `vendor-use`, one admin row per call; prints nothing, never blocks |
//! | `stop` | `ready` only: a Stop hook cannot hand text to the agent without blocking the turn, which PH-1 does not do, so mail waits for the next tool call |
//!
//! Fail directions (6.3): the **turn** fails open: any error (no socket,
//! refused, timeout, bad answer) prints nothing, exits 0 and appends one line to
//! `hook-errors.log`, so the agent is never blocked and the message stays
//! STORED where the sender sees it waiting. The **delivery** fails closed: a
//! frame is printed only when the sidecar returned one, and the hook never
//! records a hand-over; the finalizer asks the sidecar, which reads the
//! transcript.

//! The sidecar's local API on per-scope Unix sockets (send, status, admin) and the status view.
//! C-4 local API (architecture note section 3) and the C-10 status view.
//!
//! One unix stream socket per scope under `<runtime>/sidecar/` (dir 0700, sockets
//! 0600): `<agent>.send.sock`, `<agent>.status.sock`, `<agent>.admin.sock`. On
//! accept the peer uid is read with `SO_PEERCRED`; any uid other than the owner's
//! is refused (SI-14). Framing is one JSON object per line. An op is served only
//! on the socket of its own scope, so the agent sockets cannot reach `delivery`.
//!
//! B5 serves `status` and the admin `delivery` flag; B6 adds `send` (through
//! `send::Sender`), B9 adds `pull`, `claim` and `handed-over` (through
//! `deliver::Deliverer`); each answers `not-configured` when its path is not
//! attached. B11 adds `reply` (through the send path). Every op answers with
//! what actually happened; none is faked.
//!
//! No verb takes a path: every field is on a per-op allow-list and every name is
//! checked against the store's name charset, so a path or command cannot arrive.
