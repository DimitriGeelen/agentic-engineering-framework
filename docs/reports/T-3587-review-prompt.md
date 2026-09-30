You are an INDEPENDENT REVIEWER (not the builder). EVALUATE, do not rubber-stamp. Verdicts: green / amber / red / escalate, each with mandatory guidance. Repo /opt/999-Agentic-Engineering-Framework: read-only EXCEPT your one report file. No commits, no fw task verbs.

Task T-3587 made evidence references on review pages into working links. The operator's words: "I need the full URLs generated dynamically with the port number right and the path the project is in ... especially in the evidence section." Read the spec (.tasks/active/T-3587-*.md) and the builder's commits (`git show e7d05fd01 7866e6058 --stat`, then the diff of web/shared.py, web/blueprints/docs.py, web/blueprints/approvals.py, web/static/css/file-refs.css).

Evidence (open with Read):
- /tmp/playwright-mcp/review/t3587-review-evidence.png: /review/T-3581, around its Evidence section
- /tmp/playwright-mcp/review/t3587-file-line.png: /file/web/shared.py#L640 (should land on line 640)
Live: http://192.168.10.107:3002/review/T-3581, http://192.168.10.107:3002/approvals, http://192.168.10.107:3002/inception/T-3576, http://192.168.10.107:3002/file/web/shared.py#L640 (curl them).

Judge:
1. Do the evidence and recommendation references on those pages link, and do the links open the right file (curl a sample of the /file/ hrefs: 200, and the right content)?
2. Are dead references visibly different from live ones, and do they read sensibly rather than as errors to the operator?
3. Does `path:NNN` land on the line?
4. Did the renderer changes break anything visible: brace-group text readable, no nested or garbled anchors, code blocks intact, italics still working in normal prose?
5. Absolute URLs outside Watchtower: do `bin/fw task review T-3581` and `bin/fw watchtower url` print the right host and port?

Write docs/reports/T-3587-render-review.md with VERDICT, WHAT I CHECKED, GUIDANCE. Print only the verdict line.
