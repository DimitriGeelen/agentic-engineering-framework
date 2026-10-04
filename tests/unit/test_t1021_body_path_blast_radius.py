#!/usr/bin/env python3
"""T-542 teeth — the cost axis must measure surface, and must decline to guess.

`blast_radius` carries weight 0.6 in the F8 composite (0.6×br + 0.3×tier +
0.1×effort) — the dominant term. Before T-542 it was derived from the task's
`components:` frontmatter alone, and `components:` was EMPTY on 59 of 59
non-completed active tasks here. Every non-inception task therefore scored
br=0 via the `no-components` branch.

That 0 was not a measurement. It was a blind read wearing the cheapest value
on the scale, and the whole cost axis collapsed to `inception ? 3.6 : 1.4`
with 29 of 59 tasks tied at the modal value. An HV/LC filter run over it
promotes on fabric coverage, not on cost — and it does so silently, because a
number is present and looks like every other number.

T-2189 had already recognised the identical shape one population earlier: its
docstring says the count "always returns 0, making inceptions look artificially
cheap", and it repaired inceptions only. The same sentence was true of every
task with an empty `components:`.

This probe defends the four properties that make the repaired axis worth
having, none of which a green `fw bvp estimate-cost all` would reveal:

  1. GRADED     — blast_radius reaches >= 3 distinct non-absent values on the
                  real corpus. Guards the exact binary collapse T-542 fixed;
                  a dominant term with two values is a flag worth 0.6.
  2. HONEST ABSENCE — when nothing is knowable the key is OMITTED, not set to
                  0 and not set to null. `compute_cost` keys off
                  `br is not None`, so an omitted key lands on the existing
                  `source: 'absent'` branch and the task drops OUT of the
                  ranking rather than entering it at the cheapest value.
  3. MEASURED, NOT MENTIONED — a body naming a path that does not exist in the
                  tree must not raise the blast radius. The existence check is
                  the whole difference between a measurement and a word count,
                  and it is what makes a rename stop counting.
  4. DECLARATION WINS — an explicit `components:` list still beats the body
                  scan. The fallback is a fallback; it must not overrule the
                  author.

Exit codes:  0 = green   1 = a leg is red   2 = REFUSE (stimulus not established)
"""

import glob
import hashlib
import importlib.util
import os
import sys
from pathlib import Path

ROOT = Path(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
# the framework repo itself (FRAMEWORK.md at root), else a vendored consumer
FW = ROOT if (ROOT / "FRAMEWORK.md").is_file() else ROOT / ".agentic-framework"
EST = FW / "agents" / "termlink" / "bvp-estimator" / "estimator.py"

# Below this the distribution legs would be asserting over noise.
MIN_TASKS = 20

# Real repo paths, each with a directory segment and a known extension. If any
# of these is renamed the probe REFUSES rather than silently weakening — the
# fixture's whole point is that these resolve on disk.
REAL_PATHS = [
    "lib/arc.sh",
    "lib/inception.sh",
    "agents/audit/audit.sh",
    "agents/context/check-active-task.sh",
    "agents/fabric/lib/traverse.sh",
]

# Deliberately absent from the tree, and deliberately SHAPED like a real path
# so it clears the regex and can only be rejected by the existence check.
FAKE_PATHS = [
    "web/t542-no-such-module.js",
    "lib/t542-not-a-file.py",
    "docs/t542-imaginary.md",
    "tools/t542-absent-probe.sh",
    "tests/t542-nothing-here.yaml",
]


def refuse(msg):
    print("REFUSE: %s" % msg)
    sys.exit(2)


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def load_estimator():
    # MUST be set before import: the module resolves PROJECT_ROOT at import
    # time and its fallback is `Path(__file__).resolve().parents[3]`. In AEF's
    # own repo the estimator sits at `agents/termlink/bvp-estimator/`, so that
    # is the repo root. VENDORED it sits at `.agentic-framework/agents/...`,
    # so parents[3] is `.agentic-framework` — off by one level, and it resolves
    # to a directory that EXISTS and contains a plausible `policy/` and
    # `.tasks/`, so nothing errors. Found here by leg 5 going red: the existence
    # check was resolving fixture paths against the framework tree, where
    # `policy/value-drivers.yaml` also exists, and 5 real paths scored as 3.
    # Reported upstream (T-542); not patched, because the fallback is correct
    # in AEF's own layout and only wrong under vendoring.
    os.environ["PROJECT_ROOT"] = str(ROOT)
    spec = importlib.util.spec_from_file_location("aef_bvp_estimator", str(EST))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    if Path(mod.PROJECT_ROOT).resolve() != ROOT.resolve():
        refuse("estimator resolved PROJECT_ROOT to %s, not %s — every existence check "
               "below would run against the wrong tree and the legs would measure "
               "another repo" % (mod.PROJECT_ROOT, ROOT))
    return mod


def non_completed_tasks():
    import yaml
    out = []
    for p in sorted(glob.glob(str(ROOT / ".tasks" / "active" / "T-*.md"))):
        txt = open(p, encoding="utf-8").read()
        if not txt.startswith("---"):
            continue
        try:
            fm = yaml.safe_load(txt.split("---", 2)[1]) or {}
        except Exception:
            continue
        if fm.get("status") == "work-completed":
            continue
        out.append(Path(p))
    return out


def main():
    if not EST.is_file():
        refuse("estimator not found at %s" % EST)

    before = sha256(EST)
    mod = load_estimator()

    if not hasattr(mod, "score_blast_radius"):
        refuse("estimator has no score_blast_radius — the function this probe defends is gone")

    # The fixtures are only meaningful if the tree agrees with them.
    for rp in REAL_PATHS:
        if not (ROOT / rp).is_file():
            refuse("fixture path %s no longer exists — legs 1/3/4 would assert over a "
                   "path the existence check correctly rejects, and would pass for the "
                   "wrong reason" % rp)
    for fp in FAKE_PATHS:
        if (ROOT / fp).exists():
            refuse("fixture path %s was expected NOT to exist but does — leg 3 would "
                   "pass vacuously" % fp)

    paths = non_completed_tasks()
    if len(paths) < MIN_TASKS:
        refuse("only %d non-completed task(s) (need >= %d) — the distribution legs "
               "would assert over noise" % (len(paths), MIN_TASKS))

    failures = []

    # ── Leg 1 — GRADED. The dominant term must take at least three distinct
    #    non-absent values across the real corpus.
    br_vals, cost_vals, absent = [], [], 0
    for p in paths:
        r = mod.estimate_cost(p)
        ce = r["cost_estimate"]
        br = ce.get("blast_radius")
        if br is None:
            absent += 1
            continue
        br_vals.append(br)
        cost_vals.append(round(0.6 * br + 0.3 * ce["tier"] + 0.1 * ce["effort"], 2))
    distinct_br = sorted(set(br_vals))
    distinct_cost = sorted(set(cost_vals))
    if len(distinct_br) < 3:
        failures.append("leg1: blast_radius takes only %d distinct value(s) %s across %d "
                        "task(s) — the 0.6-weighted term is a flag, not a measurement. This "
                        "is the pre-T-542 collapse returning"
                        % (len(distinct_br), distinct_br, len(br_vals)))
    if len(distinct_cost) < 3:
        failures.append("leg1b: the F8 composite takes only %d distinct value(s) %s — the "
                        "cost axis cannot sort" % (len(distinct_cost), distinct_cost))

    # ── Leg 2 — HONEST ABSENCE, on a synthetic task with nothing knowable.
    #    Anti-vacuity: proves the absent state is REACHABLE, so leg 3 below is
    #    testing a live branch rather than an unreachable one.
    blind_fm = {"workflow_type": "build"}
    blind_body = "Fix the thing that is broken. No files named, no components declared."
    br, ev = mod.score_blast_radius(blind_fm, blind_body, [])
    if br is not None:
        failures.append("leg2: a task with no components, no target_blast_radius and no "
                        "named path scored blast_radius=%r (%s) instead of absent. A blind "
                        "read is being reported at the cheapest value on the scale, which "
                        "is what an HV/LC filter promotes on" % (br, ev[-1] if ev else ""))
    if absent == 0:
        failures.append("leg2b: no task in the real corpus yields an absent blast_radius, so "
                        "the absent branch is unexercised by anything but the synthetic "
                        "fixture — leg 3 cannot be trusted to be testing live code")

    # ── Leg 3 — MEASURED, NOT MENTIONED. Five well-formed but non-existent
    #    paths must leave the blast radius absent. Under a mutant that drops
    #    the `.is_file()` check these five score 5 and this leg goes red.
    fake_body = "Rework " + ", ".join(FAKE_PATHS) + " end to end."
    br, ev = mod.score_blast_radius({"workflow_type": "build"}, fake_body, [])
    if br is not None:
        failures.append("leg3: a body naming %d paths that DO NOT EXIST scored "
                        "blast_radius=%r (%s) — the existence check is gone and the signal "
                        "is a word count, so quoting a filename raises a task's cost and a "
                        "rename never lowers it" % (len(FAKE_PATHS), br, ev[-1] if ev else ""))

    # ── Leg 4 — DECLARATION WINS. One declared component alongside five real
    #    paths in the body must score the component (1), not the paths (5).
    mixed_body = "Touches " + ", ".join(REAL_PATHS) + " in passing."
    br, ev = mod.score_blast_radius(
        {"workflow_type": "build", "components": ["one-declared-component"]}, mixed_body, [])
    if br != 1:
        failures.append("leg4: an explicit single-entry components: list scored %r (%s) "
                        "instead of 1 — the body-path fallback is overruling the author's "
                        "own declaration" % (br, ev[-1] if ev else ""))

    # ── Leg 5 — the fallback is actually WIRED, not merely defined. Same five
    #    real paths with NO components must reach the ladder.
    br, ev = mod.score_blast_radius({"workflow_type": "build"}, mixed_body, [])
    if br != 5:
        failures.append("leg5: %d real paths named in the body with no components: scored "
                        "%r (%s) instead of 5 — the body-path source is not reached, so the "
                        "corpus falls back to absent everywhere and nothing ranks"
                        % (len(REAL_PATHS), br, ev[-1] if ev else ""))

    # ── Leg 6 — the envelope OMITS the key rather than carrying a null. A
    #    `blast_radius: null` would satisfy leg 2 and still break the consumer,
    #    which does `ce.get('blast_radius')` and then arithmetic.
    env = mod.estimate_cost.__wrapped__ if hasattr(mod.estimate_cost, "__wrapped__") else None
    blind_task = next((p for p in paths
                       if mod.estimate_cost(p)["cost_estimate"].get("blast_radius") is None),
                      None)
    if blind_task is not None:
        ce = mod.estimate_cost(blind_task)["cost_estimate"]
        # T-1005 retarget (1.7.740): upstream T-3068 emits `blast_radius: null` on
        # purpose, and its compute_cost tests `br is not None`, not key presence. So
        # the leg now asserts the property that matters -- a null cannot enter the
        # ranking -- against the consumer's actual test, instead of the key shape.
        bvp_sh = (FW / "lib" / "bvp.sh").read_text()
        if "blast_radius" in ce and ce["blast_radius"] is not None:
            failures.append("leg6: %s blind task carries blast_radius=%r, not null/absent"
                            % (blind_task.name, ce["blast_radius"]))
        elif "blast_radius" in ce and "if br is not None and tier is not None" not in bvp_sh:
            failures.append("leg6: %s carries blast_radius: null and compute_cost no longer "
                            "tests `br is not None` — a null may re-enter the ranking"
                            % blind_task.name)

    # ── Leg 8 — TEMPLATE-BLIND. A task consisting of nothing but the template
    #    must yield NO blast-radius signal. `.tasks/templates/default.md` cites
    #    two real tool paths in its errexit warning and every task created from
    #    it inherits them, so without this subtraction the estimator measures
    #    the template. Found the hard way: the first `estimate-cost all` run of
    #    T-542 scored T-542 ITSELF at blast_radius=5, and two of the four paths
    #    in its own rationale were the template's.
    tpl_dir = ROOT / ".tasks" / "templates"
    tpls = sorted(tpl_dir.glob("*.md"))
    if not tpls:
        refuse("no task templates under %s — the template-blindness leg would pass "
               "vacuously" % tpl_dir)
    tpl_text = "\n".join(t.read_text(encoding="utf-8") for t in tpls)
    # T-859: was `mod._BODY_PATH_RE.search(tpl_text)`. That attribute was REMOVED by
    # 7b5e227e (T-840's upgrade to AEF 1.7.68, 1,409 vendored files replaced — one of the
    # six reverted-fix casualties in OBS-386), so this probe raised AttributeError instead
    # of measuring, and the sweep read its silence as a regression in the cost axis.
    #
    # NOT A RENAME. The module now exposes `_PATH_TOKEN_RE`, and it is a DIFFERENT
    # predicate: the old pattern required a real extension (py|sh|js|…|bpmn) and carried a
    # negative lookbehind; the new one matches any slash-separated token, allows glob
    # metacharacters, and has no lookbehind. Swapping the name in would have silently
    # changed what this guard asks.
    #
    # Asking via `_candidate_paths` is better than either regex, because this guard's
    # question is in the SUBJECT's terms, not ours: leg 8 asserts the subject does not
    # score the templates' own paths, so the stimulus that must exist is "the subject has
    # paths here it would consider". Re-implementing the subject's notion of a path is how
    # a probe drifts from its runner (PL-275) — this asks the subject directly.
    if not mod._candidate_paths({}, tpl_text):
        refuse("the estimator's own path extraction finds nothing in any task template — "
               "leg 8 would pass vacuously, since there is nothing for the subtraction "
               "to remove")
    br, ev = mod.score_blast_radius({"workflow_type": "build"}, tpl_text, [])
    if br is not None:
        failures.append("leg8: the task templates' OWN text scored blast_radius=%r (%s) — "
                        "every task inherits those lines, so the cost axis is measuring the "
                        "template rather than the task, exactly as score_d3_usability does "
                        "on 37 of 58 tasks" % (br, ev[-1] if ev else ""))

    # ── Leg 7 — the probe never writes the file it reads.
    after = sha256(EST)
    if before != after:
        failures.append("leg7: estimator.py changed during the run (%s -> %s)"
                        % (before[:12], after[:12]))

    print("T-542 cost blast-radius teeth — %d non-completed task(s)" % len(paths))
    print("    blast_radius distinct values : %s   (absent on %d task(s))"
          % (distinct_br, absent))
    print("    F8 composite distinct values : %d   range %s..%s"
          % (len(distinct_cost),
             distinct_cost[0] if distinct_cost else "-",
             distinct_cost[-1] if distinct_cost else "-"))
    print("    %d real fixture path(s), %d deliberately-absent fixture path(s)"
          % (len(REAL_PATHS), len(FAKE_PATHS)))

    if failures:
        print("\n%d finding(s):" % len(failures))
        for f in failures:
            print("  - %s" % f)
        return 1
    print("\nall legs green")
    return 0


if __name__ == "__main__":
    sys.exit(main())
