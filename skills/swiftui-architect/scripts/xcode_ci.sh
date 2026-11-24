#!/usr/bin/env bash
#
# Builds or tests a scheme with xcodebuild on an installed iPhone simulator, failing on a
# warning in the repository's own code. Run it from a package's folder, beside Package.swift,
# or from the app's, beside its Xcode project or workspace:
#
#     xcode_ci.sh <build|test> <scheme> [arguments…]
#     xcode_ci.sh test Catalog-Package
#     xcode_ci.sh build MoviesApp
#
# Other arguments go to xcodebuild; a -destination among them replaces the simulator this
# script picks. It touches the repository's Swift files first, since a file a build doesn't
# compile again reports no warning. Prints xcodebuild's errors and warnings, then each warning
# in the repository's own code under FAIL and each other warning under REVIEW, and exits 1 if
# the build or a test fails or the repository's own code has a warning.

set -u

usage() {
    echo "usage: xcode_ci.sh <build|test> <scheme> [arguments…], from a package's or the app's folder" >&2
    exit 2
}

[ "$#" -ge 2 ] || usage
case "$1" in
build | test) ;;
*) usage ;;
esac

action=$1
scheme=$2
shift 2

if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "xcode_ci.sh needs Xcode's xcodebuild, on macOS" >&2
    exit 2
fi

found=0
for project in Package.swift *.xcodeproj *.xcworkspace; do
    [ -e "$project" ] && found=1
done
if [ "$found" -eq 0 ]; then
    echo "xcode_ci.sh runs from a package's folder, beside Package.swift, or the app's, beside its project" >&2
    exit 2
fi

# The simulator: the last iPhone the newest runtime lists, unless the arguments name one.
named=0
for argument in "$@"; do
    [ "$argument" = "-destination" ] && named=1
done
if [ "$named" -eq 0 ]; then
    simulator=$(xcrun simctl list devices available | grep -E '^[[:space:]]+iPhone' | tail -n 1 |
        sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
    if [ -z "$simulator" ]; then
        echo "xcode_ci.sh found no iPhone simulator; add an iOS runtime in Xcode's settings" >&2
        exit 2
    fi
    set -- -destination "id=$simulator" "$@"
fi

root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
log=$(mktemp "${TMPDIR:-/tmp}/xcode_ci.XXXXXX")
trap 'rm -f "$log"' EXIT

# Dependencies' folders, whose code isn't the repository's own.
dependencies='/(\.build|\.swiftpm|DerivedData|SourcePackages|Pods|Carthage)/'

find "$root" \( -name .git -o -name .build -o -name .swiftpm -o -name DerivedData -o -name SourcePackages \
    -o -name Pods -o -name Carthage \) -prune -o -type f -name '*.swift' -exec touch {} +

xcodebuild "$action" -scheme "$scheme" -quiet "$@" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}

# A warning is the repository's own when its file is in the repository and outside the build
# products and dependencies' checkouts.
warnings=$(grep -E ': warning: ' "$log" | sort -u)
owned=$(printf '%s\n' "$warnings" | grep -F "$root/" | grep -vE "$dependencies")
others=$(printf '%s\n' "$warnings" | grep -v '^$' | grep -vxF -e "${owned:-//}")

if [ -n "$owned" ]; then
    echo "FAIL The repository's own code builds with no warning"
    printf '%s\n' "$owned" | sed 's/^/  /'
    status=1
fi

if [ -n "$others" ]; then
    echo "REVIEW each is a dependency's warning, a departure to record, or the project's own to fix"
    printf '%s\n' "$others" | sed 's/^/  /'
fi

if [ "$status" -ne 0 ]; then
    exit 1
fi

echo "xcodebuild $action passed with no warning in the repository's own code."
