# T-1501: Toolchain build commands at the verification gate

**Inception scope:** Should `verification-gate.sh` infer toolchain build commands (e.g. `dotnet build` when `*.vbproj` was edited) from file-type triggers, or stay toolchain-agnostic and rely on per-task `## Verification` discipline?

**Origin:** 003-NTB-ATC-Plugin / T-077 — broken WPF DLL committed to master, undetected for 5 days. Agent ACs included no `dotnet build` step; only a deferred Human AC mentioned it. P-011 ran whatever commands the agent wrote, found nothing wrong, passed the gate.

**Decision:** DEFER (recorded 2026-04-26T13:57:39Z, re-recorded 14:47:09Z).

## Findings

### A1 — Glob-as-trigger reliability
A glob like `*.vbproj | *.csproj | *.xaml` is a sound *trigger* signal. Edge case: docs-only edits inside a `.NET` directory don't actually compile, so the gate must be diff-based (`git diff --name-only HEAD~..HEAD | grep -E '\.(vbproj|csproj|xaml)$'`), not "directory contains a `.vbproj`". Trigger is reliable when scoped to the actual diff.

### A2 — Cost
Diff + grep at gate time is sub-millisecond. Not a concern.

### A3 — Consumer-config schema
Sketched as `.framework.yaml`:

```yaml
verification_triggers:
  - match: "*.vbproj"
    require: "command -v dotnet >/dev/null && dotnet build"
  - match: "*.go"
    require: "command -v go >/dev/null && go build ./..."
```

Schema works for .NET, Go, Rust (`Cargo.toml` → `cargo check`), TypeScript (`tsconfig.json` → `tsc --noEmit`), Java (`pom.xml` → `mvn -q compile`). No special-casing per language — the same `match` / `require` shape covers all five. Host-availability is the consumer's responsibility (`command -v` guard).

### A4 — Toolchain-agnostic
Holds **iff** the toolchain map lives in the consumer's `.framework.yaml`, not in framework source. Hardcoding `*.vbproj → dotnet build` in `verification-gate.sh` would put .NET knowledge into the framework — directly violates Portability (directive #4), opens the long tail (Maven? Gradle? Bazel? CMake? `pyproject.toml`?), and the framework has no test fixtures to validate any of them.

### A5 — Recurrence evidence
Single instance (T-077). Grep across `.context/project/learnings.yaml` and `concerns.yaml` returned zero prior "agent forgot toolchain build" entries. The systemic-prevention case requires ≥2 instances; we are at 1.

## Why DEFER and not GO

Two load-bearing reasons:

1. **Toolchain-agnostic principle.** Even with the consumer-config escape hatch (A3+A4), shipping the schema before recurrence means the framework owns a config surface area for a problem that may not repeat. Maintenance cost is non-zero — schema docs, validation, edge-case bug reports.
2. **Single-instance evidence.** One incident is the threshold for *learning + per-task discipline*. Two incidents is the threshold for *structural prevention*. Promoting prematurely violates the framework's own evidence-driven escalation pattern (CLAUDE.md §Error Escalation Ladder).

## Why DEFER and not NO-GO

The bug is real and the structural-prevention case is honest. NO-GO would close the door; DEFER keeps the option open. If a second consumer hits the same class of bug within 30 days, promote to GO with the A3 schema as the implementation path.

## Mitigations landed under DEFER

Three things shipped immediately so the next agent on the next .NET-flavoured project has a fighting chance:

1. **Learning entry L-291** — captured in `.context/project/learnings.yaml`, indexes the file-type → build-command mapping.
2. **Template hint** — both `.tasks/templates/default.md` and `.tasks/templates/inception.md` carry a comment in `## Verification` pointing at L-291 with the mapping.
3. **CLAUDE.md §Verification Gate** — gained a "Toolchain build commands" subsection with the mapping table and host-scoping guidance (`command -v dotnet >/dev/null && dotnet build`).

## Promotion criteria (DEFER → GO)

GO if any of:

- A second consumer project hits the same class of bug within 30 days (i.e. by 2026-05-26).
- The pattern shows up across two different toolchains in the same window (e.g. one Go consumer + one .NET consumer both forget the build step).
- A consumer asks for the consumer-config schema explicitly (revealed need, not anticipated need).

NO-GO conversion if recurrence stays at 1 instance for 90 days (by 2026-07-25) — at that point the learning + template hint + CLAUDE.md update is the proven mitigation, no framework code needed.

## Rejected alternatives

- **Hardcode `*.vbproj → dotnet build` in `verification-gate.sh`.** Violates Portability. Single-toolchain solution to a multi-toolchain class of problem.
- **`.framework.yaml` consumer-config schema now (A3 implementation).** Sound design but premature without ≥2 instances. Adopting prematurely commits the framework to maintaining a config schema before we know what it should cover.
- **`fw doctor` toolchain probe.** Out of scope — different concern (does the consumer's declared toolchain build *at all*, not just at gate time).
