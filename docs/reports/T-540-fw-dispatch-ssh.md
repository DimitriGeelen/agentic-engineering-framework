# T-540: fw dispatch SSH-based cross-machine communication

## Finding
TermLink handles cross-terminal communication on a single machine. For cross-machine scenarios (dev laptop to build server), SSH-based dispatch reuses existing infrastructure. Implementation: serialize bus envelope as JSON, pipe via SSH to `fw bus receive` on remote.

## Decision: GO — implement fw dispatch send/hosts using SSH transport to remote fw bus
