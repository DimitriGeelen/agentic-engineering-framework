**Mis-framing, stated first.** D1 asks which text classifier is best, but no classifier can be a boundary against (b). Every parser has the same blind spot: scripts, aliases, `$(…)` output and glob matches are only known at run time (§9). The vendor's own docs say Bash rules are "not a security boundary" (§10.1). Also, 27 of the 76 attack cases are attempts at self-approval (block-self: T0-012…015, 030…038, 048, 055…058, 061, 063…070). Detection cannot win that class. It disappears only when approval needs a credential the agent cannot hold. The question I answer is: **what boundary makes text classification non-load-bearing, and what guardrail best catches (a)?**

```
D1: Layered — boundary = non-root agent uid + enforcement files owned by root/aef-gov + privileged broker (T-2428's aef-govd) holding the approval state and the forge force-push credential + server-side ref protection; guardrail = per-harness adapters (Claude Code hooks, opencode plugin) calling one AST-based default-deny classifier; payload proxy added later as the cross-harness guardrail, not as the boundary | survives-pilot confidence: medium because uid separation and server-side protection are standard controls, but none is deployed or exercised here (§13.1 "nothing installed"; §11 OneDev protection unknown)
D2: other: polyglot — Go (broker, hook binary, Tier 0 classifier on mvdan.cc/sh); bash stays for the CLI glue; Python stays for Watchtower and the ledger logic; TypeScript frozen at its current scope
D3: Tier 0 gate + pre-push guard; dynamic state store (approvals, focus, bypass log) → broker; hook entry path (replaces `bin/fw hook`); custody of the ledger signing key. Not core: budget gate, task-close gates, the bin/fw CLI
D4: system-level install, root-owned and versioned (/opt/aef/<ver>/: static Go binaries per OS/arch, checksums pinned by the release), referenced from managed settings; the vendored copy keeps the non-core parts; a missing or failed core component means exit 2 on every mutating tool, and the operator does the repair, not the agent
D5: privileged broker on a unix socket that authenticates callers by peer credential; operator approval through WebAuthn on a phone | prompt-free categories: restart of AEF-owned services, installs from an operator-pinned package list, regenerating read-only projections, fast-forward pushes | one-tap categories: every Tier 0 action, every Tier 2 skip, writes to governance or config paths, installing policy or sandbox, any package not on the pinned list
PILOT: Tier 0 gate (Go + mvdan, shadow mode alongside the bash gate) | STOP IF: any §5 expected-block case is allowed, OR the false-block rate on a replay of ≥2 weeks of real Bash commands exceeds the current gate's, OR p95 > 100 ms on the reference host
WOULD CHANGE MY MIND: T-2433's deciding validation (Claude Code + TermLink running as a non-root user with enforcement paths read-only) failing, or needing operator action more than occasionally
```

## 1. Diagnosis

**§5 (76 attack cases).** Roughly 15% are parsing problems that a real syntax tree fixes:
- unmapped spellings and wrappers: T0-011, 017, 024–026, 040–043;
- over-blocks: T0-044, 062, 074.

Roughly 85% are spec/design problems:
- self-approval by text, 27 cases (above);
- keys built by string serialisation, 14 cases: T0-003/004, 045–054, 059/060;
- runtime environment and config the hook cannot see, ~11 cases: T0-001, 006–010, 021–023, 027, 039, 073;
- isolation: T0-015/016/071/072;
- replay and locking: T0-002/028/029.

Almost none are language problems.

**§6 (39 defects).** Mostly language problems, about 22 entries (≈56%). Most are bash evaluating text meant as data, or bash exit-status semantics (D-01…16, 18, 20–23, 25, 28). Two of these sit inside the Tier 0 hook itself: a fail-open (D-06) and an executed `git push` (D-08).

I reclassify D-27, D-31 and D-33 from parsing to **spec**:
- D-27: no parser knows the tool shell's `CDPATH`.
- D-31: putting an interpreter on an allowlist is unsound whatever the parser.
- D-33: keys should be structured, not serialised strings.

That leaves only D-37 (and part of D-32) as genuine parsing: ≈5%. Spec ≈40% (D-17, 19, 24, 26, 27, 29–36, 38, 39).

**Conclusion.** The language explains the silent defects in the plumbing. The design (a text gate treated as a boundary, same-uid state) explains the Tier 0 treadmill.

## 2. Security contract per layer

**Guardrail layer** (hooks, opencode plugin, later the proxy):
- **Trusts:** the harness to invoke it and honour exit 2.
- **Against (a):** blocks or maps every parseable Tier 0 shape. Any word with a non-literal part (expansion, glob, brace, escape) in the command position or a Tier 0 argument is *unmapped*, which means exact-text approval.
- **Against (b):** nothing. It is UX and early warning only.
- **Unsupported input:** a parse error or an unknown construct gets exit 2. A timeout is enforced internally, below the harness timeout, and also exits 2.
- **Excludes:** scripts run later, MCP tools without a matcher, harness bugs.

**Isolation layer** (agent uid, root/aef-gov-owned code, settings, `.git/hooks`, the broker, forge protection):
- **Trusts:** the kernel, the broker binary, the forge, the operator's authenticator.
- **Against (b):** no write to enforcement or approval state (closes T0-016, T0-015's effect, hook edits). No self-approval, because the approval is a WebAuthn assertion the broker verifies (closes the 27 block-self cases and T0-071). No force-push or remote ref deletion by any spelling, because the agent's forge credential lacks the right (closes T0-018, 040–042, 059/060, 072).
- **Residual:** destruction *inside the agent-writable workspace* (T0-011, 017, 043, 073) can only be recovered, not prevented. Recovery comes from broker-held snapshots or refs.

**Gaps only the harness vendor can close (feature request):**
- A per-hook `failClosed` option: today a crash, a hook that cannot start, or a timeout all allow (§2.1, D-35).
- An exec-level hook that sees the resolved argv/env, or sandbox execve events delivered to a hook (§10.4).
- The tool shell's real environment and cwd (CDPATH, aliases, profile) passed to hooks, or a guaranteed hermetic shell (T0-073).
- A managed-only lock for `sandbox.excludedCommands` (§10.3).
- A documented guarantee that `tool_use_id` is unique per session (T0-029).
- A non-forgeable identity, or separate OS principals, for in-process subagents (§13.1 residual).
- Externally verifiable attestation of human approval for permission prompts.
- One cross-harness hook protocol (P-063; codex and opencode have none, §14).

## 3. Options table

The gate column is judged against §3. Implementation rows are judged for the guardrail (a) only, because (b) depends on the architecture.

| Option | Gate | §6 ×2 | Portab. ×2 | Migr. risk ×2 | Maint. ×2 | Latency ×1 |
|---|---|---|---|---|---|---|
| Hooks only, hardened | FAIL: same uid, fail-open harness (§2.1, §11) | 2: per-instance lint treadmill continues | 3: works today, Claude Code only | 4: incremental | 2: seven rounds, still open | 2: 0.42 s added per Bash call (§4) |
| Proxy + OS cage (T-2428 as designed) | UNKNOWN: never fired; proxy matches substrings (§13.1) | 3: cage fixes isolation, not plumbing | 2: microVM Linux-only | 1: microVM unbuilt, 3.5 months idle | 2: virtio backends, heavy for one operator | ?: buffers whole body |
| Harness-native perms + sandbox | FAIL: "not a security boundary" (§10.1) | 1: no effect | 2: per-harness, no WSL1 | 4: configuration only | 4: vendor maintains | 5: in-process |
| **Hybrid (mine)**: uid + broker + forge protection + AST hooks, proxy later | PASS remote/self-approval; in-workspace residual | 4: state and keys leave agent reach | 4: uid, unix socket, forge on all three OSes | 3: system install step for consumers | 3: one broker, one classifier | 4: direct binary, no bin/fw |
| Own: credential separation only (broker performs every push) | PASS remote; in-workspace residual | 2: plumbing untouched | 4: forge-side | 3: workflow change | 3: small | 4 |
| bash + parser | FAIL: no in-bash parser; expansion re-implemented (D-37) | 1: same language defects | 4: text files | 4: familiar | 2: inline Python persists | 2 |
| Python-strict + bashlex | UNKNOWN: no expander; GPL-3.0 vs Apache (§9) | 3: removes string-embedding | 3: Python ≥3.8 present | 3 | 3 | 2: 70 ms launch (§4) |
| TypeScript (T-586) | UNKNOWN: no TS expander listed (§9) | 3: typed, no escaping | 2: Node premise is harness-dependent | 3: lib/ts barely used | 3 | ?: 28 ms prototype only |
| Go + mvdan.cc/sh | UNKNOWN→PASS(a) if pilot holds; `expand` exists (§9) | 4: typed, static, no eval | 4: static cross-compile, needs build | 3: new toolchain | 3: no Go on team (§8) | 4: no interpreter |
| Rust + tree-sitter-bash | UNKNOWN: no expander; ERROR nodes (§9) | 4: typed | 4: static, native lib | 2: write own expander | 3: TermLink precedent | 4 |
| Polyglot (Go core, bash glue, Python UI/ledger) | as Go | 4 | 4 | 3 | 3: three languages, bounded | 4 |

## 4. Reasoning

**D1.** I agree with T-2428's thesis: hooks are never a boundary. Its aef-govd broker (§4e) is my broker. I disagree with its sequencing:
- Its proxy policy is substring matching, which reproduces Problem A (§13.1 Q3).
- The microVM tier is unbuilt, Linux-only, and nothing has been installed in 3.5 months.

The boundary I propose (uid, broker, forge protection) is harness-independent by construction: it does not care which harness launched the process. Harness-specific code shrinks to thin adapters over one classifier binary. The proxy then becomes the portable replacement for those adapters, not the trust anchor.

**D2.** Go plus mvdan is the only §9 option with a real expansion engine and a typed AST, under a permissive licence. Static binaries remove the 70 ms Python launch and the ~100 ms `bin/fw` parse (§4). The string-embedding defects (D-06, D-08) go away. I disagree with T-586 for the core:
- Its premise ("Node is available wherever the harness runs") ties the runtime to Claude Code, which contradicts harness independence.
- No TS bash expander is listed (§9).
- Only one hook shipped in TS (§13.2).

**D3.** I replace the criterion. Core is any code whose failure or forgery would admit an unreviewed destructive or self-authorising action, or which sits on the fail-closed path of every hook. "Stable spec plus tests" measures readiness to migrate, not whether something is core.

**D4.** If enforcement code is vendored into the workspace, the agent can write it, so it guarantees nothing against (b). The core therefore installs root-owned per host, version-pinned. A project names a version; a missing version means deny. This removes the D-34 allow, and removes the self-lock risk (L-332), because repair goes through the operator or `sudo fw upgrade`, outside the gated session.

## 5. Migration and validation

**Sequence:**
1. Non-root agent user; core paths read-only to it (P-01 IW-2).
2. Server-side protection on OneDev; the force-push credential moves to the broker.
3. Approval and focus state moves behind the broker, with WebAuthn approval.
4. Managed settings: `allowManagedHooksOnly`, `disableBypassPermissionsMode`, `failIfUnavailable`, `allowUnsandboxedCommands:false`.
5. Go Tier 0 classifier in shadow mode, then cut over.
6. Hook entry binary.
7. Proxy.

**Parity:** both gates run on every call; only the old one decides; disagreements are logged. The test inputs are all §5 cases plus a replayed corpus of real commands.

**Contract:** the black-box bats suites (§1.3), plus §5 as fixtures. These do **not** cover:
- the isolation properties: test them with red-team scripts run as the agent uid;
- inert tests (L-631/636/651): mutation-test the new gate.

**Fail-closed:** a missing binary, a parse error or an internal timeout means exit 2. An explicit `timeout` is set in settings.

**Rollback triggers:**
- any false allow on §5;
- the false-block rate rises;
- p95 > 100 ms;
- the broker is unreachable for more than one session per week.

Rollback restores the bash gate as guardrail, never a fail-open path.

## 6. Strongest case against

The bottleneck is operator install actions, not language: nothing from T-2428 has been installed in 3.5 months (§13.1). Once steps 1–4 land, the text gate is no longer load-bearing for (b). For (a), a few bash patches plus "non-literal word means unmapped" may be good enough. Adding Go would then bring:
- a language no human on the team reads (§8);
- a cross-compile and release pipeline for each OS/arch;
- another moving part for vendored consumers.

The cheaper verdict would be D2 = no-change for the hooks, with Go only for the broker, or even Python for the broker. I would accept that if the shadow pilot shows the bash gate, once demoted to guardrail, generates no false allows on the corpus.

## 7. Assumptions and missing facts (ranked)

1. OneDev supports per-credential protection against force-push and deletion (§11: unknown). Without it, the remote closure collapses.
2. Claude Code and TermLink work as a non-root user with read-only hooks, settings and `.git/hooks` (unverified; the T-2433 validation was not run, §13.1).
3. Consumers accept a privileged one-time install step (§7.2 unratified; §7.4).
4. mvdan's `expand` handles the §5 spellings (unverified, §9).
5. WebAuthn from a phone to the broker is possible: it needs TLS or a reachable origin, and the authenticity of a tap is not established today (§12.1).
6. Static binaries are acceptable on size, licence and offline install (§7.4: PROPOSED, NOT CONFIRMED).
7. Node is present under non-Claude harnesses (§14: unverified).

## Repo-only findings

None. I did not read the repository; every claim above comes from the pack.
