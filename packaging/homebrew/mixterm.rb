cask "mixterm" do
  version "1.0.0"
  # This is v1.0.0's real hash, but that build is only ad-hoc signed (no
  # Developer ID cert configured yet — see packaging/README.md). Don't
  # submit to homebrew-cask until a release has run with real signing +
  # notarization, then recompute this from that build instead.
  sha256 "897cdfec7a743ad6928ddfc1835831dc297c1fa6530e5c3d7c719ff3712e18c4"

  url "https://github.com/muhammetali/mixterm/releases/download/v#{version}/mixterm-macos.zip"
  name "MixTerm"
  desc "Professional SSH/SFTP client with multi-tab terminals and encrypted credential storage"
  homepage "https://github.com/muhammetali/mixterm"

  depends_on macos: ">= :big_sur"

  app "mixterm.app"

  zap trash: [
    "~/Library/Application Support/mixterm",
    "~/Library/Preferences/com.mixterm.mixterm.plist",
    "~/Library/Saved Application State/com.mixterm.mixterm.savedState",
  ]
end
