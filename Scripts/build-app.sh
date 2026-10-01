#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/toolchain.sh"
configuration="${RELAY_CONFIGURATION:-release}"
destination_bundle="${1:-$build_directory/Byte Relay.app}"
/usr/bin/swift build "${swift_options[@]}" -c "$configuration" --product ByteRelay
/usr/bin/swift build "${swift_options[@]}" -c "$configuration" --product relay-tunnel-runner
binary_directory="$(/usr/bin/swift build "${swift_options[@]}" -c "$configuration" --show-bin-path)"
"$project_root/Scripts/package-app.sh" "$binary_directory/ByteRelay" "$destination_bundle"
