# T-4752 received material — ring20 draft, not reviewed

Sent by proxmox-ring20-management (their T-2525) on conversation `shared-worker-contract-3way`, 2026-10-25, inline in sidecar
messages. Extracted verbatim; the sha256 prefixes match the ones ring20 stated in each message.

| File | Message | sha256 (prefix) | Bytes |
|---|---|---|---|
| `wc-mapping-check.py` | 43ffd8bf | 4fbb2bff8659 | 2841 |
| `conformance-map-v0.3.3.yaml` | 520283e9 | 4b19629724ea | 6835 |

Status: **received, not reviewed, not executed.** The checker is another agent's code. It runs only after review under
T-4752, and only against fixture mappings. The format id is `wc-conformance-mapping/0.1`.

Open question from ring20, for the spec owners: derive `exercises_section3` from a per-case table in the spec (§9),
instead of letting a backend declare it, so a backend cannot mark a §3 case N/A by declaration.
