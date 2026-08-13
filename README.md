# mPlayer

Cross-platform video player and media server client (Jellyfin/Emby) with SMB/WebDAV/cloud-drive support.

Built with Flutter. Priority platforms: Android, Windows, Linux — iOS/macOS are scaffolded but deferred.

See [docs/PLAN.md](docs/PLAN.md) for the architecture and phase checklist.

## Building

```bash
flutter pub get
flutter run                    # or: flutter build windows / apk / linux
```

Linux additionally needs system libmpv: `sudo apt install libmpv-dev mpv`.

## License

mPlayer is free software, licensed under the **GNU General Public License v3.0 or later**.
The full text is in [LICENSE](LICENSE).

    Copyright (C) 2026 Nam <namicedtea@gmail.com>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the
    Free Software Foundation, either version 3 of the License, or (at your
    option) any later version.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
    General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <https://www.gnu.org/licenses/>.

### Third-party components

| Component | License | Note |
|---|---|---|
| Flutter, Dart packages (`media_kit`, `drift`, `go_router`, `dio`, …) | BSD-3-Clause / MIT / Apache-2.0 | Permissive; GPLv3-compatible |
| libmpv / FFmpeg on Android, iOS, macOS, Linux (`media_kit_libs_*`) | LGPL-2.1-or-later (upstream) | Dynamically linked; GPLv3-compatible |
| libmpv / FFmpeg on **Windows** ([shinchiro build](https://github.com/shinchiro/mpv-winbuild-cmake)) | **GPL-2.0-or-later** | Replaces the trimmed build so image-based subtitles decode; GPL is fine here only because this app is GPL |
| Service-layer code adapted from [NipaPlay-Reload](https://github.com/MCDFsteve/NipaPlay-Reload) | MIT | GPLv3-compatible; MIT notice retained in adapted files |
| Material Icons | Apache-2.0 | Bundled via `uses-material-design` |
| Roboto (`assets/fonts/Roboto-Variable.ttf`) | SIL OFL 1.1 | Bundled, not fetched at runtime; notice in `assets/fonts/OFL.txt` and registered with `LicenseRegistry` |

Because the app links libmpv, distributing binaries obliges you to also make this
project's source available under the GPL — which the license above already does.
