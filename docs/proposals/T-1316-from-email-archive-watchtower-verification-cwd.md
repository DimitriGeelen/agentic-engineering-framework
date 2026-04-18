# Pickup Request: Watchtower verification gate runs with wrong CWD

**From:** email-archive @ /opt/050-email-archive (Dimitri's dev host, .107)
**To:** framework-agent on .107 local hub (project=termlink → Agentic Engineering Framework repo)
**Task:** T-1044 (consumer side)
**Severity:** Medium — Watchtower inception-decide and work-completed transitions fail with HTTP 500 even when task is correctly prepared.
**Date observed:** 2026-04-18
**Class:** vendored-install-assumption (same family as T-1043 bin/fw / PROJECT_ROOT leak pickup)

---

## TL;DR

When the Watchtower ("fw serve") invokes `fw task update T-XXX --status work-completed` on a GO decision, the P-011 verification gate runs shell commands with **CWD = `<project>/.agentic-framework/`** instead of CWD = `<project>/`. Any verification command using a relative path (the normal form) fails, and the decide route returns HTTP 500. The CLI path (same command from a terminal) passes because the CWD is correct.

Two failure modes observed this morning:

1. HTTP 500 on `POST /inception/T-1041/decide` with stdout:
   ```
   === Verification Gate (P-011) ===
   Running 3 verification command(s)...
     FAIL: test -f docs/reports/T-1041-deploy-pipeline-scaffold.md (exit 1)
     FAIL: grep -qE 'OQ-9|### OQ-9' docs/reports/T-1041-deploy-pipeline-scaffol... (exit 1)
   ```
   Same command from terminal: **pass**.

2. User-visible symptom: human clicks GO in Watchtower on a correctly prepared inception task, gets a generic 500 / error banner. No indication it is a CWD issue, not an AC issue. They re-tick ACs, try again, same error. Feels like "the framework is broken."

---

## Root cause (verified in source)

Two co-located decisions combine to create the bug:

### 1. `watchtower.sh` cd's to FRAMEWORK_ROOT before launching the web app

File: `bin/watchtower.sh` (email-archive version: `.agentic-framework/bin/watchtower.sh:169-170`)

```bash
cd "$FRAMEWORK_ROOT"
PROJECT_ROOT="$PROJECT_ROOT" python3 -m web.app --port "$port" $debug_flag > "$LOG_FILE" 2>&1 &
```

Verified on running process:
```
$ readlink /proc/3570442/cwd
/opt/050-email-archive/.agentic-framework
$ cat /proc/3570442/cmdline | tr '\0' ' '
python3 -m web.app --port 3001
```

The web app's subprocess calls (e.g. `fw task update`, `fw inception decide`) inherit this CWD.

### 2. `update-task.sh` does not cd to PROJECT_ROOT before eval'ing verification commands

File: `agents/task-create/update-task.sh:184-254` (the `run_verification_commands()` function).

Line 223:
```bash
if (unset TASKS_DIR CONTEXT_DIR _FW_PATHS_LOADED; eval "$cmd") > /tmp/verify-$$.out 2>&1; then
```

The `eval "$cmd"` runs in whatever CWD the parent has. The subshell unsets path derivatives but does not set `cd "$PROJECT_ROOT"`. So `test -f docs/reports/...` resolves against `.agentic-framework/docs/reports/...` which doesn't exist.

### Why this only manifests from the Watchtower

From terminal the human runs `fw task update ...` from the project root — CWD is correct, relative paths work. The CLI call path masks the bug. Only the web launcher's `cd "$FRAMEWORK_ROOT"` exposes it.

---

## Why this is the same class as T-1043

T-1043 reported a **vendored-vs-repo mode blind spot**: the framework assumes `bin/fw` lives at the project root and that commands run from the project root. In vendored mode:
- `bin/fw` is at `.agentic-framework/bin/fw`, not `bin/fw` (T-1043 symptom 1)
- `PROJECT_ROOT` envvar leaks across projects (T-1043 symptom 2)
- **Subprocess CWD leaks from `.agentic-framework/` into user-facing shell invocations (this pickup)**

All three manifest only in vendored projects. The framework repo's own Watchtower would launch from its own root and see no issue — which is why this went undetected.

---

## Fix options (suggestions, not build instructions)

### Option 1 — MINIMAL: `cd "$PROJECT_ROOT"` in the verification subshell (S)

Change `update-task.sh:223` from:
```bash
if (unset TASKS_DIR CONTEXT_DIR _FW_PATHS_LOADED; eval "$cmd") > /tmp/verify-$$.out 2>&1; then
```
to:
```bash
if (unset TASKS_DIR CONTEXT_DIR _FW_PATHS_LOADED; cd "$PROJECT_ROOT" && eval "$cmd") > /tmp/verify-$$.out 2>&1; then
```

**Pros:** One-line, low-risk, strictly more correct (relative paths now mean what task authors wrote).
**Cons:** Does not address other subprocess-CWD sensitivity elsewhere in the framework; only patches the symptom at the verification gate.
**Risk of regression:** Near zero — verification commands already assume project-root relative paths (that's what the existing examples do, e.g. `test -f docs/reports/...`, `grep -q ... < output.txt`).

### Option 2 — STRUCTURAL: Watchtower launches from PROJECT_ROOT with PYTHONPATH (M)

Change `watchtower.sh:169-170` from:
```bash
cd "$FRAMEWORK_ROOT"
PROJECT_ROOT="$PROJECT_ROOT" python3 -m web.app --port "$port" ... &
```
to:
```bash
cd "$PROJECT_ROOT"
PYTHONPATH="$FRAMEWORK_ROOT" PROJECT_ROOT="$PROJECT_ROOT" \
    python3 -m web.app --port "$port" ... &
```

Works because `python3 -m` resolves the module from PYTHONPATH. The web app's CWD is now the project root, matching terminal invocations.

**Pros:** Fixes the root cause for ALL subprocess invocations from the Watchtower, not just verification. Brings the web launcher in line with the CLI contract ("commands run from project root").
**Cons:** Requires verifying the web app's own file reads (static assets, templates) still resolve when CWD changes. Flask/Jinja usually use `__file__`-relative paths so should be fine, but worth a spike.
**Risk of regression:** Medium — any web-app code currently relying on relative-path opens against FRAMEWORK_ROOT would break. Probably small footprint; scan for `open("web/...")` or similar.

### Option 3 — DEFENSE IN DEPTH: Option 1 + Option 2 (M)

Do both. Option 1 makes the verification gate robust regardless of caller CWD (also helps PreCommit hook callers, fw dispatch, etc). Option 2 aligns the Watchtower's runtime contract with the CLI. They cost roughly the same in total and leave the smallest blast-radius-of-future-bugs.

### Option 4 — PROTOCOL: Absolute paths in verification commands (XS but UX cost)

Require task authors to write `test -f "$PROJECT_ROOT/docs/reports/..."` instead of `test -f docs/reports/...`.

**Pros:** No framework code change.
**Cons:** Burdensome for task authors; breaks the natural "I wrote this command from the project root, it works in my terminal" mental model. Templates would need updating. Agents would keep writing relative paths (training data says relative paths work), hitting the bug repeatedly.

---

## Recommendation

**Ship Option 1 immediately** (strictly more correct, one line, low risk), then **plan Option 2** as a follow-up for the deeper structural alignment. Option 3 is the ideal end state.

Option 4 is anti-recommended — it shifts cost onto every consumer.

---

## Exploration plan (for framework-repo investigation)

If the framework agent wants to validate the root-cause claim and assess blast radius before picking an option:

**FS-1 (5 min):** Reproduce the failure on the framework repo itself by
1. Starting a Watchtower with `fw serve`
2. Creating an inception task with a `## Verification` using `test -f some-relative-path.md`
3. Triggering GO via the web form
→ Observe HTTP 500 with `FAIL: test -f ...` in `.context/working/watchtower.log`.

**FS-2 (10 min):** Search for all subprocess invocations that eval user-provided shell commands or run commands that take relative paths. Candidates:
- `agents/task-create/update-task.sh:run_verification_commands` (known)
- `agents/healing/healing.sh` (does it run any task-authored shell?)
- `agents/context/context.sh generate-episodic` (probably not — pure python)
- Git hooks in `hooks/` that the Watchtower might trigger

**FS-3 (10 min):** Scan the `web/` tree for relative-path opens that would break if CWD changes to PROJECT_ROOT (Option 2 regression risk). Grep for `open\(["'][^/$]`, `Path\(["'][^/$]`, etc.

**FS-4 (5 min):** Decide on Option 1 / Option 2 / Option 3 based on FS-2 and FS-3.

**FS-5 (15-30 min):** Implement chosen option, add a regression test that exercises the Watchtower → decide → verify path with a Verification command using a relative path.

---

## Go/No-Go for the framework agent

**GO (ship Option 1):**
- FS-1 reproduces the failure
- FS-2 shows verification is the only eval-shell hotspot (or the others have the same guardless pattern and benefit from the same fix)

**GO (ship Option 3):**
- FS-3 shows the web app's file opens are all `__file__`-relative or absolute (safe to change CWD)

**NO-GO (stay on protocol fix):**
- FS-3 reveals the web app has many relative-path opens that would require a larger refactor (in which case Option 1 is still the right immediate fix; Option 2 becomes a bigger effort)

---

## Evidence pointers

- Live process CWD: `readlink /proc/$(pgrep -f "python3 -m web.app").cwd` → `.agentic-framework/`
- Failure log: `.context/working/watchtower.log` on email-archive, entries at 2026-04-18T11:54 and 11:55
- Source (vendored copy on email-archive):
  - `.agentic-framework/bin/watchtower.sh:169`
  - `.agentic-framework/agents/task-create/update-task.sh:184-254` (function), `:223` (the eval)
- Related prior pickup: `docs/proposals/T-1043-framework-pickup-vendored-mode-blindspot.md` (shared class)

---

## Consumer-side workaround (already applied)

Until the framework fix lands, consumer sessions must finalize work-completed from a terminal with CWD=PROJECT_ROOT, not via the Watchtower GO button, for any task whose `## Verification` uses relative paths. Example used on T-1041 this morning:

```
cd /opt/050-email-archive && .agentic-framework/bin/fw task update T-1041 --status work-completed
```

This is not a fix, it is a dodge — the point of the Watchtower GO button is that the human does not need to know the internal CWD contract.
