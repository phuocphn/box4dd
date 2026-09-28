#!/bin/sh
# Runs the test suite. With only the Command Line Tools installed (no Xcode),
# SwiftPM can't find Swift Testing by itself, so point it at the CLT copy.
set -e
cd "$(dirname "$0")/.."
DEV=/Library/Developer/CommandLineTools/Library/Developer
if xcode-select -p | grep -q CommandLineTools; then
    exec swift test \
        -Xswiftc -F -Xswiftc "$DEV/Frameworks" \
        -Xlinker -F -Xlinker "$DEV/Frameworks" \
        -Xlinker -rpath -Xlinker "$DEV/Frameworks" \
        -Xlinker -rpath -Xlinker "$DEV/usr/lib" "$@"
fi
exec swift test "$@"
