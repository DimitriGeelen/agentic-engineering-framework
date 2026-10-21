# Shared worker-contract conformance vectors

`vectors.yaml` is the **single** conformance vector file for the shared dispatched-worker
contract (spec v0.3.3, `contract_version: wc/0.3`, §9 cases CC-01..CC-25). AEF owns it, as
agreed with TermLink and ring20. Every backend that claims conformance (TermLink's `hub`, AEF's
`local`, any external backend such as `ring20`) runs these same vectors through its own adapter.
The file is data only and names no backend's paths.

## Contributing

**TermLink contributes the hub-side cases as a patch to `vectors.yaml`**, as other backends do
for theirs. Do not fork the file and do not keep a second vector file. A patch:

- keeps one entry per case id; new steps or variants go into the existing case;
- uses only the ops, writers, capabilities and refusals declared under `vocabulary:` (a new
  term goes into the vocabulary in the same patch, with a one-line meaning);
- passes `python3 check_vectors.py vectors.yaml` (stdlib + PyYAML).

The check enforces the contract's fixed sets: all 25 case ids, the seven `fence_reject`
reasons of §3.3, and the N2 rule of §6.6. A case whose subject is a §3 transition row has
`n_a_allowed: false`. Only cases about the answer channel, `registry_epoch` or caller-chosen
ids may be n/a.

## Files

| File | What it is |
|---|---|
| `vectors.yaml` | the vectors; its header explains `given` / `steps` / `then` / `variants` |
| `check_vectors.py` | schema check; exit 0 valid, 1 invalid, 2 unreadable |
| `run_local.py` | runs the vectors against AEF's local backend. While that backend does not exist, each vector is reported `not-implemented` with what is missing, never `pass` |

Other backends write their own runner against the adapter shape described in `run_local.py`
(reset from `given`, apply one step, snapshot the record).
