#!/usr/bin/env bash
#
# Builds or tests a scheme with xcodebuild once for each platform it declares, failing on a
# warning in the repository's own code. Run it from a package's folder, beside Package.swift,
# or from the app's, beside its Xcode project or workspace:
#
#     xcode_ci.sh <build|test> <scheme> [arguments…]
#     xcode_ci.sh test Catalog-Package
#     xcode_ci.sh build MoviesApp
#
# A package's platforms are those its Package.swift lists, and an app's those every target of
# its scheme supports. Each runs on the Mac for macOS, and on the newest installed simulator for
# each other platform. Other arguments go to xcodebuild; a -destination among them replaces the
# platforms with that one destination. It touches the repository's Swift files first, since a
# build reports the warnings of only the files it compiles again. Prints xcodebuild's errors and
# warnings, then each warning in the repository's own code under FAIL and each other warning
# under REVIEW, and exits 1 if a build or a test fails or the repository's own code has a warning.

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

app=0
for project in *.xcodeproj *.xcworkspace; do
    [ -e "$project" ] && app=1
done
if [ "$app" -eq 0 ] && [ ! -e Package.swift ]; then
    echo "xcode_ci.sh runs from a package's folder, beside Package.swift, or the app's, beside its project" >&2
    exit 2
fi

# Whether the arguments name a destination, and the ones that pick the app's project.
named=0
selection=()
previous=
for argument in "$@"; do
    [ "$argument" = "-destination" ] && named=1
    case "$previous" in
    -workspace | -project) selection+=("$previous" "$argument") ;;
    esac
    previous=$argument
done

# package_platforms: the platforms Package.swift lists, in its order.
package_platforms() {
    if ! manifest=$(xcrun swift package dump-package 2>&1); then
        printf '%s\n' "$manifest" >&2
        echo "xcode_ci.sh couldn't read the platforms Package.swift lists" >&2
        exit 2
    fi
    printf '%s\n' "$manifest" | grep -oE '"platformName" *: *"[a-z]+"' | sed -E 's/.*"([a-z]+)"$/\1/' |
        while IFS= read -r name; do
            case "$name" in
            ios) echo iOS ;;
            macos) echo macOS ;;
            tvos) echo tvOS ;;
            watchos) echo watchOS ;;
            visionos) echo visionOS ;;
            esac
        done
}

# app_platforms: the platforms every target of the app's scheme supports.
app_platforms() {
    if ! settings=$(xcodebuild -showBuildSettings -scheme "$scheme" ${selection[@]+"${selection[@]}"} 2>&1); then
        printf '%s\n' "$settings" >&2
        echo "xcode_ci.sh couldn't read the platforms the scheme $scheme supports" >&2
        exit 2
    fi
    printf '%s\n' "$settings" | awk '
        /^Build settings for action/ { targets++ }
        $1 == "SUPPORTED_PLATFORMS" { for (i = 3; i <= NF; i++) count[$i]++ }
        END { for (sdk in count) if (count[sdk] == targets) print sdk }
    ' | sort | while IFS= read -r sdk; do
        case "$sdk" in
        iphonesimulator) echo iOS ;;
        macosx) echo macOS ;;
        appletvsimulator) echo tvOS ;;
        watchsimulator) echo watchOS ;;
        xrsimulator) echo visionOS ;;
        esac
    done
}

# destination <platform>: the Mac for macOS; otherwise the last of the platform's simulators
# that the newest runtime lists, or nothing when none is installed.
destination() {
    case "$1" in
    macOS)
        # The variant leaves out Mac Catalyst and an iPad app on the Mac, which match the Mac too.
        echo "platform=macOS,arch=$(uname -m),variant=macos"
        return
        ;;
    iOS) device=iPhone ;;
    tvOS) device='Apple TV' ;;
    watchOS) device='Apple Watch' ;;
    visionOS) device='Apple Vision' ;;
    esac
    simulator=$(xcrun simctl list devices available | grep -E "^[[:space:]]+$device" | tail -n 1 |
        sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
    if [ -n "$simulator" ]; then
        echo "id=$simulator"
    fi
}

# runs: a line per run, its platform and its destination separated by a tab.
tab=$(printf '\t')
if [ "$named" -eq 1 ]; then
    runs="the destination given$tab"
else
    if [ "$app" -eq 1 ]; then
        platforms=$(app_platforms) || exit 2
        where="the scheme $scheme supports no platform with a simulator or the Mac"
    else
        platforms=$(package_platforms) || exit 2
        where="Package.swift lists no platforms; list each of the app's"
    fi
    if [ -z "$platforms" ]; then
        echo "xcode_ci.sh found nothing to run on: $where" >&2
        exit 2
    fi
    runs=
    for platform in $platforms; do
        to=$(destination "$platform")
        if [ -z "$to" ]; then
            echo "xcode_ci.sh found no $platform simulator; add a $platform runtime in Xcode's settings" >&2
            exit 2
        fi
        runs="$runs$platform$tab$to
"
    done
fi

root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
log=$(mktemp "${TMPDIR:-/tmp}/xcode_ci.XXXXXX")
trap 'rm -f "$log"' EXIT

# Dependencies' folders, whose code isn't the repository's own.
dependencies='/(\.build|\.swiftpm|DerivedData|SourcePackages|Pods|Carthage)/'

find "$root" \( -name .git -o -name .build -o -name .swiftpm -o -name DerivedData -o -name SourcePackages \
    -o -name Pods -o -name Carthage \) -prune -o -type f -name '*.swift' -exec touch {} +

status=0
ran=
while IFS="$tab" read -r platform to; do
    [ -n "$platform" ] || continue
    echo "xcodebuild $action $scheme for $platform"
    if [ -n "$to" ]; then
        xcodebuild "$action" -scheme "$scheme" -quiet -destination "$to" "$@" </dev/null 2>&1 | tee -a "$log"
    else
        xcodebuild "$action" -scheme "$scheme" -quiet "$@" </dev/null 2>&1 | tee -a "$log"
    fi
    [ "${PIPESTATUS[0]}" -eq 0 ] || status=1
    ran="${ran:+$ran, }$platform"
done <<RUNS
$runs
RUNS

# A warning is the repository's own when its file is in the repository and outside the build
# products and dependencies' checkouts.
warnings=$(grep -E ': warning: ' "$log" | sort -u)
owned=$(printf '%s\n' "$warnings" | grep -F "$root/" | grep -vE "$dependencies")
others=$(printf '%s\n' "$warnings" | grep -v '^$' | grep -vxF -e "${owned:-//}")

if [ -n "$owned" ]; then
    echo "FAIL The repository's own code builds cleanly, so each of its warnings is fixed"
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

echo "xcodebuild $action passed for $ran, and the repository's own code built cleanly."
