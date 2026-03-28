#!/bin/bash
# fw first-run — Guided walkthrough after fw init
#
# Shows the user the key framework commands by running them one at a time.
# Opt-out: fw init --no-first-run
#
# Steps:
#   1. fw doctor (verify setup)
#   2. fw context init (start session)
#   3. Explain next steps (create task, commit, audit, handover)

# Colors (inherited from caller, but define fallbacks)
RED="${RED:-\033[0;31m}"
GREEN="${GREEN:-\033[0;32m}"
YELLOW="${YELLOW:-\033[1;33m}"
CYAN="${CYAN:-\033[0;36m}"
BOLD="${BOLD:-\033[1m}"
NC="${NC:-\033[0m}"

do_first_run() {
    local target_dir="${1:-.}"

    echo ""
    echo -e "${BOLD}=== First Run Walkthrough ===${NC}"
    echo ""
    echo "Let's verify your setup and get you started."
    echo ""

    # Step 1: Doctor
    echo -e "${CYAN}Step 1/3:${NC} Checking framework health..."
    echo -e "  Running: ${BOLD}fw doctor${NC}"
    echo ""
    (cd "$target_dir" && fw doctor 2>&1) | sed 's/^/  /'
    echo ""

    # Step 2: Context init
    echo -e "${CYAN}Step 2/3:${NC} Initializing your first session..."
    echo -e "  Running: ${BOLD}fw context init${NC}"
    echo ""
    (cd "$target_dir" && fw context init 2>&1) | sed 's/^/  /'
    echo ""

    # Step 3: What to do next
    echo -e "${CYAN}Step 3/3:${NC} You're ready to work!"
    echo ""
    echo "  Start your first task:"
    echo -e "    ${GREEN}fw work-on 'Your task name' --type build${NC}"
    echo ""
    echo "  When you're done working:"
    echo -e "    ${GREEN}fw handover --commit${NC}"
    echo ""
    echo "  Useful commands:"
    echo "    fw help          Show all commands"
    echo "    fw audit         Check compliance"
    echo "    fw doctor        Health check"
    echo ""
    echo -e "${GREEN}Setup complete.${NC} Happy building!"
}

# Allow sourcing or direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    do_first_run "$@"
fi
