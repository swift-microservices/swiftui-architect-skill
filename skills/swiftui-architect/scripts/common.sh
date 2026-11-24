# Shared by check_boundaries.sh and check_style.sh, which load it with `.`; not run on its own.
# shellcheck shell=bash

# The scripts that load this file read it to choose their exit status.
# shellcheck disable=SC2034
failed=0

# report <rule> <failures>: prints the rule and its failures, if it has any.
report() {
    if [ -n "$2" ]; then
        echo "FAIL $1"
        printf '%s\n' "$2" | sed 's/^/  /'
        failed=1
    fi
}
