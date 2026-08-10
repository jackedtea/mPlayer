# mPlayer

Cross-platform video player and media server client (Jellyfin/Emby) with SMB/WebDAV/cloud-drive support.

**Read [docs/PLAN.md](docs/PLAN.md) first** — it holds the architecture, the phase checklist, and the environment gotchas already resolved.

## Current state (2026-08-10)

Phase 0 done; Phase 1 in progress — the app shell is navigable.

Built: `app/tokens.dart` (design tokens as `ThemeExtension`s + `WindowSize`), `app/theme.dart`,
`app/router.dart`, `app/adaptive_scaffold.dart`, and screens 1a Storage, 1c Server-empty +
add-server sheet, 1n Search-idle, 1l Settings-index. All render against
`core/sample_data.dart` placeholders — **no real data source exists yet.**

Verified by actually building and running, not assumed:

- Windows debug build links and bundles `libmpv-2.dll`
- Android debug APK builds and bundles `libmpv.so` for all three ABIs
- `flutter analyze` clean; `flutter test` 12/12 passing, covering the three
  breakpoints, the no-server-gate startup rule and search scoping

Still open:

1. Run the smoke test (`/smoke` route) on a real Android device and confirm video
   actually renders (a successful build does not prove playback works)
2. Confirm the Linux build on a machine with `libmpv-dev`
3. Bundle Roboto / Roboto Flex TTFs — the design specifies them, but only Android
   supplies Roboto as a system font; Windows and Linux currently fall back

Next real work is design build step 2: `MediaSource` interface, local source, and the
player screen — one device file playing end to end.

## Design source of truth

`../design/` holds the exported design bundle. **`../design/README.md` is the spec** —
colour/type/shape tokens, the adaptive-layout table, and screens `1a`–`1n` described in
prose. `Jellyfin Client.dc.html` is the visual reference; open it in a browser, do not
port its markup. `../design/CLAUDE.md` carries the non-negotiables and the build order.

Read-only, like `refs/`.

Four rules from that bundle that are easy to violate by accident:

1. The app must be fully usable with **no server configured**. Never gate startup on a
   login or a reachable server; a dead server shows an inline retry, never a modal.
2. Stock Material 3 widgets first — do not hand-roll what `NavigationBar`, `FilterChip`,
   `ListTile`, `Slider` or `SearchBar` already provide.
3. One player screen serves local files, SMB/WebDAV/NFS shares and Jellyfin streams.
   Do not fork it per source.
4. No magic numbers in widgets — spacing and radii come from `context.spacing` /
   `context.radii`, colours from `context.colors`, and the few M3 has no slot for
   (success green, rating star, divider) from `context.semantic`.

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

## UI icons

**Material only** (`Icons.*`, enabled via `uses-material-design: true`). No FontAwesome —
Flutter's built-in widgets draw Material glyphs internally, so mixing sets splits the
visual language, and FA Free's CC BY 4.0 attribution is needless friction.
`cupertino_icons` was removed as unused.

The design specifies **Material Symbols Rounded**, so use the `_rounded` suffix
(`Icons.folder_rounded`, `Icons.dns_rounded`). Its glyph names map 1:1 onto the names
listed in `../design/README.md`.

Filled vs outlined carries meaning — use the filled variant **only** for the selected
navigation destination and the play/pause glyph; everything else is `_outlined` or the
plain rounded form.

Brand marks Material lacks (Jellyfin, Emby, Google Drive, OneDrive) go in `assets/brands/`
as SVGs from [simple-icons](https://simpleicons.org) (CC0), rendered with `flutter_svg`.

## Stack

Flutter 3.44 · Riverpod 3 (**hand-written providers, no codegen**) · Drift · go_router · media_kit · dio · freezed

## Hard-won constraints — do not undo without re-verifying

- **No `riverpod_generator`, no `riverpod_lint`, no `custom_lint`.** They conflict irreconcilably with `freezed` + `drift_dev` over `analyzer` versions. Riverpod providers are written by hand.
- **`compileSdk = 37`** is pinned in `android/app/build.gradle.kts` (required by `flutter_secure_storage 11.x`; Flutter's default is 36).
- **`kotlin.incremental=false`** in `android/gradle.properties` — this host intermittently fails with "Could not close incremental caches" otherwise.
- Linux builds need system libmpv: `sudo apt install libmpv-dev mpv`.

## Launcher icons

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
