#!/usr/bin/env python3
"""Component Reference Doc Generator — generates markdown from fabric cards."""

import yaml
import os
import re
import glob
import sys


def extract_source_header(src_path, max_lines=10):
    """Extract description from source file header comments."""
    if not src_path or not os.path.isfile(src_path):
        return ""
    with open(src_path) as f:
        lines = f.readlines()[:40]
    header_lines = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("#!"):
            continue
        if stripped.startswith("# ====") or stripped.startswith("# ---"):
            continue
        if stripped.startswith("# ") and not stripped.startswith("# shellcheck"):
            header_lines.append(stripped.lstrip("# ").rstrip())
        elif header_lines and not stripped.startswith("#"):
            break
    return "\n".join(header_lines[:max_lines])


def extract_claude_section(claude_md_path, name, location):
    """Find matching section in CLAUDE.md for this component."""
    if not os.path.isfile(claude_md_path):
        return ""
    with open(claude_md_path) as f:
        content = f.read()

    search_terms = [name]
    if location:
        search_terms.append(os.path.basename(location))

    for term in search_terms:
        pattern = re.compile(
            r"^###?\s+.*" + re.escape(term) + r".*$",
            re.MULTILINE | re.IGNORECASE,
        )
        match = pattern.search(content)
        if not match:
            continue

        heading_level = len(match.group().split()[0])
        rest = content[match.end():]
        end_pattern = re.compile(r"^#{1," + str(heading_level) + r"}\s", re.MULTILINE)
        end_match = end_pattern.search(rest)
        section = rest[: end_match.start()].strip() if end_match else rest[:500].strip()

        # Ensure code fences are balanced
        fence_count = section.count("```")
        if fence_count % 2 != 0:
            last_fence = section.rfind("```")
            section = section[:last_fence].strip()

        # Trim to reasonable size
        if len(section) > 600:
            cut = section[:600].rfind("\n\n")
            if cut > 300:
                section = section[:cut].strip()
            else:
                section = section[:600].strip()
            fence_count = section.count("```")
            if fence_count % 2 != 0:
                last_fence = section.rfind("```")
                section = section[:last_fence].strip()
            section += "\n\n*(truncated — see CLAUDE.md for full section)*"

        return section
    return ""


def find_related_tasks(episodic_dir, location, limit=5):
    """Find episodic entries mentioning this component's location."""
    related = []
    if not os.path.isdir(episodic_dir):
        return related
    for ep_file in sorted(glob.glob(os.path.join(episodic_dir, "T-*.yaml")))[-200:]:
        try:
            with open(ep_file) as f:
                ep = yaml.safe_load(f)
            if not ep:
                continue
            artifacts = ep.get("artifacts", []) or []
            if isinstance(artifacts, dict):
                artifacts = list(artifacts.keys())
            for art in artifacts:
                if isinstance(art, str) and location and location in art:
                    tid = ep.get("task_id", "")
                    tname = ep.get("task_name", "")
                    related.append(f"{tid}: {tname}")
                    break
        except Exception:
            continue
    return related[-limit:]


def find_related_learnings(learnings_file, tags, name, limit=5):
    """Find learnings matching this component's tags or name."""
    related = []
    if not os.path.isfile(learnings_file):
        return related
    try:
        with open(learnings_file) as f:
            data = yaml.safe_load(f)
        for learning in data or []:
            if not isinstance(learning, dict):
                continue
            ltags = learning.get("tags", []) or []
            ldesc = str(learning.get("description", ""))
            lid = learning.get("id", "")
            if any(t in ltags for t in tags) or name.lower() in ldesc.lower():
                related.append(f"{lid}: {ldesc[:80]}")
    except Exception:
        pass
    return related[:limit]


def generate_doc(card_path, framework_root, output_dir):
    """Generate a reference doc for a single component card."""
    with open(card_path) as f:
        card = yaml.safe_load(f)

    if not card:
        return None

    card_name = os.path.basename(card_path).replace(".yaml", "")
    name = card.get("name", "Unknown")
    ctype = card.get("type", "unknown")
    subsystem = card.get("subsystem", "unknown")
    location = card.get("location", "")
    purpose = card.get("purpose", "No purpose documented")
    tags = card.get("tags", []) or []
    depends_on = card.get("depends_on", []) or []
    depended_by = card.get("depended_by", []) or []
    docs = card.get("docs", []) or []
    last_verified = card.get("last_verified", "")

    claude_md = os.path.join(framework_root, "CLAUDE.md")
    episodic_dir = os.path.join(framework_root, ".context", "episodic")
    learnings_file = os.path.join(framework_root, ".context", "project", "learnings.yaml")
    src_path = os.path.join(framework_root, location) if location else ""

    source_header = extract_source_header(src_path)
    claude_section = extract_claude_section(claude_md, name, location)
    related_tasks = find_related_tasks(episodic_dir, location)
    related_learnings = find_related_learnings(learnings_file, tags, name)

    # Build markdown
    out = []
    out.append(f"# {name}")
    out.append("")
    out.append(f"> {purpose}")
    out.append("")
    out.append(f"**Type:** {ctype} | **Subsystem:** {subsystem} | **Location:** `{location}`")
    out.append("")
    if tags:
        out.append("**Tags:** " + ", ".join(f"`{t}`" for t in tags))
        out.append("")

    # What It Does
    out.append("## What It Does")
    out.append("")
    if source_header:
        out.append(source_header)
        out.append("")
    if claude_section:
        out.append("### Framework Reference")
        out.append("")
        out.append(claude_section)
        out.append("")

    # Dependencies
    if depends_on:
        out.append(f"## Dependencies ({len(depends_on)})")
        out.append("")
        out.append("| Target | Relationship |")
        out.append("|--------|-------------|")
        for dep in depends_on:
            if isinstance(dep, dict):
                target = dep.get("target", "?")
                dtype = dep.get("type", "uses")
                out.append(f"| `{target}` | {dtype} |")
        out.append("")

    if depended_by:
        out.append(f"## Used By ({len(depended_by)})")
        out.append("")
        out.append("| Component | Relationship |")
        out.append("|-----------|-------------|")
        for dep in depended_by:
            if isinstance(dep, dict):
                target = dep.get("target", "?")
                dtype = dep.get("type", "used_by")
                out.append(f"| `{target}` | {dtype} |")
        out.append("")

    # Documentation
    if docs:
        out.append("## Documentation")
        out.append("")
        for doc in docs:
            title = doc.get("title", doc.get("path", ""))
            path = doc.get("path", "")
            dtype = doc.get("type", "")
            out.append(f"- [{title}]({path})" + (f" ({dtype})" if dtype else ""))
        out.append("")

    # Related
    if related_tasks or related_learnings:
        out.append("## Related")
        out.append("")
        if related_tasks:
            out.append("### Tasks")
            for t in related_tasks:
                out.append(f"- {t}")
            out.append("")
        if related_learnings:
            out.append("### Learnings")
            for le in related_learnings:
                out.append(f"- {le}")
            out.append("")

    # Footer
    out.append("---")
    out.append(f"*Auto-generated from Component Fabric. Card: `{card_name}.yaml`*")
    if last_verified:
        out.append(f"*Last verified: {last_verified}*")

    output_path = os.path.join(output_dir, f"{card_name}.md")
    with open(output_path, "w") as of:
        of.write("\n".join(out) + "\n")

    return card_name


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: generate_component.py <card_path> <framework_root> <output_dir>")
        sys.exit(1)

    card_path = sys.argv[1]
    framework_root = sys.argv[2]
    output_dir = sys.argv[3]

    result = generate_doc(card_path, framework_root, output_dir)
    if result:
        print(f"  {result}.md")
