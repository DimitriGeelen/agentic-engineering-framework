# T-4832 — GET /api/field-catalog: sizing and design consultation

**Why this exists.** On 2026-10-27 the operator said: "I really want this functionality to be implemented but also want to do it in a right, sensible, usable and consistent way." The operator was unsure whether about 1,300 attributes is "a lot". Two independent views were gathered before building.

**Contract.** 832 `docs/reports/T-1312-field-catalog-contract.md`, also summarised in `docs/reports/T-4737-designer-data-apis.md`:
- **Request:** GET with no input.
- **200:** `{ok:true, catalog:{version:1, attributes:[{ref, notation, label, system, systemLabel, entity, dataType, keyRole, sources, …}]}}`, the file served unchanged.
- **404:** `{ok:false, error:"no field catalog"}`.
- **422:** the file is malformed, refused whole.
- **Source:** the file is a server setting, never part of the request.
- **Consumer:** designer 0.30.0's ref picker under the io editor. Absence means no picker, and the editor stays as today.

## 832: measured with designer 0.30.0's own filter code (msg ec29ccf0)

On 1,294 synthetic rows in the v1 shape (greenfield's real file is the same size):

| Rows | Raw | Gzipped | Parse | Search per keystroke |
|---:|---:|---:|---:|---:|
| 1,294 | 309 KB | 20 KB | 1 ms | 0.3 ms (max 1.2) |
| 10,000 | 2.4 MB | 149 KB | 16 ms | 2 ms (max 5) |
| 100,000 | 24 MB | 1.5 MB | 89 ms | 21 ms (max 24) |

**How the designer uses it:** it fetches once per page load (`cache: 'no-store'`), then filters linearly per keystroke: every typed word must occur in notation, label or ref, case-insensitive. It shows at most 8 hits, plus "N more".

**832's suggestions:**
- Answer gzip when the client accepts it.
- State a soft ceiling (about 20k rows or 5 MB) beyond which a future `?q=…&limit=8` server-search mode is expected.
- Put no hard cap in the contract, because a cap would refuse a project's own data.

## Codex: independent review

Review dispatch cx4737-0e2a4b8f9018. It ran read-only, and its cost is logged in `.context/costs/reviews.jsonl`. Its payload estimates (0.4–1 MB raw) are larger than 832's measurement; the measured figures win.

**Scale:**
- About 1,300 rows is comfortably small.
- Move to server-side search when *measured* startup or search latency demands it, not at a row count.
- Server search must rank the whole catalog, because pagination does not solve searching rows the browser never loaded.

**Validation:**
- Validate the whole file before serving: version 1, an attributes array, every row an object, every ref a non-blank string.
- Preserve unknown fields.
- Refuse missing refs and duplicate exact refs (422). Never silently drop, merge or repair rows.
- Ref identity stays case-sensitive.

**Size:** bound the read before parsing, with a documented, configurable limit (suggested 10 MiB). An oversized file is refused whole, never truncated.

**HTTP:**
- Gzip with `Vary: Accept-Encoding`.
- Optionally cache the validated, serialized content per project and path, invalidated by mtime, size and file identity, with an ETag from a content hash.
- Caveat: a body-less 304 must never reach the designer's "200 only" gate.

**Consistency with the sibling route:**
- Today `/api/lens-definition` answers 500 for both a missing and a malformed file, so the contract's 404/422 split is a deliberate divergence. Keep the contract, and document the difference.
- Resolve the config from `PROJECT_ROOT/.framework.yaml` (project data), never `FRAMEWORK_ROOT`.

**Safety:**
- Keep the resolved path inside the project root, symlinks included.
- Keep filesystem details out of error messages.
- Serving the whole catalog exposes every field, `sources` included, to dashboard users. Confirm with the project that it holds nothing sensitive.

**Picker usability (832's side):**
- Rank exact ref/notation first, then prefix, then substring.
- Normalise case and diacritics for search only.
- Show systemLabel or entity to tell apart equal labels.
- Support keyboard use and accessible states.

## Resolution: what T-4832 builds

Where the two views differ, this is how they are reconciled:
- **Hard cap vs soft ceiling.** The contract gets no hard cap (832). The server applies a *bounded read* as a resource safety limit (Codex): a configurable setting, defaulting to 10 MiB, which is about 4× the 10k-row size. An oversized file gets a 422 naming the limit, without filesystem details. The soft ceiling (about 20k rows / 5 MB) is documented as the point to ask 832 for server search.
- **Duplicate and missing refs.** These are refused (422 for the whole file). The contract's "malformed, refused whole" covers them. 832 has been told so it can confirm.

**Must-have, in this task:**
- a config key in the project's `.framework.yaml` (proposed `DESIGNER_FIELD_CATALOG`), a path relative to the project root, confined to the root;
- 404 when unset or missing;
- the bounded read;
- full structural validation (version, attributes array, row objects, non-blank unique refs);
- the file content served unchanged;
- gzip when accepted;
- errors without filesystem details;
- the config key registered (registry parity);
- tests, including the absence case the designer relies on.

**Nice-to-have, not in this task:** a validated-content cache with an ETag, after checking the 304 path against the designer.

**Only if it grows:** a server-side `?q=&limit=` mode, added to the contract with 832.
