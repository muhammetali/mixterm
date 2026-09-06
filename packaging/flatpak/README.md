# Flatpak packaging — not yet Flathub-ready

`com.mixterm.mixterm.yml` in this directory is a **starting scaffold**, not a
submittable manifest. It currently installs a pre-built `flutter build linux`
bundle as a module source, which works for a local `flatpak-builder` test but
**Flathub rejects this** — their review requires the app to actually build
from source inside the sandboxed, network-isolated build environment, not
ship a precompiled binary as a "source".

Flutter's own build (`flutter pub get`, engine artifact downloads) needs
network access, which conflicts with that sandbox. The standard way other
Flutter apps on Flathub solve this is to pre-generate an offline sources list
(pinned pub packages + Flutter SDK artifacts, each with a checksum) using the
community tool [flatpak-flutter](https://github.com/TheAssassin/flatpak-flutter),
then reference that generated file from the manifest instead of a live
`flutter pub get`.

**Remaining step before submitting to Flathub:** run flatpak-flutter (or
equivalent) against this project on a Linux machine to generate that offline
sources file, wire it into `com.mixterm.mixterm.yml`, verify a real
`flatpak-builder` build succeeds, then open a PR against
github.com/flathub/flathub. This needs a Linux environment with Docker (which
flatpak-flutter uses) — not available in this session.
