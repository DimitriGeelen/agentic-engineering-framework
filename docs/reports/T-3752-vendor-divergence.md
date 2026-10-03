# T-3752: vendor-divergence register — fw upgrade never silently erases a consumer's local fixes

Inception research artifact. Proposals: 010-termlink (framework:pickup @304 code +
guide, @305 live register; sidecar @130), 832-Workflow-designer (originated the
convention, framework:pickup @19; protocol run on 1.7.740).

## Evidence

- 832, first protocol run on 1.7.740 (their T-988/T-1005): 1599 unrecorded + 11 stale
  divergences → 0 unrecorded + 51 stale after the baseline advance; 13 of 27 stale local
  fixes already superseded by AEF, 9 re-applied, 8 moved out of vendored files.
- Losses: an undeclared fix (T-943 on lib/verification-port.sh) erased with nothing
  listing it; 5 consumer-added files deleted by the vendor copy, 4 undeclared; two
  audit.sh fixes (T-382, T-660) erased by an earlier upgrade while the file still
  diverged in other ways — a per-path register saw nothing for 8 days.

## 832's answers (sidecar 02c52e69, 2026-10-03), recorded verbatim in substance

- **IW-1 schema.** Top-level `baseline_commit`; per entry: path, kind
  (content|added|mode), task, upstream (fix|superseded|vendoring-repair|local-config|
  unknown), reason, superseded_changes. Keep from 010: owning task, upstream status,
  content hash at patch time. Add: (a) PER-CHANGE identity, not per-path; (b) a PROBE
  per change — a command proving the behaviour is present. "Probes, not hashes, found
  every loss and every supersession."
- **IW-2 on upgrade.** Overwrite and NAME EACH; never refuse, never silently keep.
  Protocol: pristine commit of AEF's bytes (vendored paths only) → baseline advance →
  worklist of each lost change's patch + probe, re-applied one commit each (3-way merge
  applied cleanly for 6 of 10 audit.sh fixes). Refusing would have kept 13 already
  superseded fixes; keeping theirs would hide AEF's better versions.
- **IW-3 undeclared changes.** BOTH upgrade-time hashing (catches the erase as it
  happens) and their G4 commit gate (stops undeclared edits between upgrades). Neither
  sees a partial loss inside a still-divergent file; only per-change probes do.
- **IW-4 upstream intake.** filed-upstream = a pickup keyed by the entry (patch series
  verified on a clean tree + its probe; their T-1009 is the first). Supersession: at
  upgrade, run each entry's probe against AEF's new bytes with the local change absent;
  if it passes, mark superseded automatically and name the AEF task that did it.

## Dialogue Log

### 2026-10-03
- Inception filed; 832 consulted (sidecar vendor-divergence-proposal e24a7384).
- 832 answered all four IWs (above). 010's view on reconciling the two schemas pending.
