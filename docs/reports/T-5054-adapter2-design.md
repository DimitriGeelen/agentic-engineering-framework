# T-5054 — Claude Code adapter for `termlink.adapter/2`: design note

Inputs: 010's spec pack (`T-5054-adapter2-spec-pack.md`, TermLink 8b5e51fd0) and the parity fixtures in
`tests/fixtures/termlink-parity/` (sha256 verified on receipt). Operator yes: 2026-11-13.

## Scope, as settled with 010 (msgs 223ad482, 8e252ddc, 2026-11-13)

1. **Producer only.** The adapter is a hook that writes reports to the TermLink sidecar serving the session, on the
   owner-only socket named by `TERMLINK_SIDECAR_SOCKET`. AEF's own receiver does **not** implement AL-1 intake.
   The fixtures test our emitted lines: fed to TermLink's meter they must give the expected order and turn state.
2. **Wire.** One JSON object per line, newline-terminated, at most 64 KiB, **no `op` field** (a line with `op` is an
   API call). Reply: `{"ok":true}` applied; `{"ok":true,"dropped":why}` superseded; `{"ok":false,"ignored":why}`
   rejected. An applied `prompt_submit` reply carries `origin_checked` and `basis_checked`; the lease claim uses
   those, never the hook's own guess (17.5.e).
3. **Coexistence.** Never on the same session as TermLink's own W1 hooks (`termlink-sidecar hook …`). Installed only
   where no such hook is configured; the field trial runs on one agent the operator names; switching each agent over
   is an operator act (17.9, NID). Nothing that works today is switched off.

## Event mapping (Claude Code hook → adapter/2 reports)

| Claude Code hook | Reports, in order |
|---|---|
| SessionStart | `session_start {harness_pid, interactive, transcript_path}` |
| UserPromptSubmit | `ready BUSY`, then `prompt_submit {origin, basis}` |
| PreToolUse | `ready BUSY`, `tool_start {tool}` |
| PostToolUse | `tool_end {tool}` |
| Stop | `turn_stop`, then `ready READY` |
| SessionEnd | `session_end` (`ready NOT_RUNNING` is implied by the meter) |

Every report: `schema, harness: "claude-code", harness_version, session_id, agent_id, event, at_ms, boot_id,
mono_ns`. `boot_id` from `/proc/sys/kernel/random/boot_id`; `mono_ns` = `CLOCK_BOOTTIME` in ns as a **decimal
string**; `at_ms` wall time, display only. Two reports from one hook take two clock reads, so their order is strict.
`evidence` and `complete` (17.6) belong with delivery and are a later slice.

## 17.5.d — does Claude Code mark generated prompts? (verified on this host, Claude Code 2.1.267)

Measured over the 3,670 user records of one long AEF session transcript. Claude Code writes, per prompt record:

| Mark | Values seen |
|---|---|
| `origin.kind` | `human`, `task-notification`, `peer` (a UDS peer message, with verified peer pid) |
| `promptSource` | `typed`, `suggestion_accepted`, `queued`, `system` |
| `turnOrigin` | `human`, `task_notification`, `scheduled` |
| `scheduledTaskId` | present on scheduled wake-ups (with `isMeta`) |

**Finding:** the marks prove a prompt is **generated** (task notification, scheduled wake-up, peer message) → report
`automated`, basis `harness-mark`. They cannot prove a prompt is **human**: text that reaches the terminal through a
PTY injector (the doorbell line, `inject`) is recorded as `origin.kind: human`, `promptSource: typed`, because Claude
Code sees only the terminal. So `human` stays `inferred` (or `pty-input` from the receiver's counters), and
TermLink's 17.5.e check remains the defence. Open: whether the UserPromptSubmit **hook input** carries these marks or
only the transcript does (the record may not be written yet when the hook runs). Slice 1 logs the hook-input keys to
settle it; until then the adapter reads the marks from the transcript's newest prompt record and falls back to
`inferred` / `unknown`.

Origin rules (17.5): doorbell prefix in prompt text → `automated/doorbell`; non-interactive session (print mode,
dispatched worker) → `automated/non-interactive`; transcript mark generated → `automated/harness-mark`; interactive
with no mark → `human/inferred`; cannot read → `unknown`.

## Slices

1. **Emitter** (`lib/sidecar/adapter2.py`): builds the reports above, clocks, origin rules; writes to the socket with
   a short timeout; fails open (prints nothing, one line to `hook-errors.log`). Off unless enabled per agent.
   Test: for every fixture step, the emitter's line for the matching hook input equals the fixture payload (clock
   values injected); `mono_ns` is a string; no line carries `op`; a mutant ordering on `at_ms` is caught.
2. **Lease** (T-5014 `main_session`): the claim on UserPromptSubmit uses `origin_checked`; only `human` renews or
   takes; tool activity never does; `unknown` when the sidecar cannot be reached. Test: all 13 cases of
   `r3-prompt-origin.json`.
3. **Wiring and guard:** hook entries added only where no `termlink-sidecar hook` entry exists; enable flag per agent
   (operator act). Field trial on the agent the operator names, then report to 010 on framework:pickup.
