#!/usr/bin/env python3
"""
T-525 teeth — does the fabric coverage WARN actually discriminate, or just warn?

The check being exercised warned unconditionally on `unregistered > 0` and printed raw counts.
That is why no leg here may assert merely "a fabric warning appeared": the pre-change code
satisfies that for free, on every run, for every input. The deliverable is the DISCRIMINATION —
card loss must read differently from source growth — so every leg pins which branch was taken
and, where it asserts a branch was NOT taken, also proves the check was reached at all.

That second half is L-from-T-524, learned the hard way one task ago: a negative assertion is
satisfied by silence. "The output does not say CARD LOSS" passes when there is no output, which
is precisely the broken-audit case such a leg exists to catch. So legs 3 and 5 additionally
require the coverage line to be present and well-formed.

History is controlled through FABRIC_HISTORY_DIR (a seam the audit declares) rather than by
writing fabricated audit reports into the live `.context/audits/`. Fabricating real-looking
reports in the tree to test a check that reads reports is how you end up with a fixture nobody
recognises six weeks later — and a crashed run leaves it behind.

WHERE EACH LEG RUNS (T-549). The branch legs no longer audit THIS repository, and the reason
is cost that grows on its own. Five full `fw audit --sections structure` runs cost 86.04s
against _t509's 90s cap (T-543), and profiling one run (16.86s) found the three most expensive
checks to be BVP coherence 3.93s, the tracked-tree secret scan 3.69s, and the concerns walk
2.56s — 60% of the run, and not one of them can depend on FABRIC_HISTORY_DIR. The four branch
runs were paying for a whole-repository audit to vary a single input that one check reads.
Worse, that price tracks the tree: 254 watched files today and climbing, so raising the cap
would have bought headroom the repo consumes again.

So the four branch runs use PROJECT_ROOT — a seam the framework already declares and its own
cron entries already use — pointed at a freshly built fixture of 20 watched files and 8 cards.
This is a REAL `fw audit` process running the REAL check through the REAL code path; what
changed is the tree it walks, not the thing under test. 16.86s -> ~1.5s each.

What that must not cost, and what keeps it honest:
  - Leg 1 still audits THIS repository. "The check is reached and its arithmetic is right"
    is a claim about here, and a fixture cannot make it.
  - Leg 6a is STRONGER on the fixture than it was on the real tree. It asserts severity is
    invariant across branches, and on the real tree an unrelated check flapping mid-run (cron,
    a concurrent agent, a handover commit) moved the warn count for reasons having nothing to
    do with the branch — the same class of defect T-533 fixed in leg 7. On the fixture, history
    is the only thing that varies, so a difference in the count means what the leg says it does.
  - The standing risk is now fixture drift: a fixture cannot notice a branch the real tree
    reaches and it does not. Leg 1 covers the reachability half. The other half is
    tools/_t549-fabric-coverage-mutation-teeth.py, which mutates the audit's coverage branch
    and requires these legs to go RED — because a cheaper stimulus that can no longer fail is
    not a cheaper test, it is a deleted one (PL-206).

Legs:
  1  the check is REACHED on THIS repo and reports a ratio, not just a difference (guards 3/5)
  2  history showing MORE cards than now → the CARD LOSS branch, with the arithmetic right
  3  history showing FEWER cards than now → the growth branch, NOT card loss, and the line exists
  4  history equal to now → the flat branch, which is the case that says "the unregistered
     movement you are looking at is tree growth, not carding"
  5  no usable history → ABSTAINS. "I have no prior value" must not render as "no change"
     (PL-205), and must not silently fall into any of the three comparison branches.
  6a severity is UNCHANGED across all four branches on the fixture.
  6b the coverage finding on THIS repo is carried at WARN. The operator's T-344 [REVIEW]
     accepted this warning; a reporting fix that quietly promoted it to FAIL would overturn
     that decision under cover of a cosmetic change. Asserted on the FINDING's own severity
     rather than on the repo's total Fail count, which is a global moving property that would
     make this leg go red for somebody else's unrelated failure (G-015).
  7  hermetic — the SUBJECT'S WRITE-SET is byte-identical after the run (scoped, T-533).

Exit 0 all legs pass, 1 a leg failed, 2 REFUSE (the audit did not produce a coverage line at
all — nothing was evaluated, and that is not a pass).
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _t1021_writeset_hermeticity import (declared_writes_observed, snapshot,  # noqa: E402
                                   today_iso, write_set_violations)

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# the framework repo itself (FRAMEWORK.md at root), else a vendored consumer
_SELF = os.path.isfile(os.path.join(REPO, "FRAMEWORK.md"))

# T-549: which `fw` to drive. Defaults to the vendored one, which is the only value any
# ordinary run uses. The override exists for exactly one caller —
# tools/_t549-fabric-coverage-mutation-teeth.py — which points it at a copied framework whose
# coverage branch has been deliberately broken, and then requires the legs below to go red.
# Declared as a seam and named here for the same reason FABRIC_HISTORY_DIR is: an env var that
# changes what a probe measures should be documented where the probe is read, not discovered.
FW = os.environ.get("T525_FW") or os.path.join(REPO, "bin/fw" if _SELF else ".agentic-framework/bin/fw")

# Fixture size for the branch legs. Chosen so every branch has arithmetic room: card loss
# compares against CARDS+12, growth against CARDS-7, and both stay positive and distinct.
FIXTURE_CARDS = 8
FIXTURE_WATCHED = 20

# T-549: run only the fixture legs (2-5, 6a) and skip the three that audit this repository.
# The mutation probe needs to run this file four times, and at ~25s each that would rebuild
# the cost problem this seam exists to have solved. Branch scope costs ~8s.
#
# A SUBSET RUN CAN NEVER EXIT 0. It abstains with rc=2 whatever the legs say, because the one
# thing a partial instrument must not do is hand back the same green as the whole one — that
# is the T-548 finding (an instrument nobody heard from is not a pass) applied to this file
# before someone discovers it the expensive way.
SCOPE = os.environ.get("T525_SCOPE", "full")
BRANCHES_ONLY = SCOPE == "branches"

# AEF form (T-2735: one coverage claim): "Fabric drift: U source file(s) have no fabric card —
# P% covered (R of W watched; NOTE)". Named groups, read by name below.
COVERAGE_RE = re.compile(r"Fabric drift:\s*(?P<unreg>\d+)\s+source file\(s\) have no fabric card\s*[—-]\s*"
                         r"(?P<pct>\d+)%\s*covered\s*\((?P<reg>\d+)\s+of\s+(?P<watched>\d+)\s+watched;\s*(?P<note>.*)\)\s*$")

failures = []
passes = 0


def refuse(msg):
    print("REFUSE: %s" % msg)
    print("This is an abstention, not a pass — no leg was evaluated.")
    sys.exit(2)


def leg(name, ok, detail=""):
    global passes
    if ok:
        passes += 1
        print("  PASS  %s" % name)
    else:
        failures.append(name)
        print("  FAIL  %s%s" % (name, ("\n        " + detail) if detail else ""))


def build_fixture():
    """A minimal project the audit can walk in ~1.5s instead of ~17s.

    Everything here exists to reach ONE branch: the coverage check needs a non-empty watch
    set, at least one card, and unregistered > 0. The rest of the structure section runs too
    — this is not a stub of the audit, it is the audit on a small tree — it simply has almost
    nothing to walk.

    Built fresh per run under mktemp and removed in a finally, so there is no fixture left in
    any tree for someone to find in six weeks and fail to recognise, which is the failure this
    file's own header warns about for fabricated audit reports.
    """
    root = tempfile.mkdtemp(prefix="t525-fixture-")
    for d in (".tasks/active", ".tasks/completed", ".tasks/templates",
              ".context/audits", ".context/project", ".fabric/components", "src"):
        os.makedirs(os.path.join(root, d), exist_ok=True)
    tmpl = os.path.join(REPO, ".tasks/templates/default.md")
    if os.path.isfile(tmpl):
        shutil.copy2(tmpl, os.path.join(root, ".tasks/templates/default.md"))
    for i in range(FIXTURE_WATCHED):
        with open(os.path.join(root, "src", "f%02d.py" % i), "w") as fh:
            fh.write("# t525 fixture file %d — synthetic, built per run\nx = %d\n" % (i, i))
    # T-1005 (1.7.740): one project YAML, so upstream's T-3105 "candidate set empty" rail is
    # EVALUATED on every run. Without it the first run warns NOT EVALUATED and later runs do
    # not (the first run's own output gives them a file), so leg 6a compared two different
    # trees and read the difference as a severity change.
    with open(os.path.join(root, ".context/project", "t525-fixture.yaml"), "w") as fh:
        fh.write("fixture: t525\n")
    with open(os.path.join(root, ".fabric/watch-patterns.yaml"), "w") as fh:
        fh.write('patterns:\n  - glob: "src/**/*.py"\n')
    for i in range(FIXTURE_CARDS):
        with open(os.path.join(root, ".fabric/components", "c%02d.yaml" % i), "w") as fh:
            fh.write("id: C-%03d\nname: f%02d\ntype: module\nlocation: src/f%02d.py\n"
                     "purpose: t525 fixture card\n" % (i, i, i))
    # A git repo, because several structure checks (secret scan, large-file scan) address the
    # TRACKED tree and would otherwise be skipped rather than run cheaply — and a check that
    # silently does not run is not a check that got faster.
    for argv in (["git", "init", "-q", "."],
                 ["git", "add", "-A"],
                 ["git", "-c", "user.email=t525@fixture", "-c", "user.name=t525",
                  "commit", "-qm", "t525 fixture"]):
        subprocess.run(argv, cwd=root, capture_output=True, text=True, check=True)
    return root


def audit(history_dir=None, root=None):
    """Run the structure audit and return (coverage_match, warn_count, fail_count, raw).

    `root` selects the tree via PROJECT_ROOT (T-549). None means this repository.
    """
    env = dict(os.environ)
    if history_dir is not None:
        env["FABRIC_HISTORY_DIR"] = history_dir
    cwd = root or REPO
    if root is not None:
        env["PROJECT_ROOT"] = root
    p = subprocess.run([FW, "audit", "--sections", "structure"], cwd=cwd, env=env,
                       capture_output=True, text=True, timeout=600, check=False)
    raw = p.stdout + p.stderr
    match = None
    for line in raw.splitlines():
        m = COVERAGE_RE.search(line)
        if m:
            match = m
            break
    warn = fail = None
    mw = re.search(r"^Warn:\s*(\d+)", raw, re.M)
    mf = re.search(r"^Fail:\s*(\d+)", raw, re.M)
    if mw:
        warn = int(mw.group(1))
    if mf:
        fail = int(mf.group(1))
    return match, warn, fail, raw


def coverage_severity(raw):
    """The severity marker on the line carrying the coverage finding, e.g. 'WARN'.

    Read off the finding itself rather than from the report's Fail: total. The total is a
    property of the whole tree that moves whenever any unrelated check fails, so asserting on
    it would make this leg report someone else's regression as a severity change here (G-015).
    """
    for line in raw.splitlines():
        if COVERAGE_RE.search(line):
            m = re.match(r"\s*\[([A-Z]+)\]", line)
            return m.group(1) if m else None
    return None


def history(tmp, name, registered):
    """A directory holding one daily audit report that states `registered` cards."""
    d = os.path.join(tmp, name)
    os.makedirs(d, exist_ok=True)
    if registered is not None:
        # Filename must be a plausible LATER day than any real report, because the reader
        # takes the most recent. 2099 is unmistakably synthetic to anyone who sees it.
        with open(os.path.join(d, "2099-01-01.yaml"), "w") as fh:
            fh.write('  - check: "Fabric: %d registered, 1 unregistered (of 2 watched)"\n'
                     % registered)
    return d


if not os.path.isfile(FW):
    refuse("missing %s — the subject is not here" % FW)

print("T-525 teeth — does the fabric coverage WARN discriminate, or just warn?")
print("subject: agents/audit/audit.sh (fabric coverage check)")
print()

tmp = tempfile.mkdtemp(prefix="t525-teeth-")

# T-533: SCOPED to this subject's write-set, not to the whole tree.
# The original form compared over the entire repository across this script's ~61-second run, so
# ANY other writer — cron, a handover commit, a concurrent agent — turned leg 7 red while the
# script passed 7/7 standalone. Demonstrated under T-527: one persistent file created mid-run
# drove it red naming the marker. That made the bridge suite non-deterministic and cost a whole
# investigation (T-526) to localise.
# The subject here is `fw audit`, which writes its report under `.context/audits/`. The `cron/`
# subdirectory is EXCLUDED because it belongs to a different actor on a 15-minute timer — the
# single likeliest unrelated writer, and including it would rebuild the defect at 1/15th scale.
#
# T-552: the SCOPE above was right; the COMPARAND was not. It was `git status --porcelain`,
# which reports status letters rather than content — so a rewrite of any already-dirty file was
# invisible, including both files the audit actually writes — and which reads the legitimate
# creation of `<today>.yaml` as a violation, so the leg could not pass on the first audit of any
# day (OBS-273). Now a path->digest map judged against the paths the subject is entitled to
# write. See tools/_writeset_hermeticity.py for the measurements behind both halves.
# T-1005 (1.7.740): upstream's audit also records its run time in full-audit-timing.yaml
# (AUDIT_TIMING_FILE, used to size the pre-push timeout) -- a declared output of the subject.
ALLOWED_WRITES = {os.path.join(".context/audits/discoveries", "LATEST.yaml"),
                  os.path.join(".context/audits", "full-audit-timing.yaml"),
                  # the GO-scope triage report (T-3562) is rewritten on every full audit
                  os.path.join(".context/audits/go-scope-unpropagated", "LATEST.md")}


def audits_state():
    return snapshot(REPO, ".context/audits")


before = audits_state()
# Read on both sides of the run: this probe takes ~61s and can straddle midnight, on which run
# the audit legitimately writes tomorrow's report rather than today's.
allowed_writes = set(ALLOWED_WRITES) | {".context/audits/%s.yaml" % today_iso()}
fixture = None
try:
    # ── leg 1: the real run reaches the check and reports a ratio ──────────────────────────
    base_raw = ""
    if BRANCHES_ONLY:
        print("  SKIP  1 (branch scope — this repository is not audited in this mode)")
    else:
        base, base_warn, base_fail, base_raw = audit()
        if base is None:
            refuse("the audit produced no fabric coverage line at all, so no branch could be "
                   "observed. Either the check did not run (is `unregistered` zero on this "
                   "tree, which sends it down the pass() arm?) or its message shape changed "
                   "and the regex in this file is stale. Nothing below was evaluated.")

        now_reg = int(base.group("reg"))
        watched = int(base.group("watched"))
        pct = int(base.group("pct"))
        leg("1 the check is REACHED and reports COVERAGE, not just a difference",
            watched > 0 and pct == (now_reg * 100 // watched),
            "registered=%d watched=%d printed=%d%%. The whole finding is that `unregistered` "
            "alone moves opposite to coverage; if the ratio is absent or wrong, nothing else "
            "here means anything." % (now_reg, watched, pct))

    # ── the fixture the branch legs run against (T-549) ────────────────────────────────────
    # Built once and reused across legs 2-5: each leg varies FABRIC_HISTORY_DIR only, which is
    # precisely the isolation the old real-tree version could not offer.
    fixture = build_fixture()
    fx, fx_warn, fx_fail, fx_raw = audit(root=fixture)
    if fx is None:
        refuse("the audit produced no fabric coverage line on the T-549 fixture, so the four "
               "branch legs have no stimulus. The fixture is meant to sit in the same arm the "
               "real tree does (cards registered, watch set non-empty, unregistered > 0); if "
               "the audit now takes a different arm on it — the expander-unavailable or "
               "empty-watch-set warnings — the fixture has drifted from the thing it stands "
               "in for and must be repaired, not worked around. Nothing below was evaluated.\n"
               "fixture output:\n%s" % fx_raw[-1500:])
    fx_reg = int(fx.group("reg"))

    # ── leg 2: card loss ───────────────────────────────────────────────────────────────────
    m, warn_loss, fail_loss, raw = audit(history(tmp, "loss", fx_reg + 12), root=fixture)
    note = m.group("note") if m else ""
    leg("2 history with MORE cards than now takes the CARD LOSS branch, arithmetic right",
        m is not None and "CARD LOSS" in note and ("12 fewer cards" in note)
        and ("%d -> %d" % (fx_reg + 12, fx_reg)) in note,
        "note=%r. Card loss and routine growth must not print the same line — a deleted or "
        "malformed card stops participating in component resolution (T-522/T-524) and makes "
        "its own file report as unregistered." % note)

    # ── leg 3: growth — a NEGATIVE assertion, so prove the line exists first ───────────────
    m, warn_grow, fail_grow, raw = audit(history(tmp, "grow", max(fx_reg - 7, 0)), root=fixture)
    note = m.group("note") if m else ""
    leg("3 history with FEWER cards takes the growth branch and NOT card loss",
        m is not None and note != "" and "CARD LOSS" not in note
        and note.startswith("+%d cards since" % (fx_reg - max(fx_reg - 7, 0))),
        "note=%r (line present=%s). This leg asserts a branch was NOT taken, so it must also "
        "prove the check produced a line — otherwise a broken audit satisfies it by silence, "
        "which is exactly the T-524 vacuous-leg failure." % (note, m is not None))

    # ── leg 4: flat ────────────────────────────────────────────────────────────────────────
    m, warn_flat, fail_flat, raw = audit(history(tmp, "flat", fx_reg), root=fixture)
    note = m.group("note") if m else ""
    leg("4 history EQUAL to now takes the flat branch",
        m is not None and note.startswith("cards flat since"),
        "note=%r. This is the branch that tells the operator the unregistered movement they are "
        "looking at is tree growth rather than carding activity." % note)

    # ── leg 5: abstention — also a negative assertion ──────────────────────────────────────
    m, warn_abs, fail_abs, raw = audit(history(tmp, "empty", None), root=fixture)
    note = m.group("note") if m else ""
    leg("5 no usable history ABSTAINS rather than falling into a comparison branch",
        m is not None and note.startswith("direction not evaluated")
        and "CARD LOSS" not in note and "flat since" not in note and not note.startswith("+"),
        "note=%r (line present=%s). 'I have no prior value' rendered as 'no change' would be a "
        "claim about history the instrument cannot support (PL-205)." % (note, m is not None))

    # ── leg 6a: severity untouched across branches, measured where only history varies ─────
    leg("6a severity is UNCHANGED across every branch on the fixture",
        None not in (fx_warn, warn_loss, warn_grow, warn_flat, warn_abs,
                     fx_fail, fail_loss, fail_grow, fail_flat, fail_abs)
        and fx_warn == warn_loss == warn_grow == warn_flat == warn_abs
        and fx_fail == fail_loss == fail_grow == fail_flat == fail_abs == 0,
        "warn counts base=%s loss=%s grow=%s flat=%s abstain=%s; fail %s/%s/%s/%s/%s. Only "
        "FABRIC_HISTORY_DIR differs between these five runs, so any difference here is the "
        "branch changing severity and nothing else. On the real tree this same comparison "
        "could move because an unrelated check flapped mid-run (T-533's lesson, one leg over)."
        % (fx_warn, warn_loss, warn_grow, warn_flat, warn_abs,
           fx_fail, fail_loss, fail_grow, fail_flat, fail_abs))

    # ── leg 6b: and on THIS repo the finding is still a WARN ────────────────────────────────
    if BRANCHES_ONLY:
        print("  SKIP  6b (branch scope — this repository is not audited in this mode)")
    else:
        base_sev = coverage_severity(base_raw)
        leg("6b the coverage finding on THIS repo is carried at WARN, not FAIL",
            base_sev == "WARN",
            "severity=%r. The operator's T-344 [REVIEW] accepted this standing WARN; promoting "
            "it to FAIL inside a reporting fix would overturn a ratified decision as a side "
            "effect. Asserted on the finding's own marker rather than on the report's Fail: "
            "total, which moves for reasons that have nothing to do with this check."
            % base_sev)
finally:
    shutil.rmtree(tmp, ignore_errors=True)
    if fixture:
        shutil.rmtree(fixture, ignore_errors=True)

after = audits_state()
allowed_writes |= {".context/audits/%s.yaml" % today_iso()}
if BRANCHES_ONLY:
    # Nothing in this mode writes to the real .context/audits, so the leg has no stimulus and
    # would be satisfied by that absence rather than by hermeticity — a vacuous pass of exactly
    # the kind leg 3 and leg 5 were built to refuse.
    print("  SKIP  7 (branch scope — nothing in this mode writes to the subject's write-set)")
else:
    breaches = write_set_violations(before, after, allowed_writes)
    # T-552: hermeticity is a negative claim and a negative claim is satisfied by silence
    # (T-524), so the leg also requires that the subject DID write. `fw audit` stamps its report
    # with a timestamp, so an audit that ran always moves at least one declared output; an empty
    # observation here means the audit did not run, which must not read as hermetic.
    wrote = declared_writes_observed(before, after, allowed_writes)
    leg("7 hermetic — the subject wrote its declared outputs and nothing else",
        not breaches and wrote,
        "content changed across the run WITHIN THIS SUBJECT'S WRITE-SET (.context/audits, "
        "excluding cron/) at a path the subject does not declare as output. The audit writes "
        "its report there, so a leg that let it run unconstrained would dirty the tree and "
        "make every later verdict in the session ambiguous. Two scopings apply: T-533 means an "
        "unrelated writer ELSEWHERE in the repo can no longer cause this, and T-552 means the "
        "comparand is content rather than git status letters — so a red here is a real byte "
        "change by this run, at a path outside %r. Declared outputs observed to move: %r — if "
        "that list is EMPTY the audit did not write at all, and this leg is red because a "
        "subject that never ran is not a hermetic subject.\n%s"
        % (sorted(allowed_writes), wrote, "\n".join(breaches)))

print()
total = passes + len(failures)
if failures:
    print("%d/%d legs passed — FAILED: %s" % (passes, total, ", ".join(failures)))
    sys.exit(1)
if BRANCHES_ONLY:
    print("%d/%d legs passed — SUBSET RUN (T525_SCOPE=branches), NOT a pass of this file. "
          "Legs 1, 6b and 7 were not evaluated: they audit this repository and nothing here "
          "did. Exiting 2 (abstain) so no caller can read a partial run as a whole one."
          % (passes, total))
    sys.exit(2)
print("%d/%d legs passed" % (passes, total))
sys.exit(0)
