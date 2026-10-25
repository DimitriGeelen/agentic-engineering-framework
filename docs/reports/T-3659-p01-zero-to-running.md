# T-3659: P-01, zero-to-running AEF (inception research artifact)

**Source:** proposal "P-01 — Zero-to-running AEF", 2026-09-29, Dimitri Geelen, unratified. The operator pasted it into the framework session on 2026-10-01 with "please ingest and action for onboarding improvement for windows". Summarised here; the proposal is the primary record.

## The pattern
One command installs Claude Code, the framework and every dashboard dependency, natively for the OS (Windows goes through WSL). It skips onboarding, puts `fw` on PATH, and creates a desktop icon. The icon:
- opens a terminal in the project;
- starts Watchtower detached and opens it in the browser;
- runs Claude Code under `claude-fw`, so enforcement is live;
- leaves the user in a project shell when Claude exits.

On first launch the user is asked only for logins.

## Evidence (one Windows 10 machine, framework 1.7.0 @29f3b02, 57 findings)

| Route | Time | Manual fixes | Outcome |
|---|---|---|---|
| Documented install, native Git Bash | 15m51s | 2 | Blocked: Watchtower cannot start; doctor exit 1 |
| Documented install, WSL, by hand | 1m49s | ~10 | Working after fixes to deps, PATH, Claude Code and the dashboard |
| P-01 `Install-AEF.ps1` | 127s | 0 | Ready project, icon, two projects side by side on :3000/:3001 |

## Findings → AEF tasks (each is a defect, independent of the installer decision)

| Finding | AEF task |
|---|---|
| Win F-07: a CRLF checkout silently disables the secret scan (**security**, now) | T-3665 |
| Win F-08, F-12, F-27: Watchtower fcntl crash, doctor FAILs, no "use WSL" pointer | T-3666 |
| WSL F-16, F-17: Watchtower dies with its shell; `--debug` is not foreground | T-3660 |
| WSL F-25: `fw watchtower status` exits 0 when stopped | T-3661 |
| WSL F-28: every project resolves :3000, and identity is not checked | T-3662 |
| WSL F-15, F-03: undeclared Watchtower deps, incomplete hint, no pip | T-3663 |
| WSL F-24, F-27: the onboarding gate, then the placeholder-AC gate, block "build now" | T-3664 (`fw work-on --ac`) |
| WSL F-06/F-26: `fw` not on PATH after install | in the installer (bootstrap) |
| WSL F-02: `claude` inside WSL resolves to the Windows binary | in the installer (native Claude Code in Linux) |

## Proposed landing (from P-01)
1. `install.sh --quickstart` (or `fw quickstart`): bootstrap plus a desktop entry for the detected OS. Onboarding skip is an explicit flag.
2. `install.ps1` next to `install.sh`, documented as the Windows route; native Git Bash marked unsupported for now.
3. Framework fixes that retire the launcher's workarounds (the tasks above).
4. Validate Linux and macOS with the same instrumented install prompt before calling them supported.

## Open questions, with recommendations (also IW-1..IW-4 in the task)
1. **Skip onboarding for everyone, or offer "guided vs quickstart"?** Recommend: offer both, with **quickstart as the default** for the one-command path and guided behind a flag. Onboarding exists to teach governance, but the evidence shows it blocks first work; quickstart is the safer default only if question 3 also lands, so that the governance gates are met by construction rather than skipped.
2. **WSL distros often default to root: accept it, or create a normal user?** Recommend: **install.ps1 creates a normal user** and runs the bootstrap as that user. Root is today's reality on this host, but it is what made the stray `/.git` and test leaks dangerous (T-2787, T-3610), and it hides permission bugs consumers on normal accounts will hit.
3. **Should the installer ask for the project goal and create the first task with ACs?** Recommend: **yes.** This is the same authoring moment T-3535 ratified: the greenfield seed T-002 writes the objectives file (T-3636). Ask for the goal, write `objectives.yaml`, and create the first task with real ACs via `fw work-on --ac` (T-3664), so the user never meets the active-task or placeholder-AC gate cold.
4. **Where should the kit live?** Recommend: **in the framework repo under `install/`.** It is versioned and released with the framework, it is what `fw upgrade` can refresh, and the per-OS wrappers stay thin over a shared core. A separate repo would drift from the framework version it bootstraps, the same class as 055's stale vendored copy.

## What is needed to proceed
- **The kit files:** P-01 says they sit "next to this page" (`launcher/aef-bootstrap.sh`, `launcher/aef-start.sh`, `windows/Install-AEF.ps1`, `windows/New-AefShortcut.ps1`, `linux/…`, `macos/…`). Their location was not in the paste. Once known, they come into `install/` under a build task after the GO, and are reviewed before landing.
- **The operator's answers** to the four questions (or acceptance of the recommendations above).

## Reference launcher: `install/launcher/aef-start.sh` (T-4721)
The icon's launcher now ships in the repo as `install/launcher/aef-start.sh`; the rest of the kit is still not landed. It was `claude-fw || claude`, so every click opened a new conversation, and after a restart the operator could not get back into his work (055, laptop 'greenfield', 2026-10-23).

- **Default: continue.** `aef-start.sh [PROJECT_DIR]` runs `claude-fw -c`. claude-fw resolves `-c` to this project's last interactive conversation, never a `claude -p` worker's, and starts fresh when there is none (T-4497).
- **`--new`** starts a fresh conversation (`claude-fw` with no `-c`).
- **Duplicate-conversation guard (T-3890, T-4714, T-4048).** `-c` goes through the guard like any resume. If the conversation is already live in another process, or is a live background job, claude-fw prints REFUSED and exits with **exit 3**. The launcher then does **not** fall back to a fresh session. Doing so would hide the live work behind a second conversation, which is exactly what 055's hand-patched `claude-fw -c || claude-fw || claude` did. It says the conversation is live elsewhere and points at `--new`. The claude daemon / pty host never counts as a holder (T-4714), so it does not cause a refusal.
- **Fallback.** Any other failure within `AEF_START_FALLBACK_SECS` (default 15 s) means `-c` never started: an older claude-fw, or plain `claude -c` with nothing to continue. The launcher then starts a fresh conversation. A session that ran and then exited non-zero is not restarted. Without claude-fw on PATH it runs plain `claude` with the same rules, but plain claude has no guard.
- Pinned by `tests/unit/t4721_aef_start_launcher.bats`.

## Dialogue Log
- 2026-10-01, operator: "please ingest and action for onboarding improvement for windows" + the P-01 proposal. Actions: filed this inception (recommendation GO), seven defect tasks (T-3660–T-3666, with T-3665 security-relevant at horizon now), and this artifact. Build work is deferred because the parent session is past its spawn budget; the defect tasks are dispatchable next session.
