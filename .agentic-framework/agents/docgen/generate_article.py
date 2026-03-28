#!/usr/bin/env python3
"""Subsystem Article Generator — assembles context from fabric + source + episodic,
then generates a deep-dive article prompt or calls Ollama directly.

Usage:
    python3 generate_article.py <subsystem> <framework_root> [--generate]

Without --generate: writes a prompt file to docs/generated/articles/{subsystem}-prompt.md
With --generate: calls Ollama to produce the article in docs/articles/deep-dives/
"""

import yaml
import os
import re
import glob
import sys


def load_subsystem_cards(components_dir, subsystem):
    """Load all component cards for a subsystem."""
    cards = []
    for card_file in sorted(glob.glob(os.path.join(components_dir, "*.yaml"))):
        try:
            with open(card_file) as f:
                card = yaml.safe_load(f)
            if card and card.get("subsystem") == subsystem:
                cards.append(card)
        except Exception:
            continue
    return cards


def extract_source_headers(framework_root, cards, max_per_card=5):
    """Extract source file headers for key components."""
    headers = {}
    for card in cards:
        loc = card.get("location", "")
        if not loc:
            continue
        src_path = os.path.join(framework_root, loc)
        if not os.path.isfile(src_path):
            continue
        with open(src_path) as f:
            lines = f.readlines()[:50]
        header_lines = []
        in_docstring = False
        for line in lines:
            stripped = line.strip()
            if stripped.startswith("#!"):
                continue
            if stripped.startswith("# ====") or stripped.startswith("# ---"):
                continue
            if stripped.startswith('"""') or stripped.startswith("'''"):
                if in_docstring:
                    break
                in_docstring = True
                text = stripped.strip("\"'").strip()
                if text:
                    header_lines.append(text)
                continue
            if in_docstring:
                if stripped.endswith('"""') or stripped.endswith("'''"):
                    text = stripped.strip("\"'").strip()
                    if text:
                        header_lines.append(text)
                    break
                header_lines.append(stripped)
            elif stripped.startswith("# ") and not stripped.startswith("# shellcheck"):
                header_lines.append(stripped.lstrip("# ").rstrip())
            elif header_lines and not stripped.startswith("#"):
                break
        if header_lines:
            headers[card.get("name", loc)] = "\n".join(header_lines[:max_per_card])
    return headers


def extract_claude_section(claude_md_path, subsystem):
    """Find CLAUDE.md section matching the subsystem name."""
    if not os.path.isfile(claude_md_path):
        return ""
    with open(claude_md_path) as f:
        content = f.read()

    # Try matching subsystem name variants
    search_terms = [
        subsystem.replace("-", " ").title(),
        subsystem.replace("-", " "),
        subsystem,
    ]
    for term in search_terms:
        pattern = re.compile(
            r"^###?\s+.*" + re.escape(term) + r".*$",
            re.MULTILINE | re.IGNORECASE,
        )
        match = pattern.search(content)
        if not match:
            continue

        heading_level = len(match.group().split()[0])
        start = match.start()
        rest = content[match.end():]
        end_pattern = re.compile(r"^#{1," + str(heading_level) + r"}\s", re.MULTILINE)
        end_match = end_pattern.search(rest)
        section = rest[:end_match.start()].strip() if end_match else rest[:2000].strip()

        # Balance code fences
        fence_count = section.count("```")
        if fence_count % 2 != 0:
            last_fence = section.rfind("```")
            section = section[:last_fence].strip()

        # Cap at 2000 chars for prompt context
        if len(section) > 2000:
            cut = section[:2000].rfind("\n\n")
            section = section[:cut].strip() if cut > 500 else section[:2000].strip()
            fence_count = section.count("```")
            if fence_count % 2 != 0:
                last_fence = section.rfind("```")
                section = section[:last_fence].strip()

        return section
    return ""


def find_subsystem_episodic(episodic_dir, cards, limit=10):
    """Find episodic entries related to subsystem components."""
    locations = {c.get("location", "") for c in cards if c.get("location")}
    tags = set()
    for c in cards:
        for t in c.get("tags", []) or []:
            tags.add(t)

    entries = []
    if not os.path.isdir(episodic_dir):
        return entries

    for ep_file in sorted(glob.glob(os.path.join(episodic_dir, "T-*.yaml")))[-200:]:
        try:
            with open(ep_file) as f:
                ep = yaml.safe_load(f)
            if not ep:
                continue

            # Match by artifacts or tags
            artifacts = ep.get("artifacts", []) or []
            if isinstance(artifacts, dict):
                artifacts = list(artifacts.keys())
            ep_tags = ep.get("tags", []) or []

            matched = False
            for art in artifacts:
                if isinstance(art, str) and any(loc and loc in art for loc in locations):
                    matched = True
                    break
            if not matched and any(t in tags for t in ep_tags):
                matched = True

            if matched:
                tid = ep.get("task_id", "")
                tname = ep.get("task_name", "")
                summary = ep.get("summary", "").strip()[:120]
                entries.append({"id": tid, "name": tname, "summary": summary})
        except Exception:
            continue

    return entries[-limit:]


def find_subsystem_learnings(learnings_file, cards, limit=8):
    """Find learnings related to subsystem."""
    tags = set()
    names = set()
    for c in cards:
        for t in c.get("tags", []) or []:
            tags.add(t)
        names.add(c.get("name", "").lower())

    learnings = []
    if not os.path.isfile(learnings_file):
        return learnings

    try:
        with open(learnings_file) as f:
            data = yaml.safe_load(f)
        for learning in data or []:
            if not isinstance(learning, dict):
                continue
            ltags = learning.get("tags", []) or []
            ldesc = str(learning.get("description", ""))
            lid = learning.get("id", "")
            if any(t in ltags for t in tags) or any(n in ldesc.lower() for n in names if n):
                learnings.append(f"{lid}: {ldesc[:100]}")
    except Exception:
        pass
    return learnings[:limit]


def find_subsystem_decisions(decisions_file, cards, limit=5):
    """Find decisions related to subsystem."""
    tags = set()
    for c in cards:
        for t in c.get("tags", []) or []:
            tags.add(t)

    decisions = []
    if not os.path.isfile(decisions_file):
        return decisions

    try:
        with open(decisions_file) as f:
            data = yaml.safe_load(f)
        for dec in data or []:
            if not isinstance(dec, dict):
                continue
            dtags = dec.get("tags", []) or []
            ddesc = str(dec.get("decision", ""))
            did = dec.get("id", "")
            if any(t in dtags for t in tags):
                rationale = dec.get("rationale", "")[:80]
                decisions.append(f"{did}: {ddesc[:80]} — {rationale}")
    except Exception:
        pass
    return decisions[:limit]


def load_style_reference(deep_dives_dir):
    """Load first existing deep-dive as style reference."""
    for dd_file in sorted(glob.glob(os.path.join(deep_dives_dir, "*.md")))[:1]:
        try:
            with open(dd_file) as f:
                return f.read()[:3000]
        except Exception:
            pass
    return ""


def count_existing_deep_dives(deep_dives_dir):
    """Count existing deep-dive articles to determine the next number."""
    return len(glob.glob(os.path.join(deep_dives_dir, "*.md")))


def build_prompt(subsystem, cards, source_headers, claude_section,
                 episodic_entries, learnings, decisions, style_ref, article_num):
    """Assemble the full prompt for the LLM."""
    prompt = []

    prompt.append("You are writing a deep-dive article about a subsystem in the Agentic Engineering Framework.")
    prompt.append("Follow the exact structure and tone of the style reference below.")
    prompt.append("")

    # Style reference
    if style_ref:
        prompt.append("## STYLE REFERENCE (follow this structure exactly)")
        prompt.append("")
        prompt.append(style_ref)
        prompt.append("")
        prompt.append("---")
        prompt.append("")

    # Subsystem overview
    prompt.append(f"## SUBSYSTEM: {subsystem}")
    prompt.append(f"Components: {len(cards)}")
    prompt.append("")

    prompt.append("### Components")
    for card in cards:
        name = card.get("name", "?")
        ctype = card.get("type", "?")
        purpose = card.get("purpose", "")
        loc = card.get("location", "")
        deps = len(card.get("depends_on", []) or [])
        depby = len(card.get("depended_by", []) or [])
        prompt.append(f"- **{name}** ({ctype}) @ `{loc}` — {purpose} [{deps} deps, {depby} dependents]")
    prompt.append("")

    # Source headers
    if source_headers:
        prompt.append("### Source Code Headers (key components)")
        for name, header in list(source_headers.items())[:6]:
            prompt.append(f"\n**{name}:**")
            prompt.append(f"```\n{header}\n```")
        prompt.append("")

    # CLAUDE.md section
    if claude_section:
        prompt.append("### Framework Documentation (CLAUDE.md)")
        prompt.append(claude_section)
        prompt.append("")

    # Episodic memory
    if episodic_entries:
        prompt.append("### Task History (episodic memory)")
        for ep in episodic_entries:
            prompt.append(f"- **{ep['id']}**: {ep['name']} — {ep['summary']}")
        prompt.append("")

    # Learnings
    if learnings:
        prompt.append("### Learnings")
        for le in learnings:
            prompt.append(f"- {le}")
        prompt.append("")

    # Decisions
    if decisions:
        prompt.append("### Architectural Decisions")
        for dec in decisions:
            prompt.append(f"- {dec}")
        prompt.append("")

    # Instructions
    prompt.append("---")
    prompt.append("")
    prompt.append("## INSTRUCTIONS")
    prompt.append("")
    prompt.append(f"Write Deep Dive #{article_num}: {subsystem.replace('-', ' ').title()}")
    prompt.append("")
    prompt.append("Follow the EXACT structure from the style reference:")
    prompt.append("1. **Title** — SEO-friendly, under 70 chars")
    prompt.append("2. **Post Body** opening — universal governance principle (ISO, programme management, clinical) → transition to AI agents → problem statement")
    prompt.append("3. **How it works** — mechanism explanation with code/YAML examples from the source headers above")
    prompt.append("4. **Why / Research section** — cite specific task IDs from the episodic memory, quantified findings, decision rationale")
    prompt.append("5. **Try it** — installation command + usage example")
    prompt.append("6. **Platform Notes** — Dev.to/LinkedIn/Reddit guidance")
    prompt.append("7. **Hashtags** — relevant tags")
    prompt.append("")
    prompt.append("Rules:")
    prompt.append("- Write in first person (\"I built\", \"I discovered\")")
    prompt.append("- Cite real task IDs (T-XXX) from the episodic data")
    prompt.append("- Include at least one code/config example from the source headers")
    prompt.append("- Opening analogy must come from a real-world governance domain")
    prompt.append("- No emojis, no exclamation marks, no \"we\"")
    prompt.append("- Tone: peer-to-peer technical discussion, not a product pitch")

    return "\n".join(prompt)


def generate_article_via_ollama(prompt, model="qwen3:14b"):
    """Call Ollama to generate the article."""
    try:
        import ollama
    except ImportError:
        print("ERROR: ollama package not installed. Run: pip install ollama", file=sys.stderr)
        return None

    try:
        response = ollama.chat(
            model=model,
            messages=[{"role": "user", "content": prompt}],
            options={"temperature": 0.7, "num_predict": 4096},
        )
        content = response.get("message", {}).get("content", "")
        # Strip thinking tags if present (Qwen3 thinking mode)
        content = re.sub(r"<think>.*?</think>", "", content, flags=re.DOTALL).strip()
        return content
    except Exception as e:
        print(f"ERROR: Ollama call failed: {e}", file=sys.stderr)
        return None


def main():
    if len(sys.argv) < 3:
        print("Usage: generate_article.py <subsystem> <framework_root> [--generate]")
        print("  Without --generate: writes prompt file only")
        print("  With --generate: calls Ollama to produce article")
        sys.exit(1)

    subsystem = sys.argv[1]
    framework_root = sys.argv[2]
    do_generate = "--generate" in sys.argv

    components_dir = os.path.join(framework_root, ".fabric", "components")
    episodic_dir = os.path.join(framework_root, ".context", "episodic")
    learnings_file = os.path.join(framework_root, ".context", "project", "learnings.yaml")
    decisions_file = os.path.join(framework_root, ".context", "project", "decisions.yaml")
    claude_md = os.path.join(framework_root, "CLAUDE.md")
    deep_dives_dir = os.path.join(framework_root, "docs", "articles", "deep-dives")
    prompt_dir = os.path.join(framework_root, "docs", "generated", "articles")

    # Load data
    cards = load_subsystem_cards(components_dir, subsystem)
    if not cards:
        print(f"ERROR: No components found for subsystem '{subsystem}'", file=sys.stderr)
        available = set()
        for f in glob.glob(os.path.join(components_dir, "*.yaml")):
            try:
                with open(f) as fh:
                    d = yaml.safe_load(fh)
                if d:
                    available.add(d.get("subsystem", "unknown"))
            except Exception:
                pass
        print(f"Available subsystems: {', '.join(sorted(available))}", file=sys.stderr)
        sys.exit(1)

    source_headers = extract_source_headers(framework_root, cards)
    claude_section = extract_claude_section(claude_md, subsystem)
    episodic_entries = find_subsystem_episodic(episodic_dir, cards)
    learnings = find_subsystem_learnings(learnings_file, cards)
    decisions = find_subsystem_decisions(decisions_file, cards)
    style_ref = load_style_reference(deep_dives_dir)
    article_num = count_existing_deep_dives(deep_dives_dir) + 1

    # Build prompt
    prompt = build_prompt(
        subsystem, cards, source_headers, claude_section,
        episodic_entries, learnings, decisions, style_ref, article_num,
    )

    # Always write prompt file
    os.makedirs(prompt_dir, exist_ok=True)
    prompt_path = os.path.join(prompt_dir, f"{subsystem}-prompt.md")
    with open(prompt_path, "w") as f:
        f.write(prompt + "\n")
    print(f"Prompt written: {prompt_path}")

    if do_generate:
        print(f"Calling Ollama to generate article...")
        article = generate_article_via_ollama(prompt)
        if article:
            slug = f"{article_num:02d}-{subsystem}.md"
            article_path = os.path.join(deep_dives_dir, slug)
            os.makedirs(deep_dives_dir, exist_ok=True)
            with open(article_path, "w") as f:
                f.write(article + "\n")
            print(f"Article written: {article_path}")
        else:
            print("Generation failed — use the prompt file manually", file=sys.stderr)
            sys.exit(1)
    else:
        print("Use --generate to call Ollama, or use the prompt file with your preferred LLM")


if __name__ == "__main__":
    main()
