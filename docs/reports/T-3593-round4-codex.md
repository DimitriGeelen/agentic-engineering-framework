## VERDICT

- **T-3593: RED.** The named round-3 spellings are addressed, but environment-changing wrappers still defeat the new mapping rule. A touched Git-option detector also misses commands with escaped-space paths.
- **T-3594: AMBER.** The tag namespace fix is consistent in the code and passed in-memory probes. End-to-end verification remains incomplete, and the text-gate findings below still affect its documented coverage.

Repository unchanged. I could not append this review because the filesystem is read-only.

## WHAT I CHECKED

Read commit `1d034653a`’s message, stat and implementation/docs diff; both round-3 reports; task Decisions; the two round-4 suites; and updated idempotency/hash-normalization tests.

**Execution limits:** Bats stopped before running tests:

```text
Error: BATS_TMPDIR (/tmp) is not writable
```

I therefore cannot confirm **148/148**. Instead, I executed the hook’s detection/classification section in isolation, stopping before approval-file operations, and exercised approval transitions with an in-memory store. These are not substitutes for end-to-end or filesystem-concurrency tests. No destructive command or real approval was executed.

| Requested probe | Independent result |
|---|---|
| `HOME`, `XDG_CONFIG_HOME`, `GIT_CONFIG_GLOBAL`, including `env` | Named forms flagged as HOOK BYPASS and unmapped |
| Multi-setting `GIT_CONFIG_PARAMETERS` | Flagged and unmapped |
| `CDPATH` prefix and inherited environment | Unsafe relative mapping rejected; `./sub` control remained mapped |
| `git -P push -f` | Detected; explicit branch ref mapped |
| Tag deletion `:v1`, `--delete v1`; force update `HEAD:v1` | Correct `refs/tags/v1` keys with simulated local refs |
| Stranded tag approval versus same-named branch | Branch consumption refused in memory |
| `git commit -n -m x`, combined `-anm` | HOOK BYPASS detected |
| Distinct tool calls after consumption | Second call refused in memory |
| Actual `reset --hard HEAD~1` executed twice | Not run; filesystem restriction prevents fixture setup |
| Ordinary push, handover, tag creation, mirror command, project `status` | Detection returned SAFE; actual workflows not executed |
| Typed round-3 self-approval variants | Listed shell-wrapper, split-word and variable-verb forms detected |

Shell syntax checks passed. All three changed implementation files matched their vendored copies.

I did **not** find round-4 Decisions entries in the supplied active task files: T-3593 contains earlier decisions; T-3594’s Decisions section is a template.

## T-3593 — FINDINGS

### HIGH — Environment taint disappears behind shell wrappers

**Where:** [lib/tier0_action.py:292](/opt/999-Agentic-Engineering-Framework/lib/tier0_action.py:292), `env_effect`, `classify_segment`, and `classify`.

**What:** `env_effect()` examines the raw first word before wrapper removal or shell token normalization. These probes still produced an ordinary force-push action:

```bash
command export GIT_CONFIG_GLOBAL=/tmp/config &&
git -C <project> push -f origin refs/heads/main

'export' GIT_CONFIG_GLOBAL=/tmp/config &&
git -C <project> push -f origin refs/heads/main

command source /tmp/envfile &&
git -C <project> push -f origin refs/heads/main
```

The unreadable first segment invalidates the cwd but does not set environment taint. The later absolute `-C` restores a known repository, permitting action mapping.

For the first two probes, the overall detector even reported HOOK BYPASS while still emitting the force-push action. Pattern coverage is checked per segment, losing the cross-segment relationship.

This leaves the round-3 N1 failure mechanism reachable: configuration can disable pre-push while the text gate admits an ordinary push approval. The unconsumed record can subsequently authorize another push within its admission window. That consequence follows from the code; I could not replay the full push chain here.

**Fix:** Recognize environment-changing builtins after safe wrapper/token normalization. Conservatively preserve environment uncertainty across unreadable segments; `git -C` must not clear it. Ensure a cross-segment HOOK BYPASS cannot coexist with an action approval that does not cover it.

### HIGH — Escaped-space Git global-option arguments evade detection

**Where:** [agents/context/check-tier0.sh:174](/opt/999-Agentic-Engineering-Framework/agents/context/check-tier0.sh:174), `GIT_PRE`.

**What:** The extracted detector returned **SAFE** for:

```bash
git -C /tmp/a\ b push -f origin main
git -C /tmp/a\ b reset --hard HEAD
git -C /tmp/a\ b commit -n -m x
HOME=/tmp git -C /tmp/a\ b push origin main
```

These are valid shell spellings of a path containing a space. The regex does not recognize the argument boundary, so the conservative global-option classifier never gets a chance to reject or map the command.

This is a remaining gap in code touched by round 4; I am not claiming round 4 introduced it. Pre-push still protects forced updates when it runs. Hard reset has no equivalent backstop.

**Fix:** Parse Git command/global-option boundaries using shell-aware tokens, with conservative fallback for unsupported syntax. Add escaped-space controls alongside quoted-path tests.

### MEDIUM — Legacy deduplication proceeds after lock acquisition failure

**Where:** [agents/context/check-tier0.sh:432](/opt/999-Agentic-Engineering-Framework/agents/context/check-tier0.sh:432).

**What:** `flock -w 10` failure is unchecked. The script continues into the legacy check-and-consume path without owning the lock. Missing `flock` also leaves that path unlocked. Consequently, concurrent consumption is not unconditionally serialized.

The Python action store independently uses a blocking lock; this finding concerns the legacy exact-text path. It is a code-inspection finding, not a reproduced filesystem race.

**Fix:** Fail closed on lock acquisition failure. Explicitly handle unsupported locking rather than proceeding through an unprotected approval consumption.

### MEDIUM — Deduplication guarantees need qualification and stronger tests

**Where:** [lib/tier0_action.py:896](/opt/999-Agentic-Engineering-Framework/lib/tier0_action.py:896), the legacy sentinel, and round-4 tests.

Observed and inspected behavior:

- **Fresh distinct ID:** cannot reuse a consumed approval.
- **Missing ID:** no duplicate grace; duplicate registrations can block their own call.
- **Replayed valid ID:** accepted again. In memory, the original ID remained accepted long after grant expiry because duplicate matching precedes expiry processing.
- **Malformed ID:** shell validation clears disallowed characters; this is syntax checking, not authentication.
- **Concurrent fires:** action-store locking serializes transitions; actual concurrent fixture execution remains unverified.
- **Retry after execution error:** a new ID needs fresh approval once consumed. Push approvals can remain admitted until consumption or expiry. Reusing the original ID remains eligible for duplicate grace.

This is acceptable only with an explicit assumption that trusted runtime IDs are unique per execution and unavailable for caller-controlled replay. It is not a forgery-resistant guarantee, consistent with the existing same-user limitation.

The round-4 test named “cannot run twice” does **not execute either reset**. It tests hook admissions against unchanged repository state.

**Fix:** Document the ID trust and retry assumptions. Add a fixture that actually performs the first reset, attempts the second under a fresh ID, and checks the branch moved only once. Cover lock failure and execution-error retries.

### Documentation corrections

The guides now honestly describe script visibility limits, same-user approval forgery, configuration-based hook bypasses and the 60-second admission expiry.

However:

- The blanket environment-taint and global-option claims exceed the behavior demonstrated above.
- “An approved command runs once” needs the trusted-ID qualification.
- T-3593’s earlier Decision says 60 seconds “removes” the second-use window. It **bounds** that window.
- `FRAMEWORK.md` overstates CDPATH handling: explicitly anchored relative paths such as `./sub` remain mapped.

**GUIDANCE:** Do not close T-3593. Fix the two high findings and lock-failure handling, qualify the documentation, then rerun the targeted fixture suites.

## T-3594 — FINDINGS

**No separate high-severity defect found in the changed ref-key logic.**

The shared namespace resolver correctly produces `refs/tags/v1` for the named deletion and force-update forms. The in-memory consumer refused a branch deletion against a stranded tag approval. Ambiguous or absent local evidence falls back to unmapped rather than guessing.

The common `git commit -n` fast-path defect is closed for the named spellings. Its global-option path remains affected by the escaped-space finding above.

**MEDIUM — Verification remains incomplete.** Actual tag deletion, forced tag movement, stranded-approval isolation, concurrent hooks, and ordinary handover/mirror workflows could not be rerun here. Safe text classification does not establish end-to-end workflow compatibility.

**GUIDANCE:** Retain AMBER pending independent fixture execution. Keep the namespace fix, add the escaped-path regression tests, and avoid declaring the combined round-3 findings closed until T-3593’s remaining prefix gap is fixed.