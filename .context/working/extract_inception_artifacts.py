#!/usr/bin/env python3
"""T-2515: backfill inception research artifacts by FAITHFUL extraction from task
bodies. Copies real research sections verbatim — invents nothing. Sections that are
task-mechanics (Acceptance Criteria, Verification, Updates, Evolution, empty
Decisions template, Reviewer Verdict) are dropped; research sections are kept and
HTML template comments are stripped."""
import re, sys, glob, os

TASKS = ["T-1372","T-1376","T-1444","T-1506","T-1507","T-1616","T-1617","T-1621",
         "T-1710","T-1713","T-1732","T-1829","T-1831","T-1833","T-1958","T-1959",
         "T-1981","T-2000","T-2159","T-2203","T-2252","T-2324","T-2416"]

# sections to DROP (task mechanics, not research)
DROP = {"acceptance criteria","verification","updates","evolution","decisions",
        "reviewer verdict","reviewer","human"}

def strip_comments(t):
    return re.sub(r"<!--.*?-->", "", t, flags=re.DOTALL)

def frontmatter_and_body(s):
    parts = s.split("---", 2)
    return parts[1], parts[2] if len(parts) >= 3 else ("", s)

def field(fm, key):
    m = re.search(rf"(?m)^{key}:\s*(.+)$", fm)
    return m.group(1).strip().strip('"').strip("'") if m else ""

def decision_of(body):
    m = re.search(r"(?im)^\**\s*(?:Recommendation|Decision)\**\s*:?\s*\**\s*(GO|NO-GO|NO GO|DEFER)\b", body)
    if m:
        return m.group(1).upper().replace("NO GO", "NO-GO")
    return "recorded in body"

def sections(body):
    """Split on H2 (## ), yield (title, content). Content before first H2 kept as 'preamble'."""
    out = []
    idx = [(m.start(), m.group(1).strip()) for m in re.finditer(r"(?m)^##\s+(.+)$", body)]
    if not idx:
        return [("", body.strip())]
    if body[:idx[0][0]].strip():
        out.append(("", body[:idx[0][0]].strip()))
    for i,(pos,title) in enumerate(idx):
        end = idx[i+1][0] if i+1 < len(idx) else len(body)
        seg = body[pos:end]
        # drop the "## title" header line from the content capture; re-add cleanly
        content = re.sub(r"(?m)^##\s+.+\n?", "", seg, count=1).strip()
        out.append((title, content))
    return out

def build(task_id):
    files = glob.glob(f".tasks/completed/{task_id}-*.md")
    if not files:
        return None, f"{task_id}: task file not found"
    f = files[0]
    slug = re.sub(rf"^{task_id}-", "", os.path.basename(f)[:-3])
    s = open(f).read()
    fm, body = frontmatter_and_body(s)
    name = field(fm, "name")
    body = strip_comments(body)
    # remove the leading H1 title line
    body = re.sub(r"(?m)\A\s*#\s+.+\n", "", body).strip()
    dec = decision_of(body)
    kept = []
    for title, content in sections(body):
        if not content.strip():
            continue
        if title.strip().lower() in DROP:
            continue
        if title:
            kept.append(f"## {title}\n\n{content}")
        else:
            kept.append(content)
    if not kept:
        return None, f"{task_id}: no research sections after filtering"
    header = (f"# {task_id} — {name}\n\n"
              f"> **Inception research artifact** (backfilled by T-2515 from the "
              f"`{task_id}` task body — the research was captured in-task at decision "
              f"time; this extracts it verbatim to the canonical `docs/reports/` home "
              f"per C-001). Source: `{f}`. **Decision recorded: {dec}.**\n")
    art = header + "\n" + "\n\n".join(kept) + "\n"
    out = f"docs/reports/{task_id}-{slug}.md"
    return (out, art), None

if __name__ == "__main__":
    dry = "--write" not in sys.argv
    only = [a for a in sys.argv[1:] if a.startswith("T-")]
    targets = only or TASKS
    for t in targets:
        res, err = build(t)
        if err:
            print("SKIP", err); continue
        out, art = res
        lines = art.count("\n")
        if dry:
            print(f"[dry] {out}  ({lines} lines, {len(art)} bytes)")
        else:
            open(out, "w").write(art)
            print(f"WROTE {out}  ({lines} lines)")
