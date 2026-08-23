# mPlayer — Implementation Plan

Cross-platform video player and media server client.

- **Package**: `mplayer` · **Bundle ID**: `dev.icedtea.mplayer` · **Display name**: mPlayer
- **Priority platforms**: Android, Windows, Linux. iOS/macOS are scaffolded but deferred until a Mac is available.
- **Reference source**: [NipaPlay-Reload](../../refs/NipaPlay-Reload) (MIT) — service layer to adapt, not to fork wholesale.

---

## Expected workspace layout

After the planned move to `D:\Work\Projects\mPlayer-app`:

```
D:\Work\Projects\mPlayer-app\
├── mPlayer\              ← this Flutter app
│   ├── docs\PLAN.md      ← this file
│   ├── lib\
│   ├── assets\icon\      ← generated PNGs (source of truth is icon.svg at app root)
│   └── linux\packaging\  ← .desktop + hicolor icons
└── refs\
    └── NipaPlay-Reload\  ← read-only reference
```

Paths in this document are relative to the app root (`mPlayer/`).

---

## Verified environment facts

Established by actually building on this machine — do not re-litigate these.

| Fact | Value |
|---|---|
| Flutter / Dart | 3.44.0 stable / 3.12.0 |
| Android SDK installed | up to `android-37.0` |
| `media_kit` on Windows | ✅ builds, bundles `libmpv-2.dll` (28 MB) automatically |
| `media_kit` on Android | ✅ builds, bundles `libmpv.so` per ABI (~11–15 MB each) |
| Debug fat APK size | 199 MB (all 3 ABIs + symbols) — release with `--split-per-abi` will be far smaller |

### Gotchas already hit and resolved

- **`riverpod_generator` is unusable here.** It demands `analyzer ^13`, while `freezed 3.2.5` demands `analyzer ^12` and `drift_dev 2.34` caps lower. No combination resolves. → **Riverpod 3 providers are written by hand.** Do not add `riverpod_generator` back without re-checking the whole analyzer graph.
- **`riverpod_lint` + `custom_lint` are also excluded** — `riverpod_lint` pins `riverpod` to ≤3.1.0, incompatible with the resolved `riverpod 3.4.2`.
- **`compileSdk` is pinned to 37** in `android/app/build.gradle.kts` because `flutter_secure_storage 11.x` requires it. Flutter 3.44's default is 36.
- **`kotlin.incremental=false`** is set in `android/gradle.properties`. Without it this host intermittently fails with `Could not close incremental caches` (on-access AV scanning of the build dir is the likely cause). The same host also intermittently locks directories against rename.
- **Linux build needs system libmpv**: `sudo apt install libmpv-dev mpv` (or distro equivalent). `media_kit_libs_linux` does not vendor it the way Windows/Android do.

### Locked dependency versions

```
flutter_riverpod 3.4.2   drift 2.34.3 / drift_dev 2.34.0   media_kit 1.2.6
go_router 17.4.0         freezed 3.2.5                     media_kit_video 2.0.1
dio 5.11.0               json_serializable 6.14.1          analyzer 10.2.0
```

---

## Architecture

Two distinct abstractions — conflating them is the main design trap.

### `StorageDriver` — byte-level sources

Local disk, SMB, WebDAV, and later cloud drives. They hand you a filesystem and nothing else — titles have to be derived from filenames, and richer metadata only arrives later if a scraper is ever added (Phase 10, low priority).

```dart
abstract class StorageDriver {
  String get id;
  Future<List<RemoteEntry>> list(String path);
  Future<RemoteStat> stat(String path);
  Future<Uri> resolvePlayableUri(String path);   // may be a local proxy URL
  Stream<List<int>> openRange(String path, int start, int end);
  Future<void> dispose();
}
```

### `MediaLibrarySource` — catalog-level sources

Jellyfin and Emby. They hand you **metadata, artwork, playback URLs, and progress sync** already assembled.

```dart
abstract class MediaLibrarySource {
  String get id;
  Future<List<LibrarySection>> sections();
  Future<Page<MediaItem>> browse(String sectionId, {int offset, int limit});
  Future<MediaDetail> detail(String itemId);
  Future<PlaybackInfo> playbackInfo(String itemId, PlaybackCapabilities caps);
  Future<void> reportProgress(String itemId, Duration position, Duration duration);
}
```

A `StorageDriver` becomes a `MediaLibrarySource` by running it through the local **scanner + Drift cache**. That adapter is written once and serves SMB, WebDAV, local, and every cloud drive added later. Metadata enrichment plugs into the same adapter later as an optional decorator — the library must be fully usable without it.

### Layering

```
UI (Material 3)  →  Riverpod providers  →  repositories
                                              ├── MediaLibrarySource  (Jellyfin, Emby, ScannedLibrary)
                                              ├── StorageDriver       (local, SMB, WebDAV, cloud…)
                                              ├── Drift (metadata cache, watch history, profiles)
                                              └── PlaybackController  (wraps media_kit Player)
```

### Directory shape

```
lib/
├── main.dart
├── app/            app.dart, theme.dart, router.dart
├── core/           result types, errors, logging, extensions
├── data/
│   ├── db/         Drift database, DAOs, migrations
│   ├── storage/    StorageDriver + local/smb/webdav implementations
│   └── servers/    MediaLibrarySource + jellyfin/emby implementations
├── domain/         MediaItem, MediaDetail, PlaybackInfo, ServerProfile (freezed)
└── features/
    ├── playback/   PlaybackController, player UI, controls, gestures, subtitles
    ├── library/    browse, grid/list, detail pages
    ├── servers/    add/edit server, connection test
    ├── search/
    └── settings/
```

---

## Phase 0 — Foundation

- [x] Delete Ghosten-Player, move NipaPlay-Reload to `refs/`
- [x] `flutter create` with `--org dev.icedtea --project-name mplayer`, all 5 platforms
- [x] Add dependencies, resolve to stable versions
- [x] Verify `media_kit` builds and links on Windows
- [x] Verify `media_kit` builds and links on Android
- [x] `icon.svg` → launcher icons for Android (incl. adaptive + monochrome), iOS, Windows, macOS
- [x] Linux `.desktop` + hicolor icon set in `linux/packaging/`
- [x] Display name `mPlayer` on every platform
- [x] Smoke-test page + passing widget/unit tests
- [x] Move workspace to `D:\Work\Projects\mPlayer-app`
- [x] `git init`, first commit, `.gitignore` review
- [x] GPL-3.0-or-later `LICENSE` + per-file SPDX headers
- [ ] Run the smoke test on a real Android device and confirm video actually renders (build success ≠ playback success)
- [ ] Set up a Linux VM/WSL with `libmpv-dev` and confirm the Linux build

**Exit criteria**: the smoke-test page plays video on Windows, Android, and Linux.

---

## Phase 1 — App shell

The UI from here on follows the design bundle in `../design/` — `README.md` there is
the authoritative spec (tokens, screens `1a`–`1n`, adaptive table), and its build order
supersedes the ordering guesses in this phase list where the two disagree.

- [x] `app/router.dart` — go_router `StatefulShellRoute.indexedStack`, 3 branches
      (Storage / Server / Search), Settings above the shell
- [x] Responsive breakpoint helper — `WindowSize` in `app/tokens.dart` (600 / 1240)
- [x] `app/adaptive_scaffold.dart` — `NavigationBar` / `NavigationRail` / `NavigationDrawer`
- [x] Material 3 theme: seeded `0xFF0A6E9E`, role values pinned to the design table,
      spacing/radii/semantic colours as `ThemeExtension`s
- [x] Screens 1a (Storage), 1c (Server empty + add-server sheet), 1n (Search idle),
      1l (Settings index) against placeholder data
- [x] Bundle Roboto (variable, OFL) — `google_fonts` rejected, it fetches at runtime
- [x] Theme mode + accent persisted via `shared_preferences` — `app/appearance_settings.dart`,
      read by the app root. Pure-black dark and Material You (Android 12+, via
      `dynamic_color`) ride along with it
- [ ] Replace `core/sample_data.dart` with repository-backed Riverpod providers

### Design build step 2 — playback core (done)

- [x] `sources/media_source.dart` — `MediaSource`, `MediaRef`, `PlayableMedia`,
      `SourceCapabilities`, `MediaSourceException`
- [x] `sources/local_source.dart` — device files + `file_selector` picker
- [x] `features/player/playback_controller.dart` — Riverpod `Notifier` over `media_kit`;
      `media_kit` types stay out of the UI apart from the `Video` surface itself
- [x] `features/player/player_page.dart` — screen 1h: video surface, transport, scrubber,
      auto-hiding chrome, keyboard transport, inline error
- [ ] Verify a `content://` handle from the Android picker actually opens in libmpv

**Dependency note**: `file_picker` is unusable here — 8.3.3–11.x pin `win32 ^5.9.0` while
`flutter_secure_storage_windows` needs `win32 ^6.0.1`. Use `file_selector` (flutter.dev).

### Design build step 3 — player chrome (done)

- [x] `controls_overlay.dart` — top bar (PiP/cast/overflow), transport, scrubber with
      chapter ticks, control-row pills (subtitles / audio / quality / speed) and the
      lock · rotation · chapters · fullscreen icon buttons
- [x] `gesture_layer.dart` — left third brightness, right third volume, double-tap ±10/30s,
      horizontal drag scrub, each with its own indicator
- [x] `track_sheet.dart` — subtitle, audio, speed and chapter pickers
- [x] `more_menu.dart` — rotation, lock, aspect, sleep timer, stats, player settings
- [x] `stats_overlay.dart` — monospace key/value card, `—` for anything unreported
- [x] `player_ui_state.dart` — lock, rotation, aspect, stats, sleep timer as a Notifier
- [x] Locked state: dim, double-tap-to-unlock, progress bar stays visible
- [x] Container chapters read from libmpv `chapter-list/*`, so local MKV/MP4 files get
      ticks and a chapter sheet; source chapters take precedence when a server supplies
      them, since only those mark intros reliably
- [ ] Verify the `chapter-list` read against a real chaptered MKV — no sample file or
      ffmpeg on this machine, so only the precedence logic is unit-tested
- [x] Casting over **DLNA/UPnP**, hand-written in Dart (`lib/cast/`): SSDP discovery, the
      device description, and AVTransport over SOAP. Works on Android, Windows and Linux
      alike, and a second `MediaProxyServer` bound to the LAN serves the file — a
      television cannot fetch the loopback address libmpv plays from
- [ ] Casting to **Chromecast** — needs `play-services-cast-framework` and a Kotlin
      channel behind the same `CastRenderer` interface. Android only
- [x] Audio delay (A/V sync) — in Player settings and in the player's overflow menu,
      since it is a fault you notice mid-film
- [x] Picture-in-picture — `PipChannel.kt` + `features/player/pip_controller.dart`.
      Auto-enters when the user leaves mid-play (API 31+ from the params, 26-30 from
      `onUserLeaveHint`), and the window's own transport buttons run the player's own
      methods
- [ ] Quality / transcode control — meaningless until a server can transcode (step 5)

### Design build step 4 — filesystem sources (partly done)

- [x] `BrowsableSource` interface — `listDirectory` split out of `MediaSource`
- [x] `LocalSource` browsing: device folders, dot-files skipped, folders-first sort
- [x] `WebDavSource` — hand-written PROPFIND over dio, tested against captured
      Nextcloud and Apache mod_dav responses; playback streams straight from the server
      with a Basic auth header, so it is direct-play
- [x] `SourceRegistry` + `SourceRepository` — configs in `shared_preferences`,
      passwords in `flutter_secure_storage`, never together
- [x] Add-share sheet with a real connection test before saving
- [x] Screen 1b wired to live listings: loading, inline retry on failure, empty state
- [ ] **SMB driver.** Blocked on a design decision, not on effort: libmpv cannot read a
      Dart stream, so `smb_connect.openRead` needs a local `HttpServer` bridge on
      `127.0.0.1` that maps Range requests onto `openRead(start, end)`. Pure Dart, no
      native build. `refs/NipaPlay-Reload` needed a patched vendored `smb_connect` plus
      its own FFI package, so budget accordingly.
- [ ] NFS driver
- [ ] Network scan ("Or scan the local network" on the add tile)
- [ ] Resume points for network sources — needs the Drift schema from Phase 1
- [ ] `data/db/app_database.dart` — Drift schema v1:
  - [ ] `server_profiles` (type, url, credentials ref, display name, last used)
  - [ ] `media_items` (metadata cache)
  - [ ] `watch_history` (item id, position, duration, watched, updated_at)
  - [ ] `storage_sources` (driver type, root path, credentials ref)
- [ ] `flutter_secure_storage` wrapper for passwords/tokens — **never** put credentials in Drift
- [ ] Riverpod provider conventions documented in `docs/CONVENTIONS.md` (hand-written, no codegen)
- [ ] Global error surface (snackbar + log sink)
- [ ] Settings page skeleton: appearance, playback, sources, about

**Exit criteria**: navigable empty app with persisted theme and a migrating database.

---

## Phase 2 — Playback core

- [ ] `features/playback/playback_controller.dart` — wrap `media_kit` `Player`; expose position, duration, buffering, tracks, state as Riverpod `AsyncNotifier`s. Keep `media_kit` types out of the UI layer.
- [ ] Player page: video surface, tap-to-toggle chrome, auto-hide
- [ ] Seek bar with buffered range + preview thumbnail (desktop first)
- [ ] Track selection: audio, subtitle, video quality
- [ ] Subtitle rendering — ASS/SSA/SRT; verify `media_kit` handles ASS styling adequately before writing anything custom
- [x] External subtitle loading — "Open subtitle file" in the subtitle sheet, which
      loads *and* selects. Sidecar auto-detect needs no code: libmpv's own `sub-auto`
      already finds a file named after the video beside it
- [ ] Playback speed, aspect ratio / zoom modes
- [ ] Mobile gestures: double-tap seek, vertical drag for volume/brightness, horizontal drag to scrub, long-press speed-up
- [ ] Desktop: keyboard shortcuts, fullscreen, always-on-top, `window_manager` integration
- [ ] Playlist / next-episode queue
- [ ] Resume-from-position prompt
- [ ] Wakelock during playback

**Exit criteria**: play a local file with full controls on Windows and Android.

**Reference**: `refs/NipaPlay-Reload/lib/player_abstraction/` for the multi-kernel interface shape — but implement against `media_kit` only. Don't inherit their kernel-switching complexity yet.

---

## Phase 3 — Storage drivers

- [ ] `data/storage/storage_driver.dart` — the interface above
- [ ] `LocalStorageDriver` — `dart:io`, plus Android SAF handling for external storage
- [ ] `WebDavStorageDriver` — port from `refs/.../lib/services/webdav_service.dart` (1617 lines; adapt, don't copy blindly)
- [ ] `SmbStorageDriver` — evaluate `nipaplay_smb2` (their FFI package, `refs/.../packages/nipaplay_smb2`) vs a pure-Dart SMB client. FFI means per-platform native builds.
- [ ] Local HTTP proxy so `media_kit` can stream from drivers that only expose byte ranges (their `smb_proxy_service.dart` is the model)
- [ ] Connection test + credential capture UI
- [ ] Directory browser UI with breadcrumbs, sort, filter by media type
- [ ] Play directly from the browser without a library scan

**Exit criteria**: browse an SMB share and a WebDAV mount, play a file from each.

---

## Phase 4 — Media server clients

- [ ] `data/servers/media_library_source.dart` — the interface above
- [ ] `JellyfinSource`: auth (username/password + API key), libraries, items, images, playback info, direct play vs transcode decision, progress reporting
- [ ] `EmbySource`: same surface; Emby and Jellyfin diverged enough that a shared base plus two subclasses is right — mirror `refs/.../lib/services/media_server_service_base.dart` (837 lines)
- [ ] Quick-connect / device ID handling
- [ ] Multi-server support with a server switcher
- [ ] Transcode settings (max bitrate, resolution cap, force direct play)
- [ ] Image loading with a disk cache
- [ ] Handle multiple network addresses per server (LAN vs WAN) — see their `multi_address_server_service.dart`

**Exit criteria**: log into a Jellyfin server and an Emby server, browse libraries, play with progress reported back.

---

## Phase 5 — Library & scanning

Deliberately **without** metadata scraping. Jellyfin and Emby already supply metadata, so the scraper only benefits raw file sources — and a filename-derived library is perfectly usable in the meantime. Scraping is deferred to Phase 10.

- [ ] Scanner: walk a `StorageDriver`, detect video files, group into movies / series-season-episode
- [ ] Filename parser (title, year, S01E02, resolution, release group) — this alone carries the whole library UX until Phase 10
- [ ] Folder-structure heuristics (`Show/Season 01/…`) as a second signal
- [ ] Sidecar artwork pickup: `poster.jpg`, `folder.jpg`, `fanart.jpg` next to the media — cheap, no network, covers most well-organised libraries
- [ ] Video thumbnail generation as poster fallback (`media_kit` screenshot at ~10%)
- [ ] Incremental rescan + scheduled background scan
- [ ] `ScannedLibrarySource` adapter exposing scanned content as a `MediaLibrarySource`
- [ ] Design the adapter so a metadata decorator can be slotted in later without touching the UI layer

**Exit criteria**: point at an SMB folder of movies, get a browsable, playable library with sensible titles and whatever artwork is already on disk.

---

## Phase 6 — History, resume, sync

- [ ] Unified watch history across all source types
- [ ] Continue Watching row on home
- [ ] Next Up for series
- [ ] Two-way progress sync with Jellyfin/Emby (server wins on conflict, configurable)
- [ ] Mark watched/unwatched, favorites
- [ ] Export/import of local history

---

## Phase 7 — Desktop polish

- [ ] Window size/position persistence (`window_manager`)
- [ ] System tray with playback controls (optional)
- [ ] File association: open a video file with mPlayer (Windows registry, Linux `.desktop` MimeType already declared)
- [x] Command-line argument handling (`mPlayer video.mkv`) — the Windows and Linux
      runners already forward the arguments; `main` feeds them to `incomingMediaProvider`
- [ ] Drag-and-drop a file onto the window
- [ ] Single-instance enforcement
- [ ] Global media key handling

---

## Phase 8 — Mobile polish

- [x] Picture-in-picture (Android)
- [x] Background audio + media notification — `PlaybackService.kt`, a foreground service
      owning the notification, a `MediaSession` for the lock screen and headset buttons,
      and audio focus. Every button is forwarded to Dart rather than acted on natively
- [x] Screen orientation control per-context
- [x] Handle audio focus / interruptions — pauses on focus loss and on
      `ACTION_AUDIO_BECOMING_NOISY`; ducking is deliberately not offered
- [ ] Android storage permissions (scoped storage, `MANAGE_EXTERNAL_STORAGE` only if truly needed)
- [ ] Battery-aware behaviour on mobile data

---

## Phase 9 — Cloud drives

Neither reference project provides usable code here — Ghosten's cloud support was closed-source, NipaPlay has none. This is greenfield.

- [ ] Extend `StorageDriver` with an OAuth-capable base
- [ ] Token storage + refresh in secure storage
- [ ] Per-provider implementation, one at a time — pick based on actual need:
  - [ ] WebDAV-compatible providers (already covered by Phase 3)
  - [ ] OneDrive / Google Drive (well-documented REST + OAuth)
  - [ ] Alipan / Quark (Chinese providers; undocumented APIs, higher maintenance burden)
- [ ] Range-request streaming through the local proxy
- [ ] Download-and-cache for unstable connections

---

## Phase 10 — Metadata scraping (low priority)

Explicitly deprioritised. It applies **only** to raw file sources — media servers already provide metadata — and Phase 5 makes those sources usable without it. Pick this up when the rest of the app is solid, or skip it entirely if server-backed libraries turn out to be the real use case.

- [ ] Metadata provider interface, designed as a decorator over `ScannedLibrarySource`
- [ ] `.nfo` reader first — no network, no API key, no rate limits, and it covers libraries already curated by Jellyfin/Emby/Kodi
- [ ] TMDB provider (user-supplied API key in settings; **never** bake a key into the binary)
- [ ] Local artwork cache on disk + Drift index
- [ ] Manual match / re-identify UI
- [ ] Rate limiting, retry, and offline degradation
- [ ] Make the whole feature switchable off without breaking the library

**Exit criteria**: the same SMB library from Phase 5, now with posters, synopses, and cast — and still working correctly when the scraper is disabled.

---

## Phase 11 — Packaging & release

- [ ] Android: release signing config, `--split-per-abi`, R8 rules for `media_kit`
- [ ] Windows: MSIX or Inno Setup installer; confirm `libmpv-2.dll` ships
- [ ] Linux: `.deb` + AppImage (bundle libmpv or declare the dependency), reuse `linux/packaging/`
- [ ] Flatpak manifest (optional)
- [ ] CI: GitHub Actions matrix for Android + Windows + Linux
- [ ] Version bump + changelog process
- [ ] Crash/error reporting decision (self-hosted vs none — avoid third-party telemetry by default)

---

## Phase 12 — Apple platforms (deferred)

Blocked on Mac hardware.

- [ ] macOS build + entitlements (network client, file access)
- [ ] iOS build, background modes, App Store review considerations for a media client
- [ ] Verify `media_kit` HDR/hardware decode behaviour on Apple silicon
- [ ] Notarization / signing pipeline

---

## Cross-cutting

- [ ] Localization (`flutter_localizations` + ARB) — English and Vietnamese from the start; retrofitting is painful
- [ ] Accessibility pass: semantics labels, focus order, contrast
- [ ] Test strategy: unit tests for parsers/drivers, widget tests for controls, integration test for the playback happy path
- [ ] `docs/CONVENTIONS.md` — Riverpod patterns, error handling, naming
- [ ] Performance: large-library scrolling, image cache limits, memory on 2 GB Android devices

---

## Deliberate non-goals (for now)

- Danmaku / bullet comments
- Multiple player kernels (media_kit only until there's a concrete reason)
- Anime-specific integrations (Bangumi, dandanplay)
- Built-in torrent client
- Plugin system
