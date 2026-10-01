## VERDICT: AMBER

**I found no remaining HIGH within T-3580’s stated same-user trust boundary.** The round-7 high findings’ specific routes are closed, but three medium issues remain in the touched enforcement code. This is not an unconditional green.

No real verdict was recorded, no task criterion was ticked, and no repository file was changed. I could not append this review: the sandbox also denies temporary writes.

## WHAT I CHECKED

Reviewed the named commits, both round-7 reports, T-3580’s Decisions, T-3581’s accepted residual boundary, and the relevant dispatch, runtime, policy and ledger code.

Verification:

- **6 fixture-free round-8 tests passed; 69 deselected.**
- Full round-8 pytest execution was blocked by “No usable temporary directory.”
- Bats execution was blocked by “BATS_TMPDIR (/tmp) is not writable.”
- Ran actual CLI refusal checks and in-memory probes against implementation functions, substituting filesystem/Git/authenticated-record inputs where necessary.
- All six vendored source files matched their originals at `1f773f3f2`.
- Relevant working-tree implementation files matched that reviewed commit.

I cannot independently confirm **510 pytest / 68 Bats passing** or successful live review dispatches.

| Requested probe | Result |
|---|---|
| Consult stanza before brief | Actual `_prompt_fault` refused it. Canonical prompt passed; appended text failed. Dispatcher omits the stanza, and the review-worker hook suppresses consult delivery. |
| Different `--model` | Registration refused a different model in an in-memory probe. CLI execution stopped earlier because registry loading requires a temporary file. |
| `--mcp-config` | Actual dispatch CLI refused it before spawning. |
| `settings.local.json` env/hook | Runtime selects `user,project`, excluding `local`. Verified by code and documented CLI semantics; no live Claude invocation. |
| `$(...)` environment value | JSON accepted it as data; the runtime’s literal Bash export operation preserved it without executing it. `env.sh` is refused. |
| Lowered-and-left-lowered risk | Actual judge planning, with substituted history inputs, selected rung 5 from historical blast radius 9 despite current radius 0. |
| Git history read failure | `log` and `show` failures raised `HistoryUnreadable`; **`rev-parse` failure still returned empty history**. |
| Components at rung time | Five matching committed cards produced rung 5. **Equivalent quoted locations produced rung 1.** |
| Committed free-text spend | Spend calculation counted the free-text row as zero. Commit/append-only integration could not run. |
| `10**400` spend | `_money` returned `None`; spend calculation refused the amount without `OverflowError`. |
| Caller `--env` | Actual CLI refused `GIT_AUTHOR_NAME=Operator` with the intended explanation. |

The `--full-history` change addresses the identified TREESAME pruning route by inspection; I could not rerun its Git fixture.

## FINDINGS

### 1. MEDIUM — Initial HEAD lookup still fails open

**Where:** [`_head_sha`](/opt/999-Agentic-Engineering-Framework/lib/verdict_ledger.py:727), [`_task_history_fms`](/opt/999-Agentic-Engineering-Framework/lib/verdict_ledger.py:1776), and `_git_components`.

**What:** `_head_sha` converts every unsuccessful `git rev-parse` into `""`. The history and component functions interpret this as an unborn repository and return no historical risk.

Reproduced with Git status 128:

```text
_task_history_fms → []
task_required_strength → (1, 'default')
```

The second probe supplied a low task at a known reviewed revision. Thus, although the specific `log`/`show` failures are fixed, an earlier lookup failure can still discard historical requirements.

**Fix:** Distinguish a verified unborn repository from an unreadable HEAD/repository. Raise `HistoryUnreadable` for the latter, and do not cache that result as empty history.

### 2. MEDIUM — Component counting can silently undercount valid cards and lose historical coverage

**Where:** [`_git_components`](/opt/999-Agentic-Engineering-Framework/lib/verdict_ledger.py:1821).

**What:** Fabric cards are parsed by splitting `git grep` output, rather than parsing YAML. Valid quoting remains part of the location string and prevents path matching.

Using the same five changed source paths:

```text
location: lib/m0.py       → components=5 → rung 5
location: "lib/m0.py"     → components=0 → rung 1
```

Additionally, mappings come only from cards at current HEAD. Committing card removal or location changes can erase attribution for earlier task commits. My substituted-Git probe returned five components with the cards and zero without them. Historical task frontmatter cannot preserve this information when `components` remained empty.

**Fix:** Parse committed cards as YAML. Resolve attribution against the relevant historical commits, or preserve a monotonic historical component set. Add controls for quoted locations and committed card removal/renaming.

### 3. MEDIUM — Old signed starts can be recycled as fresh weekly spend

**Where:** [`_judge_row_cost`](/opt/999-Agentic-Engineering-Framework/lib/review_policy.py:224) and [`_spent`](/opt/999-Agentic-Engineering-Framework/lib/review_policy.py:253).

**What:** Binding and per-dispatch caps close the original arbitrary free-text amount route. However, the seven-day window uses the cost row’s unsigned `ts`; neither the signed run timestamp nor signed start time constrains it.

With authenticated-record inputs representing a **2020** run/start, a fresh **2026** cost row contributed **3.0**. Including the original old cost row did not prevent this: it was filtered out before deduplication.

Consequently, an accumulated stock of old dispatches can support renewed step-downs through newly committed cost rows, without new runtime starts. This is narrower than the original fabrication route but exceeds the documented residual of needing enough genuinely started reviews for the week.

**Fix:** Derive spend eligibility from signed execution time, validate the cost timestamp against it, and deduplicate dispatches across the ledger before applying the weekly window.

### 4. LOW — Documentation overstates several guarantees

**Where:** [CLAUDE.md](/opt/999-Agentic-Engineering-Framework/CLAUDE.md:875), [T-3580 Decisions](/opt/999-Agentic-Engineering-Framework/.tasks/active/T-3580-t-3557-slice-3-fw-reviewer-judge---dispa.md:509), and touched function docstrings.

**What and fix:**

- **No concrete models are currently pinned.** `worker_models(policy/review-backends.yaml)` returns `{}`. The mechanism binds an empty model argument, meaning “worker default.” Say that explicitly, or populate concrete pins.
- “History git cannot read refuses” needs qualification until finding 1 is fixed.
- “Every consult” is stronger than `_consult_traffic`’s bounded read of 500 messages per topic. Document truncation or paginate.
- “About sixteen rung-5 panels” applies near the **100 floor**, not the **10,000 default**. At the default, approximately 1,666 fully counted panels’ worth is needed. The Decisions also inconsistently say “panel seats.”
- Some docstrings still describe `env.sh` and suffix matching despite the new JSON/equality implementation.

## GUIDANCE

The exact preamble check, signed environment data, literal environment loading, caller-flag refusals and shared history-aware planning are substantial improvements. I found no bypass of their specific round-7 probes.

**`~/.claude/settings.json` remains a steering route.** `user,project` intentionally loads it, along with project settings. This falls within the explicitly disclosed same-user residual, but “operator-owned, not caller-owned” is not an OS isolation boundary when both run as the same user. Project settings are also loaded from disk; this flag does not authenticate them against Git. The exclusion of local settings and retention of user/project settings match [Claude’s CLI reference](https://code.claude.com/docs/en/cli-reference) and [settings documentation](https://code.claude.com/docs/en/settings).

For ordinary dispatches, I found no new unconditional block by inspection:

- The judge passes none of the newly forbidden options.
- Direct review dispatch without overrides follows the intended path.
- `fw reviewer T-XXX --dispatch` uses the separate static-review wrapper; it should not be treated as equivalent to the signed semantic judge path.

Successful execution remains unverified here. Retaining user/project permission settings is an explicit compatibility choice, not evidence of an isolated reviewer environment.

T-3619 and T-3620 appropriately track the cleanup/WARN and handover residuals. **The operator can now decide whether the three mediums and disclosed trust-boundary residuals are acceptable; I am not requesting another broad review round.** If fixes are required, targeted regression tests for these three findings are the next useful work.