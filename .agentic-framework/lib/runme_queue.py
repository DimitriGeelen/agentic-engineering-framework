#!/usr/bin/env python3
"""lib/runme_queue.py — the runme job queue (T-4491, slice 1 of the T-4470 GO).

The operator types ONE fixed command, `bin/fw runme queue`, and sees the pending jobs.
The agent writes jobs; it never writes the code that asks the operator anything.

A JOB is DATA: .context/runme/jobs/<NNN>-<name>/job.json, read with json.loads and
nothing else. It is never sourced, so job text cannot reach the launcher's prompts
(T-4470 review finding 1) and loading it runs nothing (finding 2):

    {"title": "Upgrade AEF to 1.8.2", "task": "T-1049",
     "why": "one or more lines the operator reads first",
     "helpers": {"commit_closed": "git commit -m \\"$1\\" -- .tasks"},
     "scripts": ["tools/upgrade-helper.sh"],
     "steps": [{"title": "Readiness", "argv": ["bin/fw", "task", "review", "T-1"],
                "probe": ["bin/fw", "task", "review", "T-1"]},
               {"title": "Commit", "sh": "commit_closed 'T-1: close'"}]}

  argv  runs with no shell; what is shown is exactly what runs.
  sh    runs as `bash -c <helpers + text>` in a child; the whole script is shown.
  probe a read-only readiness check (the target command's own, where one exists —
        832 addendum §3). Never run by dry-run (finding 3); the operator is asked
        before probes run and sees their result before the job is confirmed.
  scripts files the steps reach that no step names (a file a script sources); bound
        like the rest. Missing at dry-run is refused.
Unknown keys are refused, so a "preflight"/"checks" block cannot creep back in.

THE SHA MANIFEST (T-4492, slice 2; review finding 5). Dry-run records, per step, the
sha of every file that step reaches: each argv / sh / helper / probe word that names an
existing file, the resolved executable of each command word, and the declared scripts.
job.json's own sha is kept beside it. The whole manifest decides the menu state, and the
job's sha plus the step's files are checked again immediately before each probe and each
step: a changed, removed or newly named file stops the job there. A step that edits a
file a later step calls therefore stops that later step (re-rehearse). Not covered: a
file named only at run time (computed paths, $VAR), the environment, and same-user
edits to the manifest itself (same residual as slice 1).

  fw runme job new <name> (--manifest FILE | --title T [--task T-X] [--why W] -- <sh> ...)
  fw runme job dry-run <name>   validate + show the resolved plan + record its sha. Runs nothing.
  fw runme job list [--all]     the menu: state (NOT REHEARSED / ready / CHANGED) and last outcome
  fw runme job retire <name> --reason R   out of the queue without claiming it ran
  fw runme queue                the operator's command

What the queue does NOT do (finding 5 of the review; T-4470 §7.5): it is never an
authorisation. Each step's resolved text is handed to check-tier0.sh exactly as a typed
command would be, and a Tier 0 step stops there until approved at its own gate.
Answers come from /dev/tty only; FW_RUNME_TEST_ANSWERS needs FW_RUNME_TEST=1 and a
project root that is not a real framework project (finding 6). Same-user residual: an
agent that drives a pty of its own can still answer; the queue does not claim otherwise.

Each step is confirmed on its own (y/N, typeahead discarded) just before it runs, and
the confirm comes before check-tier0, never instead of it. Slice 3 (ordered batches) is
a separate task. Exit: 0 done / nothing to do, 1 stopped or refused, 2 usage.
"""
import argparse
import datetime
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys

FRAMEWORK_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOP_KEYS = {"title", "task", "why", "helpers", "scripts", "steps"}
STEP_KEYS = {"title", "argv", "sh", "probe"}
NAME_RE = re.compile(r"^[A-Za-z0-9._][A-Za-z0-9._-]*$")
HELPER_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
# C0 controls other than tab/newline, DEL and C1: an ESC in a title could repaint the
# operator's screen and hide the command they are about to confirm.
CTRL_RE = re.compile(r"[\x00-\x08\x0b-\x1f\x7f-\x9f]")
REAL_PROJECT_MARKERS = (".framework.yaml", "FRAMEWORK.md", ".tasks", ".agentic-framework")


class Refused(Exception):
    pass


def root():
    return os.environ.get("PROJECT_ROOT") or os.getcwd()


def jobs_dir():
    return os.path.join(root(), ".context", "runme", "jobs")


def now():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# ---------------------------------------------------------------- manifest (data only)
def _text(v, where, multiline=False):
    if not isinstance(v, str) or not v.strip():
        raise Refused(f"{where} must be a non-empty string")
    if CTRL_RE.search(v) or (not multiline and "\n" in v):
        raise Refused(f"{where} contains a control character{'' if multiline else ' or newline'}")
    return v


def _argv(v, where):
    if not isinstance(v, list) or not v or not all(isinstance(a, str) for a in v):
        raise Refused(f"{where} must be a non-empty list of strings")
    for a in v:
        if CTRL_RE.search(a):
            raise Refused(f"{where} contains a control character")
    return v


def validate(m):
    if not isinstance(m, dict):
        raise Refused("job.json must be a JSON object")
    extra = set(m) - TOP_KEYS
    if extra:
        raise Refused(f"unknown key(s) {sorted(extra)}; a job has only {sorted(TOP_KEYS)} "
                      "(no preflight/checks: readiness checks are per-step 'probe' argv, shown and consented)")
    _text(m.get("title"), "title")
    if m.get("task") is not None and not re.fullmatch(r"T-\d+", str(m["task"])):
        raise Refused("task must look like T-123")
    if m.get("why") is not None:
        _text(m["why"], "why", multiline=True)
    helpers = m.get("helpers") or {}
    if not isinstance(helpers, dict):
        raise Refused("helpers must be an object of name -> bash body")
    for k, body in helpers.items():
        if not HELPER_RE.match(k):
            raise Refused(f"helper name {k!r} is not a shell identifier")
        _text(body, f"helper {k}", multiline=True)
    scripts = m.get("scripts", [])
    if not isinstance(scripts, list):
        raise Refused("scripts must be a list of file paths")
    for x in scripts:
        _text(x, "scripts entry")
    steps = m.get("steps")
    if not isinstance(steps, list) or not steps:
        raise Refused("steps must be a non-empty list")
    for i, s in enumerate(steps, 1):
        if not isinstance(s, dict):
            raise Refused(f"step {i} must be an object")
        extra = set(s) - STEP_KEYS
        if extra:
            raise Refused(f"step {i}: unknown key(s) {sorted(extra)}; a step has {sorted(STEP_KEYS)}")
        _text(s.get("title"), f"step {i} title")
        if ("argv" in s) == ("sh" in s):
            raise Refused(f"step {i} needs exactly one of argv or sh")
        if "argv" in s:
            _argv(s["argv"], f"step {i} argv")
        else:
            _text(s["sh"], f"step {i} sh", multiline=True)
        if "probe" in s:
            _argv(s["probe"], f"step {i} probe")
    return m


def load(d):
    """(manifest, sha) from ONE read of job.json, so what is hashed is what is parsed."""
    path = os.path.join(d, "job.json")
    try:
        raw = open(path, "rb").read()
    except OSError:
        raise Refused(f"{os.path.basename(d)}: no job.json")
    try:
        m = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as e:
        raise Refused(f"{os.path.basename(d)}/job.json does not parse: {e}")
    return validate(m), hashlib.sha256(raw).hexdigest()


def script_for(m, s):
    """The exact program a step runs: argv list, or bash -c text with helper bodies."""
    if "argv" in s:
        return list(s["argv"]), shlex.join(s["argv"])
    defs = "".join(f"{k}() {{\n{b}\n}}\n" for k, b in (m.get("helpers") or {}).items())
    text = defs + s["sh"]
    return ["bash", "--norc", "--noprofile", "-c", text], text


# ---------------------------------------------------------------- sha manifest (T-4492)
CMD_SEP = {";", "&&", "||", "|", "&", "(", ")", "{", "}", "!", "then", "do", "else", "elif",
           "if", "while", "until", "time", "exec", "command", "xargs", "env", "sudo", "nohup"}
REDIR_OUT = {">", ">>", ">|", "&>", "&>>"}
_BUILTINS = None


def builtins():
    """bash builtins and keywords (a fixed command; no job text runs)."""
    global _BUILTINS
    if _BUILTINS is None:
        p = subprocess.run(["bash", "--norc", "--noprofile", "-c", "compgen -bk"],
                           capture_output=True, text=True)
        _BUILTINS = set(p.stdout.split())
    return _BUILTINS


def sh_words(text):
    """(command words, other words) of a bash text, read statically. Never executed."""
    cmds, words = [], []
    for line in text.splitlines():
        lx = shlex.shlex(line, posix=True, punctuation_chars=True)
        lx.whitespace_split = True
        lx.commenters = "#"
        try:
            toks = list(lx)
        except ValueError:
            toks = line.split()
        at_cmd, after_redir = True, False
        for t in toks:
            if after_redir:                      # an output target is written, not called
                after_redir = False
                continue
            if t in REDIR_OUT:
                after_redir = True
                continue
            if t in CMD_SEP or set(t) <= set(";&|()<>"):
                at_cmd = True
                continue
            if at_cmd and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", t):
                continue
            (cmds if at_cmd else words).append(t)
            at_cmd = False
    return cmds, words


def _resolve(word, as_cmd, skip):
    if not word or word in skip:
        return None
    if "/" not in word and as_cmd:
        if word in builtins():
            return None
        hit = shutil.which(word, path=child_env().get("PATH", os.defpath))
        return os.path.realpath(hit) if hit else None
    path = word if os.path.isabs(word) else os.path.join(root(), word)
    return os.path.realpath(path) if os.path.isfile(path) else None


def file_sha(path):
    h = hashlib.sha256()
    try:
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(1 << 20), b""):
                h.update(chunk)
    except OSError:
        return "UNREADABLE"
    return h.hexdigest()


def step_files(m, s):
    """{realpath: sha} of every file step s (command, probe, helpers, declared scripts) reaches."""
    helpers = m.get("helpers") or {}
    pairs = []                                   # (word, is a command word)
    for argv in (s.get("argv"), s.get("probe")):
        if argv:
            pairs += [(argv[0], True)] + [(w, False) for w in argv[1:]]
    if "sh" in s:
        for text in [s["sh"]] + list(helpers.values()):
            c, w = sh_words(text)
            pairs += [(x, True) for x in c] + [(x, False) for x in w]
    out = {}
    for word, as_cmd in pairs:
        p = _resolve(word, as_cmd, helpers)
        if p:
            out[p] = file_sha(p)
    for x in m.get("scripts", []):
        p = os.path.realpath(x if os.path.isabs(x) else os.path.join(root(), x))
        out[p] = file_sha(p) if os.path.isfile(p) else "MISSING"
    return out


def manifest_of(m, sha):
    return {"job": sha, "steps": [step_files(m, s) for s in m["steps"]]}


def show_path(p):
    r = os.path.realpath(root())
    return os.path.relpath(p, r) if p.startswith(r + os.sep) else p


def drift(recorded, current):
    """What differs between two {path: sha} maps, readably; [] when equal."""
    out = []
    for p in sorted(set(recorded) | set(current)):
        a, b = recorded.get(p), current.get(p)
        if a != b:
            out.append(f"{show_path(p)} " + ("is newly named" if a is None
                                           else "is gone" if b in (None, "MISSING") else "changed"))
    return out


def recorded_manifest(d):
    """The manifest dry-run wrote, or None when absent or not the one dryrun.ok names."""
    try:
        raw = open(os.path.join(d, "dryrun.manifest.json"), "rb").read()
    except OSError:
        return None
    if kv(os.path.join(d, "dryrun.ok")).get("manifest") != hashlib.sha256(raw).hexdigest():
        return None
    try:
        return json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, ValueError):
        return None


def recheck(d, m, i):
    """Just before probe/step i (1-based): are job.json and the step's files as rehearsed? [] = yes."""
    rec = recorded_manifest(d)
    if rec is None:
        return ["the dry-run manifest is missing or altered"]
    try:
        raw = open(os.path.join(d, "job.json"), "rb").read()
    except OSError:
        return ["job.json is gone"]
    if hashlib.sha256(raw).hexdigest() != rec.get("job"):
        return ["job.json changed"]
    steps = rec.get("steps") or []
    if len(steps) != len(m["steps"]):
        return ["the step list changed"]
    return drift(steps[i - 1], step_files(m, m["steps"][i - 1]))


def plan_text(name, m):
    out = [f"Job:   {name}" + (f"   ({m['task']})" if m.get("task") else ""), f"What:  {m['title']}"]
    if m.get("why"):
        out += ["       " + ln for ln in m["why"].splitlines()]
    out.append(f"Steps ({len(m['steps'])}); each line under 'runs' is exactly what the child process executes:")
    for i, s in enumerate(m["steps"], 1):
        _, text = script_for(m, s)
        kind = "argv, no shell" if "argv" in s else "bash -c, expands at run time"
        out.append(f"  {i}. {s['title']}")
        out.append(f"     runs ({kind}):")
        out += ["       | " + ln for ln in text.splitlines()]
        if "probe" in s:
            out.append(f"     readiness probe (read-only, asked before it runs): {shlex.join(s['probe'])}")
        files = step_files(m, s)
        if files:
            out.append("     sha-bound files (rechecked just before this step): "
                       + ", ".join(show_path(p) for p in sorted(files)))
    return "\n".join(out)


# ---------------------------------------------------------------- lifecycle
def all_jobs():
    d = jobs_dir()
    if not os.path.isdir(d):
        return []
    return sorted(os.path.join(d, n) for n in os.listdir(d)
                  if os.path.isdir(os.path.join(d, n)) and not n.startswith("."))


def pending():
    return [d for d in all_jobs() if os.path.isfile(os.path.join(d, "job.json"))
            and not os.path.exists(os.path.join(d, "done"))
            and not os.path.exists(os.path.join(d, "retired"))]


def kv(path):
    out = {}
    try:
        for ln in open(path, encoding="utf-8"):
            k, _, v = ln.rstrip("\n").partition("=")
            out[k] = v
    except OSError:
        pass
    return out


def find(name):
    hits = [d for d in all_jobs() if os.path.basename(d) == name]
    hits = hits or [d for d in all_jobs() if os.path.basename(d).split("-", 1)[-1] == name]
    if len(hits) != 1:
        raise Refused(f"no single job named {name!r}" + (f" ({len(hits)} match)" if hits else ""))
    return hits[0]


def state(d):
    ok = os.path.join(d, "dryrun.ok")
    if not os.path.exists(ok):
        return "NOT REHEARSED"
    try:
        raw = open(os.path.join(d, "job.json"), "rb").read()
    except OSError:
        return "NO job.json"
    if kv(ok).get("sha") != hashlib.sha256(raw).hexdigest():
        return "CHANGED since dry-run"
    rec = recorded_manifest(d)
    if rec is None:
        return "NOT REHEARSED (no file manifest)"
    try:
        m = validate(json.loads(raw.decode("utf-8")))
    except (Refused, UnicodeDecodeError, ValueError):
        return "CHANGED since dry-run"
    return "ready" if rec == manifest_of(m, rec.get("job")) else "CHANGED since dry-run"


def changed_files(d):
    """Which files make a CHANGED job changed (named in the operator's stop message)."""
    rec = recorded_manifest(d)
    try:
        m, _ = load(d)
    except Refused:
        return []
    if rec is None or len(rec.get("steps") or []) != len(m["steps"]):
        return []
    out = []
    for i, s in enumerate(m["steps"]):
        out += [x for x in drift(rec["steps"][i], step_files(m, s)) if x not in out]
    return out


def last_outcome(d):
    logs = sorted(f for f in os.listdir(d) if f.startswith("run-") and f.endswith(".log"))
    if not logs:
        return "never run"
    when = logs[-1][4:-4]
    for ln in reversed(open(os.path.join(d, logs[-1]), encoding="utf-8", errors="replace").read().splitlines()):
        if ln.startswith("DONE: "):
            return f"completed {when}"
        if ln.startswith("STOPPED: "):
            return f"STOPPED {when}: {ln[9:]}"
    return f"no outcome recorded {when} (interrupted?)"


def title_of(d):
    try:
        t = json.loads(open(os.path.join(d, "job.json"), encoding="utf-8").read()).get("title")
        return t if isinstance(t, str) and not CTRL_RE.search(t) else ""
    except (OSError, ValueError, AttributeError):
        return ""


def job_line(d):
    t = title_of(d)
    return f"{os.path.basename(d)}{' — ' + t if t else ''}  [{state(d)}; last: {last_outcome(d)}]"


def event(name, ev, step="", rc=""):
    path = os.path.join(root(), ".context", "runme", "events.jsonl")
    try:
        with open(path, "a", encoding="utf-8") as f:
            f.write(json.dumps({"name": name, "event": ev, "step": step, "rc": str(rc),
                                "signal": "", "ts": now(), "source": "queue"}) + "\n")
    except OSError:
        pass


# ---------------------------------------------------------------- agent verbs
def cmd_new(a):
    if not NAME_RE.match(a.name):
        raise Refused("name must match [A-Za-z0-9._-]+")
    if a.manifest:
        raw = sys.stdin.read() if a.manifest == "-" else open(a.manifest, encoding="utf-8").read()
        try:
            m = json.loads(raw)
        except json.JSONDecodeError as e:
            raise Refused(f"manifest does not parse: {e}")
    else:
        if not a.title or not a.cmds:
            raise Refused("need --manifest FILE, or --title and at least one command after --")
        m = {"title": a.title, "steps": [{"title": c.splitlines()[0][:80] or "step", "sh": c} for c in a.cmds]}
        if a.task:
            m["task"] = a.task
        if a.why:
            m["why"] = a.why
    validate(m)
    os.makedirs(jobs_dir(), exist_ok=True)
    nums = [int(os.path.basename(d).split("-", 1)[0]) for d in all_jobs()
            if re.match(r"^\d+-", os.path.basename(d))]
    d = os.path.join(jobs_dir(), f"{(max(nums) + 1) if nums else 1:03d}-{a.name}")
    os.makedirs(d)
    with open(os.path.join(d, "job.json"), "w", encoding="utf-8") as f:
        json.dump(m, f, indent=1, ensure_ascii=False)
        f.write("\n")
    print(f"job {os.path.basename(d)} written (NOT REHEARSED). Next: bin/fw runme job dry-run {os.path.basename(d)}")
    return 0


def cmd_dry_run(a):
    d = find(a.name)
    name = os.path.basename(d)
    m, sha = load(d)
    man = manifest_of(m, sha)
    missing = sorted({show_path(p) for st in man["steps"] for p, h in st.items() if h == "MISSING"})
    if missing:
        raise Refused(f"declared script(s) not found: {', '.join(missing)}")
    print(f"== DRY RUN {name}")
    print(plan_text(name, m))
    raw = json.dumps(man, sort_keys=True, indent=1).encode("utf-8")
    mpath = os.path.join(d, "dryrun.manifest.json")
    if os.path.exists(mpath):
        os.chmod(mpath, 0o644)
    with open(mpath, "wb") as f:
        f.write(raw)
    os.chmod(mpath, 0o444)
    with open(os.path.join(d, "dryrun.ok"), "w", encoding="utf-8") as f:
        f.write(f"sha={sha}\nmanifest={hashlib.sha256(raw).hexdigest()}\nat={now()}\n")
    os.chmod(os.path.join(d, "job.json"), 0o444)
    nfiles = len({p for st in man["steps"] for p in st})
    print(f"dry-run recorded: job.json sha {sha[:12]} (now read-only) and a manifest of {nfiles} "
          "file(s) the steps reach, rechecked before each step. Nothing was executed "
          "(no step, no probe); the operator sees this same plan before confirming.")
    return 0


def cmd_list(a):
    ds = all_jobs() if a.all else pending()
    shown = 0
    for d in ds:
        if not os.path.isfile(os.path.join(d, "job.json")):
            continue
        shown += 1
        if os.path.exists(os.path.join(d, "retired")):
            reason = open(os.path.join(d, "retired"), encoding="utf-8").readline().strip()
            print(f"{os.path.basename(d)}  [RETIRED: {reason}]")
        elif os.path.exists(os.path.join(d, "done")):
            print(f"{os.path.basename(d)}  [done]")
        else:
            print(job_line(d))
    if not shown:
        print("no pending jobs")
    return 0


def cmd_retire(a):
    d = find(a.name)
    if not a.reason.strip():
        raise Refused("retire needs --reason")
    with open(os.path.join(d, "retired"), "w", encoding="utf-8") as f:
        f.write(a.reason.strip() + "\n")
    print(f"{os.path.basename(d)} retired: {a.reason.strip()}")
    return 0


# ---------------------------------------------------------------- the operator's run
def is_real_project(r):
    r = os.path.realpath(r)
    return r == os.path.realpath(FRAMEWORK_ROOT) or any(
        os.path.exists(os.path.join(r, p)) for p in REAL_PROJECT_MARKERS)


class Answers:
    """Answers come from the operator's terminal. A file of answers exists for the test
    runner only, and never where steps would run in a real project (finding 6)."""

    def __init__(self):
        test = os.environ.get("FW_RUNME_TEST") == "1"
        path = os.environ.get("FW_RUNME_TEST_ANSWERS")
        if path:
            if not test:
                raise Refused("FW_RUNME_TEST_ANSWERS is honoured only with FW_RUNME_TEST=1 (the test runner)")
            if is_real_project(root()):
                raise Refused(f"scripted answers are refused on a real project ({root()}); tests only")
            self.f, self.tty = open(path, encoding="utf-8"), False
            return
        if os.environ.get("CLAUDECODE") == "1" and not (test and not is_real_project(root())):
            raise Refused("the queue is the operator's command, run from their own terminal "
                          "(CLAUDECODE=1 here); hand over: bin/fw runme queue")
        try:
            self.f, self.tty = open("/dev/tty", "r", encoding="utf-8"), True
        except OSError:
            raise Refused("cannot read answers from /dev/tty (run this in a terminal)")

    def ask(self, prompt):
        if self.tty:
            try:
                import termios
                termios.tcflush(self.f.fileno(), termios.TCIFLUSH)   # discard typeahead
            except (ImportError, OSError):
                pass
        sys.stdout.write(prompt + " ")
        sys.stdout.flush()
        reply = self.f.readline().strip()
        if not self.tty:
            print(reply)
        return reply

    def confirm(self, prompt):
        return self.ask(prompt + " [y/N]") in ("y", "Y")


class Log:
    def __init__(self, d):
        self.path = os.path.join(d, f"run-{datetime.datetime.now().strftime('%Y%m%dT%H%M%S')}.log")
        self.f = open(self.path, "a", encoding="utf-8")

    def say(self, s=""):
        print(s, flush=True)
        self.f.write(s + "\n")
        self.f.flush()


def child_env():
    # No exported shell functions cross into a step, and no test switch leaks to a child.
    return {k: v for k, v in os.environ.items()
            if not k.startswith("BASH_FUNC_") and not k.startswith("FW_RUNME_TEST")}


def run_child(argv, log):
    p = subprocess.Popen(argv, cwd=root(), env=child_env(), stdin=subprocess.DEVNULL,
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, close_fds=True)
    for ln in p.stdout:
        log.say("  " + ln.decode("utf-8", "replace").rstrip("\n"))
    return p.wait()


def tier0_gate(name, i, text, log):
    """Hand the step to check-tier0.sh exactly as a typed command. 0 = pass, else stop."""
    hook = os.path.join(FRAMEWORK_ROOT, "agents", "context", "check-tier0.sh")
    payload = json.dumps({"tool_name": "Bash", "tool_use_id": f"runme-queue-{name}-{i}-{os.getpid()}",
                          "tool_input": {"command": text}})
    env = dict(os.environ, PROJECT_ROOT=root())
    r = subprocess.run(["bash", hook], input=payload.encode(), capture_output=True, env=env, cwd=root())
    if r.returncode == 0:
        return True
    for ln in r.stderr.decode("utf-8", "replace").splitlines():
        log.say("  " + ln)
    return False


def staged(r):
    """Staged paths in the git index, or [] (not a repo / clean)."""
    p = subprocess.run(["git", "-C", r, "diff", "--cached", "--name-only"], capture_output=True, text=True)
    return [x for x in p.stdout.splitlines() if x] if p.returncode == 0 else []


def staged_note():
    files = staged(root())
    if not files:
        return ""
    who = kv(os.path.join(jobs_dir(), ".staged-by")).get("job", "")
    return (f"NOTE: the git index has {len(files)} staged path(s) "
            f"({', '.join(files[:5])}{' …' if len(files) > 5 else ''})"
            + (f", left by job {who}" if who else ", not left by a queued job"))


def width():
    return max(20, shutil.get_terminal_size((80, 24)).columns)


def run_job(d, ans):
    name = os.path.basename(d)
    log = Log(d)
    event(name, "start")

    def stop(why):
        log.say(f"STOPPED: {why}")
        event(name, "exit", rc=1)
        after(name, log)
        return 1

    st = state(d)
    if st != "ready":
        what = changed_files(d) if st.startswith("CHANGED") else []
        if what:
            log.say("changed since dry-run: " + "; ".join(what))
        return stop(f"{name} is {st}; nothing run. The agent runs: bin/fw runme job dry-run {name}")
    m, sha = load(d)
    if kv(os.path.join(d, "dryrun.ok")).get("sha") != sha:
        return stop(f"{name} changed while loading; nothing run")
    log.say(f"runme queue  {name}   sha {sha[:12]}   rehearsed {kv(os.path.join(d, 'dryrun.ok')).get('at', '?')}")
    log.say(plan_text(name, m))
    note = staged_note()
    if note:
        log.say(note)
    probes = [(i, s) for i, s in enumerate(m["steps"], 1) if "probe" in s]
    if probes:
        if not ans.confirm(f"Run the {len(probes)} read-only readiness probe(s) shown above?"):
            return stop("probes not confirmed; nothing run")
        bad = 0
        for i, s in probes:
            moved = recheck(d, m, i)
            if moved:
                return stop(f"before the probe for step {i}: {'; '.join(moved)} since dry-run; nothing run")
            log.say(f"probe for step {i}: {shlex.join(s['probe'])}")
            rc = run_child(s["probe"], log)
            log.say(f"{'ok  ' if rc == 0 else 'FAIL'}  probe for step {i} (rc={rc})")
            bad |= rc != 0
        if bad:
            return stop("a readiness probe failed; the target command would refuse. Nothing run")
    n = len(m["steps"])
    for i, s in enumerate(m["steps"], 1):
        argv, text = script_for(m, s)
        later = "nothing run" if i == 1 else "later steps not run"
        moved = recheck(d, m, i)
        if moved:
            return stop(f"step {i}/{n}: {'; '.join(moved)} since dry-run; this step and {later}. "
                        f"The agent runs: bin/fw runme job dry-run {name}")
        log.say(f"Step {i}/{n}: {s['title']}")
        log.say("  runs:")
        for ln in text.splitlines():
            log.say("    | " + ln)
        # Per-step consent (T-4492): asked just before the step, typeahead discarded.
        # It is consent, not authorisation: check-tier0 still runs after it.
        if not ans.confirm(f"Run step {i}/{n} of {name} exactly as shown above?"):
            return stop("not confirmed; nothing run" if i == 1
                        else f"step {i}/{n} not confirmed; later steps not run")
        log.say(f"operator confirmed step {i}/{n}")
        moved = recheck(d, m, i)                 # the operator may have paused at the prompt
        if moved:
            return stop(f"step {i}/{n}: {'; '.join(moved)} while waiting for the confirm; {later}")
        if not tier0_gate(name, i, text, log):
            return stop(f"step {i}/{n} is held by the Tier 0 gate; a queue 'y' is not an approval. "
                        f"Approve it at its own gate, then run the queue again")
        event(name, "step", f"{i}/{n}")
        rc = run_child(argv, log)
        if rc != 0:
            return stop(f"step {i}/{n} failed (rc={rc}); later steps not run")
        log.say(f"ok    step {i}/{n}")
    with open(os.path.join(d, "done"), "w", encoding="utf-8") as f:
        f.write(f"at={now()}\nsha={sha}\nlog={os.path.basename(log.path)}\n")
    log.say(f"DONE: {name} — all {n} step(s) ran. rc=0  (log: {log.path})")
    event(name, "exit", rc=0)
    after(name, log)
    return 0


def after(name, log):
    """832 addendum §4: a job that leaves the index dirty is named, here and at the next run."""
    marker = os.path.join(jobs_dir(), ".staged-by")
    files = staged(root())
    if files:
        log.say(f"NOTE: {name} left {len(files)} staged path(s) in the git index: {', '.join(files[:5])}")
        with open(marker, "w", encoding="utf-8") as f:
            f.write(f"job={name}\n")
    elif os.path.exists(marker):
        os.remove(marker)


def cmd_queue(a):
    todo = pending()
    if not todo:
        print(f"Nothing to run: no pending job in {jobs_dir()}.")
        return 0
    ans = Answers()
    note = staged_note()
    if note:
        print(note)
    if len(todo) == 1:
        chosen = todo[0]
    else:
        w = width()
        print("Pending jobs:")
        for i, d in enumerate(todo, 1):
            ln = f"  {i}. {job_line(d)}"
            print(ln if len(ln) <= w else ln[:w - 1] + "…")
        r = ans.ask(f"Which job? [1-{len(todo)}; anything else = stop]")
        if not r.isdigit() or not 1 <= int(r) <= len(todo):
            print("STOPPED: no job chosen; nothing run")
            return 1
        chosen = todo[int(r) - 1]
    print(f"Chosen: {os.path.basename(chosen)}")
    return run_job(chosen, ans)


def main(argv=None):
    p = argparse.ArgumentParser(prog="fw runme", description="runme job queue (T-4491)")
    sub = p.add_subparsers(dest="cmd", required=True)
    job = sub.add_parser("job").add_subparsers(dest="verb", required=True)
    n = job.add_parser("new")
    n.add_argument("name")
    n.add_argument("--manifest")
    n.add_argument("--title")
    n.add_argument("--task")
    n.add_argument("--why")
    n.add_argument("cmds", nargs="*")
    job.add_parser("dry-run").add_argument("name")
    job.add_parser("list").add_argument("--all", action="store_true")
    r = job.add_parser("retire")
    r.add_argument("name")
    r.add_argument("--reason", required=True)
    sub.add_parser("queue")
    a = p.parse_args(argv)
    fn = cmd_queue if a.cmd == "queue" else {
        "new": cmd_new, "dry-run": cmd_dry_run, "list": cmd_list, "retire": cmd_retire}[a.verb]
    try:
        return fn(a)
    except Refused as e:
        print(f"REFUSED: {e}", file=sys.stderr if a.cmd == "job" else sys.stdout)
        return 2 if a.cmd == "job" else 1


if __name__ == "__main__":
    sys.exit(main())
