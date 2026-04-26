# gpu-recover Agent

Free GPU memory by terminating the largest non-ollama VRAM consumer.

## Usage

```bash
fw gpu recover [--requester <name>] [--dry-run] [--threshold-mb N] [--json]
```

## Behavior

Reactive only. When invoked:

1. Read `nvidia-smi --query-compute-apps=pid,used_memory`
2. Exclude PIDs matching `pgrep -f ollama`
3. Find heaviest remaining process above `--threshold-mb` (default 2048)
4. SIGTERM, wait 3s, escalate to SIGKILL if still alive
5. Emit one-line result (or JSON with `--json`); log to `/var/log/fw-gpu-recover.log`

## Exit Codes

| Code | Meaning |
|------|---------|
| 0    | Action taken OR no eligible target (no-action) |
| 1    | Environment error (nvidia-smi unavailable) |
| 2    | Eligible target found but kill failed |

## When to use

- Cooperative GPU host where ollama-using projects coexist with non-ollama GPU consumers (FLUX, Whisper, etc.)
- Called from an ollama-failure path (e.g., warm-pool probe failure) before retry
- Manually as a one-shot when GPU contention is suspected

## Origin

Promoted from `email-archive/scripts/gpu-recover.sh` per T-1180 GO decision (two-layer GPU coordination design). Layer 2 = cross-process kick on ollama failure. Layer 1 = ollama keep_alive discipline lives in each consumer.

See: T-1180 inception report, T-1181 build, T-1182 promotion (this).
