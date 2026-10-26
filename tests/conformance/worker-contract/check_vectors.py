#!/usr/bin/env python3
"""Schema check for the shared worker-contract conformance vectors (T-4520).

Validates vectors.yaml against the structure its header describes and against the
contract's fixed sets (spec v0.3.3): every case CC-01..CC-25 present exactly once,
fence_reject reasons from §3.3, the N2 applicability rule from §6.6, steps naming
ops/writers/transitions from the file's own vocabulary, and no paths into one
backend's tree (the file is shared with TermLink and ring20).

Usage: check_vectors.py [vectors.yaml]    exit 0 = valid, 1 = invalid, 2 = unreadable
Stdlib + PyYAML only.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

HERE = Path(__file__).resolve().parent
DEFAULT_PATH = HERE / "vectors.yaml"

REQUIRED_IDS = [f"CC-{i:02d}" for i in range(1, 26)]
# §3.3 fence_reject reasons — fixed by the spec, not by the file.
FENCE_REASONS = {"stale_attempt", "bad_nonce", "bad_credential", "stale_gen",
                 "cas_mismatch", "forbidden_transition", "done_conflict"}
# §6.6 N2: n/a only when the case's subject is one of these capabilities.
NA_CAPABILITIES = {"answer_channel", "registry_epoch", "caller_chosen_ids"}
STATES = {"dispatched", "running", "done", "lost", "unknown"}
OUTCOMES = {"succeeded", "failed", "refused", "handback-malformed", "paused"}
TRANSITIONS = {"T1", "T2", "T3", "T3b", "T-RECLAIM", "T4", "T5", "T6", "T6b",
               "T7a", "T7b", "T7c", "T7d", "T8"}
VOCAB_KEYS = {"states", "outcomes", "transitions", "writers", "fence_reasons",
              "errors", "refusals", "capabilities", "ops"}
VECTOR_KEYS = {"id", "title", "spec_refs", "applicability", "given", "steps", "then"}
OPTIONAL_VECTOR_KEYS = {"variants", "spec_note", "parity"}
VARIANT_KEYS = {"name", "requires", "given", "steps", "then", "equivalent"}
EXPECT_PRIMARY = {"accepted", "fence_reject", "error", "refused", "response",
                  "no_transition", "ok"}
EXPECT_MODIFIERS = {"notices", "values", "bind"}
# Paths into one backend's own tree: the shared file must stay backend-neutral.
BACKEND_PATH = re.compile(r"\.context/|\.tasks/|(^|[\s/])lib/|(^|[\s/])agents/|bin/fw|run\.sh|\bfw worker\b")


class Checker:
    def __init__(self) -> None:
        self.errors: list[str] = []

    def err(self, where: str, msg: str) -> None:
        self.errors.append(f"{where}: {msg}")

    # ── whole file ────────────────────────────────────────────────────────
    def check(self, doc) -> list[str]:
        if not isinstance(doc, dict):
            self.err("file", "top level must be a mapping")
            return self.errors
        for key in ("schema", "contract_version", "vocabulary", "vectors"):
            if key not in doc:
                self.err("file", f"missing top-level key '{key}'")
        if doc.get("contract_version") not in (None, "wc/0.3"):
            self.err("file", f"contract_version {doc.get('contract_version')!r} is not wc/0.3")
        self._scan_paths("file", doc)
        vocab = doc.get("vocabulary") or {}
        self.vocab = self._check_vocab(vocab)
        vectors = doc.get("vectors")
        if not isinstance(vectors, list):
            self.err("vectors", "must be a list")
            return self.errors
        seen: dict = {}
        for i, vec in enumerate(vectors):
            vid = vec.get("id") if isinstance(vec, dict) else None
            where = vid or f"vectors[{i}]"
            if vid in seen:
                self.err(where, "duplicate id")
            seen[vid] = i
            self._check_vector(where, vec)
        missing = [c for c in REQUIRED_IDS if c not in seen]
        extra = [c for c in seen if c not in REQUIRED_IDS]
        if missing:
            self.err("vectors", f"missing cases: {', '.join(missing)}")
        if extra:
            self.err("vectors", f"unknown case ids: {', '.join(map(str, extra))}")
        return self.errors

    def _scan_paths(self, where: str, node) -> None:
        if isinstance(node, str):
            if BACKEND_PATH.search(node):
                self.err(where, f"backend-specific path in shared data: {node!r}")
        elif isinstance(node, dict):
            for k, v in node.items():
                self._scan_paths(where, k)
                self._scan_paths(where, v)
        elif isinstance(node, list):
            for v in node:
                self._scan_paths(where, v)

    def _check_vocab(self, vocab) -> dict:
        if not isinstance(vocab, dict):
            self.err("vocabulary", "must be a mapping")
            return {}
        for key in VOCAB_KEYS - set(vocab):
            self.err("vocabulary", f"missing '{key}'")
        if set(vocab.get("fence_reasons") or []) != FENCE_REASONS:
            self.err("vocabulary", f"fence_reasons must be exactly {sorted(FENCE_REASONS)}")
        if set(vocab.get("states") or []) != STATES:
            self.err("vocabulary", f"states must be exactly {sorted(STATES)}")
        if set(vocab.get("outcomes") or []) != OUTCOMES:
            self.err("vocabulary", f"outcomes must be exactly {sorted(OUTCOMES)}")
        if set(vocab.get("transitions") or []) != TRANSITIONS:
            self.err("vocabulary", f"transitions must be exactly {sorted(TRANSITIONS)}")
        if not NA_CAPABILITIES <= set(vocab.get("capabilities") or {}):
            self.err("vocabulary", f"capabilities must include {sorted(NA_CAPABILITIES)}")
        return {
            "ops": set(vocab.get("ops") or {}),
            "writers": set(vocab.get("writers") or []),
            "errors": set(vocab.get("errors") or []),
            "refusals": set(vocab.get("refusals") or {}),
            "capabilities": set(vocab.get("capabilities") or {}),
        }

    # ── one vector ────────────────────────────────────────────────────────
    def _check_vector(self, where: str, vec) -> None:
        if not isinstance(vec, dict):
            self.err(where, "vector must be a mapping")
            return
        for key in VECTOR_KEYS - set(vec):
            self.err(where, f"missing '{key}'")
        for key in set(vec) - VECTOR_KEYS - OPTIONAL_VECTOR_KEYS:
            self.err(where, f"unknown key '{key}'")
        if not isinstance(vec.get("spec_refs"), list) or not vec.get("spec_refs"):
            self.err(where, "spec_refs must be a non-empty list")
        self._check_applicability(where, vec.get("applicability"))
        if not isinstance(vec.get("given"), dict):
            self.err(where, "given must be a mapping")
        self._check_steps(where, vec.get("steps"))
        variants = vec.get("variants")
        then = vec.get("then")
        if variants is None:
            if isinstance(then, dict) and "judged_by" in then:
                self.err(where, "then.judged_by: variants, but the vector has no variants")
            self._check_then(where, then, required=True)
        else:
            if not isinstance(then, dict) or then.get("judged_by") != "variants":
                self.err(where, "a vector with variants must say then: {judged_by: variants}")
            if not isinstance(variants, list) or not variants:
                self.err(where, "variants must be a non-empty list")
                return
            names = set()
            for j, var in enumerate(variants):
                vw = f"{where}/{var.get('name', j) if isinstance(var, dict) else j}"
                if not isinstance(var, dict):
                    self.err(vw, "variant must be a mapping")
                    continue
                if not var.get("name") or var["name"] in names:
                    self.err(vw, "variant needs a unique name")
                names.add(var.get("name"))
                for key in set(var) - VARIANT_KEYS:
                    self.err(vw, f"unknown key '{key}'")
                if "equivalent" in var and (not isinstance(var["equivalent"], str)
                                            or not var["equivalent"].strip()):
                    self.err(vw, "equivalent must be a non-empty string naming what a backend runs instead")
                for cap in var.get("requires") or []:
                    if cap not in self.vocab.get("capabilities", set()):
                        self.err(vw, f"unknown capability '{cap}'")
                if "given" in var and not isinstance(var["given"], dict):
                    self.err(vw, "variant given must be a mapping")
                self._check_steps(vw, var.get("steps"))
                if not var.get("steps") and not vec.get("steps"):
                    self.err(vw, "variant has no steps and the vector has no shared steps")
                self._check_then(vw, var.get("then"), required=True)

    def _check_applicability(self, where: str, app) -> None:
        if not isinstance(app, dict):
            self.err(where, "applicability must be a mapping")
            return
        subject = app.get("subject")
        requires = app.get("requires")
        na = app.get("n_a_allowed")
        rows = app.get("rows")
        if subject not in ("transition", "capability"):
            self.err(where, "applicability.subject must be 'transition' or 'capability'")
        if not isinstance(requires, list):
            self.err(where, "applicability.requires must be a list")
            requires = []
        if not isinstance(na, bool):
            self.err(where, "applicability.n_a_allowed must be true or false")
        if not isinstance(rows, list):
            self.err(where, "applicability.rows must be a list")
            rows = []
        for cap in requires:
            if cap not in self.vocab.get("capabilities", set()):
                self.err(where, f"unknown capability '{cap}'")
        for row in rows:
            if row not in TRANSITIONS:
                self.err(where, f"unknown §3 row '{row}'")
        # N2 rule (§6.6): a §3 transition row is never n/a.
        if subject == "transition":
            if na is not False:
                self.err(where, "N2: a case whose subject is a §3 transition row must have n_a_allowed: false")
            if not rows:
                self.err(where, "a transition-subject case must name its §3 rows")
        if na is True:
            if subject != "capability":
                self.err(where, "N2: n/a allowed only for a capability-subject case")
            if not set(requires) & NA_CAPABILITIES:
                self.err(where, f"N2: n/a allowed only when requires names one of {sorted(NA_CAPABILITIES)}")

    def _check_steps(self, where: str, steps) -> None:
        if steps is None:
            self.err(where, "steps missing")
            return
        if not isinstance(steps, list):
            self.err(where, "steps must be a list")
            return
        for k, step in enumerate(steps):
            self._check_step(f"{where}/steps[{k}]", step)

    def _check_step(self, sw: str, step) -> None:
        if not isinstance(step, dict):
            self.err(sw, "step must be a mapping")
            return
        op = step.get("op")
        if op not in self.vocab.get("ops", set()):
            self.err(sw, f"unknown op '{op}'")
        writer = step.get("writer")
        if writer is not None and writer not in self.vocab.get("writers", set()):
            self.err(sw, f"unknown writer '{writer}'")
        if "expect" not in step:
            self.err(sw, "step needs an expect")
            return
        if op == "concurrent":
            inner = (step.get("args") or {}).get("step")
            count = (step.get("args") or {}).get("count")
            if not isinstance(count, int) or count < 2:
                self.err(sw, "concurrent needs args.count >= 2")
            if not isinstance(inner, dict) or "expect" in inner:
                self.err(sw, "concurrent needs args.step without its own expect")
            exp = step["expect"]
            if not isinstance(exp, dict) or set(exp) != {"exactly_one", "rest_any_of"}:
                self.err(sw, "concurrent expect must be {exactly_one, rest_any_of}")
                return
            self._check_expect(sw, exp["exactly_one"])
            for e in exp["rest_any_of"] or []:
                self._check_expect(sw, e)
            return
        self._check_expect(sw, step["expect"])

    def _check_expect(self, sw: str, exp) -> None:
        if not isinstance(exp, dict) or not exp:
            self.err(sw, "expect must be a non-empty mapping")
            return
        if "any_of" in exp:
            if set(exp) != {"any_of"} or not isinstance(exp["any_of"], list) or len(exp["any_of"]) < 2:
                self.err(sw, "any_of must stand alone and list at least two expects")
                return
            for e in exp["any_of"]:
                self._check_expect(sw, e)
            return
        primary = set(exp) & EXPECT_PRIMARY
        if len(primary) != 1:
            self.err(sw, f"expect needs exactly one of {sorted(EXPECT_PRIMARY)}")
        for key in set(exp) - EXPECT_PRIMARY - EXPECT_MODIFIERS:
            self.err(sw, f"unknown expect key '{key}'")
        if "accepted" in exp and exp["accepted"] not in TRANSITIONS:
            self.err(sw, f"accepted names unknown transition '{exp['accepted']}'")
        if "fence_reject" in exp and exp["fence_reject"] not in FENCE_REASONS:
            self.err(sw, f"fence_reject reason '{exp['fence_reject']}' is not a §3.3 reason")
        if "response" in exp and exp["response"] != "T8":
            self.err(sw, "response is only T8 (duplicate finalisation)")
        if "error" in exp and exp["error"] not in self.vocab.get("errors", set()):
            self.err(sw, f"unknown error '{exp['error']}'")
        if "refused" in exp and exp["refused"] not in self.vocab.get("refusals", set()):
            self.err(sw, f"unknown refusal '{exp['refused']}'")
        if "notices" in exp and not isinstance(exp["notices"], int):
            self.err(sw, "notices must be an integer")

    def _check_then(self, where: str, then, required: bool) -> None:
        if then is None or then == {}:
            if required:
                self.err(where, "then must describe the admissible end state")
            return
        if not isinstance(then, dict):
            self.err(where, "then must be a mapping")
            return
        if "judged_by" in then:
            self.err(where, "judged_by belongs only on a vector with variants")
        if required and not ({"final", "admissible_histories", "dispatch_count"} & set(then)):
            self.err(where, "then needs final, admissible_histories or dispatch_count")
        for key, attempt in (then.get("final") or {}).items():
            if not re.fullmatch(r"A\d+", str(key)):
                self.err(where, f"final key '{key}' is not an attempt (A1, A2, …)")
            if not isinstance(attempt, dict):
                continue
            state = attempt.get("state")
            states = state.get("any_of") if isinstance(state, dict) else [state]
            for s in states or []:
                if s not in STATES:
                    self.err(where, f"final {key} state '{s}' unknown")
            outcome = attempt.get("outcome", None)
            if outcome is not None and outcome not in OUTCOMES:
                self.err(where, f"final {key} outcome '{outcome}' unknown")
            if outcome is not None and state != "done":
                self.err(where, f"I2: final {key} has an outcome but state is not done")
            if state == "done" and "outcome" in attempt and outcome is None:
                self.err(where, f"I2: final {key} is done with a null outcome")
        hist = then.get("admissible_histories")
        if hist is not None:
            if not isinstance(hist, dict):
                self.err(where, "admissible_histories must map attempt -> list of state sequences")
            else:
                for key, seqs in hist.items():
                    if not isinstance(seqs, list) or not seqs:
                        self.err(where, f"admissible_histories {key} must be a non-empty list")
                        continue
                    for seq in seqs:
                        if not isinstance(seq, list) or not seq:
                            self.err(where, f"admissible_histories {key} entry must be a non-empty list")
                            continue
                        for s in seq:
                            if s not in STATES:
                                self.err(where, f"admissible_histories {key} names unknown state '{s}'")


def check_file(path: Path) -> list[str]:
    doc = yaml.safe_load(path.read_text())
    return Checker().check(doc)


def main(argv: list[str]) -> int:
    path = Path(argv[1]) if len(argv) > 1 else DEFAULT_PATH
    try:
        errors = check_file(path)
    except (OSError, yaml.YAMLError) as exc:
        print(f"check_vectors: cannot read {path}: {exc}", file=sys.stderr)
        return 2
    if errors:
        for e in errors:
            print(f"INVALID {e}", file=sys.stderr)
        print(f"check_vectors: {len(errors)} error(s) in {path}", file=sys.stderr)
        return 1
    print(f"check_vectors: OK — {len(REQUIRED_IDS)} cases, {path.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
