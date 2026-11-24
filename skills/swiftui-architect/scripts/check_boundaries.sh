#!/usr/bin/env bash
#
# Checks what the compiler can't about a modular SwiftUI app's boundaries: system frameworks,
# the app target and the roles types play. Run it from the app's repository root, beside
# Packages/, with no arguments:
#
#     check_boundaries.sh
#
# Prints each failure under the rule it breaks, lists under REVIEW what needs a person's
# judgment, and exits 1 if any rule fails.

set -u

if [ "$#" -ne 0 ]; then
    echo "usage: check_boundaries.sh, from the app's repository root" >&2
    exit 2
fi

if [ ! -d Packages ]; then
    echo "check_boundaries.sh runs from the app's repository root, beside Packages/" >&2
    exit 2
fi

# A module or type name ends where no letter, digit or underscore follows; grep's \b isn't portable.
end='([^A-Za-z0-9_]|$)'
failed=0

# report <rule> <failures>: prints the rule and its failures, if it has any.
report() {
    if [ -n "$2" ]; then
        echo "FAIL $1"
        printf '%s\n' "$2" | sed 's/^/  /'
        failed=1
    fi
}

# swift_grep <grep options> <pattern> <folders…>: greps the Swift files under the folders,
# skipping .build, sorted by file and line. It finds the files itself, since BusyBox's grep has
# no --include.
swift_grep() {
    options=$1
    pattern=$2
    shift 2
    find "$@" -name .build -prune -o -type f -name '*.swift' -exec grep "$options" -e "$pattern" {} + 2>/dev/null |
        sed 's|^\./||' | sort -t: -k1,1 -k2,2n
}

# package_dependencies <features|others>: each package dependency outside the shared package,
# DesignSystem and Networking, either on a feature (a package with an XCore target) or on
# anything else. DesignSystem and Networking may depend on what they need.
package_dependencies() {
    for manifest in Packages/*/Package.swift; do
        [ -f "$manifest" ] || continue
        package=${manifest%/Package.swift}
        case "$package" in
        Packages/DesignSystem | Packages/Networking) continue ;;
        esac
        grep -n '\.package(' "$manifest" | grep -vE '"\.\./(Shared|DesignSystem|Networking)/?"' |
            while IFS= read -r line; do
                path=$(echo "$line" | sed -n 's/.*path: *"\([^"]*\)".*/\1/p')
                path=${path%/}
                if [ -n "$path" ] && [ -d "$package/$path/Sources/$(basename "$path")Core" ]; then
                    [ "$1" = features ] && echo "$manifest:$line"
                else
                    [ "$1" = others ] && echo "$manifest:$line"
                fi
            done
    done
}

# imported_modules <folders…>: each module the Swift files under the folders import, one per line.
imported_modules() {
    swift_grep -hE "^[[:space:]]*(@[A-Za-z]+[[:space:]]+)*([a-z]+[[:space:]]+)?import[[:space:]]" "$@" |
        sed -E 's/.*import[[:space:]]+((typealias|struct|class|enum|protocol|let|var|func)[[:space:]]+)?([A-Za-z0-9_]+).*/\3/' |
        sort -u
}

# outside_previews <pattern> <file>: each line of the file matching the pattern outside a
# #Preview block.
outside_previews() {
    awk -v pattern="$1" '
        /^[ \t]*#Preview/ { preview = 1; depth = 0; opened = 0 }
        !preview && $0 ~ pattern { print FILENAME ":" FNR ":" $0 }
        preview {
            line = $0
            opens = gsub(/[{]/, "", line)
            closes = gsub(/[}]/, "", line)
            depth += opens - closes
            if (opens > 0) opened = 1
            if (opened && depth <= 0) preview = 0
        }
    ' "$2"
}

report "Features depend only on the shared package, DesignSystem and Networking" "$(
    package_dependencies features
)"

report "XCore and Shared import no UI framework or Networking" "$(
    swift_grep -lE "import (SwiftUI|UIKit|Networking)${end}" Packages/*/Sources/*Core Packages/Shared/Sources/Shared
)"

report "XUI and SharedUI import no Networking or Live target" "$(
    swift_grep -lE "import (Networking|[A-Za-z]+Live)${end}" Packages/*/Sources/*UI
)"

report "Only the app's screens read services" "$(
    swift_grep -HnE '@Environment\(\\\.[A-Za-z]+Service\)' Packages/*/Sources
)"

report "Destinations register only at stack roots, so a package registers them only in previews" "$(
    swift_grep -l 'navigationDestination' Packages/*/Sources | while IFS= read -r file; do
        outside_previews 'navigationDestination' "$file"
    done
)"

report "No type plays a role the architecture leaves out" "$(
    swift_grep -HnE "(class|struct|enum|actor|protocol) [A-Za-z]+(Repository|UseCase|Interactor|Manager|Coordinator)${end}" .
)"

others=$(package_dependencies others)
if [ -n "$others" ]; then
    echo "REVIEW each is an infrastructure package, such as analytics, never a feature"
    printf '%s\n' "$others" | sed 's/^/  /'
fi

# What a Live target imports beyond Foundation, the shared package, Networking and XCore reaches
# the API or the store, unless a Core, UI or Shared target needs it too.
live_modules=$(imported_modules Packages/*/Sources/*Live | grep -vxE 'Foundation|Shared|SharedLive|Networking|[A-Za-z]+Core')
if [ -n "$live_modules" ]; then
    modules=$(printf '%s\n' "$live_modules" | paste -s -d '|' -)
    shared=$(swift_grep -HnE "import[[:space:]]+(${modules})${end}" \
        Packages/*/Sources/*Core Packages/*/Sources/*UI Packages/Shared/Sources/Shared)
    if [ -n "$shared" ]; then
        echo "REVIEW each imports a module a Live target imports too, which must be neither the API's nor the store's"
        printf '%s\n' "$shared" | sed 's/^/  /'
    fi
fi

if [ "$failed" -eq 0 ]; then
    echo "Boundary checks passed."
fi

exit "$failed"
