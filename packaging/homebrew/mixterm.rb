cask "mixterm" do
  version "1.1.2"
  sha256 "33f8e11526969bb0d9cef5068443cd1a8039f667d8e5935fc7a81f46f68c456e"

  url "https://github.com/muhammetali/mixterm/releases/download/v#{version}/mixterm-macos.zip"
  name "MixTerm"
  desc "SSH/SFTP client with multi-tab terminals and encrypted credential storage"
  homepage "https://github.com/muhammetali/mixterm"

  # LSMinimumSystemVersion in the shipped bundle, not a guess. An earlier
  # draft of this file said big_sur, which would have refused to install on
  # two releases of macOS the app actually runs on.
  depends_on macos: ">= :catalina"

  # Lowercase, matching the bundle inside the zip. The display name is
  # MixTerm — see CFBundleName — but the directory is not.
  app "mixterm.app"

  # The app is sandboxed, so everything it writes lives under its container.
  # An earlier draft listed ~/Library/Application Support/mixterm and
  # ~/Library/Preferences/com.mixterm.mixterm.plist, neither of which exists:
  # `--zap` would have reported success while leaving the encrypted server
  # list and the stored Google credentials on disk. Verified against an
  # installed copy rather than assumed.
  zap trash: [
    "~/Library/Application Scripts/com.mixterm.mixterm",
    "~/Library/Containers/com.mixterm.mixterm",
  ]
end
