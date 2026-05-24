# T-2030 — Review hand-offs must always emit concrete, verified, clickable links

**Type:** Inception (one question, go/no-go)
**Question:** How do we make the framework *structurally* guarantee that every human-review
hand-off carries concrete, resolved, clickable links (pages **and** captured screenshots),
instead of relying on the agent to author good links by hand?

**Status:** exploration — research artifact (C-001). No build artifacts until GO.

---

## 1. Symptom (what the human hit)

On `fw task review T-2027` / `T-2028` the Human AC rendered as:

> **[REVIEW]** Arc badges … stay legible across all five palettes
> **Steps:** 1. Open the Watchtower `/arcs` page (base from `bin/fw watchtower url`)
> 2. Cycle each palette at `/settings/appearance` …
> 3. … open an arc with a NO-GO anchor recommendation and check the red NO-GO verdict

Human verdict: *"is useless for me i need concrete links."*

Failures in that one AC (all curl-verified, not asserted):

| # | Failure | Why it's useless |
|---|---------|------------------|
| F1 | `base from \`bin/fw watchtower url\`` | A **command to run**, not a link to click. The human has to open a terminal, run it, copy the base, then hand-build the URL. |
| F3 | "open an arc with a NO-GO anchor recommendation" | **A state that does not exist.** Curl-verified: all six arc anchors are GO / GO-with-adjustments, so the `verdict-NO-GO` pill renders nowhere. The step is unverifiable by construction. |
| F4 | screenshots never linked | The slice captured `web/static/ux-review/T-2027-arcs-pages-tokens.png` (served HTTP 200) — the single most concrete "here is the rendered result" artefact — and the hand-off never referenced it. |

### F2 — the route failure that proves the thesis (self-demonstrated)

This one is worth its own section because the *agent caused it twice, in opposite
directions, while trying to fix the problem*:

1. The original AC said cycle palettes at **`/settings/appearance`**. In a follow-up I
   asserted that was a 404 and "corrected" it to **`/appearance`**. **Both claims were made
   without checking.**
2. Curl ground truth: `/settings/appearance` → **200** (the original AC was *correct*);
   `/appearance` → **404** (my "fix" was the broken one). The human hit the 404 *I*
   introduced.

So F2 is not "the agent wrote a wrong path once" — it's "the agent cannot reliably author
or verify routes from memory, and is confidently wrong in both directions." That is the
single strongest argument in this document for **candidate C (validate every referenced
path against `app.url_map`)**: an agent explicitly trying to produce a correct link still
shipped a 404, because nothing mechanically checks the route. Discipline demonstrably
cannot fix this; only tooling can.

## 2. Root cause (why the framework allowed it)

The link content of a review hand-off is **100% agent-authored free prose** in the AC
`Steps:` block. Nothing in the pipeline:

- resolves `bin/fw watchtower url` to a real base and substitutes it;
- validates that a referenced path is a real route;
- checks that a referenced UI *state* exists before asking the human to inspect it;
- discovers the task's own captured screenshots and links them.

`fw task review` (the designated hand-off verb) emits the `/review/T-XXX` URL + QR — good —
but it treats the AC `Steps:` as an opaque blob. So the quality of every other link rides
entirely on agent discipline, which is the exact thing the framework's gates exist to stop
relying on. CLAUDE.md already mandates "copy-pasteable full-path commands" and "clickable
Watchtower URLs", but those are **advisory text**, and advisory text degrades (this is the
same class as T-1878 `[REVIEW]:[REVIEWER]` adoption gap and T-1550 RCA-was-advisory: the
rule existed, the structure didn't).

**The framework was blind:** an AC can ship with an unresolved command, a 404 path, an
impossible state, and zero screenshot links, and every gate passes. That's a detectable
class — so it's a structural omission, not a one-off.

## 3. Candidate directions

Two complementary axes: **(I) generate** the links from tooling, and **(II) detect** bad
links so they can't ship. Best fix likely does both (generate to make the right thing easy;
detect to make the wrong thing fail).

### A — `fw task review` enriches with resolved links + screenshots  *(generate)*
On `fw task review T-XXX`, in addition to the `/review` URL, auto-emit:
- the resolved base (`http://192.168.10.107:3000`) prepended to every relative path found in the AC Steps;
- a **Screenshots** block listing `/static/ux-review/T-XXX-*.png` it finds on disk (the capture convention already exists);
- (optional) deep links the task declares (see E).
Moves link-building from prose to tooling. Low risk, immediately useful.

### B — Reviewer static-scan rule: "vague review link"  *(detect)*
Add a detector to the reviewer agent (T-1443) that, on `[REVIEW]` ACs touching a render
surface, flags Steps that: contain the literal string `bin/fw watchtower url` /
`fw watchtower` (unresolved command), or contain a relative `/path` with no `http`
(unresolved), or reference no screenshot when one exists for the task. Emits CONCERN at
task close — same surface as the prose-mismatch detector (T-1947).

### C — Route validation  *(detect)*
A check that every `/path` referenced in a review AC resolves to a registered Flask route
(introspect `app.url_map`). Catches F2 (`/settings/appearance` → 404). Cheap, deterministic.

### D — `fw review-link T-XXX [/path]` helper  *(generate)*
A tiny verb that prints a concrete clickable URL (resolved base + path), so any AC/chat
references the helper's output rather than raw `bin/fw watchtower url`. Composes with A.

### E — `?wt-palette=` query override + per-palette review links  *(generate, palette-specific)*
Today the palette is a global server-persisted setting → "cycle 5 palettes" is a manual
toggle at `/appearance`. A `?wt-palette=bone` query override (read once on load, no persist)
would let a review hand-off emit **five one-click links**, one per palette — directly
serving the "legible across all five palettes" class of AC. Slightly larger (touches the
appearance JS) but kills the most painful manual loop.

### F — "verify-the-state-exists" discipline  *(detect, harder)*
The deepest failure (F3) is asking the human to inspect a state that doesn't render. Fully
general detection is hard, but a partial: if an AC says "check the X pill/badge/verdict",
the author must link a concrete instance URL where X renders; the reviewer flags
"check the …" phrasing with no accompanying concrete instance link.

## 4. Recommendation (advisory — human decides at go/no-go)

**GO**, scoped as **A + B + C** for v1 (generate the good links + detect the three
mechanical failure modes F1/F2/F4), with **E** as a fast-follow (the palette deep-links,
highest UX payoff) and **D/F** optional.

Rationale: A makes the correct hand-off the default with near-zero agent effort; B+C make
the three deterministic failures (unresolved command, 404 path, missing screenshot link)
impossible to ship silently — converting advisory text into a gate, consistent with how the
framework closed T-1550 (RCA), T-1718 (Evolution), T-1947 (prose-mismatch). E is separable
and the biggest single UX win for multi-palette reviews.

Per "one inception = one question / one task = one deliverable", a GO spawns **separate
build tasks**: T-a (fw task review enrichment, A+D), T-b (reviewer detector + route check,
B+C), T-c (palette query override + per-palette links, E). Not built under this inception ID.

## 5. Open questions for the human

1. **Scope of v1:** A+B+C now, E fast-follow? Or include E in v1 (the palette deep-links are
   what hurt most here)?
2. **Detector severity:** should the "vague review link" detector be a CONCERN (visible,
   non-blocking) or a hard gate that **refuses** `--status work-completed` (like the
   render-review gate P-013)? Blocking is stronger but riskier on legacy ACs.
3. **Screenshot convention:** is `web/static/ux-review/T-XXX-*.png` the canonical, permanent
   home for review artefacts? (It's currently `.gitignore`d — fine for a live server, but
   review links die if the server is rebuilt from a clean checkout. Should review artefacts
   be committed, or is the live server always the source of truth?)

## 6. Dialogue Log

### 2026-05-24 — origin
- **Human:** the `fw task review` Human-AC format is "useless for me i need concrete links."
- **Agent:** resolved the real URL, confirmed the captured screenshots are web-served
  (HTTP 200), and found that no arc has a NO-GO verdict (the AC step was impossible).
- **Human:** "please fix it structurally — incept what goes wrong here and how we can
  improve this in the framework so the correct links always get generated and incorporated."
- **Outcome:** this inception. Direction: tooling **generates** resolved page+screenshot
  links (A/D/E) and the reviewer **detects** unresolved/404/missing-screenshot links (B/C).

### 2026-05-24 — F2 correction (the inception caught itself)
- **Human:** "http://192.168.10.107:3000/appearance gives 404".
- **Agent:** investigated `app.url_map` + curl. Ground truth: `/settings/appearance` → 200,
  `/appearance` → 404. The *original* AC route was correct; my follow-up "correction" to
  `/appearance` was the actual 404, asserted without checking. Retracted the false F2 claim
  and rewrote §1 to mark this as the self-demonstration of candidate C (route validation):
  an agent fixing the link problem still shipped a 404. Strengthens GO.
