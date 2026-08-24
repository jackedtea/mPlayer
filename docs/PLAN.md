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
| Debug fat APK size | 199 MB (all 3 ABIs + symbols) |
| Release APK, per ABI | armeabi-v7a 36.2 MB · arm64-v8a 39.3 MB · x86_64 44.2 MB (`--split-per-abi`) |
| Cost of the Cast SDK | ~0.9 MB per ABI after R8 |

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

What was built, which is flatter than the sketch this section used to hold — the
`data/` and `domain/` split never earned its keep while every source was a driver with
one job:

```
lib/
  main.dart
  app/         app.dart, theme.dart, router.dart, tokens.dart, appearance_settings.dart
  cast/        CastRenderer + DLNA (ssdp, upnp, dlna_renderer) and Chromecast
  core/        models, resume_repository, thumbnail_store, languages, sample data
  sources/     MediaSource + local / MediaStore / SAF / SMB / WebDAV + media_proxy_server
  features/
    player/    PlaybackController, chrome, gestures, PiP, now-playing, smart subtitles
    cast/      device picker, casting overlay, controller
    files/     screen 1a, share sheet
    browse/    screen 1b
    servers/   screens 1c-1g - still on sample data
    search/    screen 1n - still on sample data
    downloads/ screen 1i - still on sample data
    settings/  screens 1l/1m
```

`MediaLibrarySource` and the Drift cache land with Phase 4; there is no `data/` layer
until something needs one.

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
- [x] Screens 1a and 1b read live data (`SourceRegistry`, the drivers, `ResumeRepository`)
- [x] Localisation of every screen that is real — player, Files, Browse, the share sheet,
      casting and all seven settings pages. The sample-data screens are left in English
      on purpose: they are rewritten with Phase 4
- [ ] Screens 1d-1g, 1i and the active state of 1n still render `core/sample_library.dart`
      — they are the Jellyfin client's UI and land with Phase 4

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
- [x] Casting to **Chromecast** — `CastChannel.kt` over `play-services-cast-framework`,
      behind the same `CastRenderer` interface. Android only, and optional at runtime: a
      device without Play Services simply lists no Chromecasts. Adds ~0.9 MB per ABI
      after R8. The default media receiver plays MP4/WebM and **not** Matroska, which a
      rejected load reports in words
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
- [x] **SMB driver** — `sources/smb_source.dart` over `dart_smb2`, with
      `sources/media_proxy_server.dart` as the local HTTP bridge: libmpv cannot read a
      Dart stream, so Range requests are mapped onto offset reads and libmpv is pointed
      at `http://127.0.0.1:<port>/...`. Pure Dart — no vendored package and no FFI were
      needed in the end
- [x] `MediaStoreSource` and `SafSource` — scoped storage forbids listing shared storage
      directly, so the Files tab is built from Android's media index, with SAF for the
      folders it cannot see
- [x] Resume points for every source — `ResumeRepository` keys on `sourceId::itemId` in
      `shared_preferences`, so a share resumes like a local file. No Drift needed
- ~~NFS driver~~ — **dropped.** No viable pure-Dart client exists, so it would mean
      hand-written RPC/XDR or an FFI package with a native build per platform. SMB and
      WebDAV cover the same shares on every NAS worth supporting
- ~~Network scan~~ ("Or scan the local network" on the add tile) — dropped; a share is
      added by address
- [ ] `data/db/app_database.dart` — Drift schema v1:
  - [ ] `server_profiles` (type, url, credentials ref, display name, last used)
  - [ ] `media_items` (metadata cache)
  - [ ] `watch_history` (item id, position, duration, watched, updated_at)
  - [ ] `storage_sources` (driver type, root path, credentials ref)
- [ ] `flutter_secure_storage` wrapper for passwords/tokens — **never** put credentials in Drift
- [ ] Riverpod provider conventions documented in `docs/CONVENTIONS.md` (hand-written, no codegen)
- [ ] Global error surface (snackbar + log sink) — errors currently surface per screen
- [x] Settings pages: Appearance, General, Player, **Audio**, Subtitle, About, plus
      Diagnostics and Privacy below About

**Exit criteria**: navigable app with persisted theme — met, except for the database,
which nothing needs before Phase 4.

---

## Phase 2 — Playback core

Done, apart from the three items marked open. The controller is
`features/player/playback_controller.dart` (a hand-written `Notifier`, not an
`AsyncNotifier` — the state is a single value, not a future) and it is the only place
outside the video surface that imports `media_kit`.

- [x] `features/player/playback_controller.dart` — position, duration, buffering, tracks
      and state as one `PlaybackState`
- [x] Player page: video surface, tap-to-toggle chrome, auto-hide
- [ ] Seek bar: buffered range — `PlaybackState.buffered` is tracked but the scrubber
      does not draw it
- ~~Preview thumbnails on the scrubber~~ — dropped
- [x] Track selection: audio and subtitle. Video quality needs a server that transcodes,
      so the pill hides until one exists
- [x] Subtitle rendering — ASS/SSA/SRT through libass (`libass: true`), with styling for
      the plain-text formats. See the Subtitles section of `CLAUDE.md` for the PGS
      problem and how the bundled libmpv was replaced to fix it
- [x] External subtitle loading — "Open subtitle file" in the subtitle sheet, which
      loads *and* selects. Sidecar auto-detect needs no code: libmpv's own `sub-auto`
      already finds a file named after the video beside it
- [x] Playback speed, aspect ratio / zoom modes, rotation, sleep timer, lock
- [x] Mobile gestures: double-tap seek, vertical drag for brightness and volume,
      horizontal drag to scrub. **Long-press speed-up is not implemented**
- [x] Desktop: keyboard transport and fullscreen through `window_manager`. Always-on-top
      is not implemented
- [x] Playlist / next-episode queue — the folder the file came from, loaded after
      playback starts so the first frame never waits on a directory listing
- [x] Resume — applied **silently** from `ResumeRepository` rather than by prompting.
      Deliberate: a dialog between the user and their film is worth more than the two
      seconds it saves when the guess is wrong
- [x] Wakelock during playback — nothing to write: `media_kit_video`'s `Video` widget
      owns one and defaults it on
- [x] Audio delay (A/V sync), smart subtitles, external subtitle loading

**Exit criteria**: play a local file with full controls on Windows and Android — met on
Windows; Android is built and installed but has never been run on a real device.

**Reference**: `refs/NipaPlay-Reload/lib/player_abstraction/` for the multi-kernel interface shape — but implement against `media_kit` only. Don't inherit their kernel-switching complexity yet.

---

## Phase 3 — Storage drivers

Done, and not as this phase imagined it: there is no separate `StorageDriver`. The
`MediaSource` / `BrowsableSource` pair from Phase 1 turned out to cover both jobs, and a
second interface would only have been a second thing to implement per source.

- [x] `sources/media_source.dart` — `MediaSource` resolves for playback, `BrowsableSource`
      adds `listDirectory`
- [x] `LocalSource`, plus `MediaStoreSource` and `SafSource` for Android's scoped storage
- [x] `WebDavSource` — hand-written PROPFIND over dio, tested against captured Nextcloud
      and Apache mod_dav responses. The reference implementation was not ported: listing
      is the only operation needed and playback bypasses the client entirely
- [x] `SmbSource` over `dart_smb2` — pure Dart, no FFI and no vendored fork
- [x] `sources/media_proxy_server.dart` — the local HTTP bridge, with Range parsing and
      1 MiB chunked reads. Also what serves a file to a television when casting
- [x] Connection test + credential capture UI (`features/files/source_sheet.dart`)
- [x] Directory browser with breadcrumbs (screen 1b), play straight from it
- [ ] Filter by media type in the browser

**Exit criteria**: browse an SMB share and a WebDAV mount, play a file from each — the
code path is complete and unit-tested; neither has been run against a real NAS.

---

## Phase 4 — Media server clients

- [x] `servers/media_library_source.dart` — the interface, plus the domain types
      (`LibraryView`, `ServerItem`, `ServerPlayback`, `PlaybackCapabilities`). Deliberately
      **not** the `core/models/library_models.dart` types: those hold strings the design
      already shaped ("2h 16m", "48m · watched") and an `IconData`, so building them in
      the data layer would put formatting and translation behind the network client
- [x] `servers/jellyfin_source.dart` + `servers/jellyfin_dto.dart` — probe, sign in,
      views, items, episodes, resume, next-up, search, artwork, playback info and the
      whole progress/played/favourite surface. Parsing is a separate, pure file so the
      protocol is tested against captured responses with no server, the same split
      `parsePropfind` follows
- [x] `servers/server_registry.dart` — profiles in preferences, tokens in the keychain,
      the same two-store split `SourceRepository` keeps. Also owns the **stable device
      id**: Jellyfin files sessions and tokens under it, so a fresh one per launch
      orphans the token issued to the last
- [x] The add-server sheet is real: the address is probed as it is typed (before any
      password is asked for), and sign-in stores a working session
- [x] Quick Connect — offered only where the server actually has it
- [x] The screens are wired: server home (1d) with Continue watching, Next up, Recently
      added and the library list; the library grid (1e) with a real sort; movie detail
      (1f); series with its seasons (1g); and server search (1n). Only Downloads (1i) is
      still on sample data, and that is parked until after this phase
- [ ] Artwork: `imageUrl` is built and tested but nothing draws it yet — the tiles still
      render the gradient placeholder
- [ ] Playing from a server: `playback()` resolves a URL, but the detail screen's Play
      button does not call it yet
- [ ] Progress reporting from the player back to the server
- [ ] Map the domain types onto what the screens draw — the presentation models will
      need reshaping, since they were written around the sample data
- [ ] `EmbySource`: same surface; Emby and Jellyfin diverged enough that a shared base plus two subclasses is right — mirror `refs/.../lib/services/media_server_service_base.dart` (837 lines)
- [x] Quick-connect / device ID handling
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

- [x] Unified watch history across all source types — `ResumeRepository`, keyed
      `sourceId::itemId`, throttled to one write every 5 seconds. Barely-started and
      finished files are dropped rather than stored
- [x] Continue Watching row, on the Files screen rather than a home screen (there is no
      home until a server exists), with stills grabbed off the player by
      `core/thumbnail_store.dart`
- [ ] Next Up for series
- [ ] Two-way progress sync with Jellyfin/Emby (server wins on conflict, configurable)
- [ ] Mark watched/unwatched, favorites
- [ ] Export/import of local history

---

## Phase 7 — Desktop polish

- [x] Window size/position persistence — `app/desktop_window.dart`. A minimised or
      fullscreen window is deliberately not saved, and a position on a monitor that has
      since been unplugged is discarded rather than restored off-screen
- [ ] File association: open a video file with mPlayer (Windows registry, Linux `.desktop` MimeType already declared)
- [x] Command-line argument handling (`mPlayer video.mkv`) — the Windows and Linux
      runners already forward the arguments; `main` feeds them to `incomingMediaProvider`
- [x] Drag-and-drop a file onto the window — `desktop_drop`, wrapping the navigator so a
      drop anywhere plays, not only on the Files tab
- [x] Single-instance enforcement — binding a fixed loopback port *is* the lock: exactly
      one process gets it, and a second launch hands its file over that socket and exits
- ~~Global media key handling~~ — **dropped for now.** Android already has it through the
      `MediaSession` the playback service owns. On desktop the only route is
      `hotkey_manager`, whose Linux implementation needs `keybinder-3.0` **at run time as
      well as build time** — every Linux user would have to install a second system
      package beside libmpv for a convenience. Reconsider if desktop becomes the main
      platform
- [ ] System tray with playback controls — same question, lower value: a video player
      that hides in the tray is a niche want, and it is another dependency

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

- [x] Android: release signing from repository secrets, `--split-per-abi`. No extra R8
      rules were needed for `media_kit`
- [ ] Windows: MSIX or Inno Setup installer; confirm `libmpv-2.dll` ships
- [ ] Linux: `.deb` + AppImage (bundle libmpv or declare the dependency), reuse `linux/packaging/`
- [ ] Flatpak manifest (optional)
- [x] CI: `.github/workflows/release.yml` builds Android, Windows and Linux, publishes a
      GitHub release and posts to Telegram. `main` is the only production branch; every
      other ref ships as a dev channel with a `.dev` application id
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
