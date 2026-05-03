# Orchestration model pin: wrapper-only enforcement with launch-time warning on override

The Agent runs on a model configured per-project in `.framework.yaml` (default `opus`). The `claude-fw` wrapper reads the config and sets `--model` at launch. Bare `claude` bypasses the wrapper with no binary-level enforcement; `fw doctor` flags the drift on its next run. When the wrapper itself is invoked with an explicit `--model X` that contradicts `.framework.yaml`, it prints a one-line WARN at launch and proceeds; users can suppress with `--pin`.

This preserves the framework's existing user-sovereignty pattern (Tier 0, task gate, budget gate all default-friendly + structurally visible when bypassed) and gives drift immediate visibility in the user's terminal scrollback rather than waiting for a `doctor` cycle.

## Considered Options

- **Strict** — wrapper hard-fails on any model contradiction, including bare `claude`. Rejected: removes user sovereignty over their own session; breaks the override pattern the rest of the framework follows.
- **Trust-the-wrapper** — wrapper sets `--model`, no further checks. Rejected: bypass becomes invisible until much later, by which time wrong-model outcomes have already polluted `route_cache`.
- **Refuse without `--allow-override`** *(Q3.5 #3)* — wrapper exits 1 unless an override flag is passed. Rejected: re-introduces friction at exactly the moment Q3 said it shouldn't.
- **Silent accept on deliberate override** *(Q3.5 #1)* — wrapper passes through `--model haiku` without warning, relies on next `fw doctor` run. Rejected: defers visibility long enough for the wrong-model session to pollute the cache before the user notices.
