cask "mixterm" do
  version "1.0.0"
  sha256 "REPLACE_WITH_REAL_SHA256_AFTER_FIRST_SIGNED_RELEASE"

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
