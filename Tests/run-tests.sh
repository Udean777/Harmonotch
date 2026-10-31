#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

SOURCES=()
while IFS= read -r file; do
    SOURCES+=("$file")
done < <(find Harmonotch/Features/Prayer/Adhan -name '*.swift' | sort)

SOURCES+=(
    "Harmonotch/Features/Battery/ClamshellPolicy.swift"
    "Harmonotch/Features/Prayer/Compass.swift"
    "Harmonotch/Features/Media/LRCParser.swift"
    "Harmonotch/Features/Update/Version.swift"
    "Harmonotch/Features/Update/UpdateInstallerSupport.swift"
    "Tests/main.swift"
)

swiftc -o "$TMP_DIR/harmonotch-tests" "${SOURCES[@]}"
"$TMP_DIR/harmonotch-tests"
