# T-3977 — Static review of ring20's arc-009 upstream map

**Reviewed:** ring20 `docs/reports/T-2281-arc009-upstream-proposal.md` at commit `f2c968bda`; code at the
pinned commit `49708487a` (both present). Read-only, static review. No ring20 code was run. The clone was
read with `git show` only. ring20 references are `r20:<path>:<line>@49708487a`, and map sections are `map §N`.
**Reviewer:** dispatched worker `t3977-arc009-review`, 2026-10-07.

## Summary

1. The map is accurate where it could be checked. Every file and line count in map §4 matches the pinned
   commit, and every AEF symbol it calls exists with the expected signature.
2. The portable core (registry, route side-file, data classes, ledger/fold, view, candidates) really is
   portable. The estate-specific content is constants, as the map says. One exception: the supervisor hard-wires
   `systemd-run` as its default launcher and `/var/lib/orch` as its state directory.
3. The supervisor **uses** AEF's resolver, keylock, outcome, spawn and review_cost. It **duplicates** five AEF
   mechanisms: the worker launch path, the review verdict, operator approvals, P-011 extraction and the OS sandbox.
4. The review duplicate is the biggest gap. "approve/reject on a different route" does not go through
   `verdict_ledger` or `review_policy`'s rung model.
5. It **contradicts** two AEF rulings. Workers launch outside `fw termlink dispatch`, so the T-3910 worker cap
   does not apply. Nothing writes to `.context/costs/reviews.jsonl`, which T-3583 requires.
6. Of the §6 security lessons, AEF already avoids G-228 and G-231 in `lib/govd_sandbox.py`. It carries
   T-2271 (scan-tree passes on an empty index) today. T-2272 and T-2274 are latent in govd_sandbox. G-232 is
   T-3980.
7. Three small pieces are worth taking now whatever is decided about orchestration. Each fixes or factors
   something AEF already has.
8. The engine (1,524 lines in one file) should not land as a single piece. Split it along the seams it already has.

**Recommendation: GO, piece by piece.** Land the AEF-side fixes and the schemas first. Land the engine only
after three decisions: (a) the launcher seam defaults to `fw termlink dispatch`; (b) the review step records
through `verdict_ledger` (or is explicitly scoped as a different class); (c) the isolation adapter is
reconciled with arc-013's `govd_sandbox` rather than added as a second sandbox. The work is real, tested and
built on AEF. What blocks a wholesale merge is the duplicates, not the quality.

---

## IW-1 Portable core vs estate-specific

| Component (map §4) | Class | What makes it specific |
|---|---|---|
| Supervisor engine `scripts/orch-supervisor.py` (1524) | **MIXED** | `STATE_DIR` default `/var/lib/orch` (r20:…supervisor.py:49). `LANDING_REF = refs/heads/orch/landing` (:58). `HIDDEN_SOCKET_DIRS` includes `/var/lib/termlink`, `/run/dbus` (:55). The default launcher is `SystemdLauncher` (`systemd-run`, :352-373, used by default at :529). The notifier is `scripts/notify-operator.sh` (:646). Hook paths are hard-wired to the vendored layout `.agentic-framework/...` (:52, :61-64), which breaks inside the framework repo itself. `PROTECTED_PREFIXES` (:84) is ring20's layout. The map says the launcher is injectable (map §5.1), and it is (:515). But the *default* is systemd, so "no OS assumptions" holds only for the seam, not for the shipped default. |
| Registry `scripts/orch-registry.py` (253) | **PORTABLE** | It imports AEF `review_cost` (r20:…registry.py:67) and does not parse `review-backends.yaml` itself, which is correct. |
| Candidates `scripts/orch_candidates.py` (325) | **PORTABLE** (UNVERIFIED in detail: only the line count was checked) | none claimed |
| View model `scripts/orch_view.py` (311) | **PORTABLE** (UNVERIFIED in detail) | none claimed |
| Watchtower pages (82 + templates) | **MIXED** | They need a blueprint extension point. AEF's `web/blueprints/__init__.py:4` registers a static, hand-edited list, so ring20 has to patch the vendored file. There are copies under `.agentic-framework/web/templates/orch_regist*.html` at 49708487a, i.e. vendored patches. |
| Route catalogue schema + entries (151 + 108-line design) | Schema **PORTABLE**, entries **ESTATE** | the routes themselves |
| Data classes `policy/data-classes.yaml` (27) | **PORTABLE** | path defaults |
| Isolation core `scripts/orch_pool.py` (489) | **MIXED (Linux/systemd adapter)** | Pool `60900–60915` (r20:…orch_pool.py:4, :25), user names `orch-wNN`, hidden-path list. `safe_git` (:453) is portable on its own and is the piece T-3980 wants. |
| Firewall (nft + script + slice + unit, ~140) | **ESTATE** content, **PORTABLE** pattern | DNS resolvers, hairpin IPs, LAN ranges (map §4). The unit name is `ring20-orch-worker-fw.service`. |
| Preflight `scripts/orch-preflight.py` (387) | **MIXED** | deny targets, hairpin IPs, project path |
| Host setup / login (48 + 48) | **ESTATE** | user names, paths, vendor login staging |
| Tests (1832 total: 984/248/241/255/104) | **MIXED** | Fixtures copy ring20 entries (map §4). They need re-fixturing against AEF's own routes. |

The map's "~5,900 lines, a handful of constants" is fair for the data files. It understates the supervisor:
its defaults (launcher, state dir, notifier, vendored hook paths, protected prefixes) are code, not
configuration. Each one needs a config key or a seam default before the engine is portable.

## IW-2 Overlap with AEF primitives

| AEF primitive | How ring20 uses it | Verdict |
|---|---|---|
| `lib/resolver.py`: `load_workflow` (:111), `assemble_prompt` (:247), `capture_dispatch(parent_dispatch_id=)` (:768/:774), `load_task_frontmatter` (:937) | Called directly (r20:…supervisor.py:789-820). It loads the vendored module by path with `importlib` (:88-106) | **As-is**, but through *private module loading*. `capture_dispatch` is not a declared public API. An AEF refactor would break ring20 silently. Needs a stable facade. |
| `lib/keylock.py`: `exclusive`, `LockTimeout` (:121, :61) | Supervisor lease (r20:…:1380-1382) | **As-is.** Correct. |
| `lib/outcome.py`: `parse_task_file` (:51) | `task_meta` (r20:…:455-462) | **As-is.** |
| P-011 verification extraction (`update-task.sh`) | Reimplemented in `verification_commands` and `check_script` (r20:…:422-451): "first exact `## Verification` heading, HTML comments stripped, pipefail per command" | **DUPLICATE.** It is faithful today per T-3960 §3c, but it is a second parser of a gate AEF owns, and it will drift. AEF should expose the extractor as a library function. |
| `lib/spawn.py`: `update_outcome_row` (:218) | Terminal outcome write-back (r20:…:682-689) | **As-is.** The fence gap (last-writer-wins) is AEF's and is noted open in map §7. Note that the docstring at spawn.py:232-243 says the read→replace window *is* now held under `keylock.guarding`. That fixes the concurrent-append loss. It does not add an outcome fence: two terminal writers still race last-writer-wins. |
| `lib/worker_identity.py`: `worker_git_env(mechanism, dispatch_id)` (:58) | `worker_git_env(f"orch:{c.entry}", c.cid)` (r20:…:1182) | **As-is, but the join key is wrong for retries.** `cid` is the dispatch_id of attempt 1 (map §3). An attempt-N commit therefore names attempt 1's dispatch, and `fw outcome read` on the commit's identity lands on the wrong row. It should pass the attempt's own dispatch_id. Small fix on ring20's side. |
| `lib/review_cost.py`: `get_backend` (:225) | Registry backend lookup (r20:…registry.py:67-130) | **As-is.** Correct, and it keeps review-backends read-only. |
| `.context/costs/reviews.jsonl` / `fw review cost log` (T-3583) | Not called anywhere in `scripts/orch-*` (grep at 49708487a) | **CONTRADICTS** the cost ruling: "every review or dispatch records its cost". Commissions and their reviews are dispatches. |
| `fw termlink dispatch` (agents/termlink/termlink.sh, cap at :425-430) | Not used. Workers launch via `systemd-run` (r20:…:352-373). ring20's own `role-chain.py:22` *does* use `fw termlink dispatch` | **CONTRADICTS / DUPLICATES** the dispatch path. It bypasses `TERMLINK_MAX_WORKERS` (T-3910), the kill watchdog, `termlink list` observability, and review-dispatch registration (`review-dispatches.jsonl`, HMAC). It has its own caps instead (map §3 "caps reserved atomically"). Defensible for OS isolation, but it should be a declared launcher adapter, and AEF should decide whether the cap and registration apply to it. |
| `lib/verdict_ledger.py` / `lib/review_policy.py` | Not used by the orchestration engine. Review is "fresh analyst commission on a **different route**, bound to output hash" with `verdict: approve|reject` parsed from stdout (r20:…:1094-1129). ring20 *does* use verdict_ledger elsewhere (`scripts/reviewer-auto-disposition.py:111`) | **DUPLICATE.** It is a second review-verdict mechanism without rung policy (review_policy.py:11-32: rung by impact, rung 5 = three vendors), without provenance (producer set, signed dispatch), and without the append-only ledger. "Different route" is a weaker stand-in for "different vendor". |
| Tier-0 / paid-backend hooks | Invoked as subprocess `fw hook check-…` against the actual command (r20:…:537-546), with a positive control: a force-push must be refused or the run does not arm (:1349) | **As-is (wrapped).** The positive control is good practice. AEF could adopt it in `fw doctor`. |
| Approvals (`fw tier0 approve`, `fw review propose/approve`) | Own file-grant store `STATE_DIR/approvals` with `grant/consume` and an operator-only CLI (r20:…:264-298, :1472-1501) | **Partial DUPLICATE.** The "arm a run" gate has no AEF equivalent, so the new gate type is legitimate. The store and the operator-only check are a third approval mechanism next to the Tier-0 and paid-proposal ones. |
| `agents/git/lib/secret-scan.sh scan-tree` | Run on a `git archive HEAD` into a fresh root-built repo (r20:…:1187-1214), with a catalogue-missing refusal (:1192) | **Wrapped**, and it compensates for an AEF fail-open (see IW-4, T-2271). |
| Notifications (`fw_notify`) | `scripts/notify-operator.sh` (r20:…:646) | **Duplicate (minor).** It should go through `fw notify`. |
| `lib/govd_sandbox.py` (arc-013: uid demotion, nft egress, systemd unit emit/install/drift) | Not referenced. `orch_pool.py` + nft + slice + preflight is a second sandbox | **DUPLICATE in intent.** They differ in scope: one agent uid and a proxy-only egress (AEF) versus a per-attempt uid pool with deny lists (ring20). Two sandboxes in one framework would be the G-230 drift class at framework scale. |
| Release train / landing | Lands on `refs/heads/orch/landing` via a private index + CAS `update-ref` (r20:…:1136-1184), with a Tier-0 hook check on the update-ref (:1171) | **New mechanism.** It does not contradict the release train (it never touches master or bleeding-edge), but `fw integrate`, `fw worktree gc` and branch-hygiene (`lib/branch-hygiene.sh`) know nothing about `orch/landing`. T-3960 flagged this already. |

## IW-3 PR-sized pieces (smallest useful first)

Sizes are rough line counts including tests. Pieces 0a–0c are AEF-side and stand alone.

| # | Piece | Size | Depends on |
|---|---|---|---|
| 0a | `scan-tree` fails closed when the tree has no index or zero tracked files (rc 3, NOT CHECKED), plus a bats test mirroring ring20's `test_secret_committed_then_cleaned_in_worktree_is_still_caught` | ~40 | none |
| 0b | Expose the P-011 extractor as a library function (`lib/verification_extract.py` or similar), used by `update-task.sh` and importable by consumers | ~120 | none |
| 0c | `safe_git` helper in `lib/` (no system/global config, no hooks, no fsmonitor, `--no-ext-diff --no-textconv`), adapted from r20:…orch_pool.py:453 | ~80 | feeds T-3980 |
| 1 | Route side-file schema + `data-classes.yaml` + validator. It reads `review-backends.yaml` through `review_cost` only | ~300 | review_cost |
| 2 | Registry schema / lint / admission + `admit` CLI (operator-only, same `CLAUDECODE` refusal pattern as `fw review approve`) | ~450 | 1 |
| 3 | Commission ledger + `fold()` + atomic caps, extracted from the supervisor, on keylock | ~500 | keylock, 1 |
| 4 | A stable `fw`-side facade over resolver/outcome/spawn (the functions ring20 loads by path today) | ~150 | none; prerequisite for 5 |
| 5 | Supervisor engine with seams. Default launcher = `fw termlink dispatch`. Review through a `verdict_ledger` adapter. Cost logging through `review_cost`. Notifier = `fw notify`. Hermetic fakes suite | ~1,500 (split in 2–3 PRs: gates+lifecycle, review+landing, recovery+guard) | 0b, 2, 3, 4, plus decisions D-a/D-b below |
| 6 | View model + candidates | ~800 | 2, 3 |
| 7 | Watchtower pages | ~350 | 6, plus P-037 blueprint extension point |
| 8 | linux-systemd isolation adapter (pool, per-attempt tmpfs, reclaim, preflight, nft pattern), *merged into or layered on* `govd_sandbox` | ~1,200 | 5, 0c, T-3980, D-c |

Decisions to take before piece 5:
- **D-a:** Is `systemd-run` an allowed launcher next to TermLink? If so, does the T-3910 cap apply to it?
- **D-b:** Does orchestration review write `verdict_ledger` rows at a policy rung, or is it a separately named
  class that never ticks ACs?
- **D-c:** Is there one sandbox in AEF or two?

ring20's proposed order (map §9 Q6) matches pieces 1→2→3→5→6→8. The changes here are three: lead with
0a–0c, insert the facade (4), and gate 5 on the three decisions.

## IW-4 Security lessons — does AEF have the same exposure today?

| Lesson | AEF exposure | Evidence |
|---|---|---|
| G-228 `skuid != X accept` | **No.** AEF matches positively: `meta skuid $aef_agent_uid jump aef_agent_egress`. | `lib/govd_sandbox.py:214` |
| G-230 two launch paths drift | **Partial / UNVERIFIED.** govd_sandbox emits one unit for the agent *session* (`ExecStart=… claude-fw --termlink`, :153). Whether TermLink-dispatched workers and review workers inherit that profile or run unconfined was not verified. If ring20's engine lands with its own launcher (IW-2), AEF *will* have two launch paths by construction. | `lib/govd_sandbox.py:150-175` |
| G-231 private-range deny list vs global IPv6 | **No, by design.** AEF uses an `inet` table and drops everything except the proxy (allow-list, not deny-list). The cgroup mirror is `IPAddressDeny=any`. | `lib/govd_sandbox.py:211-219`, `:167-168` |
| G-232 git in worker-written tree | **Not today** (same uid, no privilege crossing). **Yes** the day a uid split lands. Filed as **T-3980** (`docs/reports/T-3980-git-in-worker-trees.md`), which lists `lib/integrate.py`, `lib/worktree.sh`, `agents/termlink/termlink.sh`, `lib/reviewer/*`. Also `lib/spawn.py:121-124` runs `git status --porcelain` in the project root, which a worker shares. | T-3980; `lib/spawn.py:118-135` |
| T-2271 scan-tree fail-open on a missing index | **Yes, today.** `scan_tree` searches with `git grep` over *tracked* files and `scan_names` uses `git ls-files`. With an empty or missing index both return nothing and the function returns 0 (PASS). The T-3971 fix only covers a missing *catalogue*. | `agents/git/lib/secret-scan.sh:228-286`, `:443` → piece 0a |
| T-2272 systemd: `InaccessiblePaths=` on a parent hides RW/RO children; `-` prefix; `/dev/shm` | **Latent.** govd_sandbox validates only *exact* path overlap between inaccessible and readable lists, not nesting, so an inaccessible parent above a RW child passes validation. Today's single inaccessible entry (`/run/aef-govd`) has no child entries, so it is not live. | `lib/govd_sandbox.py:91-93`; `policy/sandbox-profile.yaml:42-43` |
| T-2273 nft `socket cgroupv2` binds at load | **No.** AEF matches on uid only, with no cgroup match. The ruleset-digest drift check exists but is by content at emit/install time, not checked before every launch. | `lib/govd_sandbox.py:18-21`, `:214` |
| T-2274 worker reads `/run/systemd/transient` and binaries with embedded keys | **Latent / UNVERIFIED.** The AEF profile does not hide `/run/systemd/transient` (`ProtectSystem=strict` makes it read-only, not invisible) and has no visible-secret content scan from inside the profile. Whether a secret is actually readable on the AEF host was not checked. | `lib/govd_sandbox.py:160-165`; `policy/sandbox-profile.yaml` |

UNVERIFIED overall: whether `govd_sandbox` is *installed* on any AEF host. It is emit-safe and install is
human-only. If it is not installed, every "No" above is a property of the emitted artefact, not of a running host.

## Their §9 questions with suggested AEF answers

1. **In scope as a framework capability, or a separate package?** In scope as an engine with optional
   adapters. It is built on AEF primitives and duplicates AEF gates if kept outside. A separate package would
   freeze the duplicates.
2. **Where: `lib/orchestration/` + `agents/orchestrator/`; fold into the orchestrator card / arc-012?**
   `lib/orchestration/` for the core and `agents/orchestrator/` for the CLI. Home it in a new arc. arc-003
   (`.context/arcs/orchestrator-rethink.yaml`) is model routing and is shipped, so it is not the right home.
   I could not find an "arc-012" orchestration arc file (UNVERIFIED which arc they mean).
3. **systemd/nft isolation adapter acceptable as an optional reference adapter under directive 4?** Yes, as
   optional, but reconciled with arc-013's `govd_sandbox` (one sandbox model, two scopes) rather than a second,
   parallel one.
4. **Take the Watchtower pages (presupposes P-037)?** Yes, after P-037. Today `web/blueprints/__init__.py`
   is a static list, and the pages are the last piece in the order, not the first.
5. **G-232: does AEF run git as a privileged user in worker-written trees?** Not as a *different*
   user today. The same paths become exposed under a uid split. That is T-3980, plus `lib/spawn.py:121`.
   Piece 0c gives T-3980 its helper.
6. **How to receive it?** Review of the map first (this document), then the PR order in IW-3: AEF-side
   fixes 0a–0c first, schemas next, the engine only after decisions D-a/D-b/D-c.

## Method and limits

- Verified: map file list and line counts at 49708487a; the existence and signatures of every AEF symbol ring20
  calls; ring20's launch, review, approval, landing and cost paths by grep and read of `orch-supervisor.py` and
  `orch_pool.py`; the AEF files cited above.
- Not read in full: `orch_candidates.py`, `orch_view.py`, `orch-preflight.py`, the tests, the S-1/S-3 contracts
  and panel records. Claims about them are the map's own and are marked UNVERIFIED where they matter.
- Nothing was executed from the ring20 tree. The ring20 Watchtower URLs in map §1 were not fetched.
