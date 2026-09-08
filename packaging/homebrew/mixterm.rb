cask "mixterm" do
  version "1.1.2"
  sha256 "33f8e11526969bb0d9cef5068443cd1a8039f667d8e5935fc7a81f46f68c456e"

  url "https://github.com/muhammetali/mixterm/releases/download/v#{version}/mixterm-macos.zip"
  name "MixTerm"
  desc "SSH/SFTP client with multi-tab terminals and encrypted credential storage"
  homepage "https://github.com/muhammetali/mixterm"

  # No `depends_on macos:` on purpose. The bundle's LSMinimumSystemVersion is
  # 10.15, and Homebrew has removed version constraints that old outright —
  # `depends_on macos: :catalina` is disabled with "There is no replacement",
  # which makes the whole tap fail to load, not just this line. Every macOS
  # Homebrew still supports is far past 10.15, so the constraint said nothing
  # anyway. (An earlier draft asked for big_sur, which was simply wrong: it
  # would have refused two releases the app runs on.)

  # The bundle inside the zip is lowercase, but it installs as MixTerm.app:
  # that is CFBundleName, it is what the release notes and the Linux
  # packages call it, and macOS filesystems are case-insensitive by default,
  # so shipping `mixterm.app` would collide with a hand-installed
  # `MixTerm.app` rather than replace it.
  app "mixterm.app", target: "MixTerm.app"

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
