#!/usr/bin/env bash
#
# Checks the style rules a script can see in a modular SwiftUI app's own code: its packages'
# sources and the app's, leaving out tests and build products. Run it from the app's
# repository root, beside Packages/, with no arguments:
#
#     check_style.sh
#
# Prints each failure under the rule it breaks, lists under REVIEW what needs a person's
# judgment, and exits 1 if any rule fails.

# The awk programs are single-quoted so that awk, not the shell, reads their fields.
# shellcheck disable=SC2016

set -u

if [ "$#" -ne 0 ]; then
    echo "usage: check_style.sh, from the app's repository root" >&2
    exit 2
fi

if [ ! -d Packages ]; then
    echo "check_style.sh runs from the app's repository root, beside Packages/" >&2
    exit 2
fi

# shellcheck source-path=SCRIPTDIR source=common.sh
. "$(dirname "$0")/common.sh"

# owned_files: the app's own Swift files, one per line, leaving out tests, build products
# and dependencies' checkouts.
owned_files() {
    find . \( -name .build -o -name .git -o -name .swiftpm -o -name DerivedData -o -name SourcePackages \
        -o -name Tests -o -name '*Tests' \) -prune -o -type f -name '*.swift' -print | sed 's|^\./||' | sort
}

# domain_files: the Swift files of the targets that hold no views: XCore, Shared, adapter
# targets and Networking, which is every package target but a UI target or DesignSystem's.
domain_files() {
    printf '%s\n' "$files" | grep '^Packages/[^/]*/Sources/' | grep -v '^Packages/DesignSystem/' |
        grep -vE '^Packages/[^/]*/Sources/[^/]*UI/'
}

# run_awk <program> <files>: runs the program over the files, if there are any.
run_awk() {
    [ -n "$2" ] || return 0
    printf '%s\n' "$2" | tr '\n' '\0' | xargs -0 awk "$1"
}

# lines <pattern> <files>: prints file:line: text for each line of the files matching the
# pattern, outside string literals and comments.
lines() {
    [ -n "$2" ] || return 0
    printf '%s\n' "$2" | tr '\n' '\0' | xargs -0 awk -v pattern="$1" '
        {
            code = $0
            gsub(/"([^"\\]|\\.)*"/, "\"\"", code)
            sub(/\/\/.*$/, "", code)
            if (code ~ pattern) {
                text = $0
                sub(/^[[:space:]]+/, "", text)
                print FILENAME ":" FNR ": " text
            }
        }
    '
}

files=$(owned_files)

# Joins a call's wrapped arguments and finds a try or await that starts an argument.
effects_in_arguments='
function flush() {
    if (joined ~ /(\(|[A-Za-z0-9_]: |, )(try|await) /) {
        print file ":" start ": " joined
    }
    joined = ""
}
FNR == 1 { flush(); in_string = 0 }
{
    line = $0
    quotes = gsub(/"""/, "&", line)
    if (quotes % 2 == 1) { in_string = !in_string; flush(); next }
    if (in_string) next

    code = $0
    gsub(/"([^"\\]|\\.)*"/, "\"\"", code)
    sub(/\/\/.*$/, "", code)
    sub(/^[[:space:]]+/, "", code)
    sub(/[[:space:]]+$/, "", code)

    if (joined != "" && (joined ~ /[(,]$/ || code ~ /^\)/)) {
        separator = (joined ~ /\($/ || code ~ /^\)/) ? "" : " "
        joined = joined separator code
    } else {
        flush()
        joined = code
        file = FILENAME
        start = FNR
    }
}
END { flush() }
'

report "Build, then call: no try or await inside a call's arguments" "$(
    run_awk "$effects_in_arguments" "$files"
)"

# The types declared at a file's top level, outside multi-line strings, but private ones,
# which a small helper view may be.
top_level_types='
function finish() {
    if (count > 1) print file ": " names
    count = 0
    names = ""
}
FNR == 1 { finish(); in_string = 0; file = FILENAME }
{
    line = $0
    quotes = gsub(/"""/, "&", line)
    if (quotes % 2 == 1) { in_string = !in_string; next }
    if (in_string) next

    if ($0 ~ /^((@[A-Za-z]+(\([^)]*\))?|public|package|internal|open|final|indirect|nonisolated) +)*(struct|enum|class|actor|protocol) +[A-Z]/) {
        name = $0
        sub(/^.*(struct|enum|class|actor|protocol) +/, "", name)
        sub(/[^A-Za-z0-9_].*$/, "", name)
        names = (count == 0) ? name : names ", " name
        count++
    }
}
END { finish() }
'

report "One type per file, but a small private helper view" "$(
    run_awk "$top_level_types" "$files"
)"

report "Absence is an optional, never \"\", -1 or a distant date, in the targets that hold no views" "$(
    lines '[?][?] *(""|-1([^0-9]|$))|[.]distant(Past|Future)' "$(domain_files)"
)"

report "An unstructured task starts only in a view's action or the app, never in a target that holds no views" "$(
    lines '(^|[^A-Za-z0-9_.])Task[[:space:]]*[({]' "$(domain_files)"
)"

report "No Task.detached or DispatchQueue" "$(
    lines 'Task[.]detached|DispatchQueue' "$files"
)"

report "Access levels go on members, never on an extension" "$(
    lines '(^|[[:space:]])(public|package|internal|fileprivate|private|open)[[:space:]]+extension[[:space:]]' "$files"
)"

unchecked=$(lines '@unchecked[[:space:]]+Sendable|nonisolated[(]unsafe[)]|@preconcurrency' "$files")
if [ -n "$unchecked" ]; then
    echo "REVIEW each wraps a dependency that needs it, once, with its reason on the line above"
    printf '%s\n' "$unchecked" | sed 's/^/  /'
fi

if [ "$failed" -eq 0 ]; then
    echo "Style checks passed."
fi

exit "$failed"
