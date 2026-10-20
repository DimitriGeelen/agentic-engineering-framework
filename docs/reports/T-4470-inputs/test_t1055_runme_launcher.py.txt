#!/usr/bin/env python3
"""T-1055: the runme launcher enforces the operator's safeguards itself, so no job can skip them.

Every leg runs the REAL entry point (runme.sh -> tools/runme-launcher.sh) against a scratch job
directory, with answers fed through RUNME_TTY (honoured only off the real job dir; leg 11 shows the
refusal) and events to a scratch file. Steps write marker files, so "ran" / "did not run" is
observed, not inferred. Exit 0 = all legs pass.
"""
import os
import stat
import subprocess
import sys
import tempfile

ROOT = os.environ.get("T1055_ROOT") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUNME = os.path.join(ROOT, "runme.sh")
# runme.sh execs this; named here so a broken stub fails as itself (leg 0), not as missing output.
LAUNCHER = os.path.join(ROOT, "tools", "runme-launcher.sh")
NEW = os.path.join(ROOT, "tools", "runme-new.sh")
fails = []


def leg(ok, name, detail=""):
    print("%s  %s%s" % ("PASS" if ok else "FAIL", name, (" — " + detail) if detail else ""))
    if not ok:
        fails.append(name)


class Box:
    """One scratch job dir + events file + answers file."""

    def __init__(self, tmp, tag):
        self.dir = os.path.join(tmp, tag)
        self.jobs = os.path.join(self.dir, "jobs")
        self.out = os.path.join(self.dir, "out")
        os.makedirs(self.jobs)
        os.makedirs(self.out)
        self.events = os.path.join(self.dir, "events")
        self.answers = os.path.join(self.dir, "answers")

    def job(self, name, body):
        d = os.path.join(self.jobs, name)
        os.makedirs(d)
        with open(os.path.join(d, "job.sh"), "w") as fh:
            fh.write(body.replace("@OUT@", self.out))
        return d

    def run(self, *args, answers="", picker=False):
        with open(self.answers, "w") as fh:
            fh.write(answers)
        env = dict(os.environ, RUNME_JOBS_DIR=self.jobs, RUNME_EVENTS_FILE=self.events,
                   RUNME_SIGNAL_NO_TERMLINK="1", RUNME_TTY=self.answers, RUNME_PICKER="1" if picker else "0")
        r = subprocess.run(["bash", RUNME] + list(args), capture_output=True, text=True, env=env, timeout=60)
        return r.returncode, r.stdout + r.stderr

    def made(self, marker):
        return os.path.exists(os.path.join(self.out, marker))

    def events_text(self):
        return open(self.events).read() if os.path.exists(self.events) else ""


TWO_STEPS = '''JOB_TITLE="Two steps"
JOB_TASK="T-1055"
JOB_WHY="test job"
preflight() { check "always true" 'true'; }
steps() {
    step "first" 'touch @OUT@/s1'
    step "second" 'touch @OUT@/s2'
}
'''


def main():
    # 0 the operator's command is the stub, and the stub runs the tested launcher
    with open(RUNME) as fh:
        stub = fh.read()
    leg(os.access(LAUNCHER, os.X_OK) and "tools/runme-launcher.sh" in stub and stub.count("\n") < 30,
        "0 runme.sh is a short fixed stub that execs tools/runme-launcher.sh")

    with tempfile.TemporaryDirectory() as tmp:
        # 1 a job that runs a command when loaded is refused, and the command never runs
        b = Box(tmp, "l1")
        b.job("001-bad", 'touch @OUT@/loaded\nJOB_TITLE="x"\nsteps() { step "s" "true"; }\n')
        rc, out = b.run("--dry-run")
        leg(rc != 0 and "runs a command when it is loaded" in out and not b.made("loaded"),
            "1 load-time command refused; it did not run", out.strip().splitlines()[-1] if out.strip() else "")

        # 2 a real run of a job never rehearsed is refused, nothing runs, the agent is signalled
        b = Box(tmp, "l2")
        b.job("001-two", TWO_STEPS)
        rc, out = b.run(answers="y\ny\n")
        leg(rc != 0 and "has not been rehearsed" in out and not b.made("s1") and "STOPPED" in b.events_text(),
            "2 no dry-run -> refused, nothing ran, STOPPED event written")

        # 3 dry-run: checks run, sha recorded, job.sh read-only, NO step runs
        rc, out = b.run("--dry-run")
        d = os.path.join(b.jobs, "001-two")
        ro = not (os.stat(os.path.join(d, "job.sh")).st_mode & stat.S_IWUSR)
        leg(rc == 0 and os.path.exists(os.path.join(d, "dryrun.ok")) and ro and not b.made("s1")
            and "ok    always true" in out, "3 dry-run records sha, makes job.sh read-only, runs no step")

        # 4 a job edited after its dry-run is refused
        os.chmod(os.path.join(d, "job.sh"), 0o644)
        with open(os.path.join(d, "job.sh"), "a") as fh:
            fh.write("# edited after the dry-run\n")
        rc, out = b.run(answers="y\ny\n")
        leg(rc != 0 and "CHANGED since its dry-run" in out and not b.made("s1"), "4 edited after dry-run -> refused, nothing ran")

        # 5 happy path: rehearsed again, y to each step -> both ran, done written, log + events
        b.run("--dry-run")
        rc, out = b.run(answers="y\ny\n")
        ev = b.events_text()
        logs = [f for f in os.listdir(d) if f.startswith("run-")]
        leg(rc == 0 and b.made("s1") and b.made("s2") and os.path.exists(os.path.join(d, "done")) and logs
            and "Job:   001-two" in out and "sha " in out and " step 1/2 first" in ev and " done rc=0" in ev,
            "5 y,y -> both steps ran, done + log written, started/step/done events")

        # 6 a done job is never run again
        os.remove(os.path.join(b.out, "s1"))
        rc, out = b.run(answers="y\ny\n")
        leg(rc == 0 and "Nothing to run" in out and not b.made("s1"), "6 done job not run again")

        # 7 N at step 2 stops: step 1 ran, step 2 did not, no done
        b = Box(tmp, "l7")
        d = b.job("001-two", TWO_STEPS)
        b.run("--dry-run")
        rc, out = b.run(answers="y\nn\n")
        leg(rc != 0 and b.made("s1") and not b.made("s2") and not os.path.exists(os.path.join(d, "done"))
            and "not confirmed at step 2/2" in out, "7 y then N -> step 1 ran, step 2 did not, no done")

        # 8 a failing step stops the run; later steps do not run
        b = Box(tmp, "l8")
        b.job("001-fails", TWO_STEPS.replace("'touch @OUT@/s1'", "'false'"))
        b.run("--dry-run")
        rc, out = b.run(answers="y\ny\n")
        leg(rc != 0 and "step 1/2 failed" in out and not b.made("s2"), "8 failing step -> stop, later steps not run")

        # 9 two pending jobs -> numbered choice; only the chosen one runs
        b = Box(tmp, "l9")
        b.job("001-a", TWO_STEPS.replace("s1", "a1").replace("s2", "a2"))
        b.job("002-b", TWO_STEPS.replace("s1", "b1").replace("s2", "b2"))
        b.run("--dry-run")
        rc, out = b.run(answers="2\ny\ny\n")
        leg(rc == 0 and "Pending jobs:" in out and b.made("b1") and b.made("b2") and not b.made("a1"),
            "9 two pending -> asks which; only the chosen job ran")

        # 10 a failing preflight fails the dry-run: no dryrun.ok, so the real run stays refused
        b = Box(tmp, "l10")
        d = b.job("001-pre", TWO_STEPS.replace("'true'", "'false'"))
        rc, out = b.run("--dry-run")
        rc2, out2 = b.run(answers="y\ny\n")
        leg(rc != 0 and not os.path.exists(os.path.join(d, "dryrun.ok")) and "has not been rehearsed" in out2
            and not b.made("s1"), "10 failing preflight -> dry-run fails, real run refused")

        # 11 answers from a file are refused on the REAL job dir (the safeguard cannot be scripted)
        env = dict(os.environ, RUNME_TTY=os.path.join(tmp, "nope"), RUNME_SIGNAL_NO_TERMLINK="1")
        env.pop("RUNME_JOBS_DIR", None)
        r = subprocess.run(["bash", RUNME], capture_output=True, text=True, env=env, timeout=30)
        leg(r.returncode != 0 and "RUNME_TTY is for tests only" in r.stdout, "11 RUNME_TTY refused on the real job dir")

        # 12 runme-new scaffolds numbered jobs that load (and refuse to run un-rehearsed)
        b = Box(tmp, "l12")
        env = dict(os.environ, RUNME_JOBS_DIR=b.jobs)
        p1 = subprocess.run(["bash", NEW, "first"], capture_output=True, text=True, env=env).stdout.strip()
        p2 = subprocess.run(["bash", NEW, "second"], capture_output=True, text=True, env=env).stdout.strip()
        rc, out = b.run("--dry-run")
        leg(p1.endswith("001-first/job.sh") and p2.endswith("002-second/job.sh") and rc == 0
            and "dry-run passed" in out, "12 runme-new scaffolds 001, 002; the scaffold rehearses cleanly")

        # 13 (T-1112) the menu names each job's title, state and LAST OUTCOME, so a job that stopped for a
        #    reason says so before the operator picks it again (008 was picked 3x while waiting on a file)
        b = Box(tmp, "l13")
        b.job("001-needs-file", TWO_STEPS.replace('"Two steps"', '"Needs a file first"')
              .replace("'touch @OUT@/s1'", "'echo \"no /root/x.secret - place it first\"; false'"))
        b.job("002-other", TWO_STEPS.replace("s1", "o1").replace("s2", "o2"))
        b.run("--dry-run")
        b.run(answers="1\ny\n")                       # run 001: step 1 fails with its reason
        rc, out = b.run(answers="nothing\n")          # menu again; answer nothing -> no job run
        menu = [l for l in out.splitlines() if l.strip().startswith("1. ")]
        leg(menu and "Needs a file first" in menu[0] and "[ready; last: STOPPED" in menu[0]
            and "no /root/x.secret" in menu[0] and "never run" in out and not b.made("o1"),
            "13 menu line: title, state and last outcome with the step's own reason", menu[0] if menu else out[-300:])

        # 14 (T-1112) a retired job is never offered and never runs; --list --all names it with its reason
        b = Box(tmp, "l14")
        d = b.job("001-old", TWO_STEPS)
        b.run("--dry-run")
        with open(os.path.join(d, "retired"), "w") as fh:
            fh.write("superseded by 002-new\n")
        rc, out = b.run(answers="y\ny\n")
        _, out2 = b.run("--list", "--all")
        leg(rc == 0 and "Nothing to run" in out and not b.made("s1") and not os.path.exists(os.path.join(d, "done"))
            and "RETIRED: superseded by 002-new" in out2, "14 retired: not offered, not run, no done written; --list --all names it")

        # 15 (T-1204) steps run with 832's TermLink key exported when the key file exists, and with the
        #    variable UNSET when it does not (termlink mints a key at a missing path, T-1151)
        envjob = TWO_STEPS.replace("'touch @OUT@/s1'", "'printf %s \"${TERMLINK_IDENTITY_FILE-UNSET}\" > @OUT@/key; printf %s \"${TERMLINK_IDENTITY_NO_CREATE-UNSET}\" > @OUT@/nocreate'")
        b = Box(tmp, "l15")
        b.job("001-env", envjob)
        b.run("--dry-run")
        fake_key = os.path.join(tmp, "fake.key")
        with open(fake_key, "w") as fh:
            fh.write("not a key\n")
        os.environ["RUNME_IDENTITY_KEY"] = fake_key
        os.environ["TERMLINK_IDENTITY_FILE"] = "/somewhere/else"
        try:
            b.run(answers="y\ny\n")
            got_present = open(os.path.join(b.out, "key")).read() if b.made("key") else None
            b2 = Box(tmp, "l15b")
            b2.job("001-env", envjob)
            b2.run("--dry-run")
            os.environ["RUNME_IDENTITY_KEY"] = os.path.join(tmp, "missing.key")
            b2.run(answers="y\ny\n")
            got_missing = open(os.path.join(b2.out, "key")).read() if b2.made("key") else None
        finally:
            os.environ.pop("RUNME_IDENTITY_KEY", None)
            os.environ.pop("TERMLINK_IDENTITY_FILE", None)
        nc = [open(os.path.join(x.out, "nocreate")).read() if x.made("nocreate") else None for x in (b, b2)]
        leg(nc == ["1", "1"], "15b (T-1203) steps run with TERMLINK_IDENTITY_NO_CREATE=1, key present or not", repr(nc))
        leg(got_present == fake_key and got_missing == "UNSET" and not os.path.exists(os.path.join(tmp, "missing.key")),
            "15 steps inherit the key when it exists; the variable is unset (nothing minted) when it is missing",
            "present=%r missing=%r" % (got_present, got_missing))

        # 16 (T-1227) batch "x": every pending job, in the listed order; each still asks y/N per step
        b = Box(tmp, "l16")
        for n, t in (("001-a", "a"), ("002-b", "b"), ("003-c", "c")):
            b.job(n, TWO_STEPS.replace("s1", t + "1").replace("s2", t + "2"))
        b.run("--dry-run")
        rc, out = b.run(answers="x\ny\ny\ny\ny\ny\ny\n")
        order = [l for l in out.splitlines() if l.startswith("DONE: ")]
        leg(rc == 0 and all(b.made(m) for m in ("a1", "a2", "b1", "b2", "c1", "c2"))
            and [l.split()[1] for l in order] == ["001-a", "002-b", "003-c"] and "BATCH: 3 of 3 completed" in out,
            "16 x -> all three ran in listed order, each with its own y/N, one summary", " ".join(order))

        # 17 (T-1227) batch "3,1": exactly those, in the order typed; 2 is not started
        b = Box(tmp, "l17")
        for n, t in (("001-a", "a"), ("002-b", "b"), ("003-c", "c")):
            b.job(n, TWO_STEPS.replace("s1", t + "1").replace("s2", t + "2"))
        b.run("--dry-run")
        rc, out = b.run(answers="3, 1\ny\ny\ny\ny\n")
        order = [l.split()[1] for l in out.splitlines() if l.startswith("DONE: ")]
        leg(rc == 0 and order == ["003-c", "001-a"] and not b.made("b1") and "BATCH: 2 of 2 completed" in out,
            "17 '3, 1' -> job 3 then job 1, job 2 not started", " ".join(order))

        # 18 (T-1227) a batch stops at the first job that does not complete; later jobs are not started
        b = Box(tmp, "l18")
        b.job("001-a", TWO_STEPS.replace("s1", "a1").replace("s2", "a2"))
        b.job("002-fails", TWO_STEPS.replace("'touch @OUT@/s1'", "'false'"))
        b.job("003-c", TWO_STEPS.replace("s1", "c1").replace("s2", "c2"))
        b.run("--dry-run")
        rc, out = b.run(answers="x\ny\ny\ny\ny\ny\ny\n")
        leg(rc != 0 and b.made("a2") and not b.made("c1") and "STOPPED at 002-fails" in out
            and os.path.exists(os.path.join(b.jobs, "001-a", "done")) and not os.path.exists(os.path.join(b.jobs, "003-c", "done")),
            "18 batch stops at the failing job; the job after it is not started; the one before stays done")

        # 19 (T-1227) a batch with a job changed since its dry-run is refused BEFORE anything runs
        b = Box(tmp, "l19")
        b.job("001-a", TWO_STEPS.replace("s1", "a1").replace("s2", "a2"))
        d2 = b.job("002-b", TWO_STEPS.replace("s1", "b1").replace("s2", "b2"))
        b.run("--dry-run")
        os.chmod(os.path.join(d2, "job.sh"), 0o644)
        with open(os.path.join(d2, "job.sh"), "a") as fh:
            fh.write("# edited\n")
        rc, out = b.run(answers="1,2\ny\ny\ny\ny\n")
        leg(rc != 0 and "batch refused before anything ran" in out and "002-b (CHANGED" in out and not b.made("a1")
            and "STOPPED batch refused" in b.events_text(), "19 a changed job in the batch -> whole batch refused up front, STOPPED event")

        # 20 (T-1227) a bad choice runs nothing: an index out of range, or the same job twice
        b = Box(tmp, "l20")
        b.job("001-a", TWO_STEPS.replace("s1", "a1").replace("s2", "a2"))
        b.job("002-b", TWO_STEPS.replace("s1", "b1").replace("s2", "b2"))
        b.run("--dry-run")
        rc1, out1 = b.run(answers="1,5\n")
        rc2, out2 = b.run(answers="2,2\n")
        leg(rc1 != 0 and "no job 5" in out1 and rc2 != 0 and "chosen twice" in out2 and not b.made("a1") and not b.made("b1"),
            "20 '1,5' and '2,2' -> refused, nothing ran")

        # 21-25 (T-1227) the arrow-key picker; keys fed as bytes (UP/DOWN are the terminal's escape sequences)
        UP, DOWN = "\x1b[A", "\x1b[B"

        def three(tag):
            b = Box(tmp, tag)
            for n, t in (("001-a", "a"), ("002-b", "b"), ("003-c", "c")):
                b.job(n, TWO_STEPS.replace("s1", t + "1").replace("s2", t + "2"))
            b.run("--dry-run")
            return b

        def done_order(out):
            return [l.split()[1] for l in out.splitlines() if l.startswith("DONE: ")]

        # 21 mark job 3, then job 1 (space marks), Enter: they run in MARKED order, job 2 not started
        b = three("l21")
        rc, out = b.run(answers=DOWN + DOWN + " " + UP + UP + " \n" + "y\n" * 4, picker=True)
        leg(rc == 0 and done_order(out) == ["003-c", "001-a"] and not b.made("b1") and "Chosen, in this order: 3 1" in out
            and "BATCH: 2 of 2 completed" in out, "21 picker: mark 3 then 1, Enter -> 3 then 1, job 2 not started",
            " ".join(done_order(out)))

        # 22 a marks all, in listed order
        b = three("l22")
        rc, out = b.run(answers="a\n" + "y\n" * 6, picker=True)
        leg(rc == 0 and done_order(out) == ["001-a", "002-b", "003-c"], "22 picker: a, Enter -> all three in listed order")

        # 23 Enter with nothing marked runs the highlighted job alone; space twice unmarks
        b = three("l23")
        rc, out = b.run(answers=" " + " " + DOWN + "\n" + "y\n" * 2, picker=True)
        leg(rc == 0 and done_order(out) == ["002-b"] and not b.made("a1") and not b.made("c1"),
            "23 picker: mark+unmark 1, move to 2, Enter -> job 2 alone", " ".join(done_order(out)))

        # 24 t falls back to typed numbers
        b = three("l24")
        rc, out = b.run(answers="t2,1\n" + "y\n" * 4, picker=True)
        leg(rc == 0 and done_order(out) == ["002-b", "001-a"] and "Which job?" in out, "24 picker: t -> typed '2,1' works")

        # 25 q and a lone Esc stop with nothing run; so does running out of keys
        b = three("l25")
        rcq, outq = b.run(answers=" q", picker=True)
        rce, oute = b.run(answers=" \x1b", picker=True)
        rcn, outn = b.run(answers=DOWN, picker=True)
        leg(rcq != 0 and rce != 0 and rcn != 0 and all("no job chosen" in o for o in (outq, oute, outn))
            and not any(b.made(m) for m in ("a1", "b1", "c1")), "25 picker: q / Esc / no more keys -> stop, nothing ran")

    print("\n%d failed leg(s)" % len(fails) if fails else "\nall legs passed")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
