# T-2608 — Single stored representation for corpus maps (inception)

**Question:** Should the corpus keep ONE stored representation per map (the canvas
BPMN XML, git-versioned in the designer store) with the YAML spec derived on demand
— retiring the two tracked spec files T-2603 shipped a day earlier?

**Status:** inception, GO recommended. Decision at `/inception/T-2608`.

## Origin (operator dialogue, 2026-07-22)

The thread that led here, in order:

1. Operator (verbatim): *"what i care most about is a repeatable relaible
   transferable process, not this particular workflow, also fine with deleting it
   and then recreating"* → T-2602 GO → T-2603 shipped `fw corpus
   derive/generate/canon/diff` + two tracked specs; T-2604 shipped lint.
2. Agent posed IW-1: spec-authoritative vs canvas-authoritative. Operator:
   *"i do not understand teh chooic and distinction. git holds versions, the canvas
   load from git or a version comparable with git? editor makes chnages (operater
   or agent induced) and chnages are saved (expolicit) which cretae a new version"*
   — i.e. the operator's mental model is: one artifact, versioned, canvas edits it,
   explicit save = new version.
3. Agent recommended canvas-authoritative with spec auto-derived on save. Operator:
   *"why are these two not combined in one file ?"*
4. Agent reflection: the spec is a **lossless derived view** (T-2603's own
   round-trip proof), so persisting it stores zero new information and creates a
   drift class. Operator: *"incept this"* → this task.

The operator's question dissolved the IW-1 authority debate: with one stored
representation there is no "who wins."

## Evidence

- **Losslessness (T-2603, proven live):** derive→generate→canonical-diff =
  IDENTICAL on both served source maps, including a save→re-fetch cycle through
  `/api/save`; mutation negative-test exits 1. The YAML is a pure view.
- **No consumer at rest (verified this session):** `grep -rn "designer/specs"
  bin/ lib/ tools/ web/ agents/ tests/` → **zero matches**. Only T-2603's task
  Verification lines and its report reference the path. `fw corpus lint` reads
  XML directly.
- **The drift-class prior:** every persisted derived artifact in this framework
  has eventually needed its own staleness gate, and each gap was found only after
  silent drift: registry→generated cron (T-1935: 3+ days), tool-set→manifest
  (T-2290), source→vendored (T-2244 chain; OBS-098/T-2607 found a NEW leg of it
  the same day this inception was filed). Keeping the spec files would obligate a
  fourth gate ("spec stale vs XML") for a file nothing reads.
- **Operator's model matches:** one artifact, git-versioned, canvas edits,
  explicit save = new version. The single-file model is their stated intuition.

## The model (what GO means)

- **Stored truth:** `.context/designer/projects/<id>/vN.bpmn` + `meta.json`
  (uuid) — exactly what exists today, nothing new.
- **Spec = lens:** `fw corpus derive <id>` prints the YAML view on demand for
  reading/reviewing. Never stored, never stale.
- **Spec = transient authoring input:** an agent drafting a NEW map (or the
  T-2605 recreate) writes a spec anywhere (scratch), runs `fw corpus generate
  --save`, and the saved XML is the truth from that moment. The input file has no
  post-save status.
- **Lint** (T-2604): unchanged — already XML-native.
- **Recreate proof** (T-2605, IW-3): default leg = derive-in-memory from current
  served XML → generate → canonical-identical (pure repeatability); optional
  `--from <git-ref>` leg = regenerate from history (survivability). Both are
  proofs about the ONE stored artifact.

## Retrofit (IW-2 — the GO's mechanical tail)

1. `git rm .context/designer/specs/{aef-task-lifecycle,aef-dispatch-loop}.yaml`
   (directory disappears; nothing reads it — A2).
2. T-2603 AC1/AC2 rewording: "specs tracked at …" → "spec format defined; derive
   emits it on demand"; Verification commands re-pointed to derive-on-the-fly
   (`fw corpus derive aef-task-lifecycle --v 2 | fw corpus generate /dev/stdin …`
   or a temp-file equivalent).
3. T-2605 Context/AC wording: "regenerate from spec" → "regenerate from derived
   spec (in-memory)"; add the `--from <ref>` leg per IW-3 recommendation.
4. T-2603 report gains a superseded-note pointing here (history preserved, not
   rewritten).

## Considered and rejected

- **Keep both files + auto-derive on every save** (agent's own earlier proposal):
  readable diffs at rest, but buys a drift class + a gate for a file with no
  reader. Rejected by the operator's question and the framework's drift history.
- **Embed the YAML inside the XML** (comment/extension block): one file, but the
  same information twice *within* it — internal drift, and 832's editor would
  re-emit or strip foreign blocks unpredictably. Worst of both.
- **Spec-authoritative (original IW-1 option 1):** canvas corrections become
  provisional until folded back — fights the established pair-draft loop (agent
  drafts, operator corrects in UI). Rejected in dialogue before this inception.

## Go/No-Go

**GO if** no consumer needs the spec at rest (verified), derive-on-demand covers
all uses (T-2603 proof + A1), retrofit bounded (4 mechanical edits above).
**NO-GO if** some workflow needs the file without invoking fw, or the recreate
proof requires a persisted non-XML source (no evidence of either).

## Dialogue Log

- **Op:** "why are these two not combined in one file?" → direct hit on the
  derived-artifact smell; agent had shipped the two-file shape reflexively
  ("readable diffs") without weighing the drift cost against the framework's own
  gate archaeology.
- **Agent course-correction:** from "canvas-authoritative + auto-synced second
  file" to "single stored file, spec as lens" — the auto-sync variant was the
  drift class with extra steps.
- **Op:** "incept this" → governed decision rather than silent flip of a
  day-old shipped design. Correct call: T-2603's ACs and T-2605's proof wording
  both change under GO; that deserves a recorded decision, not a drive-by edit.

## Recommendation

**GO** — evidence is complete (losslessness proven, zero consumers, bounded
retrofit); the change *removes* a moving part rather than adding one. Decision
belongs to the operator at `/inception/T-2608`.
