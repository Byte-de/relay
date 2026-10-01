#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/toolchain.sh"
/usr/bin/swift test "${swift_options[@]}"
/usr/bin/swift build "${swift_options[@]}" --product relay-diagnostics
/usr/bin/swift build "${swift_options[@]}" --product relay-tunnel-runner
binary_directory="$(/usr/bin/swift build "${swift_options[@]}" --show-bin-path)"
python3 "$project_root/Scripts/test-tunnel-runner.py" "$binary_directory/relay-tunnel-runner"
"$binary_directory/relay-diagnostics" --integration
"$binary_directory/relay-diagnostics"
