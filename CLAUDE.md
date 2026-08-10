# mPlayer

Cross-platform video player and media server client (Jellyfin/Emby) with SMB/WebDAV/cloud-drive support.

**Read [docs/PLAN.md](docs/PLAN.md) first** — it holds the architecture, the phase checklist, and the environment gotchas already resolved.

## Current state (2026-08-10)

Design build steps 1 and 2 done; **every screen `1a`–`1n` is now drawn and reachable**,
but only the local-playback path is backed by real data.

**Step 1 — shell.** `app/tokens.dart` (design tokens as `ThemeExtension`s + `WindowSize`),
`app/theme.dart`, `app/router.dart`, `app/adaptive_scaffold.dart`, and screens 1a Storage,
1c Server-empty + add-server sheet, 1n Search-idle, 1l Settings-index. These render against
`core/sample_data.dart` placeholders — **the browse/library UI has no real data yet.**

**Step 2 — playback.** `sources/media_source.dart` (the `MediaSource` interface,
`MediaRef`, `PlayableMedia`, `SourceCapabilities`), `sources/local_source.dart`, and
`features/player/` — `PlaybackController` (Riverpod, hand-written) over `media_kit`, plus
screen 1h with the video surface, transport and scrubber. Picking a file from the Storage
FAB plays it end to end. This path uses **no** sample data.

**Screens.** 1b browser, 1d server home, 1e library grid, 1f movie detail, 1g series,
1i downloads, 1m settings pages (Appearance / Player / Subtitle / About) and the active
state of 1n all render against `core/sample_library.dart`. General and Audio settings are
listed in the index but have no page yet — the design does not draw them either.

Verified by actually building and running, not assumed:

- Windows debug build links and bundles `libmpv-2.dll`
- Android debug APK builds and bundles `libmpv.so` for all three ABIs, plus the Roboto asset
- `flutter analyze` clean; `flutter test` 73/73 passing. `test/screens_test.dart` pumps
  **every route at all three breakpoints** and fails on any overflow — it caught a
  duplicate FAB hero tag and two real overflows, so do not weaken it.

Still open:

1. Play a real file on a real Android device. `file_selector_android` may hand back a
   `content://` URI; `LocalSource.resolve` passes those through untouched, but **whether
   libmpv opens them has not been tested**. If it fails, copy to cache or resolve the fd.
2. Confirm the Linux build on a machine with `libmpv-dev`

Next is design build step 3: player chrome — gestures (brightness / volume / double-tap
seek), lock, rotation, track & quality sheets, more menu, chapter ticks, skip-intro and
the stats overlay. Then steps 4–5, the SMB/WebDAV and Jellyfin backends that replace the
sample data.

## Layout rules learned the hard way

- **Ink rings sit outside content.** `ContinueWatchingCard` and `PosterTile` inset their
  tappable surface by `spacing.hitInset`, so callers subtract `2 * hitInset` from gaps and
  padding to keep artwork on the design's grid. Both expose `outerWidth` / `outerHeight`;
  use those rather than re-deriving the arithmetic.
- **Never size a grid cell with `childAspectRatio`** when the child has fixed-height
  content — cell width varies with the window, dragging height with it. Pass
  `mainAxisExtent` and let the artwork flex.
- **Derive text heights from the theme and `MediaQuery.textScalerOf`, then `ceilToDouble()`
  per line.** The engine lays line boxes out on whole pixels, so `fontSize * height` can
  land a fraction short and overflow a fixed-height shelf.
- **Give every persistent FAB an explicit `heroTag`.** The rail's action outlives page
  transitions and collides with page-level FABs otherwise.

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

## Typography

Roboto is **bundled**, not fetched: `assets/fonts/Roboto-Variable.ttf`, the canonical
variable font from google/fonts (OFL-1.1). Do not add `google_fonts` — it downloads at
runtime, so a first launch without network would fall back to the system face on the very
first screen.

Declared once in `pubspec.yaml` with **no `weight:`**. Since Flutter's
[font-weight-variation change](https://docs.flutter.dev/release/breaking-changes/font-weight-variation),
a `TextStyle`'s `FontWeight` drives the `wght` axis directly, so one file covers every
weight the design uses. Adding per-weight entries would pin the axis and break this.

The OFL notice is bundled as an asset and registered with `LicenseRegistry` in
`main.dart`, so it appears in the About page's licences list.

Never set `titleTextStyle` (or any text style) from a freshly constructed `ThemeData` —
that instance has no font family, so the style silently loses Roboto. Let M3 resolve it.

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
