# T-701: Context Budgeting Hints Research

## Recommendation: DEFER

Token estimates in fabric component cards would be metadata with zero consumers. Budget management (P-009) reads actual token usage from the JSONL transcript — it doesn't need estimates.

## Key Findings

1. **180 fabric cards** would need `token_estimate`, `load_strategy`, `priority` fields
2. **Budget gate** (`budget-gate.sh`) reads actual tokens from JSONL transcript, not fabric cards
3. **Checkpoint** (`checkpoint.sh`) reads actual tokens from JSONL transcript, not fabric cards
4. **Agent context loading** is driven by CLAUDE.md (auto-loaded), LATEST.md, focus.yaml — not by fabric cards
5. **No code path** exists that would consume token estimates from fabric cards
6. **Estimates go stale** — file sizes change, but the estimate stays fixed until manually updated

## When to Revisit

- Context-aware selective loader that reads fabric cards to decide what to load
- KCP integration (T-705) providing standard `hints.total_token_estimate` format
- Multi-agent scenarios where agents need to plan context usage before loading
