```text
D1: Hybrid: payload proxy + OS cage + capability broker; hooks as adapters | survives-pilot confidence: medium because T-2429 proved mediation, but containment remains undeployed (§13.1)
D2: other:TypeScript
D3: Tier 0/pre-push policy; task/focus; budget/checkpoint policy; verdict ledger; task-close gates; minimal dispatch; proxy, holder and broker
D4: Version-pinned signed bundles through fw upgrade; protected installation; deny execution when unavailable
D5: Capability broker with externally signed approvals | prompt-free categories: policy-approved reads, isolated builds, fixed low-risk maintenance | one-tap categories: destructive actions, package installation, protected configuration, consequential restarts
PILOT: Tier 0 approval holder/broker | STOP IF: any unapproved effect, replay, self-approval or fail-open executes
WOULD CHANGE MY MIND: A cross-platform adversarial pilot showing the proposed effects boundary cannot prevent unauthorized mutations without unacceptable workflow restrictions
```

### 1. Diagnosis

The framing needs one correction: **non-root execution does not prevent destruction of agent-writable files**. Strong governance requires restricting effects, including workspace mutations—not merely protecting hooks and approval keys. Force-push authorization also concerns remote authority, not necessarily local root privilege (§§3, 11–12).

For §6, assigning each row one primary cause gives approximately **59% language, 10% parsing, 31% specification/design**: 23 language rows, four parsing rows (D-27, D-31, D-33, D-37), and twelve design rows, including D-32. These are catalogue shares, not incident frequencies; several causes overlap.

In §5, parsing appears the largest family: wrappers, quoting, expansion and continuation recur (T0-021–027, T0-048, T0-055–070). Approval identity, replay and isolation form another substantial family (T0-002, T0-029, T0-045–054, T0-059–060, T0-071–073). Language alone explains little of the required security contract. Counting every spelling independently would exaggerate parsing’s causal share.

A rewrite can remove shell-as-data hazards (D-03–09); it cannot repair authority or failure semantics automatically (D-34–39).

### 2. Security contract per layer

**Guardrails:** Trust the policy implementation and, for hooks, the harness’s invocation and decision handling. Use strict schemas and recognized command shapes; unsupported syntax denies or routes to a structured operation. This catches cooperative mistakes, including known §5 cases. Neither an AST nor proxy inspection proves arbitrary program effects (§§3, 9, 13.1). Hooks provide feedback, not adversarial containment.

**Isolation:** Trust the host kernel/hypervisor, protected supervisor, broker, operator identity and release chain. Cage the entire harness and descendants, not only Bash. Keep policy, credentials, approvals and authoritative state outside it. Deny unrestricted host IPC, alternate model routes, privileged sockets and remote mutation credentials.

Give arbitrary programs disposable workspace overlays; mediate durable changes through narrowly scoped operations. Protect approved targets against replacement between authorization and execution. Against (b), this makes shell spelling, scripts and direct store edits irrelevant to protected effects. Unknown effects deny. Agent-controlled disposable data remains destructible; kernel compromise and a compromised operator are excluded.

The proxy governs model choices; the cage/broker governs effects. A dishonest harness can still misreport semantics (§13.1).

**Gaps only the harness vendor can close:**

- Make its own missing, crashed or timed-out hook mandatory-deny (§2.1; D-35).
- Supply trustworthy internal sub-agent identities and complete internal-action attribution (§13.1).
- Guarantee correspondence between mediated intent, actual internal execution and reported results (§13.1).

External containment can limit consequences without fixing those internal contracts.

### 3. Options table

Scores are architectural judgments, not measurements. Weights appear in headings. Language rows cannot independently pass the isolation gate; **UNKNOWN** means conditional on the proposed boundary and validation. Latency lacks comparable implementation measurements (§§4, 9, 13).

| Gate | Option | §6 defects ×2 | Distribution ×2 | Migration ×2 | Maintainability ×2 | Latency ×1 |
|---|---|---|---|---|---|---|
| FAIL | Hardened hooks only | 2: Leaves authority and failure semantics | 3: Existing delivery | 5: Smallest change | 2: Repeated classifier repairs | 1: Current budget missed |
| UNKNOWN | Payload proxy + OS cage, T-2428 | 4: Separates authority and effects | 2: Linux design; other hosts unresolved | 3: Existing spike and components | 3: Unified policy; substantial substrate | ?: No complete-path measurement |
| FAIL | Harness-native permissions/sandbox alone | 2: Leaves AEF state protocols unspecified | 2: Harness-dependent capabilities | 4: Available configuration mechanisms | 3: Less custom containment | ?: Not measured |
| UNKNOWN | Hybrid: proxy, cage, broker, adapters | 4: Addresses parsing, authority, failure paths | 3: Requires platform qualification | 2: Several interacting boundaries | 3: One policy; multiple adapters | ?: Pilot required |
| UNKNOWN | Own option: disposable worker, broker-only publication | 4: Removes direct durable authority | 3: Requires portable isolation substrate | 1: Largest workflow change | 3: Simple boundary; constrained workflows | ?: Publication overhead unknown |
| FAIL alone | Bash plus parser | 2: Keeps shell failure hazards | 3: Existing runtime, new parser | 4: Incremental replacement | 2: Mixed semantics remain | ?: Parser startup unknown |
| UNKNOWN | Strict Python plus bashlex | 4: Removes shell-as-data defects | 2: Runtime and licence questions | 4: Existing Python core | 4: Familiar structured implementation | ?: Service differs from measured startup |
| UNKNOWN | TypeScript, T-586 | 4: Structured data; explicit error handling | 3: Must provision protected Node runtime | 4: Existing strategy and utilities | 4: Existing JS/TS foothold | ?: Prototype isn't security-path evidence |
| UNKNOWN | Go plus mvdan.cc/sh | 4: Structured core and AST | 4: Compiled platform artifacts | 2: New repository language | 3: Parser fit; unfamiliar stack | ?: Unmeasured |
| UNKNOWN | Rust plus tree-sitter-bash | 4: Structured core; reject recovery nodes | 4: Compiled platform artifacts | 2: Rewrite and parser integration | 3: Sibling-project experience | ?: Unmeasured |
| UNKNOWN | Polyglot per component, including TypeScript | 4: Match components to requirements | 2: Multiple release/runtime surfaces | 3: Incremental reuse | 2: More interfaces for small team | ?: Component-dependent |

Basis: §§4, 6–10, 13. Do not aggregate unknowns into a misleading total or let scores override FAIL.

### 4. D1–D4 reasoning

**D1.** Endorse T-2428’s co-essential proxy/effects architecture. Its deployed implementation is not yet a boundary: substring policy, absent installation and unrun acceptance demo remain (§13.1). Retain hooks as adapters across harnesses; P-063 proves they cannot define governance coverage (§13.3). “Closed” means no protected effect without broker authority, regardless of spelling, script, tool or API route. Approval reuse, self-signing and target substitution must also fail. Arbitrary writable workspaces without effect mediation remain an explicit failure to meet that claim.

**D2.** Follow T-586: TypeScript for new policy, proxy and broker logic, with runtime validation and structured subprocess arguments. Do not rewrite the existing Python ledger immediately. Remove inline interpreter source generation. Reject two T-586 assumptions: Node availability is not established across all harnesses, and fallback to vulnerable Python is unacceptable (§§7, 13.2). Provision the runtime. TypeScript does not provide shell-expansion immunity when code still invokes a shell.

**D3.** Replace “runs every call” with “can authorize, execute, authenticate or persist a governed transition.” Include the verdict ledger and task-close gates despite their lower frequency (§1.4). Include authoritative focus/budget state, approval issuance/consumption, protected policy installation and minimal routing. Extract only security-relevant dispatcher functions; exclude most CLI commands, presentation and telemetry. Test quantity and stable specification are migration-readiness criteria, not security-boundary membership.

**D4.** Extend version-pinned vendoring with signed, platform-specific runtime bundles and protected installation (§7). Agent-editable vendored files must not become executable authority. Atomically activate compatible policy/runtime versions after startup checks. Missing runtime, unsupported protocol, unavailable state or cage failure prevents governed execution. Recovery uses a separate operator-authenticated maintenance path. Qualify Linux and WSL2 first; a Linux VM on macOS preserves T-2428’s Linux substrate direction, subject to an explicit portability pilot (§13.1).

### 5. D5: Elevation

Use a broker API for **operations**, never generic root shells. Separate the unprivileged policy/state service from minimal privileged executors. Bind approvals to principal, task, operation, immutable target, arguments, expiry and nonce; durably audit before execution and reconcile interrupted attempts without replay.

| Mechanism | Recommended role |
|---|---|
| Scoped sudoers | Fixed, protected helper only; no arbitrary arguments or agent-writable executables |
| Privileged broker | Primary authority, validation, execution and audit boundary |
| polkit/equivalent | Platform authentication adapter; never the portable policy specification |
| Time-boxed leases | Narrow capability, resource and use-count limits; never blanket root |
| Harness prompts | Optional presentation adapter; insufficient independent authority |

Tier 3 and pre-approved Tier 1 operations run without prompts within the authority envelope. Tier 0 requires one externally authenticated operator signature; Tier 2 signs one explicit exception. Package installation is not presumed low-risk. Restart only fixed, protected services without prompts when explicitly pre-approved.

Watchtower/ntfy presents the broker’s exact request; operator credentials remain outside the agent’s reach. CSRF alone is insufficient (T0-071; §12). One approval drives execution directly, avoiding layered approval consumption (T0-074). Platform-specific helpers or VM services implement the same protocol; remote pushes use scoped remote credentials, not root.

### 6. Migration and validation

First specify protected resources and authority envelopes. Deploy separate agent/service identities, protected state and authenticated approval issuance. Pilot the Tier 0 holder/broker before broader rewrites; then connect proxy, cage and adapters. Migrate remaining modules individually (§§7, 13).

Run old/new classifiers side by side **without duplicate execution or approval consumption**. Classify differences as regressions or intentional stricter policy. Preserve valid behavioral tests; explicitly supersede insecure expectations.

Replay §5 and mutation-test §6 failures. Add script, interpreter, MCP, in-process write, symlink/race, endpoint substitution, concurrent replay and credential-access attacks. Kill components and corrupt state. Existing 11,400 tests include inert tests and cannot establish containment (§1.3).

Measure complete calls, allowed/denied paths and contention across platforms; use provisional p95 <100 ms for automatic policy decisions, excluding human wait (§4).

Any false allow stops rollout. Missing telemetry, broken approval attribution or failed containment also blocks promotion. Roll back only to a previously validated protected release; otherwise halt and invoke operator recovery.

### 7. Strongest case against the verdict

This adds a distributed security system for one operator plus agents (§8). TypeScript familiarity does not prove broker correctness. The hardest problem—mediating legitimate workspace edits without permitting destructive equivalents—remains an unvalidated workflow design. T-2428’s deployment delay and missing effects-tier implementation reinforce that risk (§13.1). A narrower disposable-worker system with operator-controlled publication could be easier to establish securely, even at greater workflow cost.

### 8. Assumptions and missing facts

- **Highest:** acceptable workspace/publication restrictions; protected-effect semantics remain unspecified (§§3, 12).
- Cross-platform cage feasibility and all-harness proxy compatibility remain unproved (§13.1).
- Authentic one-tap identity and remote protection configuration remain unknown (§§11–12).
- Low-risk categories, latency budget and runtime provisioning acceptance need confirmation (§§4, 7–8, 12).