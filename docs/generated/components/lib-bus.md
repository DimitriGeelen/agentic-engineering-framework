# bus

> fw bus - Task-scoped result ledger for sub-agent communication

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/bus.sh`

## What It Does

fw bus - Task-scoped result ledger for sub-agent communication
Provides structured, size-gated result storage for sub-agent dispatch.
Results are written as typed YAML envelopes in .context/bus/results/T-XXX/.
Payloads >2KB are auto-moved to .context/bus/blobs/T-XXX/.
This prevents T-073-class context explosions by formalizing the
"write to disk, return path + summary" convention into a protocol.
Commands:
fw bus post --task T-XXX --agent TYPE --summary "text" [--result "text" | --blob PATH]
fw bus read T-XXX [R-NNN]
fw bus manifest T-XXX

### Framework Reference

The result ledger formalizes the "write to disk, return path + summary" convention into a protocol with typed YAML envelopes and automatic size gating. Use it for sub-agent dispatch:

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |

---
*Auto-generated from Component Fabric. Card: `lib-bus.yaml`*
*Last verified: 2026-02-20*
