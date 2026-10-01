#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/toolchain.sh"
version=2026.9.3
case "$(uname -m)" in
  arm64) architecture=arm64; checksum=587c2cfb1c230fe36c7fa7727da78be459dae028cabe8c001291999350f07095 ;;
  x86_64) architecture=amd64; checksum=d1155d0837487f261183b15c1eab6c4ebcad9dc49b94675f1524c3564cea3977 ;;
  *) printf 'Unsupported Cloudflare architecture\n' >&2; exit 1 ;;
esac
cache="$build_directory/cloudflared-$version-$architecture"
mkdir -p "$cache"
archive="$cache/cloudflared.tgz"
if [[ ! -f "$archive" ]]; then
  /usr/bin/curl --fail --location --silent --show-error --connect-timeout 15 --max-time 180 \
    "https://github.com/cloudflare/cloudflared/releases/download/$version/cloudflared-darwin-$architecture.tgz" \
    -o "$archive.download"
  mv "$archive.download" "$archive"
fi
actual=$(/usr/bin/shasum -a 256 "$archive" | /usr/bin/awk '{print $1}')
[[ "$actual" == "$checksum" ]] || { printf 'Cloudflare checksum mismatch; download rejected\n' >&2; exit 1; }
# Extract only the expected regular binary from the verified release asset.
/usr/bin/tar -xzf "$archive" -C "$cache" cloudflared
[[ -f "$cache/cloudflared" && ! -L "$cache/cloudflared" ]] || exit 1
chmod 755 "$cache/cloudflared"
printf '%s\n' "$cache/cloudflared"
