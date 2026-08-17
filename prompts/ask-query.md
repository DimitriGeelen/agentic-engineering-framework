# fw ask — provenance record

`fw ask` answers synchronously in the calling process — it never spawns a
worker from this dispatch. This template exists only because
`resolver.assemble_prompt()` requires a `prompt_template` for every workflow
(ADR-0002: inline workflows cannot reach the resolver at all, and `ask` must
reach it — its whole point is to capture the routing decision). The rendered
text below is stored as the dispatch blob for provenance; nothing reads it
back to drive execution.

Query: $QUERY
Route: $ROUTE
