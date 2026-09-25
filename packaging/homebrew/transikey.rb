# Homebrew cask for Transikey.
#
# This file is the source of truth. The release workflow renders `version` and
# `sha256` from the published GitHub release and pushes the result to
# digitalis-io/homebrew-tap as Casks/transikey.rb — do not edit those two
# fields by hand in the tap.
cask "transikey" do
  version "0.1.0-rc5"
  sha256 "fdaea54b6e305cef62a2006502a5cf7217cd8c94309d5cfc55fae2c59dbc627c"

  url "https://github.com/digitalis-io/transikey/releases/download/v#{version}/transikey-v#{version}-macos-universal.zip"
  name "Transikey"
  desc "Desktop client for OpenBao and HashiCorp Vault"
  homepage "https://github.com/digitalis-io/transikey"

  # Release candidates are published as pre-releases, so the default
  # :github_releases block (which skips them) would find nothing.
  livecheck do
    url :url
    regex(/^v?(\d+(?:\.\d+)+(?:-[a-z0-9.]+)?)$/i)
    strategy :github_releases do |json, regex|
      json.map do |release|
        next if release["draft"]

        match = release["tag_name"]&.match(regex)
        next unless match

        match[1]
      end
    end
  end

  depends_on macos: :ventura

  app "transikey.app"

  # Settings land in the preferences plist; secrets live in the login keychain,
  # which zap cannot touch. The cache and saved-state paths are the standard
  # AppKit ones for this bundle id.
  zap trash: [
    "~/Library/Caches/io.digitalis.transikey",
    "~/Library/Preferences/io.digitalis.transikey.plist",
    "~/Library/Saved Application State/io.digitalis.transikey.savedState",
  ]

  # The app is not signed or notarised. Homebrew keeps the quarantine flag, so
  # the first launch needs an explicit approval — see the README.
  caveats do
    <<~EOS
      Transikey is not signed or notarised. The first launch is blocked by
      Gatekeeper. Approve it once with:

        xattr -dr com.apple.quarantine /Applications/transikey.app

      Sessions and tokens are stored in the login keychain. `--zap` does not
      remove them; delete the "transikey" items in Keychain Access by hand.
    EOS
  end
end
