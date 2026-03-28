# T-538: Fix phantom aef binary name

## Finding
install.sh referenced an `aef` binary that was never built or shipped. The actual binary is `fw`. Post-install verification checked for `aef` and silently passed even when the real binary wasn't on PATH.

## Decision: GO — rename all references to `fw`, add 3-step post-install verification
