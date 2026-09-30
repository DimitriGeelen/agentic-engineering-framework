# T-3584: designer 0.14.0 re-pin, check (rung 1, parent session)

**VERDICT: GREEN.**
- Pull-at-tag designer-v0.14.0 from 832: the MANIFEST sha and bytes are self-consistent at the tag, and the sha matches both the new pin and 832's announce (0b5ae3a7…d3e6f2, 1043238 B).
- Served: GET /designer/app returns 200 with 1,043,238 bytes; the sha prefix 0b5ae3a7 matches the pin.
- Browser: the header shows v0.14.0; the aef-inception-flow map loads and renders; the new 0.14.0 surfaces are visible ("instances: unavailable", the Kind field). Screenshot: /tmp/playwright-mcp/review/designer-0.14.0.png.
- Console: exactly one error, the documented optional probe `/api/instances?template=…` returning 404 (832 @20: absence is a state, not a fault). No test asserts zero console errors on /designer, so nothing needs whitelisting.
- Retention: vendor/designer/ keeps every consumed build (unchanged behaviour); the shipped .agentic-framework copy carries only the pinned build (fw vendor self superseded 0.13.0).
