"""T-5292 (T-5290 GO): `verdict/1`, the fixed shape of a reviewer's vote, and its strict reader.

Adapted from 1409-sprind's begruendung/0.1 (docs/reports/T-5290-structured-reviewer-verdicts.md).
A vote's quality is in its reason: a vote that does not say which evidence, where, by which rule,
cannot be checked, and a pass without evidence looks the same as a pass with it. So every vote,
pass or fail, has one form, and a vote that does not follow it is refused — never coerced
(1409 caveat c: a lenient reader turned 2 of 11 faulty answers into passes).

The shape (one block per vote):

    ===VERDICT===
    format: verdict/1
    task: T-123
    reviewer: <identity>
    round: 1
    vote: green | amber | red | escalate | not-evaluated      (the overall vote)
    failed: [2]                                                (every criterion not voted green)

    ## AC<N> <short title>                                     (N = the Human AC number)
    Vote: green | amber | red | escalate | not-evaluated
    Evidence: "<verbatim quote>"            or  image: <file> region x,y,w,h
                                            or  image: <file> selector <css>
    Location: <path>:<line>[-<line>]        or  <image file> region x,y,w,h
                                            or  <image file> selector <css>
                                            or  command: <the command whose output is quoted>
    Rule: <the requirement applied: the criterion's clause, or a named rule>
    Conclusion: <one sentence linking the evidence to the rule>
    Guidance: <what is needed next — required unless Vote is green>

    ## Counter-search
    Searched: <where you looked for evidence against your vote, and for what>
    Found: <what you found>

    ## Change-my-mind
    <the concrete observation that would change this vote>
    ===END===

Labels are `Label: value` at the start of a line; an indented line continues the value above
it. Evidence and Location may repeat, in pairs (the n-th Location locates the n-th Evidence).

Consistency: the overall vote is green exactly when every criterion is green; otherwise it is
one of the non-green criterion votes, and `failed` names exactly the non-green criteria.

This module only checks FORM. Whether a quote is really in the file, or a region really shows
what is claimed, is slice 2 (T-5293).
"""
from __future__ import annotations

import re

FORMAT = "verdict/1"
#: The line a brief carries when it asked for `verdict/1`. The reader keys on it, so a run
#: whose brief predates this format keeps the old free-text reader.
BRIEF_MARKER = f"Verdict format: {FORMAT}"
BRIEF_MARKER_RE = re.compile(r"^Verdict format: (verdict/\d+)\s*$", re.M)
BEGIN, END = "===VERDICT===", "===END==="

OUTCOMES = ("green", "amber", "red", "escalate", "not-evaluated")
GREEN = "green"
HEADER_KEYS = ("format", "task", "reviewer", "round", "vote", "failed")
CRITERION_LABELS = ("Vote", "Evidence", "Location", "Rule", "Conclusion", "Guidance")
REQUIRED_LABELS = ("Vote", "Evidence", "Location", "Rule", "Conclusion")
COUNTER_LABELS = ("Searched", "Found")
VOTE = "vote"   # key in `problems` for faults of the whole vote

_ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b\][^\x07]*\x07")
_SECTION_RE = re.compile(r"^##[ \t]+(.+?)[ \t]*$")
_AC_RE = re.compile(r"^AC[ \t]*#?(\d+)\b[ \t]*(.*)$", re.I)
_LABEL_RE = re.compile(r"^([A-Za-z][A-Za-z-]*)[ \t]*:[ \t]*(.*)$")
_QUOTE_RE = re.compile(r'^(?:"(.+)"|“(.+)”|„(.+)[“”"])$', re.S)
_REGION = r"region[ \t]+\d+[ \t]*,[ \t]*\d+[ \t]*,[ \t]*\d+[ \t]*,[ \t]*\d+"
_SELECTOR = r"selector[ \t]+\S.*"
_IMG_REF_RE = re.compile(rf"^(\S+)[ \t]+(?:{_REGION}|{_SELECTOR})[ \t]*$", re.S)
_IMG_EVIDENCE_RE = re.compile(rf"^image:[ \t]*(\S+)[ \t]+(?:{_REGION}|{_SELECTOR})[ \t]*$", re.S)
_FILE_LINE_RE = re.compile(r"^\S+:\d+(?:-\d+)?$")
_COMMAND_RE = re.compile(r"^command:[ \t]*\S.*$", re.S)
_FAILED_RE = re.compile(r"^\[\s*((?:AC\s*#?)?\d+(?:\s*,\s*(?:AC\s*#?)?\d+)*)?\s*\]$|^none$", re.I)


def brief_format(brief: str) -> str:
    """The verdict format a brief asked for ('' for a brief that predates verdict/1)."""
    m = BRIEF_MARKER_RE.search(brief or "")
    return m.group(1) if m else ""


_ATTEMPT_RE = re.compile(r"^[ \t>*#-]*(?:===VERDICT===|##[ \t]+AC[ \t]*#?\d|VERDICT[ \t]*:|vote[ \t]*:)",
                         re.M | re.I)


def attempted(text: str) -> bool:
    """True when `text` shows an attempt at a vote — a vote block, a criterion section, or a
    `VERDICT:`/`vote:` line — malformed or not. A seat whose output holds none of these (empty,
    a provider error) gave no vote at all, which is not the same as a refused one."""
    return bool(_ATTEMPT_RE.search(_clean(text)))


def _clean(text: str) -> str:
    return _ANSI_RE.sub("", text or "").replace("\r", "").replace("**", "")


def _blocks(text: str) -> list[str]:
    lines = _clean(text).split("\n")
    out, cur = [], None
    for ln in lines:
        s = ln.strip().strip("`").strip()
        if s == BEGIN:
            cur = []                 # a second BEGIN before END restarts: counted as one block
            continue
        if s == END and cur is not None:
            out.append("\n".join(cur))
            cur = None
            continue
        if cur is not None:
            cur.append(ln)
    return out


def _labels(lines: list[str]) -> tuple[dict[str, list[str]], list[str]]:
    """{label: [values]} from `Label: value` lines with indented continuations; plus stray lines
    (text that is neither a label nor a continuation)."""
    got: dict[str, list[str]] = {}
    stray: list[str] = []
    last: tuple[str, int] | None = None
    for ln in lines:
        if not ln.strip():
            last = None
            continue
        if ln[:1] in (" ", "\t") and last is not None:
            k, i = last
            got[k][i] = (got[k][i] + "\n" + ln.strip()).strip()
            continue
        m = _LABEL_RE.match(ln.strip().lstrip("-* ").strip())
        if m:
            k = m.group(1)
            got.setdefault(k, []).append(m.group(2).strip())
            last = (k, len(got[k]) - 1)
        else:
            stray.append(ln.strip())
            last = None
    return got, stray


def _evidence_ok(v: str) -> bool:
    return bool(_QUOTE_RE.match(v) or _IMG_EVIDENCE_RE.match(v))


def _location_ok(v: str) -> bool:
    return bool(_FILE_LINE_RE.match(v) or _IMG_REF_RE.match(v) or _COMMAND_RE.match(v))


def _ints(s: str) -> list[int]:
    return [int(x) for x in re.findall(r"\d+", s or "")]


def parse_vote(text: str, *, task: str = "", expected_acs=None) -> tuple[dict, dict]:
    """Read ONE verdict/1 vote from `text`, strictly. Returns (parsed, problems).

    parsed:   {"format", "header": {...}, "criteria": {ac: {...}}, "counter_search": {...},
               "change_my_mind": str}
    problems: {VOTE: [faults of the whole vote], ac: [faults of that criterion]}; only
              non-empty lists are present. A fault of the whole vote means no criterion of it
              counts; a criterion fault means only that criterion gets no verdict.

    `expected_acs` (Human AC numbers the brief named): each must have a section; a section for
    another criterion is a fault of the whole vote. Use `accepted` for what may be recorded."""
    problems: dict = {}

    def vote_fault(msg: str) -> None:
        problems.setdefault(VOTE, []).append(msg)

    def crit_fault(ac: int, msg: str) -> None:
        problems.setdefault(ac, []).append(msg)

    parsed: dict = {"format": FORMAT, "header": {}, "criteria": {}, "counter_search": {},
                    "change_my_mind": ""}
    blocks = _blocks(text)
    if not blocks:
        vote_fault(f"no {BEGIN} … {END} block: free text is not a {FORMAT} vote")
        for ac in expected_acs or ():
            crit_fault(int(ac), f"no {FORMAT} vote")
        return parsed, problems
    if len(blocks) > 1:
        vote_fault(f"{len(blocks)} {BEGIN} blocks: exactly one vote is read, so none is")
        return parsed, problems

    # split the block into the header and its `## ` sections
    head: list[str] = []
    sections: list[tuple[str, list[str]]] = []
    for ln in blocks[0].split("\n"):
        m = _SECTION_RE.match(ln.strip())
        if m:
            sections.append((m.group(1), []))
        elif sections:
            sections[-1][1].append(ln)
        elif ln.strip() not in ("---", "```", "```yaml", "```text"):
            head.append(ln)

    hl, stray = _labels(head)
    header = {k.lower(): v for k, v in hl.items()}
    for k in HEADER_KEYS:
        vals = header.get(k) or []
        if not vals or not vals[0].strip():
            vote_fault(f"header field `{k}` is missing or empty")
        elif len(vals) > 1:
            vote_fault(f"header field `{k}` is given {len(vals)} times")
    extra = sorted(set(header) - set(HEADER_KEYS))
    if extra:
        vote_fault(f"header has unknown field(s) {', '.join(extra)}")
    if stray:
        vote_fault(f"header has text that is not a `field: value` line: {stray[0][:80]!r}")
    h = {k: (header.get(k) or [""])[0].strip() for k in HEADER_KEYS}
    if h["format"] and h["format"] != FORMAT:
        vote_fault(f"header format {h['format']!r} is not {FORMAT!r}")
    if h["task"] and task and h["task"] != task:
        vote_fault(f"header task {h['task']!r} is not the task under review ({task})")
    if h["round"] and not re.fullmatch(r"[1-9]\d*", h["round"]):
        vote_fault(f"header round {h['round']!r} is not a positive whole number")
    overall = h["vote"].lower()
    if h["vote"] and overall not in OUTCOMES:
        vote_fault(f"overall vote {h['vote']!r} is not one of {', '.join(OUTCOMES)}")
    failed_ok = bool(_FAILED_RE.match(h["failed"])) if h["failed"] else False
    if h["failed"] and not failed_ok:
        vote_fault(f"header failed {h['failed']!r} is not a list of criterion numbers, e.g. [2, 3] or []")
    failed = sorted(set(_ints(h["failed"]))) if failed_ok else []
    parsed["header"] = {**h, "vote": overall, "failed": failed}

    seen_counter = seen_change = False
    for title, body in sections:
        am = _AC_RE.match(title)
        low = title.strip().lower().replace(" ", "-")
        if am:
            ac = int(am.group(1))
            if ac in parsed["criteria"]:
                vote_fault(f"criterion AC{ac} has more than one section")
                continue
            got, junk = _labels(body)
            c: dict = {"short": am.group(2).strip()}
            unknown = sorted(set(got) - set(CRITERION_LABELS))
            if unknown:
                crit_fault(ac, f"unknown label(s) {', '.join(unknown)}")
            if junk:
                crit_fault(ac, f"text that is not a `Label: value` line: {junk[0][:80]!r}")
            for lab in REQUIRED_LABELS:
                vals = [v for v in got.get(lab, []) if v.strip()]
                if not vals:
                    crit_fault(ac, f"label `{lab}` is missing or empty")
            for lab in ("Vote", "Rule", "Conclusion", "Guidance"):
                if len(got.get(lab, [])) > 1:
                    crit_fault(ac, f"label `{lab}` is given {len(got[lab])} times")
            vote = ((got.get("Vote") or [""])[0]).strip().lower()
            if vote and vote not in OUTCOMES:
                crit_fault(ac, f"vote {vote!r} is not one of {', '.join(OUTCOMES)}")
            ev, loc = got.get("Evidence", []), got.get("Location", [])
            if ev and loc and len(ev) != len(loc):
                crit_fault(ac, f"{len(ev)} Evidence but {len(loc)} Location: they come in pairs")
            for v in ev:
                if v.strip() and not _evidence_ok(v.strip()):
                    crit_fault(ac, f"Evidence {v[:60]!r} is neither a \"verbatim quote\" nor "
                                   "`image: <file> region x,y,w,h` / `image: <file> selector <css>`")
            for v in loc:
                if v.strip() and not _location_ok(v.strip()):
                    crit_fault(ac, f"Location {v[:60]!r} is not `<path>:<line>`, `<image> region "
                                   "x,y,w,h`, `<image> selector <css>` or `command: <cmd>`")
            guidance = ((got.get("Guidance") or [""])[0]).strip()
            if vote in OUTCOMES and vote != GREEN and not guidance:
                crit_fault(ac, f"a {vote} vote needs `Guidance:` (what is needed next)")
            c.update(vote=vote, evidence=ev, location=loc,
                     rule=((got.get("Rule") or [""])[0]).strip(),
                     conclusion=((got.get("Conclusion") or [""])[0]).strip(), guidance=guidance,
                     text="\n".join([f"## {title}"] + body).strip())
            parsed["criteria"][ac] = c
        elif low == "counter-search":
            if seen_counter:
                vote_fault("`## Counter-search` is given twice")
            seen_counter = True
            got, junk = _labels(body)
            for lab in COUNTER_LABELS:
                if not [v for v in got.get(lab, []) if v.strip()]:
                    vote_fault(f"Counter-search label `{lab}` is missing or empty")
            if junk or set(got) - set(COUNTER_LABELS):
                vote_fault("Counter-search holds something other than `Searched:` and `Found:`")
            parsed["counter_search"] = {k.lower(): "\n".join(got.get(k, [])) for k in COUNTER_LABELS}
        elif low == "change-my-mind":
            if seen_change:
                vote_fault("`## Change-my-mind` is given twice")
            seen_change = True
            txt = "\n".join(ln.rstrip() for ln in body).strip()
            if not txt:
                vote_fault("`## Change-my-mind` is empty: name what would change this vote")
            parsed["change_my_mind"] = txt
        else:
            vote_fault(f"unknown section `## {title[:60]}`")
    if not seen_counter:
        vote_fault("section `## Counter-search` is missing")
    if not seen_change:
        vote_fault("section `## Change-my-mind` is missing")
    if not parsed["criteria"]:
        vote_fault("no `## AC<N>` criterion section")

    crits = parsed["criteria"]
    if expected_acs is not None:
        exp = {int(a) for a in expected_acs}
        for ac in sorted(exp - set(crits)):
            crit_fault(ac, f"no `## AC{ac}` section in the vote")
        other = sorted(set(crits) - exp)
        if other:
            vote_fault(f"section(s) for criteria the brief did not name: "
                       f"{', '.join(f'AC{a}' for a in other)}")

    # Consistency — only meaningful when every criterion vote could be read.
    votes = {ac: c["vote"] for ac, c in crits.items()}
    unreadable = [ac for ac, v in votes.items() if v not in OUTCOMES]
    if unreadable:
        vote_fault("overall vote cannot be checked: no readable vote for "
                   + ", ".join(f"AC{a}" for a in unreadable))
    elif crits and overall in OUTCOMES and failed_ok:
        nongreen = sorted(ac for ac, v in votes.items() if v != GREEN)
        if (overall == GREEN) != (not nongreen):
            vote_fault(f"overall vote {overall} disagrees with the criterion votes "
                       f"({', '.join(f'AC{a} {v}' for a, v in sorted(votes.items()))})")
        elif nongreen and overall not in {votes[a] for a in nongreen}:
            vote_fault(f"overall vote {overall} is none of the non-green criterion votes")
        if failed != nongreen:
            vote_fault(f"failed {failed} does not name exactly the non-green criteria {nongreen}")
    return parsed, {k: v for k, v in problems.items() if v}


def accepted(parsed: dict, problems: dict) -> dict[int, dict]:
    """{ac: record structure} for every criterion that may be recorded: none when the vote as a
    whole has a fault, else every criterion without one. The structure is what a ledger row
    carries in its `structured` field."""
    if problems.get(VOTE):
        return {}
    return {ac: structure(parsed, ac) for ac in parsed.get("criteria", {}) if not problems.get(ac)}


def structure(parsed: dict, ac: int) -> dict:
    c = dict(parsed["criteria"][ac])
    c.pop("text", None)
    return {"format": FORMAT, "header": parsed["header"], "ac": ac, "criterion": c,
            "counter_search": parsed["counter_search"],
            "change_my_mind": parsed["change_my_mind"]}


def problem_text(problems: dict, ac: int | None = None) -> str:
    """The faults that keep criterion `ac` (or the whole vote) from counting, one line each."""
    lines = [f"- vote: {p}" for p in problems.get(VOTE, [])]
    if ac is not None:
        lines += [f"- AC{ac}: {p}" for p in problems.get(ac, [])]
    return "\n".join(lines)


def brief_lines(task_id: str, acs: list[int], *, printed: bool) -> list[str]:
    """The brief's instructions for verdict/1, with a filled pass and a filled fail.
    `printed`: the vote is printed (harness seats) rather than written into each AC report."""
    ac_a = acs[0] if acs else 1
    ac_b = acs[1] if len(acs) > 1 else ac_a + 1
    where = ("Print your vote as ONE block, exactly in this form, covering EVERY criterion above"
             if printed else
             "Each evidence report `AC<N>-$FW_SIDECAR_AGENT_ID.md` holds ONE vote block, exactly "
             "in this form, with the section for that criterion (`## AC<N>`); free notes may "
             f"follow after `{END}`")
    return [
        "## Vote format (verdict/1 — required, pass and fail alike)",
        "",
        BRIEF_MARKER,
        "",
        f"{where}. It is read strictly: a missing or empty label, a vote outside "
        f"{' | '.join(OUTCOMES)}, an overall vote or `failed` list that disagrees with the "
        "criterion votes, or prose without this structure gives NO verdict for that criterion "
        "(the reason is written into its evidence report). Nothing is guessed.",
        "",
        "Rules:",
        "- `## AC<N>` uses the Human AC number (the `Human AC#N` in the criterion heading).",
        "- A green needs evidence exactly as much as a red: every criterion section has Vote, "
        "Evidence, Location, Rule and Conclusion. A vote that is not green also has Guidance.",
        "- Evidence is a verbatim quote in double quotes (copied, not paraphrased), or for an "
        "image `image: <file> region x,y,w,h` (pixels: left, top, width, height) or "
        "`image: <file> selector <css>`.",
        "- Location says where that evidence is: `<path>:<line>` (or `<path>:<from>-<to>`), "
        "`<image file> region x,y,w,h`, `<image file> selector <css>`, or `command: <cmd>` "
        "for a quote of a command's output. Evidence and Location come in pairs and may repeat.",
        "- Rule is the requirement you applied (the criterion's clause, quoted or named); "
        "Conclusion is ONE sentence joining the evidence to the rule.",
        "- Overall `vote` is green only when every criterion is green; otherwise it is one of the "
        "non-green criterion votes. `failed` lists exactly the criteria not voted green "
        "(`[]` when none).",
        "- Counter-search: where you looked for evidence AGAINST your vote, and what you found. "
        "Change-my-mind: the concrete observation that would change it (not \"more evidence\").",
        "- A label's value may continue on following lines indented by spaces.",
        "",
        "A filled example (one pass, one fail):",
        "```",
        BEGIN,
        f"format: {FORMAT}",
        f"task: {task_id}",
        "reviewer: <your reviewer identity or seat>",
        "round: 1",
        "vote: red",
        f"failed: [{ac_b}]",
        "",
        f"## AC{ac_a} Brief asks for the structured vote",
        "Vote: green",
        "Evidence: \"Vote format (verdict/1 — required, pass and fail alike)\"",
        "Location: lib/reviewer/judge_cli.py:912",
        "Rule: criterion: \"The brief ... asks for the structured vote\"",
        "Conclusion: The brief's own heading at that line asks for the structure, so the "
        "clause holds.",
        "",
        f"## AC{ac_b} Settings icon visible at 1280 px",
        "Vote: red",
        "Evidence: image: .context/working/judge-evidence/T-1/02-page.png region 895,45,65,25",
        "Location: .context/working/judge-evidence/T-1/02-page.png region 895,45,65,25",
        "Evidence: \"display: none\"",
        "Location: web/static/css/header.css:88",
        "Rule: criterion: \"the settings icon is visible at every width\"",
        "Conclusion: The icon zone is empty in the 1280 px capture and the rule at "
        "header.css:88 hides it, so the icon is not visible at that width.",
        "Guidance: Remove the display:none at header.css:88 for widths >= 1024 px and re-capture.",
        "",
        "## Counter-search",
        "Searched: the 1440 and 1920 px captures and every media query in header.css for a rule "
        "that shows the icon at 1280 px",
        "Found: the icon is present at 1440 and 1920 px; no rule shows it below 1440 px",
        "",
        "## Change-my-mind",
        "A 1280 px capture in which the region 895,45,65,25 shows the settings icon.",
        END,
        "```",
        "",
    ]


def example_vote(task: str, votes: dict, *, reviewer: str = "reviewer", why: str = "checked it",
                 guidance: str = "needs work") -> str:
    """A well-formed verdict/1 vote for `votes` ({Human AC number: outcome}). For fixtures and
    stand-in workers; its evidence is a placeholder quote, not a real check. It cites command
    output (`command:`), which the checker reports "not checkable" without failing the vote
    (T-5294): a placeholder citing a file line that does not exist would make every fixture vote
    not count."""
    nongreen = sorted(int(a) for a, v in votes.items() if v != GREEN)
    overall = votes[nongreen[0]] if nongreen else GREEN
    out = [BEGIN, f"format: {FORMAT}", f"task: {task}", f"reviewer: {reviewer}", "round: 1",
           f"vote: {overall}", f"failed: [{', '.join(map(str, nongreen))}]", ""]
    for ac, v in sorted((int(a), v) for a, v in votes.items()):
        out += [f"## AC{ac} criterion", f"Vote: {v}", f'Evidence: "{why}"',
                "Location: command: git log -1 --stat", "Rule: the criterion as written", f"Conclusion: {why}."]
        if v != GREEN:
            out.append(f"Guidance: {guidance}")
        out.append("")
    out += ["## Counter-search", "Searched: the task's diff", "Found: nothing against the vote", "",
            "## Change-my-mind", "A failing check of the criterion.", END, ""]
    return "\n".join(out)
