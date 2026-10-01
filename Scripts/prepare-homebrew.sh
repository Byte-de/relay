#!/bin/bash
# Generate a cask only from the final stapled, Gatekeeper-accepted DMG.
set -euo pipefail
source "$(dirname "$0")/toolchain.sh"
dmg="${1:?Pass the notarized Byte-Relay.dmg}"
output="${2:?Pass the output path for byte-relay.rb}"
/usr/bin/xcrun stapler validate "$dmg" >/dev/null
/usr/sbin/spctl --assess --type open --context context:primary-signature "$dmg"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$project_root/Resources/Info.plist")
checksum=$(/usr/bin/shasum -a 256 "$dmg" | awk '{print $1}')
cat > "$output" <<CASK
cask "byte-relay" do
  version "$version"
  sha256 "$checksum"

  url "https://github.com/Byte-de/relay/releases/download/v#{version}/Byte-Relay.dmg",
      verified: "github.com/Byte-de/relay/"
  name "Byte Relay"
  desc "Local dev servers, AI agents, projects and Cloudflare previews"
  homepage "https://relay.byte.de/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :tahoe
  depends_on arch: :arm64

  app "Byte Relay.app"

  zap trash: [
    "~/Library/Application Support/Byte Relay",
    "~/Library/Caches/de.byte.relay",
    "~/Library/HTTPStorages/de.byte.relay",
    "~/Library/Preferences/de.byte.relay.plist",
    "~/Library/Saved Application State/de.byte.relay.savedState",
  ]
end
CASK
printf 'Verified cask written to %s\n' "$output"
