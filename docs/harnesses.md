# Agent harnesses on this host — reference

**Maintained source** for which AI coding harnesses the Agentic Engineering Framework can drive,
how, and with what isolation. The fleet cockpit (project 055, framework:pickup 256) cites this
file; update it here, not in a copy.

- **Origin:** T-3582, 2026-10-01. Host: the framework's own host, run as `root` unless stated.
- **Marking:** **verified** = run on this host on 2026-10-01 and observed working.
  *Unverified* = taken from the tool's `--help` or documentation, not run.
- **No secrets here.** Auth is named by mechanism and file *reference* only. Never paste a token,
  key or auth-file content into this document.

## Summary

| Harness | Binary (root unless noted) | Version | Vendor | `fw termlink dispatch --worker-kind` | Panel role |
|---|---|---|---|---|---|
| Claude Code | `/root/.local/bin/claude` | 2.1.286 | anthropic | `claude` | panel seat 1 |
| Codex CLI | `/root/.nvm/versions/node/v22.22.1/bin/codex` | codex-cli 0.153.4 | openai | `codex` | panel seat 2 |
| opencode (Z.ai) | `/root/.opencode/bin/opencode` | 1.18.31 | zai | `opencode` | panel seat 3 |
| Antigravity (`agy`) | `/home/dimitri-mint-dev/.local/bin/agy` (user `dimitri-mint-dev`) | 1.1.15 | google | `antigravity` | spare seat |
| Gemini CLI | **not installed** (`command -v gemini` is empty for root) | — | google | none | — |

The kind → vendor, binary and model mapping lives in exactly one place:
`policy/review-backends.yaml` (`worker_kind`, `vendor`, `binary`, `model`). The dispatcher and the
verdict ledger read it **as committed** at the reviewed revision. Print it with
`bin/fw termlink worker-kinds --vendors`.

All four installed harnesses are **internal-class** backends: subscription or flat-rate, no
approval needed. Every use is still logged with `bin/fw review cost log` (CLAUDE.md §Review and
Dispatch Cost Ruling).

## Live proof (2026-10-01)

These runs went through `fw reviewer judge`'s own code path on a fixture task
(`tests/manual/t3582_live_review.py`). Full output is in `docs/reports/T-3582-live-runs.md`.

| Run | Seat | Wall time | Start | Completion | Verdict row |
|---|---|---|---|---|---|
| rung-5 panel | claude (anthropic) | 28.4 s | signed | signed, exit 0 | green, validated |
| rung-5 panel | codex (openai, gpt-6-astra) | 23.1 s | signed | signed, exit 0 | green, validated |
| rung-5 panel | opencode (zai, glm-5.2) | 18.5 s | signed | signed, exit 0 | green, validated |
| single seat | antigravity (google) | 136.8 s | signed | signed, exit 0 | green, validated |

The panel's criterion satisfied `satisfying_verdict`: three seats, three vendors.

---

## Claude Code

- **Binary / version:** `/root/.local/bin/claude`, 2.1.286 (Claude Code). **Verified.**
- **Interactive:** `claude`, or `claude-fw` (the framework wrapper with auto-restart). Add
  `claude-fw --termlink` to register the session with TermLink.
- **Headless (verified):** `claude -p "<prompt>" < /dev/null`
- **Headless, as a pinned review worker (verified; run.sh builds this):**
  `claude -p "<prompt>" --setting-sources user --settings <wdir>/settings.json --strict-mcp-config --output-format stream-json --verbose`
- **Resume:**
  - `claude -c` (most recent conversation);
  - `claude --resume <session-id>`.
  - `claude-fw` restarts with `claude -c` after a handover signal.
- **Auth:** Claude subscription login, stored in the user's Claude config directory (`~/.claude/`).
  Reference name only.
- **Session state:**
  - transcripts: `~/.claude/projects/<project-slug>/<session-id>.jsonl` (verified path shape);
  - user settings: `~/.claude/settings.json`;
  - project settings: `.claude/settings.json` and `.claude/settings.local.json`.
- **Under TermLink / tmux:**
  - `claude-fw --termlink` registers the session as `claude-master-<PID>`.
  - Attach with `termlink attach`; read output with `termlink pty output --strip-ansi`.
  - Workers run through `fw termlink dispatch`, which spawns a TermLink session and injects `run.sh`.
- **Pitfalls:**
  - Unset `CLAUDECODE` before nesting `claude -p` (run.sh does this).
  - `termlink run --timeout` orphans the process (T-577); use `fw termlink dispatch`.
  - A session launched by Claude Code's background-job daemon is invisible to TermLink
    (CLAUDE.md §Session Launch Policy).
- **AEF hooks and governance:**
  - An interactive session in the repo loads them: `.claude/settings.json` PreToolUse hooks
    (task gate, Tier 0, budget) plus `CLAUDE.md`.
  - A pinned **review worker** loads only the user source, so no project hooks or `CLAUDE.md`.
    Probed 2026-10-01 with marker files: the user-only launch saw none of the project
    `CLAUDE.md`/agents/commands; the default launch saw all of them.
- **Worker kind:** `claude`. Its binary is resolved on PATH at dispatch, as an absolute path, and
  signed into the registration. It writes and commits its own verdict row.

## Codex CLI (OpenAI)

- **Binary / version:** `/root/.nvm/versions/node/v22.22.1/bin/codex`, codex-cli 0.153.4.
  **Verified.** It is a node script; `fw termlink dispatch` resolves it through symlinks.
- **Interactive:** `codex` (*unverified here*).
- **Headless (verified):** `codex exec -s read-only --skip-git-repo-check -o <outfile> "<prompt>" < /dev/null`
  - Stdin **must** be closed. Otherwise it prints `Reading additional input from stdin...` and waits.
  - `-o` is written by the CLI itself, so it works under `-s read-only` (verified).
- **Headless, as a pinned review worker (verified; run.sh builds this):**
  `codex exec -s read-only --skip-git-repo-check --ignore-user-config --ignore-rules --ephemeral --color never -c project_doc_max_bytes=0 -m gpt-6-astra --json -o <wdir>/result.md "<prompt>" < /dev/null`
- **Model:** the pinned model is `gpt-6-astra`.
  - Listed by `codex debug models`; verified working with this login.
  - With `--ignore-user-config`, the default model is codex's built-in default, so the model is
    pinned explicitly.
- **Resume (unverified, from `--help`):**
  - `codex resume --last`, or `codex resume <SESSION_ID>`;
  - `codex exec resume <id>` for headless.
  - A review worker runs `--ephemeral`, so it leaves no session to resume.
- **Auth:** ChatGPT subscription login (auth_mode chatgpt) in `$CODEX_HOME/auth.json`
  (`~/.codex/auth.json`). No API key. `--ignore-user-config` still loads auth (verified).
- **Session state (unverified paths):**
  - config: `~/.codex/config.toml`;
  - sessions (rollouts) under `~/.codex/`.
  - `codex doctor` reports the state database.
- **Under TermLink / tmux:**
  - Run it with stdin closed. Headless output is plain text, or JSONL with `--json`.
  - `--color never` avoids ANSI in captured output.
- **AEF hooks and governance:**
  - **None.** Codex has its own config and execpolicy rules, not AEF hooks.
  - It reads `AGENTS.md` (the AEF provider-neutral guide) as instructions, unless
    `project_doc_max_bytes=0` is set (verified with a marker file).
  - A review worker sets `project_doc_max_bytes=0`, `--ignore-user-config` and `--ignore-rules`.
- **Worker kind:** `codex`, a **harness kind**. See [Harness kinds](#harness-kinds-codex-opencode-antigravity).

## opencode (Z.ai coding plan)

- **Binary / version:** `/root/.opencode/bin/opencode`, 1.18.31. **Verified.**
- **Interactive:** `opencode` (*unverified here*).
- **Headless (verified):** `opencode run -m zai-coding-plan/glm-5.2 "<prompt>" < /dev/null`
  - The default format has ANSI escapes.
  - `--format json` emits raw JSON events, one per line: `step_start`, `text`, `step_finish`
    (verified).
- **Headless, as a pinned review worker (verified; run.sh builds this):**
  `opencode run -m zai-coding-plan/glm-5.2 --agent plan --pure --format json "<prompt>" < /dev/null`
  - `--agent plan` is opencode's built-in no-edit agent.
  - `--pure` loads no external plugins.
- **Resume (unverified, from `--help`):**
  - `opencode run -c` (continue the last session);
  - `opencode run -s <sessionID>`;
  - `opencode session` manages sessions; `opencode export <sessionID>` exports one.
- **Auth:** provider `zai-coding-plan`, stored in `~/.local/share/opencode/auth.json`. Reference
  name only.
- **Session state:** under `~/.local/share/opencode/` (*unverified layout*). The JSON events carry
  a `sessionID`, which the runtime records as the worker session.
- **Under TermLink / tmux:**
  - Close stdin.
  - Prefer `--format json` for anything captured, because the default output is ANSI.
- **AEF hooks and governance:**
  - **None.** opencode has its own config (`opencode.json`, user config).
  - It reads `AGENTS.md`, and has no flag to turn that off (verified with a marker file).
  - It falls back to `CLAUDE.md` only when there is no `AGENTS.md`.
- **Worker kind:** `opencode`, a **harness kind**.

## Antigravity (`agy`)

- **Binary / version:** `/home/dimitri-mint-dev/.local/bin/agy`, 1.1.15. It runs as user
  `dimitri-mint-dev`, logged into the operator's Google account.
- **Headless, operator-approved form (2026-09-30):** `sudo -n -u dimitri-mint-dev -H agy -p "<prompt>" --mode plan --sandbox`
  - **As written, this fails from root (verified):** `sudo: agy: command not found`, because
    sudo's `secure_path` does not include `~/.local/bin`.
  - **Working form (verified through the dispatcher, 136.8 s, stdin closed):** the same
    command with the absolute binary:
    `sudo -n -u dimitri-mint-dev -H /home/dimitri-mint-dev/.local/bin/agy -p "<prompt>" --mode plan --sandbox < /dev/null`
  - It is non-interactive: the run completed with stdin closed and printed its verdict to stdout.
- **Interactive:** `agy` as `dimitri-mint-dev` (*unverified here*).
- **Resume:** *unverified*.
- **Model:** *unverified*; no model flag was checked. The registry pins none, so the worker uses
  its default.
- **Auth:** the operator's Google account, logged in as `dimitri-mint-dev`. The state lives under
  that user's home (*unverified location*). Root cannot use that login directly.
- **Under TermLink / tmux:**
  - It cannot read `/root` or a root-only directory, so the prompt goes in as an argument and
    the output comes back on stdout.
  - The review worker runs in a world-readable export: run.sh sets `chmod a+rX` on the worker
    directory.
  - sudo drops the caller's environment.
- **AEF hooks and governance:** none. Its instruction-file behaviour is *unverified*. It runs in
  the export, so anything it reads is the reviewed revision.
- **Worker kind:** `antigravity`, a **harness kind**. It is the **spare** panel seat: the judge
  takes the first three seat backends in registry order.
- **Not checked:** `agy --help` and any other path under `/home/dimitri-mint-dev`. The framework's
  project-boundary gate refuses those paths from this session, so they were not worked around.

## Gemini CLI

- **Not installed** for root: `command -v gemini` prints nothing (verified 2026-10-01).
- **Under `dimitri-mint-dev`:** not checked. The project-boundary gate refuses that home
  directory from this session, and sudo is approved only for the `agy` form.
- **Unverified.** No worker kind, no registry entry.

---

## Harness kinds (codex, opencode, antigravity)

This is how `fw termlink dispatch --task-type review --worker-kind <kind>` runs a non-Claude
harness. It is built in `agents/termlink/termlink.sh` (run.sh) and `lib/verdict_ledger.py`.

1. **Review-only.** These kinds refuse any `--task-type` other than `review`.
2. **Committed binary and model.**
   - The dispatcher reads `binary:` and `model:` for the kind from the registry, as committed at
     the reviewed revision.
   - The ledger refuses a registration whose binary is not the committed one (compared through
     symlinks).
   - It also refuses one whose model is not the pinned one, and refuses a vendor label that
     contradicts the mapping.
3. **No caller env or flags.**
   - The T-3580 review rules apply unchanged: no `--env`, `--model`, `--tools`,
     `--permission-mode`, `--mcp-config` or `--allowed-tools`.
   - The worker's environment is signed data (`env.json`).
4. **Signed start and completion.**
   - `start` runs first and issues the completion secret.
   - When `start` is refused, **no worker is launched** (T-3580 R9-1). The reason stays in
     `stderr.log`, which run.sh only ever appends to, and run.sh exits 3.
5. **Export, not working tree.**
   - The harness runs with its working directory set to `git archive <reviewed revision>`,
     extracted into `<wdir>/tree` without `.context/`. The tree is removed afterwards.
   - It loads exactly the reviewed revision.
   - A concurrent session's dirty `CLAUDE.md` cannot reach it, and the `dimitri-mint-dev` user
     can read it.
6. **One output shape.** Each harness's final text is normalised to `<wdir>/result.md`:
   - codex: `-o`;
   - opencode: the `text` events of `--format json`;
   - antigravity: stdout with ANSI stripped.
7. **Recorded on the worker's behalf.**
   - A harness prints its verdict in the brief's format (`N. [AC] …` / `VERDICT:` / `WHY:` /
     `GUIDANCE:`).
   - After it exits, run.sh calls `verdict_ledger.py record-for-worker`. This call is
     authenticated like `complete`: canonical parent run.sh, start secret on stdin. It:
     - writes an evidence report holding the harness output and the `sha256` of
       `result.md`/`result.jsonl`;
     - records the row as `reviewer-<dispatch id>`;
     - commits it under that identity.
   - The signed completion then lists the row and the `result_sha256`.
   - A criterion the harness did not print exactly once gets no row: `unknown`, never green.

### What each harness can and cannot isolate (residuals)

- **claude:**
  - **Isolated:** project settings, `CLAUDE.md`, agents, commands, `.mcp.json` (user source
    only, plus `--strict-mcp-config`).
  - **Not isolated:** user-level `~/.claude/` (settings, hooks, plugins, skills, `CLAUDE.md`).
    It runs in the live working tree, so it can *read* uncommitted files.
- **codex:**
  - **Isolated:** user config and execpolicy rules (`--ignore-user-config`, `--ignore-rules`),
    `AGENTS.md` injection, writes (`-s read-only`), session files (`--ephemeral`).
  - **Not isolated:** `CODEX_HOME` auth, and whatever the ChatGPT backend serves as `gpt-6-astra`.
- **opencode:**
  - **Isolated:** external plugins (`--pure`), edits (`--agent plan`).
  - **Not isolated:** user config under `~/.config/opencode` (which may change the plan agent's
    permissions), and `AGENTS.md` injection (it is the reviewed revision's).
- **antigravity:**
  - **Isolated:** the root environment (sudo), writes (`--mode plan --sandbox`, and a
    throwaway export).
  - **Not isolated:** that user's own Antigravity settings and login. Its model and its
    instruction-file behaviour are unverified.
- **All harness kinds:**
  - The runtime, not the model, writes the ledger row. The row binds the model's printed text
    (hashed in the evidence report and the completion), not a command the model ran.
  - Screenshots are not visible to them: `.context/` is not exported and a render brief's
    screenshot paths are untracked. A render criterion should get `escalate` from these seats.
- **Same-user boundary (T-3581):** every worker runs as a user who can read the signing key.
  The chain is fail-closed against accidents, not forgery-proof.
