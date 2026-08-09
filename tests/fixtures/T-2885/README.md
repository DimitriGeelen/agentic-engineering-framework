# T-2885 fixture: foreign-model cache-priming poisoning

`poisoning-transcript.jsonl` reproduces the entry shape reported by 832 (DM
rail 488, their T-401) and confirmed live in this tree on 2026-08-09: four
real `claude-opus-5` usage entries growing toward the session's actual size
(final legitimate entry: 84629 tokens — the measured real size from the
task), followed by one foreign-model cache-priming entry
(`claude-opus-4-8`, `input_tokens=2`, `cache_creation_input_tokens=252176`,
total 252178) landing LAST by transcript position.

- The pre-fix algorithm (last raw usage entry wins, no model scoping)
  returns **252178** on this fixture — the poisoned reading.
- The fixed algorithm (`lib/context_tokens.py`, scoped to the model with the
  most entries since the last boundary) returns **84629** — the real size.

See `tests/unit/t2885_context_tokens_model_scope.bats`.
