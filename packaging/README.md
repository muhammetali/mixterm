# Distribution channels

`.github/workflows/release.yml` builds every artifact below on each `v*` tag
push (or manually via "Run workflow" in the Actions tab) and attaches them to
a GitHub Release. **Verified working end-to-end** as of v1.0.0
(github.com/muhammetali/mixterm/releases/tag/v1.0.0 — all three build jobs
plus release creation ran clean; getting there took several real CI fixes:
pinning Flutter to 3.38.9 because dartssh2 2.14.0 fails to compile on newer
Dart, a `secrets` in `if:` restriction, a snap `organize` wildcard fighting
stage-packages, and a missing `contents: write` permission for
`gh release create`). What's fully automated vs. what needs a one-time
manual step from you:

## macOS — Homebrew

- **Automated:** macOS build, zipped as `mixterm-macos.zip`.
- **Blocked on you:** code signing needs a **Developer ID Application**
  certificate, which doesn't exist in Keychain yet (only "Apple Distribution"
  and "Apple Development" do — those are App Store types, not usable here).
  Create one via Xcode → Settings → Accounts → Manage Certificates → "+" →
  Developer ID Application. Then export it + its private key as a .p12 and
  add two GitHub secrets on this repo:
  - `APPLE_CERT_P12` — `base64 -i YourCert.p12 | pbcopy`, paste the result
  - `APPLE_CERT_PASSWORD` — the password you set when exporting
  - `APPLE_DEVELOPER_ID` — the cert's full name, e.g. `Developer ID
    Application: Muhammet Ali Özçelik (P23D6429S8)`

  (App Store Connect API credentials for notarization are already set as
  `APP_STORE_CONNECT_API_KEY_P8`/`_KEY_ID`/`_ISSUER_ID` secrets.)

  All three certificate secrets are set as of 1.1.2. They were not for
  1.1.1, whose macOS zip published ad-hoc signed and had to be pulled: the
  signing steps were conditional on the secret and a skipped step is a green
  step. A tagged build now fails outright without them, and the built app is
  inspected before packaging, so signing that is configured but does not take
  is caught too.

- **Homebrew:** shipped through a personal tap,
  [muhammetali/homebrew-tap](https://github.com/muhammetali/homebrew-tap):

  ```sh
  brew trust muhammetali/tap   # Homebrew 6+ refuses third-party taps otherwise
  brew tap muhammetali/tap
  brew install --cask mixterm
  ```

  `packaging/homebrew/mixterm.rb` is the source of truth; the tap holds a
  copy at `Casks/mixterm.rb`, and the `update-homebrew-tap` job rewrites its
  `version` and `sha256` after each release. That job needs
  `HOMEBREW_TAP_TOKEN` — a fine-grained token with **Contents: write** on the
  tap repository and nothing else, because `GITHUB_TOKEN` is scoped to this
  repository and cannot push to another one. Without it a tagged release
  fails rather than quietly leaving `brew upgrade` on the previous version.

  Submitting to homebrew-cask itself is not possible yet. Their [package
  acceptance policy](https://github.com/Homebrew/brew/blob/master/docs/Package-Acceptance-Policy.md)
  asks a repository owner submitting their own project for **90 forks, 90
  watchers or 225 stars**; this repository has none of the three. The cask is
  written to their rules and moves across unchanged when that day comes.

## Linux — .deb (GitHub Releases)

- **Automated, no account needed, live today:**
  github.com/muhammetali/mixterm/releases/download/v1.0.0/mixterm_1.0.0_amd64.deb
  Users: `sudo apt install ./mixterm_<version>_amd64.deb` (or `dpkg -i` +
  `apt --fix-broken install`).

## Linux — Snap

- **Automated, live today:** download
  github.com/muhammetali/mixterm/releases/download/v1.0.0/mixterm_1.0.0_amd64.snap
  and `sudo snap install --dangerous mixterm_1.0.0_amd64.snap` (`--dangerous`
  because it isn't Snap-Store-signed yet — see below).
- **Blocked on you (to reach the real Snap Store / `snap install mixterm`):**
  create a free account at snapcraft.io (Ubuntu One login), then locally:
  `snapcraft login`, `snapcraft register mixterm`, then
  `snapcraft upload --release=stable path/to/mixterm_*.snap` for each
  release. This can't be done from here — it's an interactive login tied to
  your own account.

## Linux — PPA (Launchpad)

- **Scaffolded, needs Linux + your Launchpad account.**
  `packaging/debian-source/debian/` has a source package that installs a
  CI-built bundle rather than compiling in-sandbox (Launchpad's build farm
  has no network access, which Flutter's toolchain needs). Run
  `scripts/build_ppa_source.sh` on a Linux machine, then:
  1. Create a Launchpad account + PPA (launchpad.net/people/+me →
     "Create a new PPA") and register a GPG key with it.
  2. `cd build/ppa/mixterm-<version> && debuild -S -sa`
  3. `dput ppa:<your-launchpad-id>/mixterm ../mixterm_<version>-1_source.changes`
  4. Repeat per Ubuntu series you want (the changelog's distribution field,
     currently `noble`, must match).

## Linux — Flatpak (Flathub)

- **Scaffolded but not submittable yet** — see
  `packaging/flatpak/README.md`. Flathub requires building from source
  in a network-isolated sandbox, which needs an offline pub-packages
  manifest generated by a tool like
  [flatpak-flutter](https://github.com/TheAssassin/flatpak-flutter) (needs
  Docker on a Linux machine). Not done in this session — no Linux/Docker
  environment available here.
