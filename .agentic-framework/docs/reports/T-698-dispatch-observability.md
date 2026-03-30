# T-698: TermLink Dispatch Observability Research

## Problem

`fw termlink dispatch` runs `claude -p --output-format text > result.md 2>stderr.log &` inside a TermLink PTY session. The human cannot observe the worker in real time:

- `termlink attach <session>` shows the shell, not Claude's reasoning
- `termlink pty output <session>` shows the bash prompt, not tool calls
- `claude -p` produces no interactive output — everything goes to `result.md`

**Discovery:** T-697 (KCP deep-dive) — human asked to see what the worker was doing. Mirror terminal showed nothing. Worker was clearly active (child processes visible via `pstree`) but human had zero visibility into what the agent was doing or deciding.

## Current Design Rationale

The headless design was chosen for practical reasons (traced from T-143 `tl-dispatch.sh`, T-503 framework integration, T-577 orphan fix):

1. **Reliable output capture** — `> result.md` guarantees the full response is captured cleanly. No terminal escape codes, no control sequences, no interleaved output
2. **macOS compatibility** — `claude -p` works identically on Linux and macOS. Interactive mode has terminal emulation differences
3. **Kill watchdog simplicity** — background process + `wait` + `kill` is a clean process lifecycle. Interactive mode complicates signal handling
4. **No CLAUDE.md loading** — `claude -p` with `--bare` skips hooks, which is sometimes desirable for isolated workers

## Alternatives Evaluated

### Option A: `tee` Split (stdout to both file and PTY)

**Change:** Replace `> "$WDIR/result.md"` with `| tee "$WDIR/result.md"`

```bash
claude -p "$(cat "$WDIR/prompt.md")" --output-format text 2>"$WDIR/stderr.log" \
    | tee "$WDIR/result.md" &
```

**Pros:**
- Minimal change (1 line)
- Worker output visible in PTY via `termlink attach` or `termlink pty output`
- Result file still captured
- No new dependencies

**Cons:**
- `tee` output goes to the TermLink PTY — raw text stream with no structure
- Human sees the final response text streaming, but NOT tool calls, file reads, or reasoning
- For long-running workers, output may be delayed (Claude often writes nothing until done, then dumps the full response)
- `tee` with backgrounded process may behave differently on macOS vs Linux (buffering)

**Verdict:** Marginal improvement. You see the final output streaming but miss the interesting parts (what files is it reading? what edits is it making?).

### Option B: `--output-format stream-json` + Parse Loop

**Change:** Use Claude's streaming JSON output format with a parse/display loop.

```bash
claude -p "$(cat "$WDIR/prompt.md")" --output-format stream-json 2>"$WDIR/stderr.log" \
    | while IFS= read -r line; do
        echo "$line" >> "$WDIR/result.jsonl"
        # Extract and display tool calls, progress
        type=$(echo "$line" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('type',''))" 2>/dev/null)
        case "$type" in
            tool_use)  echo "[TOOL] $(echo "$line" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('tool',''),d.get('tool_input',{}).get('command','')[:80])" 2>/dev/null)" ;;
            text)      echo "[TEXT] $(echo "$line" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('content','')[:120])" 2>/dev/null)" ;;
        esac
    done &
```

**Pros:**
- Rich observability: tool calls, file reads, edits all visible
- Human can see `[TOOL] Bash: git status`, `[TOOL] Read: src/main.rs`, `[TOOL] Edit: lib/foo.sh`
- Full structured data captured in `result.jsonl` for post-mortem analysis
- `termlink attach` shows real-time progress

**Cons:**
- Significantly more complex (~20 lines vs 1 line)
- Requires `python3` for JSON parsing (already a dependency)
- Parse loop adds latency (minimal, but non-zero)
- `stream-json` format may change between Claude Code versions
- Result file format changes from `.md` (text) to `.jsonl` (structured) — breaks `fw termlink result` which reads `result.md`
- **Dual output needed:** stream-json for observability + text capture for result file. May need two pipes or post-processing

**Verdict:** Best observability but highest complexity. The format change from text to JSONL would require updating `cmd_result()` and any consumers.

### Option C: `--verbose` Flag on Interactive Claude

**Change:** Run interactive `claude` (not `claude -p`) in the TermLink PTY.

```bash
claude --verbose --permission-mode dontAsk -p "$(cat "$WDIR/prompt.md")" \
    --output-format stream-json > "$WDIR/result.jsonl" 2>"$WDIR/stderr.log" &
```

Wait — this is still `-p` mode. True interactive mode would be:

```bash
echo "$(cat "$WDIR/prompt.md")" | claude --permission-mode dontAsk 2>"$WDIR/stderr.log"
```

**Pros:**
- Full interactive TUI visible via `termlink attach`
- Human sees everything: tool calls, reasoning, file diffs, progress bars
- Natural experience — like watching someone work

**Cons:**
- **No reliable output capture** — interactive mode writes to the terminal, not a file. Would need `script` or PTY scraping to capture output
- **Signal handling complexity** — interactive `claude` handles SIGINT differently than `claude -p`
- **Permission prompts** — even with `dontAsk`, some prompts may appear that block the worker
- **Exit detection** — harder to know when interactive claude finishes (no clean EOF like `-p` mode)
- **ANSI escape codes** — output includes colors, cursor movement, etc. Capturing clean text requires stripping
- **macOS differences** — interactive terminal behavior varies between macOS and Linux

**Verdict:** Best UX for observation but worst for automation. The fundamental problem is that interactive mode is designed for humans, not scripts. Output capture becomes unreliable.

### Option D: Hybrid — `tee` + Progress File

**Change:** Keep `claude -p` but add a lightweight progress indicator via stderr or a sidecar.

```bash
# In run.sh:
claude -p "$(cat "$WDIR/prompt.md")" --output-format stream-json 2>"$WDIR/stderr.log" \
    | tee "$WDIR/stream.jsonl" \
    | python3 -c "
import sys, json
with open('$WDIR/result.md', 'w') as out:
    for line in sys.stdin:
        try:
            d = json.loads(line)
            t = d.get('type', '')
            if t == 'result':
                out.write(d.get('result', ''))
            elif t == 'tool_use':
                tool = d.get('tool', '')
                print(f'[{tool}]', flush=True)
        except: pass
" &
```

**Pros:**
- Observability: tool names visible in PTY via `termlink attach`
- Full stream captured in `stream.jsonl` for post-mortem
- Text result extracted from stream-json `result` message type
- `termlink pty output <session> --lines 20` shows recent tool calls

**Cons:**
- Most complex option (~15 lines of Python inline in bash)
- Depends on stream-json format stability
- Python process runs for duration of worker
- Two output files: `stream.jsonl` (full) + `result.md` (text extract)

**Verdict:** Best balance of observability and reliability, but highest implementation complexity.

## Tradeoff Matrix

| Factor | A: tee | B: stream-json | C: interactive | D: hybrid |
|--------|--------|----------------|----------------|-----------|
| Implementation effort | 1 line | ~20 lines | ~10 lines | ~15 lines |
| Observability (tool calls) | No | Yes | Yes | Yes |
| Observability (reasoning) | Partial | Partial | Yes | Partial |
| Output capture reliability | High | Medium | Low | High |
| Format change needed | No | Yes (JSONL) | Yes | Minimal |
| macOS compat risk | Low | Low | High | Low |
| Maintenance burden | None | Medium | High | Medium |

## Recommendation

**GO — implement Option A (tee) now, with Option D (hybrid) as a follow-up.**

### Rationale

1. **Option A is a 1-line change** that provides immediate, if limited, improvement. The human can at least see the final response streaming via `termlink attach`. This addresses the "complete blackout" problem from T-697.

2. **Option D is the real target** but should be a separate build task. The stream-json parse loop needs testing across Claude Code versions and macOS/Linux. It's bounded (< 1 session) but warrants its own task.

3. **Option C (interactive) is a NO-GO** — the output capture problem is fundamental. `claude -p` exists precisely because interactive mode isn't scriptable.

4. **Option B is Option D without the text extraction** — if we're going to parse stream-json, we should extract text too (Option D).

### Implementation plan (if GO)

**Phase 1 (Option A):** Change line 283 of `agents/termlink/termlink.sh`:
```bash
# Before:
claude -p "$(cat "$WDIR/prompt.md")" --output-format text > "$WDIR/result.md" 2>"$WDIR/stderr.log" &

# After:
claude -p "$(cat "$WDIR/prompt.md")" --output-format text 2>"$WDIR/stderr.log" | tee "$WDIR/result.md" &
```

**Phase 2 (Option D, separate task):** Replace `--output-format text` with `--output-format stream-json`, add Python parse loop that extracts tool call names to PTY and text result to `result.md`.

### Go/No-Go against criteria

- "An alternative exists that adds observability without breaking output capture reliability" — **YES** (Option A: tee preserves file capture)
- "Implementation is bounded (< 1 session)" — **YES** (Option A: 1 line. Option D: ~1 session)
- "Observability requires TermLink product changes we can't control" — **NO** (all options work with current TermLink)
