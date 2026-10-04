#!/usr/bin/env python3
"""T-467: `fw arc tag` must write the source-of-truth field, not the deprecated one.

T-1849 made task-side `arc_id:` canonical. T-1850 MIGRATED 162 tasks off the
`tags: [arc:<slug>]` form. `fw arc tag` — the command `fw arc --help` names as the
way to record membership — kept writing the tag and never the field, so every call
re-created what the migration had cleaned up, one task at a time.

Nothing broke visibly, which is why it lasted: every reader takes the UNION of both
forms, so an arc recorded in two representations RENDERS IDENTICALLY to one recorded
in one. T-466 caught it only because a verification leg asserted the field by NAME
instead of asserting the rendered output looked right.

BOTH ARMS ARE DRIVEN. The cheap way to stop a writer emitting the wrong field is to
stop it emitting anything, so "writes arc_id:" is load-bearing next to "does not
write the tag" — a verb gutted to a no-op passes the second arm perfectly.

Every case runs `fw arc tag` for real against a THROWAWAY project root: its own
.tasks/ and .context/arcs/. Nothing here touches the live corpus.

Run with --against-head to execute the SAME arms against HEAD's pre-fix copy of
lib/arc.sh. Arms that pass there are not fencing anything.

Exit 0 all arms behaved, 1 any arm did not.
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# the framework repo itself (FRAMEWORK.md at root), else a vendored consumer
_SELF = os.path.isfile(os.path.join(REPO, "FRAMEWORK.md"))
FRAMEWORK = REPO if _SELF else os.path.join(REPO, ".agentic-framework")
ARC_REL = "lib/arc.sh" if _SELF else ".agentic-framework/lib/arc.sh"

FM = """---
id: %(tid)s
name: "fixture"
description: "fixture task"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [%(tags)s]
components: []
related_tasks: []
%(arc)s# arc_id:                         # T-1849: optional — slug OR arc-NNN
#                                 # When set, must resolve to .context/arcs/<id>.yaml
created: 2026-09-05T00:00:00Z
last_update: 2026-09-05T00:00:00Z
---

# %(tid)s: fixture

## Context

%(body)s
"""

ARC_YAML = """id: arc-900
slug: %s
name: "fence arc"
description: "throwaway"
status: draft
anchor_task:
headline_mechanic: "operator tags a task and observes canonical membership"
demo_evidence: null
created: 2026-09-05T00:00:00Z
closed_at: null
decision: null
"""


def make_root(tid="T-900", tags="", arc_line="", body="Nothing special.", arcs=("fence-arc",)):
    root = tempfile.mkdtemp(prefix="t467-")
    os.makedirs(os.path.join(root, ".tasks", "active"))
    os.makedirs(os.path.join(root, ".tasks", "completed"))
    os.makedirs(os.path.join(root, ".context", "arcs"))
    for slug in arcs:
        with open(os.path.join(root, ".context", "arcs", slug + ".yaml"), "w") as fh:
            fh.write(ARC_YAML % slug)
    tf = os.path.join(root, ".tasks", "active", "%s-fixture.md" % tid)
    with open(tf, "w") as fh:
        fh.write(FM % {"tid": tid, "tags": tags, "arc": arc_line, "body": body})
    return root, tf


def run_tag(root, arc_lib, slug, tid):
    """Invoke arc_tag out of the given lib/arc.sh, against a throwaway PROJECT_ROOT."""
    script = (
        'set -uo pipefail\n'
        'PROJECT_ROOT=%s\n'
        'FRAMEWORK_ROOT=%s\n'
        'export PROJECT_ROOT FRAMEWORK_ROOT\n'
        '. %s\n'
        'arc_tag "%s" "%s"\n'
    ) % (root, os.path.join(root, "_nolib"), arc_lib, slug, tid)
    p = subprocess.run(["bash", "-c", script], capture_output=True, text=True)
    return p.returncode, (p.stdout + p.stderr)


def frontmatter(path):
    text = open(path).read()
    m = re.match(r"^---\n(.*?\n)---\n", text, re.DOTALL)
    return (m.group(1) if m else ""), text


def head_lib():
    """HEAD's pre-fix lib/arc.sh, written to a temp file."""
    p = subprocess.run(["git", "-C", REPO, "show", "HEAD:" + ARC_REL],
                       capture_output=True, text=True)
    if p.returncode != 0:
        return None
    fd, path = tempfile.mkstemp(prefix="t467-head-", suffix=".sh")
    with os.fdopen(fd, "w") as fh:
        fh.write(p.stdout)
    return path


# ── arms ────────────────────────────────────────────────────────────────────
# Each returns (ok, detail). `lib` is the arc.sh under test.

def arm_writes_arc_id(lib):
    root, tf = make_root()
    try:
        rc, out = run_tag(root, lib, "fence-arc", "T-900")
        fm, _ = frontmatter(tf)
        live = re.search(r"^arc_id:[ \t]*(\S+)[ \t]*$", fm, re.MULTILINE)
        if rc != 0:
            return False, "arc_tag exited %d: %s" % (rc, out.strip()[:120])
        if not live:
            return False, "no live arc_id: in frontmatter"
        if live.group(1) != "fence-arc":
            return False, "arc_id: is %r" % live.group(1)
        return True, "arc_id: fence-arc"
    finally:
        shutil.rmtree(root, ignore_errors=True)


def arm_no_deprecated_tag(lib):
    # T-1005 retarget (1.7.740): upstream T-2955 DUAL-WRITES -- arc_id: (canonical)
    # plus the legacy arc:<slug> tag, which every reader unions. Not writing the tag
    # was our choice, not a defect; the property that still matters is that the two
    # forms never DISAGREE, since a disagreeing pair is a silent second membership.
    root, tf = make_root()
    try:
        run_tag(root, lib, "fence-arc", "T-900")
        fm, _ = frontmatter(tf)
        tags = re.search(r"^tags:.*$", fm, re.MULTILINE)
        other = [t for t in re.findall(r"arc:([A-Za-z0-9._-]+)", tags.group(0) if tags else "")
                 if t != "fence-arc"]
        if other:
            return False, "legacy tag disagrees with arc_id:: %s" % tags.group(0).strip()
        return True, "legacy tag (if any) agrees with arc_id:"
    finally:
        shutil.rmtree(root, ignore_errors=True)


def arm_idempotent(lib):
    # T-1005 retarget: the no-op fixture is a task ALREADY fully tagged in upstream's
    # dual-write shape (arc_id: and the agreeing legacy tag); re-tagging it must not
    # touch the file. Upstream reports the skip per form, not as one "no change".
    root, tf = make_root(tags='"arc:fence-arc"', arc_line="arc_id: fence-arc\n")
    try:
        before = open(tf).read()
        rc, out = run_tag(root, lib, "fence-arc", "T-900")
        after = open(tf).read()
        if rc != 0:
            return False, "re-tag exited %d" % rc
        if before != after:
            return False, "file changed on a no-op re-tag"
        if "skipping" not in out and "no change" not in out:
            return False, "did not report the no-op: %r" % out.strip()[:80]
        return True, "byte-identical, reported"
    finally:
        shutil.rmtree(root, ignore_errors=True)


def arm_refuses_reassign(lib):
    root, tf = make_root(arc_line="arc_id: other-arc\n", arcs=("fence-arc", "other-arc"))
    try:
        before = open(tf).read()
        rc, _ = run_tag(root, lib, "fence-arc", "T-900")
        after = open(tf).read()
        if rc == 0:
            return False, "silently accepted a cross-arc reassignment"
        if before != after:
            return False, "refused but still mutated the file"
        return True, "refused, file untouched"
    finally:
        shutil.rmtree(root, ignore_errors=True)


def arm_body_not_rewritten(lib):
    """The replaced writer ran `^tags:` over the WHOLE document.

    A task body that quotes these field names — T-467's own file does — must come
    through untouched. This is the arm that catches a document-wide regex.
    """
    body = ("The bug: `fw arc tag` wrote the wrong field. Prose below is quoted, "
            "not frontmatter:\n\n"
            "tags: [arc:some-other-arc]\n"
            "arc_id: some-other-arc\n")
    root, tf = make_root(body=body)
    try:
        run_tag(root, lib, "fence-arc", "T-900")
        fm, text = frontmatter(tf)
        tail = text[len(fm) + 8:] if fm else text
        if "tags: [arc:some-other-arc]" not in tail:
            return False, "rewrote a quoted tags: line in the body"
        if "arc_id: some-other-arc" not in tail:
            return False, "rewrote a quoted arc_id: line in the body"
        live = re.search(r"^arc_id:[ \t]*(\S+)", fm, re.MULTILINE)
        if not live or live.group(1) != "fence-arc":
            return False, "body preserved but frontmatter not set"
        return True, "body prose intact, frontmatter set"
    finally:
        shutil.rmtree(root, ignore_errors=True)


def arm_help_does_not_promise_tag(lib):
    script = ('set -uo pipefail\nPROJECT_ROOT=%s\nexport PROJECT_ROOT\n. %s\narc_help\n'
              % (REPO, lib))
    p = subprocess.run(["bash", "-c", script], capture_output=True, text=True)
    out = p.stdout + p.stderr
    m = re.search(r"^  tag <id> T-XXXX(.*?)(?=^  \w)", out, re.MULTILINE | re.DOTALL)
    if not m:
        return False, "no `tag` entry in help"
    entry = m.group(0)
    if not re.search(r"arc_id:", entry):
        return False, "help for `tag` never names arc_id:"
    # T-1005 retarget: upstream's help says the verb adds the legacy tag, which is
    # TRUE under its dual-write; what must hold is that help names the canonical field.
    return True, "help names arc_id: as what the verb writes"


# ── T-679 arms ──────────────────────────────────────────────────────────────
# The T-467 guard read only `arc_id:`, but every READER unions arc_id: with the
# legacy `arc:<slug>` tag — so a task recorded only in the tag was invisible to
# the reassignment check. Measured on the live corpus, not theorised: `fw arc tag
# designer-authoring-surface T-590` set the field and exited 0 on a task already
# in ewcr-governed-delivery, and 26 tasks here are legacy-tag-only.
#
# These arms are kept in THIS fence rather than a new one because they constrain
# the same function, and two fences each covering half of one guard is how the
# next drift starts.

def arm_refuses_legacy_tag_reassign(lib):
    """T-590's exact shape: membership in the tag, no arc_id: at all."""
    root, tf = make_root(tags="ewcr-v1, arc:other-arc", arcs=("fence-arc", "other-arc"))
    try:
        before = open(tf).read()
        rc, _ = run_tag(root, lib, "fence-arc", "T-900")
        after = open(tf).read()
        if rc == 0:
            return False, "reassigned a legacy-tag-only task silently"
        if before != after:
            return False, "refused but still mutated the file"
        return True, "refused, file untouched"
    finally:
        shutil.rmtree(root, ignore_errors=True)


def arm_legacy_tag_same_arc_upgrades(lib):
    """The upgrade path must stay open, or the 26 legacy-tag-only tasks are stranded.

    Load-bearing against the cheap fix: a guard that refuses ANY task carrying an
    arc: tag would pass the arm above and strand every legacy task, including the
    ones arc_migrate step 3 walks back through this verb.
    """
    root, tf = make_root(tags="arc:fence-arc")
    try:
        rc, out = run_tag(root, lib, "fence-arc", "T-900")
        fm, _ = frontmatter(tf)
        live = re.search(r"^arc_id:[ \t]*(\S+)", fm, re.MULTILINE)
        if rc != 0:
            return False, "refused the upgrade (exit %d): %s" % (rc, out.strip()[:90])
        if not live or live.group(1) != "fence-arc":
            return False, "no arc_id: written on the upgrade path"
        return True, "legacy tag upgraded to arc_id:"
    finally:
        shutil.rmtree(root, ignore_errors=True)


def arm_refuses_multi_arc_tags(lib):
    """arc_id: is single-valued; the legacy list form was not."""
    root, tf = make_root(tags="arc:fence-arc, arc:other-arc",
                         arcs=("fence-arc", "other-arc"))
    try:
        before = open(tf).read()
        rc, out = run_tag(root, lib, "fence-arc", "T-900")
        after = open(tf).read()
        if rc == 0:
            return False, "collapsed dual membership into one arc_id: silently"
        if before != after:
            return False, "refused but still mutated the file"
        if "other-arc" not in out:
            return False, "refused without naming the arc that would be dropped"
        return True, "refused, both arcs named"
    finally:
        shutil.rmtree(root, ignore_errors=True)


def arm_body_arc_tag_not_consulted(lib):
    """`arc:` in body prose must not be read as membership.

    Mention-is-not-membership (T-669). Without bounding the scan to the `tags:`
    line, the reassignment guard fires on any task that merely DISCUSSES an arc —
    refusing legitimate work and, worse, teaching the reader to route around it.
    """
    body = "This task discusses arc:other-arc and tags: [arc:other-arc] in prose only.\n"
    root, tf = make_root(body=body, arcs=("fence-arc", "other-arc"))
    try:
        rc, out = run_tag(root, lib, "fence-arc", "T-900")
        fm, _ = frontmatter(tf)
        live = re.search(r"^arc_id:[ \t]*(\S+)", fm, re.MULTILINE)
        if rc != 0:
            return False, "refused on a body mention (exit %d): %s" % (rc, out.strip()[:80])
        if not live or live.group(1) != "fence-arc":
            return False, "no arc_id: written"
        return True, "body mention ignored, field set"
    finally:
        shutil.rmtree(root, ignore_errors=True)


ARMS = [
    ("writes arc_id: into frontmatter", arm_writes_arc_id),
    ("legacy arc: tag never disagrees with arc_id:", arm_no_deprecated_tag),
    ("re-tagging the same arc is a byte-identical no-op", arm_idempotent),
    ("refuses cross-arc reassignment, changes nothing", arm_refuses_reassign),
    ("a body quoting tags:/arc_id: is not rewritten", arm_body_not_rewritten),
    ("--help names arc_id: as the source of truth", arm_help_does_not_promise_tag),
    # T-679
    ("refuses reassign when membership is legacy-tag-only", arm_refuses_legacy_tag_reassign),
    ("legacy tag for the SAME arc still upgrades to arc_id:", arm_legacy_tag_same_arc_upgrades),
    ("refuses a task carrying two arc: tags", arm_refuses_multi_arc_tags),
    ("an arc: tag in BODY prose is not membership", arm_body_arc_tag_not_consulted),
]


def main():
    against_head = "--against-head" in sys.argv
    if against_head:
        lib = head_lib()
        if lib is None:
            print("cannot read HEAD:" + ARC_REL)
            return 1
        print("T-467 arc tag fence — AGAINST HEAD (pre-fix)\n")
        print("Arms that PASS here fence nothing. Expect most to FAIL.\n")
    else:
        lib = os.path.join(FRAMEWORK, "lib", "arc.sh")
        print("T-467 arc tag writes the source-of-truth field\n")

    failures = []
    try:
        for label, fn in ARMS:
            try:
                ok, detail = fn(lib)
            except Exception as exc:                      # noqa: BLE001
                ok, detail = False, "arm raised: %s" % exc
            print("%-6s %-52s %s" % ("PASS" if ok else "FAIL", label, detail))
            if not ok:
                failures.append(label)
    finally:
        if against_head:
            os.unlink(lib)

    if against_head:
        print("\n%d/%d arm(s) failed against pre-fix code." % (len(failures), len(ARMS)))
        print("That is the discrimination: they detect the defect rather than the fix.")
        return 0

    if failures:
        print("\nFENCE FAILED — %d arm(s): %s" % (len(failures), "; ".join(failures)))
        return 1
    print("\nFENCE PASSED — arc_id: is written, the legacy tag never disagrees, re-tagging"
          "\nis a no-op, reassignment (incl. legacy-tag-only and multi-tag) is refused, and task bodies are left alone.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
