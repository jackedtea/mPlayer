# mPlayer

Cross-platform video player and media server client (Jellyfin/Emby) with SMB/WebDAV/cloud-drive support.

**Read [docs/PLAN.md](docs/PLAN.md) first** — it holds the architecture, the phase checklist, and the environment gotchas already resolved.

## Current state (2026-08-10)

Phase 0, nearly complete. The app is a scaffold: `lib/` contains only `main.dart`, `app/app.dart`, `app/theme.dart` and a temporary `features/playback/smoke_test_page.dart`. There is no real feature code yet.

Verified by actually building, not assumed:

- Windows debug build links and bundles `libmpv-2.dll`
- Android debug APK builds and bundles `libmpv.so` for all three ABIs
- `flutter analyze` clean, `flutter test` passing

Still open in Phase 0:

1. `git init` and a first commit — the project is **not** under version control yet
2. Run the smoke test on a real Android device and confirm video actually renders (a successful build does not prove playback works)
3. Confirm the Linux build on a machine with `libmpv-dev`

Next real work is Phase 1 (app shell: router, theme persistence, Drift schema).

## Identity

- Dart package name: `mplayer` (lowercase — Dart forbids uppercase in package names)
- Bundle ID: `dev.icedtea.mplayer`
- Display name: **mPlayer** (set in AndroidManifest, Windows CMakeLists/Runner.rc/main.cpp, Linux CMakeLists/my_application.cc, iOS Info.plist, macOS AppInfo.xcconfig)

## License

**GPL-3.0-or-later.** `LICENSE` at the app root holds the verbatim FSF text — do not edit it.

Every file under `lib/` (and new source files you add) carries a four-line header:

```dart
// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.
```

Generated files (`*.g.dart`, `*.freezed.dart`) are exempt — build_runner overwrites them.

When adapting code from `refs/NipaPlay-Reload` (MIT), keep its MIT copyright notice in the
adapted file alongside the GPL header. MIT is GPLv3-compatible; the combined work is GPLv3.

## Icons

**Material Icons only** (`Icons.*`, already enabled via `uses-material-design: true`). No
FontAwesome — Flutter's built-in widgets draw Material glyphs internally, so mixing sets
splits the visual language, and FA Free's CC BY 4.0 attribution is needless friction.
`cupertino_icons` was removed as unused.

Brand marks Material lacks (Jellyfin, Emby, Google Drive, OneDrive) go in `assets/brands/`
as SVGs from [simple-icons](https://simpleicons.org) (CC0), rendered with `flutter_svg`.

## Stack

Flutter 3.44 · Riverpod 3 (**hand-written providers, no codegen**) · Drift · go_router · media_kit · dio · freezed

## Hard-won constraints — do not undo without re-verifying

- **No `riverpod_generator`, no `riverpod_lint`, no `custom_lint`.** They conflict irreconcilably with `freezed` + `drift_dev` over `analyzer` versions. Riverpod providers are written by hand.
- **`compileSdk = 37`** is pinned in `android/app/build.gradle.kts` (required by `flutter_secure_storage 11.x`; Flutter's default is 36).
- **`kotlin.incremental=false`** in `android/gradle.properties` — this host intermittently fails with "Could not close incremental caches" otherwise.
- Linux builds need system libmpv: `sudo apt install libmpv-dev mpv`.

## Icons

`icon.svg` at the app root is the design source. Regenerate with:

```bash
dart run flutter_launcher_icons          # Android, iOS, Windows, macOS
```

Linux is not covered by that tool — its icons live in `linux/packaging/icons/hicolor/` alongside the `.desktop` file, regenerated from `icon.svg` by hand when the artwork changes.

## Reference material

`../refs/NipaPlay-Reload` (MIT) — a working Flutter media client. Its `lib/services/` contains Emby (1712 lines), Jellyfin (1655), WebDAV (1617) and SMB implementations with **zero danmaku coupling**, sharing `media_server_service_base.dart`. Adapt these; do not fork the whole app (its `lib/` is ~270k lines and heavily anime-oriented).

Read-only. Never edit anything under `refs/`.

## Commands

```bash
flutter analyze
flutter test
flutter build windows --debug
flutter build apk --debug
dart run build_runner build --delete-conflicting-outputs   # drift + freezed + json_serializable
```
