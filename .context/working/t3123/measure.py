"""T-3123 measurement harness — shell edge counts, raw and deduplicated.

Population: git-tracked *.sh excluding the vendored .agentic-framework/ mirror
(246 files, the figure the task baseline quotes).

Reports RAW (every tuple the shell detectors emit, summed over source files)
and DEDUP (unique source->target pairs). Reported together because on T-3122
the raw number alone read as a 54% regression that dedup inverted into a gain.
"""
import importlib.util, os, subprocess, sys

ROOT = "/opt/999-Agentic-Engineering-Framework"
spec = importlib.util.spec_from_file_location("m", ROOT + "/agents/fabric/lib/enrich.py")
enrich = importlib.util.module_from_spec(spec); sys.modules["m"] = enrich
spec.loader.exec_module(enrich)

cards, loc_to_id, _lc, _il, _ic = enrich.build_index(ROOT + "/.fabric/components")

tracked = [p for p in subprocess.run(["git", "-C", ROOT, "ls-files", "*.sh"],
                                     capture_output=True, text=True).stdout.split()
           if not p.startswith(".agentic-framework/")]
tracked = [p for p in tracked if os.path.isfile(os.path.join(ROOT, p))]
basenames = {os.path.basename(p) for p in tracked}

raw = 0
pairs = set()
per_file, no_source, invoke_only = {}, set(), []
for p in tracked:
    content = open(os.path.join(ROOT, p), errors="replace").read(2_000_000)
    edges = enrich.detect_bash_sources(content, p, ROOT)
    raw += len(edges)
    per_file[p] = {t for t, _ in edges}
    pairs.update((p, t) for t in per_file[p])
    has_source = any(True for _ in enrich._iter_source_args(content))
    refs = any(b in content for b in basenames if b != os.path.basename(p))
    if not has_source:
        no_source.add(p)
        if refs:
            invoke_only.append(p)

zero = [p for p in invoke_only if not per_file[p]]
carded_pairs = {(s, t) for s, t in pairs if s in loc_to_id and t in loc_to_id}

print(f"population (tracked .sh, no vendor):  {len(tracked)}")
print(f"no source/. statement:                {len(no_source)}")
print(f"invoke-only (no source, refs another):{len(invoke_only)}")
print(f"RAW shell edges:                      {raw}")
print(f"DEDUP (src,tgt) pairs:                {len(pairs)}")
print(f"DEDUP pairs both ends carded:         {len(carded_pairs)}")
print(f"files emitting >=1 edge:              {sum(1 for v in per_file.values() if v)}")
print(f"invoke-only files WITH edges:         {len(invoke_only) - len(zero)}")
print(f"invoke-only files ZERO edges:         {len(zero)}")
with open(ROOT + "/.context/working/t3123/zero-edge.txt", "w") as f:
    f.write("\n".join(sorted(zero)) + "\n")

no_source_with_edges = sum(1 for p in sorted(no_source) if per_file[p])
print(f"no-source files WITH edges:           {no_source_with_edges}  (of {len(no_source)})")
with open(ROOT + "/.context/working/t3123/pairs.txt", "w") as f:
    f.write("\n".join(f"{s} -> {t}" for s, t in sorted(pairs)) + "\n")
