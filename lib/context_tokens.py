#!/usr/bin/env python3
"""Shared "how many tokens does THIS conversation currently hold" scan.

Used by both agents/context/budget-gate.sh (PreToolUse gate) and
agents/context/checkpoint.sh (PostToolUse checkpoint) — T-2885. Both scripts
previously carried their own hand-copied inline scan; they drifted
(checkpoint.sh never received the T-2322 compact_boundary reset), and both
scoped by RAW TRANSCRIPT POSITION — "last usage entry wins". Four models
write usage entries into one transcript, and position tells you WHEN an
entry was written, not WHOSE conversation it belongs to. A foreign-model
cache-priming call landing after our own last turn (832 T-401) reports its
own 300k+ prompt as ours.

Fix: scope to the model with the MOST usage entries since the last
compact_boundary (the dominant writer — normal conversational turns from our
own model vastly outnumber a foreign cache-priming call), not to the newest
entry's model. Below two in-scope entries, return 0 rather than guess: a
session that young cannot have filled its context, and a lone foreign entry
right after a boundary is exactly the poisoning shape this replaces.

Deliberately NOT shared with lib/costs.sh / web/blueprints/costs.py: those
sum the SAME three usage fields for COST, where a foreign call genuinely did
cost money and belongs in the total regardless of whose conversation it was.
This module answers a different question ("what is in MY context window
right now") — routing cost through it would silently drop real spend.
"""
import json
import sys
from collections import Counter


def compute_context_tokens(lines, session_start_ts=""):
    """Return the current context-window token count for THIS conversation.

    Thin wrapper over compute_context_tokens_detail for the many callers that
    only want the number. The default stdout of this module is likewise a bare
    integer — see main().
    """
    return compute_context_tokens_detail(lines, session_start_ts)[0]


def compute_context_tokens_detail(lines, session_start_ts=""):
    """Return (tokens, dominant_model) for THIS conversation.

    The dominant model is computed anyway, to scope usage entries (T-2885). It
    is returned here rather than discarded because the gauges that consume this
    module apply a CONFIGURED BUDGET CAP (CONTEXT_WINDOW, default 300000) and
    could not previously say which model the cap was being applied to — the cap's
    own justifying comment still named a model two releases old. Returned as ""
    whenever tokens are 0, since a count we refused to trust carries no model
    we should report either (T-3204).

    `lines` is an iterable of JSONL transcript lines (already position-scoped
    by the caller, e.g. via `tail -c`). `session_start_ts` (ISO-8601 Z,
    T-1088) excludes entries from before the current session started — e.g.
    pre-compact entries `claude -c` carries over in the same JSONL.
    """
    entries = []  # (model, token_total) since the last compact_boundary, in order
    for line in lines:
        try:
            e = json.loads(line)
        except Exception:
            continue

        # T-2322: a compact_boundary discards everything before it — pre-compact
        # usage belongs to a conversation that no longer exists in this window.
        if e.get("type") == "system" and e.get("subtype") == "compact_boundary":
            entries = []
            continue

        model = e.get("message", {}).get("model", "")
        if model == "<synthetic>" or model.startswith("<"):
            continue

        if session_start_ts:
            entry_ts = e.get("timestamp", "")
            if entry_ts and entry_ts < session_start_ts:
                continue

        u = e.get("message", {}).get("usage")
        if u and "input_tokens" in u:
            total = (
                u["input_tokens"]
                + u.get("cache_read_input_tokens", 0)
                + u.get("cache_creation_input_tokens", 0)
            )
            entries.append((model, total))

    if not entries:
        return (0, "")

    counts = Counter(model for model, _ in entries)
    dominant_model, _ = counts.most_common(1)[0]
    in_scope = [total for model, total in entries if model == dominant_model]

    # Fail-open, not fail-guess: too few entries to trust a scope decision.
    if len(in_scope) < 2:
        return (0, "")

    return (in_scope[-1], dominant_model)


def main():
    # Flags are parsed OUT of argv rather than positionally: callers pass the
    # session-start timestamp as the first argument and it is frequently the
    # empty string, so a flag must never be mistaken for it.
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = {a for a in sys.argv[1:] if a.startswith("--")}
    session_start_ts = args[0].strip() if args else ""

    # T-3241 (folds in field report 001-CashWeb T-222/G-087): a transcript
    # containing invalid UTF-8 bytes raises UnicodeDecodeError while iterating
    # `sys.stdin` for the NEXT line — outside the try/except above, which only
    # guards json.loads on a line already successfully decoded. Uncaught, that
    # produced a bare traceback on stderr + empty stdout + exit 1; callers
    # (budget-gate.sh) already treat "no parseable integer on stdout" as a scan
    # failure, so catching here just makes that outcome deliberate and quiet
    # instead of an accidental crash with the same effect.
    try:
        tokens, model = compute_context_tokens_detail(sys.stdin, session_start_ts)
    except Exception:
        sys.exit(1)

    # DEFAULT STDOUT IS A BARE INTEGER AND MUST STAY THAT WAY (T-2885/T-3204
    # pinned contract — tests/unit/t2885_context_tokens_model_scope.bats asserts
    # "0" verbatim for the under-filled-scope cases). Both gauges capture this
    # straight into a shell integer; an unconditional extra field would corrupt
    # CONTEXT_TOKENS in both at once. The model is therefore strictly opt-in
    # (T-3204) — and doubles, via --with-model, as the T-3241 "was this
    # confidently measured" signal: model=="" on BOTH give-up branches of
    # compute_context_tokens_detail (no entries; fewer than 2 dominant-model
    # entries since the last boundary), and is likewise absent whenever this
    # process exits via the except above. A confirmed measurement always
    # carries a non-empty dominant_model. Callers that need to distinguish
    # "confidently zero" from "could not measure" pass --with-model and check
    # the model field, not the bare integer.
    if "--with-model" in flags:
        print(f"{tokens}\t{model}")
    else:
        print(tokens)


if __name__ == "__main__":
    main()
