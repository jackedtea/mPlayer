# mPlayer

Cross-platform **client** for a Jellyfin media server: browse a library,
play it in the built-in player, cast it to a television, administer the
server.

**The player is intact. The local sources are gone.** mPlayer no longer opens
a file from the device, a SAF folder, the Android media index, an SMB share or
a WebDAV mount — it plays what a server resolves and nothing else. Read
"Current state" before anything else; several sections below describe code
that has been removed, and they say so where they do.

**Read [docs/PLAN.md](docs/PLAN.md) first** — it holds the architecture, the phase checklist, and the environment gotchas already resolved.

## Current state (2026-10-18)

**mPlayer is a media-server client with a built-in player.**

Real, end to end: sign in to a Jellyfin server, browse its libraries,
open a film or an episode and **play it in the app** — chapters, the track
pickers, skip-intro from the server's media segments, trickplay previews on
the scrubber, external subtitles, smart subtitles, audio delay, picture in
picture, background audio with a media notification. Or cast it to a DLNA
renderer or a Chromecast. Watch state goes back to the server as it plays.

### What was removed, and what it means

The **local half** of the app went; the player did not.

| Removed | Why |
|---|---|
| `sources/local_source.dart`, `saf_source.dart`, `media_store_source.dart`, `smb_source.dart`, `webdav_source.dart` | The device library and network shares |
| `sources/source_registry.dart`, `source_config.dart` | Configured shares and their keychain entries |
| `sources/media_proxy_server.dart` | Existed only to serve `smb://` to libmpv over loopback |
| `features/files/`, `features/browse/` | The Files tab and the folder browser |
| `features/player/open_local_video.dart`, `incoming_media.dart` | The file picker, and the VIEW/SEND intents and command-line argument that carried a file in |
| `core/resume_repository.dart`, `core/thumbnail_store.dart` | Local resume points and the frame grab that illustrated them |
| `widgets/source_tile.dart` | A row describing a configured share |
| Android `IntentChannel.kt`, `MediaStoreChannel.kt`, `SafChannel.kt`, every VIEW/SEND intent filter, the media-read permissions | The above, natively |
| `BrowsableSource`, `siblingVideosOf`, `StableItemId`, `classifyFile`, the video extension set | The folder-as-playlist world |
| Deps: `dart_smb2`, `desktop_drop`, plus the never-used `drift`, `freezed`, `json_annotation` and their codegen | Nothing left imports them |

**Kept, and still the point of the app:** `media_kit` and the whole of
`features/player/`, `PlaybackService.kt`, `PipChannel.kt`,
`NowPlayingChannel.kt`, the Player/Audio/Subtitle settings pages, chapters,
media segments, trickplay, external subtitles, and casting.

Three consequences worth knowing:

1. **The queue is server-only.** `PlaybackController._sourceSiblings` used to
   fall back to the folder a file sat in, and then to the Android media index
   for a file handed over by another app. Only `QueueableSource.siblingsOf` is
   left, so prev/next and auto-play-next work on a *series* and nothing else.
2. **There is no local resume store.** `_recordProgress` reports to the server
   and stops there. It used to write a local point with a JPEG of the current
   frame beside it, every five seconds, so the Files tab's Continue-watching
   shelf worked offline — there is no such shelf, and the server has been
   collecting the position from every device anyway.
3. **Casting needs no proxy.** A server stream is already an address on the
   network with its token in the query, so the URL goes straight to the
   television. `_publish` refuses a non-http(s) URL, one carrying auth
   *headers* (they do not travel with a URL) and a loopback host, each with a
   sentence.

The one local file still opened is a **subtitle**:
`features/player/subtitle_picker.dart`, for a `.srt` the server does not have.

The server screens were then reworked for **one-handed use** — Settings moved
into the bottom bar, the detail screens pin Play to the foot of the scaffold
on a phone, and Search became a FAB. See "One-handed use, and what it moved".

### Verified

- `flutter analyze` clean; `flutter test` **492 passing, 1 failing**.
- The failure is `test/workflow_test.dart`, "the jq program contains no
  apostrophes" — **pre-existing**, reproduced on a clean HEAD checkout, and
  nothing to do with this change. The "317 passing" this section used to
  claim was already stale.
- Windows debug build links and runs.
- `test/screens_test.dart` still pumps **every route at all three
  breakpoints** and fails on any overflow. Do not weaken it.
- `l10n_untranslated.json` is `{}`. 31 keys were stripped from both ARBs —
  only the ones this change orphaned; 52 that were already unreferenced at
  HEAD were left alone deliberately.

**Everything platform-specific is still unverified on a real device:** the
Linux build, picture in picture, the background-audio service and its
notification, audio focus, DLNA casting, Chromecast casting. `content://`
handles through libmpv and container chapters from a real MKV have dropped off
that list — there is no local file to have either.

Also open:

1. Downloads (screen 1i) is real end to end (see "Downloads"). Offline
   playback, the Android download service and Wi-Fi-only are unverified on
   a real device.
2. English literals remain where Localisation says.
3. Dropped on purpose: **NFS**, **network scanning**, **preview thumbnails**
   generated locally (the server's trickplay covers it), and now every local
   source.

## Five-tab shell (2026-11-01)

**Home · Libraries · Search · Downloads · Settings**, in `AppBranch` order
(`app/adaptive_scaffold.dart`).

- **Home** (`features/home/home_page.dart`) picks a face instead of
  navigating: empty state, the server list, or the server's home.
  `serverSessionProvider` (`servers/auto_connect.dart`) says whether this
  launch has gone into a server; with `autoConnectProvider` on (default) it
  turns true by itself once the registry has signed the last profile back in.
  "Switch server" in the avatar menu sets it false. Tabs read
  `connectedServerProvider`, which is null until then, so Libraries/Search
  don't quietly show a server Home is still asking about. `/servers` and
  `/servers/home` are gone.
- The home is a carousel (phone) or banner (wider) of the 10 most recent resumables, Next up, and
  a "Recently added in X" row per library. Which libraries is the server's
  `UserConfiguration.LatestItemsExcludes` — the same list the web client's
  Home settings edit. Saving posts the **whole** configuration back (the
  server replaces it), to `/Users/Configuration?userId=`.
- **Libraries** opens straight into the library last browsed on this server
  (`lastLibraryProvider`, per profile id), else the first. The app-bar title
  is a switcher; no list of libraries in front. Four tabs: Browse,
  Suggestions, Collections, Playlists. Sort and filter are one dialog behind a
  FAB on Browse (`showLibraryOptionsDialog`), with removable chips over the
  grid for what is on. `/library` above the shell is still what drill-downs
  and item tiles use.
- The Home carousel is a `PageView`, not `CarouselView`: the latter hard-wires
  its snapping physics and a flick runs through several items.
  It loops both ways and moves on by itself every 9 s like the banner, holding
  while touched, hovered or focused, while its tab or the player hides it, and
  for someone who asked for less motion.
- **No navigation while Home is choosing a server** (empty state or list):
  `AdaptiveScaffold` drops the bar/rail/drawer on the Home branch when
  `connectedServerProvider` is null.
- **Back** at the root of any destination but Home goes Home (`_BackToHome`
  in `adaptive_scaffold.dart`); only Home leaves the app. It needs both halves:
  the `PopScope`, and swallowing the branch navigator's "cannot pop"
  notification, which otherwise tells Android 16's predictive back not to send
  the press to Flutter at all.
- **Start tab** (`app/start_tab.dart`, General settings): a tab to open on, or
  the last one used, device-local since it is needed before any sign-in. A
  launch still begins on Home and moves once a server is open
  (`_StartOnChosenTab`), so no server or a locked one stays where it gets solved.
- **Group by collection** (View options sheet, movie, TV and plain-folder
  libraries): `collapseBoxSetItems` on the grid and its count, always sent so
  an admin's server-wide default cannot contradict the switch. Saved per library
  in the server's `DisplayPreferences` for this client, no local copy. The server
  ignores it while a filter is on.
- **Item details are not cached past their screen.** `serverItemProvider` and
  `seriesEpisodesProvider` are `autoDispose`, so opening an item asks again.
  A detail screen stays mounted under the player, so they also watch
  `playbackStopsProvider`, bumped once the stop has reached the server.
  The resume and Next up shelves (Home, a library's Suggestions) watch it too.
- **Search**: a second tap on the destination focuses the field
  (`searchFocusRequests`).
- **Downloads** lists the offline copies from `downloadsProvider`; see "Downloads".
- **Settings** opens on `CurrentServerCard` (name, host, user, admin badge;
  Edit server / Switch server, or Add server with none), then App settings
  and, for an administrator, one Server administration row into the `/admin`
  dashboard (2026-11-10: the per-screen shortcuts beside it duplicated the
  dashboard and had already drifted from it). **About is the last row**, under the
  server section (2026-11-11); the page prints no version line of its own — the
  hard-coded "mPlayer 1.0.0 · build 1" it had was never the real version.
  A Quick Connect row approves another device's code
  (`POST /QuickConnect/Authorize`); its 401/403 means the feature is off, so it
  bypasses `_send`, which would read them as an expired session.
- **Quick Connect sign-in** (add-server sheet): `POST /QuickConnect/Initiate`
  first (10.9+ is POST-only; GET only on a 405 for 10.8), then poll
  `/QuickConnect/Connect` until approved. The poll takes a `cancelled`
  callback, so Cancel / New code / closing the sheet stop it at once. The
  choice stays visible but greyed when the server has Quick Connect off.
  Countdowns are tickers decrementing seconds, not `DateTime.now()` deltas —
  widget tests' fake time does not move the wall clock.
- **Server PIN** (`servers/server_pin.dart`, `features/servers/pin_lock.dart`):
  optional per profile, 4–8 digits. Keychain holds `v1:<salt>:<hash>`
  (20k rounds SHA-256, via `compute`); the profile holds only
  `pinProtected`. A guarded server not yet unlocked makes
  `connectedServerProvider` null — that is what keeps every tab and the
  navigation bar shut — and Home shows `PinLockPage`. Unlocks are memory only
  (`unlockedServersProvider`) and "Switch server" locks all again. Five wrong
  tries pause it 30 s. Changing or removing a PIN asks for the current one.
  It is a lock on the app's door, not encryption: the token beside it is in
  the same keychain.
- **Updates** (`core/update_check.dart`, `core/updater.dart`,
  `features/settings/update_dialog.dart`). Channel-aware: a release build
  asks `/releases/latest` and compares numbers; a dev build (`-dev-<sha>`)
  takes the `dev-<sha>` prerelease with the latest `published_at` and
  compares commits, because "latest" never points at a prerelease.
  **Never take the first one listed**: GitHub does not keep `/releases` in
  order, and on 2026-11-09 a dev build was offered an older one that way
  (`newestDevRelease`). The launch check lives in
  `AdaptiveScaffold` (never over the player), runs in **release builds
  only** (`updateAutoCheckAllowedProvider` = `kReleaseMode`, which also keeps
  widget tests off the network), at most every 20 h (a day with slack, so
  a same-time-each-evening launch is not skipped for being 23 h 50 m on) or
  on every launch if "Check every time the app opens" is on, honours a
  skipped tag, and has both switches in General.
  **A store copy never self-updates** (`core/install_source.dart`): Android
  asks `UpdateChannel.kt`'s `installSource` for the installing package and
  Dart matches it against `androidStores` (Play, Galaxy, Amazon, AppGallery,
  F-Droid and clients, …); Windows is an MSIX when `GetCurrentPackageFullName`
  (FFI) finds a package identity; Linux is Flatpak/Snap by environment.
  Anything unknown — the package installer, adb, Obtainium — is a GitHub
  copy. For a store copy the launch check returns null, General hides both
  switches, and About shows "Updates through <store>" (opening `market://`
  or the Microsoft Store's updates page) instead of Check for updates. Install: Android downloads the APK for the device's ABI (or, from a 2026-11-02..08 release, the universal one) into
  `cache/updates/` and `UpdateChannel.kt` hands it to the system installer
  through a FileProvider (`REQUEST_INSTALL_PACKAGES`); Windows/Linux download
  the installer and start a detached PowerShell/sh script that waits for the
  PID, installs (Windows: the setup `.exe` with `/VERYSILENT /DIR=<install
  dir>`; Linux: `pkexec dpkg -i` on the `.deb`), and restarts the app
  regardless — a non-writable install dir is refused up front on Windows.
- **Player chrome**: one audio-and-subtitle button (top bar) opening the
  two-pane `AudioSubtitleDialog`; the bottom bar is lock, rotation, zoom,
  chapters, fullscreen. Background play, speed, loop and screenshot are a
  quick-action tile row at the top of the More sheet, which gave up its
  rotation/aspect rows (duplicates of bar buttons) to stay within a
  landscape phone's height.
- **Jellyfin only.** Emby was removed on 2026-11-01: `ServerKind` is gone,
  the probe refuses an Emby server with a sentence, and a stored Emby profile
  is skipped on load.

## Wide windows and television (2026-11-02)

- **Home's top is a banner past 600dp** (`features/home/home_hero.dart`):
  one resumable at a time across the full width — backdrop, overview,
  Resume / Details, a pager. It advances every 9 s and **holds while hovered
  or while focus is inside it**. A phone keeps the `PageView` carousel.
- **Shelves size their tiles from the row's width** (`ShelfMetrics` in
  `features/servers/shelves.dart`): fixed 104px posters / 200px cards on a
  phone, growing with the window above that, bigger again on a television.
  `ShelfRow` adds ‹ › paging arrows on hover (not on a phone, never in focus
  traversal) and `focusRoom` padding so a focused tile can grow unclipped.
- **`FocusRing`** (`widgets/focus_ring.dart`) rings and lifts a tile while
  something in it has focus, only in traditional highlight mode — a tap
  leaves no ring behind.
- **Television** is detected once before `runApp`
  (`app/television.dart` → `MainActivity`'s `dev.icedtea.mplayer/device`
  channel: leanback feature or TV UI mode) and lands in
  `isTelevisionProvider`, false everywhere else and in tests. It gets the rail
  at any width, the banner, larger tiles, and an autofocused Resume.
  The manifest declares leanback optional and adds `LEANBACK_LAUNCHER`;
  `android:banner` is `@drawable/tv_banner` (xhdpi 320×180, xxhdpi 480×270:
  the icon's gradient, glyph and the name). Those PNGs are drawn by
  `tool/make_tv_banner.py` (Pillow) — rerun it rather than editing them.
- **Player keys** (`_handleKey`): while the player's own node is focused, or
  the chrome is hidden, arrows seek and Enter/Select plays-pauses (the first
  press over a hidden chrome only shows it); up/down move into the controls,
  after which arrows walk them. Media keys act from anywhere.
- **Backdrops are taller on wide windows and cropped from the foot**: the
  Home banner is `0.42 × width` (280–600) and the series `DetailHeader`
  backdrop `0.36 × width` (280–520) past compact, both drawn with
  `RemoteArt(alignment: Alignment(0, -0.6))`. A fixed 280 cut the faces off.
- **The series header reads left to right past compact**: a 200px poster,
  the titles start-aligned beside it, and the action icons
  (`ItemActionIcons(alignment: start)`) under the titles instead of a
  centred row of their own. The overview (6 lines before More) and genres
  are a third column right of the titles (`DetailHeader.aside`), and the
  slivers that draw them under the header are phone-only. A phone keeps the
  centred layout.
- **The movie detail uses the series layout at every width** (2026-11-08):
  `DetailHeader` inside `CollapsingHeaderSliver` (`widgets/collapsing_header.dart`,
  shared with the series screen), facts drawn only where the server filled
  them in. Past compact: a labelled Play / `Continue · 1:02:45` (plus Start
  over once started) ahead of the `ItemActionIcons`, overview and genres as
  the aside. A phone: centred glyph row, Play in `ItemPrimaryActionBar`,
  overview and genres as slivers under the header. `BackdropHeader` is no
  longer used there.
- **Long presses**: a card in `ServerCardShelf` (Next up, Continue watching)
  opens `openServerItemDetail` — an episode's series, else the item; an
  episode row on the series screen opens its ⋮ menu (`ItemActionMenu.menuKey`).
  A library tile (`PosterGrid`, long press or right click) opens
  `showLibraryItemMenu` (`library_item_menu.dart`): Play, Shuffle (containers
  only), Select, Add to collection, Add to playlist. Select puts the grid in
  multi-select (taps toggle, Back clears, a bar at the foot acts on all).
  Collections are `allCollections` / `addToCollection` / `createCollection`
  on the source, all query-bound on `/Collections`; they need the account's
  collection-management permission, and a 403 is a snackbar. The Playlists
  tab passes `itemMenu: false`. A season tab (`_SeasonTab`, long press or
  right click; `labelPadding` moved into the tab so the whole tab answers)
  opens `showSeasonMenu`: Play (from the season's next episode), Play all
  from here (this season and every later one), Shuffle, Add to collection
  (the season by `ServerItem.seasonId`, else its episodes), Add to playlist
  (the episodes), Download all, Select. **Episode multi-select**: Select in
  the season menu picks that season, Select in an episode's ⋮ menu picks
  that episode; taps and long presses then pick, rows get a checkbox in place
  of ⋮, Back clears. `SelectionBar` (`library_item_menu.dart`, shared with
  the library grid, glyphs scroll on a narrow phone) replaces the Play bar
  while picking: select all (the season on screen), play, shuffle, add to
  collection, add to playlist, download.
- **Series rows map to items by position in the same season grouping**
  `seriesDetailFrom` uses (`_episodesBySeason`). Matching on number + title
  sent every season's "Episode 1" to season 1's item.
- **`BackdropHeader` puts the title under the artwork** (episode and artist
  pages): the art is `height` tall, the title starts `overlap` (40) above its
  foot where the scrim is ~92% surface, and the header grows with the title.
  Overlaid at a fixed height, dark text sat on bright stills and a two-line
  title climbed into the back button.
- **Episode detail** shows series, title, original title, then
  `S1E2 · date · runtime · ★ · certificate · Ends at <time>`, a read-only
  Video row (`videoSummary`: "1080p HEVC SDR", class from width or height,
  range from `ServerStream.videoRange` = `VideoRangeType` ?? `VideoRange`),
  and the glyph row (`ItemActionIcons`) instead of the scrolling chips.
  `episodeOf` takes (season, episode) — the page used to swap them.
- **Series detail** adds the typical episode length and Continuing/Ended to
  the header facts, and First aired / Episode length to About.
- **External links** (IMDb, TheMovieDb, TheTVDB, Trakt…): `ExternalUrls` on
  the detail fetch only (`_detailFields`), parsed to `ServerItem.links`
  keeping http(s) alone, drawn by `ExternalLinks` (`detail_sections.dart`)
  as chips opened with `url_launcher` — at the foot of the movie and episode
  screens and of the series' About tab.
- **Person page** (`person_page.dart`): the person is an ordinary item, so
  `serverItemProvider(personId)` brings the photo, biography (`overview`),
  born (`premiereDate`), died (`endDate`, the full date — `endYear` cannot
  give an age), birth place (`productionLocations`, on the detail fetch) and
  links. Photo beside the facts; biography and links under them on a phone,
  beside on wider. Credits split into Movies and Shows grids. A person the
  server will not describe falls back to the name from the query string.
- **Images** (`media_images.dart`): `/Items/{id}/Images` (`images`, with
  width/height, sorted poster → backdrops → logo/thumb/banner/art/disc;
  chapter stills and profiles left out) drawn as a row at each picture's own
  shape — cut-outs (logo, art, disc) contained on a panel — on the movie
  screen and the series' About tab, between cast and suggestions. A tap opens
  `showImageViewer`: full screen, swipe or arrows, pinch to zoom, the
  original size. Fewer than two pictures draws nothing.
- **Mouse back/forward** (`app/mouse_navigation.dart`, wrapped in
  `MaterialApp.router`'s builder): back goes through
  `routerDelegate.popRoute()` so PopScope screens are asked first; forward
  replays a remembered `(uri, extra)` and is forgotten on any other
  navigation.
- The Windows layout (banner, scaled shelves, hover arrows) was looked at
  and approved on Windows, 2026-11-02. Not yet verified on a real TV box or
  with a remote.

## Downloads (2026-11-02)

`lib/downloads/` is the subsystem, `features/downloads/` the screen and the
shared bits (`download_ui.dart`: `watchDownload`, `DownloadBadge`,
`confirmRemoveDownload`, `formatBytes`).

- **The original file only**: `/Items/{id}/Download?ApiKey=`, gated on the
  account's `EnableContentDownloading`; a 403 is a sentence, not a fallback.
- **Layout** `<app support>/downloads/<profile>/<item>/` — `media.<ext>`
  (extension from `Content-Disposition`), `media.part` while arriving,
  `poster.jpg` — and `index.json` beside them. **No token in the index**: the
  URL is rebuilt from the signed-in session each time, so a copy of a server
  that is not signed in waits in the queue.
- **Resume is by `Range`**, written over a response stream rather than
  `Dio.download`, because a 200 to a range request must overwrite and a 206
  must append. The engine never throws; failures are `failed` + a sentence.
- **One file at a time.** The index is written on status changes only; the
  partial file is the true byte count and `load()` reads it from there.
  Writes are serialised and the rename retried — Windows refuses a rename
  over a file something has open for a moment, and two overlapping saves
  share the `.tmp`.
- The item's Download action is one `ItemAction` whatever the state
  (download → queued/percent, tap pauses → resume → remove, drawn selected).
  "Download all" on a series asks with the count; the listing has no sizes.
- **Before the bytes, `meta.json`** (`download_snapshot.dart`): the item,
  its segments and a `PlaybackInfo` asked with **no device profile** — the
  same answer that hands over the original file, so the server stream
  indexes line up with the file on disk. External subtitles are fetched
  beside it as `sub-<index>.<ext>`. Best effort; a copy without it plays.
- **Playing a copy**: `mediaSourcesProvider` holds an `OfflineMediaSource`
  per profile — wrapped around the live `JellyfinMediaSource` for the
  signed-in one, alone for any other profile with copies. A whole copy
  resolves to a `file://` URI (direct play, saved streams, chapters without
  stills, segments, local subtitles); anything else streams, or is a
  sentence with no server. `onlineMediaSourceProvider` is separate so the
  map can rebuild when copies appear without losing the Jellyfin source's
  play sessions; `downloadedProfilesProvider` narrows `downloadsProvider` to
  a joined string so a chunk does not rebuild it.
- **Resume offline**: the server's position if it answers within 4 s, else
  the last unreported stop, else the one in `meta.json`. A local play
  reports without a session; a stop the server cannot hear goes to
  `pending_reports.json` (latest per item) and is sent as
  `reportStopped` when that profile's session appears. Offline, prev/next
  walk the series' episodes on the device.
- **With no server open**, the empty state and the server list show
  "Watch downloads" when there are copies; the Downloads branch keeps its
  navigation bar, since only the Home branch drops it.
- **Android keeps the engine alive** with `DownloadService.kt`, a
  `dataSync` foreground service, through `DownloadChannel.kt`
  (`dev.icedtea.mplayer/downloads`: `update` {title, text, percent} /
  `stop`). It decides nothing: `DownloadsController` pushes the running
  file's title and percent from `listenSelf`, only when they change, and
  stops the service when nothing runs. The text is localised with
  `lookupAppLocalizations` (chosen locale, else the system's). Android 15
  caps `dataSync` at six hours a day; the queue then resumes on the next
  launch. Swiping the app away stops it — the engine doing the work goes.
- **Wi-Fi only** (`download_settings.dart`, on by default, device-local in
  `shared_preferences`): `downloadHoldProvider` combines the setting with
  `connectivity_plus` (`wifi`/`ethernet` unmetered, `mobile`/`satellite`
  metered, `none` offline; a platform that cannot say holds nothing). A hold
  stops the running file and puts it back as *queued*, not paused; release
  resumes from the partial file. The Downloads tab says which hold applies.
- **Settings › Downloads** (`/settings/downloads`, also the gear on the
  tab): Wi-Fi only, remove watched downloads (off by default — a copy played
  past 90 % of its runtime on this device is deleted after the stop is
  reported, retrying while Windows still has the file open), space used and
  remove all.
- **Deliberately not built:** downloading a transcoded copy (a transcode is
  a stream with no stable byte length, so `Range` resume and the saved
  track indexes both stop meaning anything) and a storage cap (the space
  line plus remove-all and remove-watched cover it until someone needs a
  number). Notification buttons (pause) are absent; tapping opens the app.

## Localisation

English and Vietnamese, via `flutter_localizations` + ARB codegen. `l10n.yaml` drives it;
strings live in `lib/l10n/app_en.arb` (template) and `app_vi.arb`. The generated
`app_localizations*.dart` sit **next to the ARBs in `lib/l10n/`** — Flutter 3.44 dropped
synthetic packages — and are regenerated by `flutter pub get` / `flutter gen-l10n`.

- `untranslated-messages-file: l10n_untranslated.json` is set, so a key added to the
  template and not to `app_vi.arb` shows up as a report. It must stay `{}`.
- `intl` is pinned to `^0.20.2` because `flutter_localizations` depends on exactly
  0.20.2. Do not bump it to 0.20.3 — version solving fails.
- Language choice lives in `app/locale_controller.dart` (`shared_preferences`). **Null
  means follow the system**, which is the default and is not the same as English.
- Each language is named in its own language (`Tiếng Việt`, not `Vietnamese`).
- `test/l10n_test.dart` fails when an English key has no Vietnamese translation. The
  build writes the same finding to `l10n_untranslated.json`, but only someone who opens
  that file ever sees it — a missing key is an English word in the middle of a
  Vietnamese screen, which is worth failing a test over.
- A widget that reads `AppLocalizations` needs a harness that supplies it: a test
  pumping a bare `MaterialApp` gets null back and throws.

**Every screen that is real is converted.** The shell, the player and its chrome, the
Files and Browse screens, the share sheet, casting, and all seven settings pages read
from `AppLocalizations`.

What is left is deliberate: the **server, search and downloads screens still render
sample data** and will be rewritten with the Jellyfin client, so translating them now is
work thrown away twice. `features/playback/smoke_test_page.dart` is a developer tool and
is not translated either.

Two enums lost their `label` field on the way (`RotationMode`, `AspectMode`,
`GaplessAudio`): an enum constant is built once, before there is a locale to build it in,
so the name now comes from a `label(l10n)` method or a helper next to the page that shows
it. Find any remaining literals with:

```bash
grep -rn "Text('\|tooltip: '\|labelText: '" lib/features lib/widgets --include=*.dart \
  | grep -v "l10n\."
```

Placeholder-bearing strings are already defined in the ARBs (`notImplemented`,
`connectionOk`, `showMoreFrom`, `minutes`, `itemCount`, …) — prefer reusing those keys
over adding near-duplicates.

## Sources

**There is one.** `servers/jellyfin_media_source.dart` implements
`MediaSource`, `QueueableSource` and `ProgressReporting` from
`sources/media_source.dart`, and `mediaSourcesProvider` in
`servers/server_registry.dart` is the map the player resolves against — one
entry per profile, each an `OfflineMediaSource` that plays a downloaded copy
from disk and otherwise defers to the Jellyfin source (see "Downloads").

`QueueableSource` is how a server answers the question a folder listing used
to answer for everyone else: what plays after this item. It returns the
episodes of the series, which is what gives an episode prev/next, the
end-of-file prompt and auto-play next.

**Still a map, deliberately.** `PlaybackController` looks a source up by
`mediaRef.sourceId`, and a queue entry carries the profile id it was made
against. Collapsing it to a single value would make every lookup silently
resolve to "the current server", which breaks the moment a second server can
be signed in.

Everything else that was documented here is gone — the driver table, the
share sheet, `SourceRegistry`, the keychain rules for share passwords. See
"Current state". `test/fake_keychain.dart` survives, now only for the server
token.

### Gone: the WebDAV and SMB clients

Both are named here because a search for them should land on a paragraph
rather than nothing.

- **WebDAV** — `PROPFIND` hand-written over `dio`, with `parsePropfind`
  matching on local element names because prefixes differ between servers.
  libmpv opened the `https://` URL itself with the header the driver supplied.
- **SMB** — `dart_smb2` gives random-access reads and nothing else, so
  `media_proxy_server.dart` bridged it: a loopback `HttpServer` turning
  `Range` requests into offset reads, with libmpv pointed at
  `http://127.0.0.1:<port>/media/<id>`. Its two non-obvious details were 1 MiB
  chunks with a `flush` between them (without the back-pressure a fast share
  outran the socket and buffered the whole file in memory) and a 416 carrying
  the real size (libmpv corrects its own request from it).

The proxy is also what casting used to republish a local file on the LAN. It
needs neither now: see Casting.

## Subtitles

Two kinds, and they take completely different paths:

- **Text** (ASS/SSA, SRT, WebVTT) — libmpv renders these through libass. This needs
  `PlayerConfiguration(libass: true)`, which is also what flips media_kit's
  `sub-visibility` to `yes`; with the default `false` mpv draws nothing and media_kit's
  own Flutter overlay paints unstyled text instead. media_kit's `SubtitleView` is
  therefore disabled in `player_page.dart`, or it would double-draw over libass.
  Android needs a font handed to fontconfig — the bundled Roboto is used.
- **Windows decodes with copy-back** (`HardwareDecoding.mpvValueOn`:
  `auto-copy-safe` / `auto-copy`). Plain d3d11va into media_kit's ANGLE surface
  crops the bottom ~6% of the frame to black — ASS lines there are cut in half
  and resizing the window changes nothing. Software decoding and copy-back
  both draw the whole frame (verified on Windows, 2026-11-01).
- **Image** (PGS/HDMV, VobSub, DVB, XSUB) — pictures, not text, so libass never touches
  them. Two separate upstream problems exist here; do not confuse them:
  - [media-kit#1269](https://github.com/media-kit/media-kit/issues/1269) — the bundled
    libmpv is built **without the subtitle decoders**. mpv logs
    `Could not find subtitle decoder for format 'hdmv_pgs_subtitle'`. **This is the one
    that bit us**, and `windows/CMakeLists.txt` fixes it by installing a complete
    libmpv over the plugin's trimmed copy. Android is still affected.
  - [media-kit#1371](https://github.com/media-kit/media-kit/issues/1371) — even with a
    decoder, the render path may not composite bitmap subs. Not confirmed here.

  **Diagnosing:** the decoder is named `pgssub`. The string `hdmv_pgs_subtitle` is only
  the codec *descriptor* and is present in a trimmed build too, so grepping for it
  proves nothing — a mistake made once already. Grep for `pgssub`, or better, read the
  mpv log in the stats overlay (`logLevel: MPVLogLevel.warn` feeds
  `PlaybackState.logLines`).

`MediaTrack.isImageBased` detects them from the demuxer codec so the picker labels them
instead of failing silently. That is a mitigation, not a fix. Real options, in rising
order of cost: server-side burn-in when transcoding (the Subtitle settings switch already
exists for this, and only helps server sources); patching media_kit's render path;
swapping the backend to `fvp`/libmdk, which `refs/NipaPlay-Reload` vendors.

## Smart subtitles

`features/player/smart_subtitles.dart` holds the rule as a **pure function** —
`smartSelection` takes the track lists and returns what to select, so it is unit-tested
without a decoder. `PlaybackController` applies it once per file, on the first track list
that contains a real track (mpv publishes a list of nothing but its `auto`/`no`
placeholders before a file is demuxed), and again on demand when the preference changes
mid-film.

The rule: play the audio in `PlayerSettings.preferredLanguage` if the file has it, and
turn subtitles on **only** when that was not possible. Audio the user understands means
subtitles off *explicitly*, since a file may have flagged one of its subtitle tracks as
default.

`core/languages.dart` is what makes the comparison work. A muxer writes `vie`, `vi`,
`Vietnamese`, `vi-VN` or `VIE` for the same thing, and both ISO 639-2 forms are legal
(`ger`/`deu`, `chi`/`zho`, `fre`/`fra`), so every label is reduced to a two-letter code
before it is compared. **`und` reduces to null and never matches** — a rip whose audio is
unlabelled must not be assumed to be in the user's language, or the subtitles they need
get switched off.

## Casting

`lib/cast/` speaks **DLNA/UPnP** and speaks it by hand, for the same reasons the WebDAV
client is hand-written: five AVTransport commands are the whole of what a player needs,
and every UPnP package on pub brings a content-directory browser along with them. It also
means casting works on Android, Windows and Linux from one implementation — the Google
Cast SDK is Android-only and drags in Play Services.

- `ssdp.dart` — M-SEARCH over multicast. The datagram is sent **three times**: UDP
  multicast drops packets as a matter of course, and a dropped one silently costs the
  user a device. Replies arrive as unicast, so no Android `MulticastLock` is needed.
  A `NOTIFY` is not an answer and is ignored, or the list fills with devices that never
  replied.
- `upnp.dart` — element lookups match on **local names**, the same rule `parsePropfind`
  follows: vendors namespace their descriptions differently and some prefix nothing.
  SOAP arguments are positional despite looking named, so argument order is part of the
  contract. `DIDL-Lite` metadata is optional by specification and required in practice —
  many televisions show "Unknown" or refuse the stream without it.
- `dlna_renderer.dart` — `CastRenderer` over SOAP. `Stop` before every `SetAVTransportURI`
  because a renderer already showing something rejects a new URI often enough to lose the
  second file; `Seek` only after `Play`, because a stream that is not open yet cannot be
  seeked.
- **There is no proxy any more**, and this is the biggest change here. A cast
  used to start a second `MediaProxyServer` bound to every interface, because
  libmpv played local files from `127.0.0.1` and a television cannot fetch
  that. Every stream now comes from a server — already an address on the
  network, with its token in the query — so the URL goes straight across and
  nothing this app runs is reachable from the network at all.
- `_publish` refuses three things with a sentence each: a non-`http(s)` URL, a
  stream carrying auth **headers** (they would not travel with the URL, so the
  television would fetch a 401 and sit on a black screen), and a loopback
  host. No server the app signs into hits any of them today.

### Chromecast

`CastChannel.kt` + `cast/chromecast.dart`, behind the same `CastRenderer`. Only the
mechanism differs from DLNA — `MediaRouter` instead of SSDP, `RemoteMediaClient` instead
of SOAP — and, as with every other channel here, **Kotlin decides nothing**: which device,
what to load and when to give up are all Dart's.

- The **only** Google Play Services dependency in the app, and optional at runtime: a
  device without Play Services throws from the first `CastContext` call, which is caught
  and reported as unavailable so the picker lists no Chromecasts. This is why DLNA exists
  alongside it — it is what covers Windows and Linux.
- `CastOptionsProvider` is found **by class name** from a manifest `meta-data` entry, the
  only reference to it. Renaming it breaks casting at runtime, not at compile time.
- The **default media receiver** is used, so no receiver app has to be
  registered with Google. It plays MP4/H.264 and WebM and does **not** play
  Matroska. The answer is the server's transcoder — reached by lowering
  `streamQualityProvider`'s cap — and that answer is now always available,
  because every castable item came from a server in the first place. A
  rejected load says so in words rather than leaving a black screen.
- There is no "connect" call in the SDK: selecting a route makes the session manager open
  a session, and the answer arrives as an event. `Chromecast.connect` awaits that event.
- Discovery is an **active** scan, which costs battery — so it is started with the picker
  and stopped in the sheet's `dispose`.

Nothing above `CastRenderer` knows which protocol a device speaks; `CastController` merges
the two lists and picks the renderer from `CastDevice.kind`.

## Phone remote (2026-11-02)

mPlayer on a phone drives mPlayer on a desktop (Windows/Linux) or an Android
TV on the same network. Casting hands a stream to someone else's player; this
drives **our own** player on the other machine, so the receiver plays with its
own sign-in, its own tracks and its own settings.

`lib/remote/` is the mechanism and knows nothing of Riverpod or the player;
`features/remote/` wires it in. Like casting it is `dart:io` alone — no
dependency added.

- `remote_protocol.dart` — **pure**: beacon, handshake proofs, `RemoteSnapshot`
  (what a phone is told), `RemoteCommand` (what it may ask). Tested in
  `test/remote_test.dart` without a network, plus three loopback tests that
  run the real server and client against each other.
- `remote_discovery.dart` — UDP on **47830**. The receiver broadcasts a beacon
  every 3 s **and** answers a phone's broadcast query by unicast: some access
  points drop broadcast towards wireless clients, and a unicast reply gets
  through anyway (the `ssdp.dart` reasoning). Sending is one socket **per
  interface**, since `255.255.255.255` from an "any" socket leaves by the
  default route only. The phone takes the receiver's address from the datagram,
  never from the beacon's contents. Stale after 10 s.
- `remote_server.dart` — `HttpServer` + `WebSocketTransformer` on **47831**
  (any port if taken; the beacon carries it), 4 sessions max, 5 s pings.
  State goes out at once on any change but the position, and the position
  alone at most once a second.
- `remote_client.dart` — the phone's end. "Connect by address" exists for
  networks where discovery cannot get through; that device has no id until the
  receiver's hello supplies one.
- `remote_trust.dart` — pairings in the keychain, both directions (phones a
  receiver trusts, receivers a phone paired with). Local by nature.

**Trust: same Jellyfin user, or a PIN** (the user's choice). The receiver
sends a nonce; the phone answers with HMACs over both nonces and both ids,
keyed by (a) a secret from an earlier pairing and (b) one key per signed-in
profile, `sha256(serverId|userId)`. Either matching lets it in. Otherwise the
receiver shows a 6-digit PIN **over whatever is on screen, the player
included** (`RemoteHost`, wrapped around the navigator in `app.dart`), the
phone proves it with an HMAC keyed by the PIN, and both sides derive the
paired secret from the PIN and the nonces — it is never sent. Five wrong PINs
hang up; one pairing at a time.

Known and accepted: server id and user id are **not secret** — anyone with an
account on that server can read both, which is the same trade `refs/plezy`
makes. And someone sniffing the LAN *during* a pairing could brute-force a
6-digit PIN offline from the proof. Traffic after the handshake is plain JSON;
it carries titles and positions, never a stream URL or a token.

**Receiver** (`remote_receiver.dart`): only where
`remoteReceiverAvailableProvider` — desktop or television, **never under
`flutter test`** (the widget tests pump the whole app on a desktop host). On by
default, switch in General, with "Forget paired phones" beside it. Windows asks
about the firewall the first time it starts. Every command lands on the same
`PlaybackController` methods the on-screen buttons, the notification and PiP
already call — there is no second player. Two details:

- **Stop** pops `/player` through the router when it is showing, so the screen's
  own teardown runs exactly as Back would; only without that screen is the
  controller stopped directly.
- **Play an item**: the phone sends `serverId + itemId`, never a URL. The
  receiver refuses a server it is not signed in to, or one locked behind a PIN
  nobody entered there (`connectedServerProvider` null), each as an error code
  the phone puts into words. With a player already up it calls
  `PlaybackController.openInstead` instead of pushing a second `/player`,
  whose predecessor's `dispose` would stop the new file's decoder.

**Phone** (`remote_session.dart`, `remote_page.dart`): Settings → Remote control
opens `/remote` (one route, three faces: list, PIN, controls). The connection
lives in `remoteSessionProvider`, not the screen, so it survives going back to
the library — and **while connected, `playServerItem` sends Play to the
receiver** with a "Play here" snackbar action, the way a phone joined to a
speaker plays on the speaker. `RemoteBar` sits over the navigation bar while
connected. The phone draws its own "Off" track and its ⟲/⟳ use the receiver's
skip steps.

Verified: analyze clean, protocol and loopback tests pass, and on Windows
(2026-11-02) an advertiser and a discovery found each other over the real
interfaces (Wi-Fi, Ethernet, Hyper-V and VMware adapters all up). **Not yet
verified on real hardware across a network** — Windows ↔ Android phone,
Android TV, and Linux each need a run.

## Desktop window

`app/desktop_window.dart`, all of it inert off desktop — `window_manager` throws on
Android and iOS, which is the signal to do nothing.

- **Single instance is a bound socket.** A fixed loopback port (47821) is the
  lock: exactly one process can bind it, so failing to bind *is* how a second
  launch knows it is the second. It then connects, which raises the running
  window, and exits. No lock file to go stale after a crash. It used to carry
  the file path from `mPlayer video.mkv` across; nothing is read from the
  socket now, and the connection itself is the whole message.
- Size and position are restored before the window is shown, through
  `waitUntilReadyToShow`, or the user watches it appear at the default size and jump.
  A **minimised or fullscreen** window is not saved — neither is what they left behind —
  and a position on a monitor that has since been unplugged is discarded.
- Saves are debounced 600 ms: dragging an edge fires a resize per frame.
- **Drag-and-drop is gone** with the local sources. The window used to be a
  drop target wrapping the navigator, so a file dropped anywhere in it played.

## Background playback & picture in picture

Both are Android-only, both are Kotlin, and both follow the same rule: **the platform
side decides nothing.** Every button, every focus change and every window event is
forwarded to Dart, which owns the player. Two sides both acting on one event is how a
notification ends up claiming "playing" over silence.

- `PipChannel.kt` — `supportsPictureInPicture` + `resizeableActivity` in the manifest.
  Auto-enter is armed through the params *before* the user leaves (API 31+); 26-30 do it
  by hand from `onUserLeaveHint`. The aspect ratio is clamped to roughly 1:2.39…2.39:1
  because anything outside that throws. The window's buttons arrive as broadcasts, not
  method calls, since the system draws them.
- `PlaybackService.kt` — a `mediaPlayback` foreground service holding the notification, a
  framework `MediaSession` (lock screen, headset buttons) and audio focus. No androidx
  media dependency: `android.media.session.MediaSession` and `Notification.MediaStyle`
  cover it from API 21, and minSdk is 24. Focus loss pauses — ducking is not offered,
  because a film quietened for a chime is a line of dialogue missed either way.
- `PlayerSettings.backgroundAudio` off means the player pauses when the app is
  backgrounded, and no service or notification exists at all. **The lifecycle check is
  deferred ~400 ms**: entering PiP reports the same lifecycle change, and which arrives
  first is not guaranteed, so pausing immediately would stop the video the user just
  floated onto their home screen.

## Chapters

Two independent sources, and the distinction matters:

- **Container** — MKV and MP4 routinely embed chapters. `PlaybackController`
  reads them from libmpv's `chapter-list/*` properties once the duration is
  known, which still matters: a **direct play** hands the container over
  untouched, so its own chapters are there whether or not the server extracted
  any. `getProperty` returns `""` for a missing property, so a file without
  them yields a count of 0 and stays silent.
- **Source** — a server supplies its own list, with a still per chapter where it has
  generated them (`MediaChapter.imageUri`, drawn in the chapters sheet).
  `SourceCapabilities.chapters` refers only to this. False there does **not** mean the
  media is chapterless.

`PlaybackState.chapters` prefers the source list when it is non-empty. **Where the
server has no media segments, chapter titles become segments** (`segmentsFromChapters`
in `segment_skipper.dart`, 2026-11-11): "OP"/"Opening"/"Intro" → intro, "ED"/"Ending"/
"Credits" → outro, plus Preview and Recap — server and container chapters alike, matched
on the title's first word so "OP1" and "ED - Song" count and "Option" does not. They then
go through the same per-kind actions as real segments. There used to be a separate
intro-only chapter pill and an "Auto skip intro" switch; both are gone (an old `true`
migrates to intro = skip). Server segments, when present, win outright — never both.

## Media segments, trickplay, external subtitles

The three things `refs/jellyfin-android` does with a Jellyfin server that a chapter list
alone cannot. All of them ride on the **detail fetch** (`JellyfinSource.item`), which is
the only request that asks for `_detailFields` — `Chapters` and `Trickplay` are deliberately
off the listing field list, or a hundred-poster grid would carry both a hundred times over.

### Media segments (`/MediaSegments/{id}`, Jellyfin 10.10+)

A chapter says *where* something is; a segment says **what** it is. Five kinds are acted
on — intro, outro, preview, recap, commercial — each with a per-kind action in Player
settings: do nothing, offer to skip, skip automatically. Intro and outro default to
*offer*, matching jellyfin-android's own defaults.

- **A 404 is swallowed**: `segments()` is the one call that
  returns an empty list rather than a `ServerException`, because no segments is the
  correct answer for most items on most servers and must not stop a film playing.
- **A start of zero is real.** `ticksToDuration` reads zero as "the server did not say",
  which is right for a runtime and would silently drop the commonest intro there is —
  hence `ticksToPosition` beside it. Using the wrong one is invisible in testing against
  an episode whose titles start at 1:04.
- **The skip rule is a pure function**, `features/player/segment_skipper.dart`, for the
  same reason `smartSelection` is one. Its clauses each exist to stop the player fighting
  its user: a skip fires only when playback *runs into* a segment (a jump larger than
  `maximumPlaybackStep` is a scrubber, not a second of playback), only once per segment,
  and never for a stretch under a second — where the seek stalls the decoder for longer
  than the thing being skipped lasted. The first tick of a file counts as playback from
  `openedAt` (the open's start position): without it an intro at 0:00 was never
  crossed and never auto-skipped.
- `PlaybackState.segments` returns the server's list when non-empty and the chapter-derived
  one otherwise. That is what keeps the title heuristic and the server's own answer from
  both drawing a pill.

### Volume (2026-11-11)

"Boost volume to 200%" is a switch writing `volumeBoost` 100/200 (`volume-max`, and the
ceiling for `setVolume` and the gesture). "Sync volume with device" (Android only,
`VolumeChannel.kt` / `device_volume.dart`) makes the gesture move the device's media
volume; with boost on, the first 100% is the device and the rest mpv's amplification
(`splitVolumeLevel`). The hardware buttons are heard through a `ContentObserver`; turning
the device down from its maximum drops any boost back to 100. Unverified on a device.

### Trickplay

The scrubber preview, from the server's **sprite sheets**: one image holds
`tileWidth × tileHeight` thumbnails, one every `interval` ms, so a scrub across a
two-hour film costs a handful of requests rather than a thousand. `ServerTrickplay.tileFor`
turns a position into a sheet URL and a rectangle inside it, and `_TrickplayTileImage`
paints that rectangle through a canvas — no widget crops a source rect without first
laying the whole sheet out. The **widest** advertised resolution is chosen: a preview
blown up from 160px is a smear, and the sheets are fetched one per scrub either way.

This is not the locally-generated scrubber thumbnail that was dropped on purpose; the
server has already done the work.

### External subtitles

A subtitle stream with `DeliveryMethod: External` is a file of its own that nothing would
ever fetch — a direct play hands the video over untouched and the sidecar simply never
travels with it. `externalSubtitlesFrom` resolves those against the server root with the
token in the query (libmpv fetches them itself and cannot be handed a header), and the
controller appends each with `sub-files-append` **after** the open, without selecting one:
which to show is smart subtitles' decision or the user's. `DeliveryMethod` is checked as
well as `DeliveryUrl`, because the URL survives on a stream the server has since decided
to burn in — acting on it then draws subtitles twice.

## One-handed use, and what it moved

The server UI is driven with one thumb on a tall phone, which is a constraint
on **where** a control sits, not on what it is. Three things followed from it,
and `test/one_handed_test.dart` measures each against the bottom of the
window — not "a Play button exists somewhere", which is exactly the assertion
that allowed the old layout.

- **Settings is a navigation destination**, not an app-bar icon. It was in the
  top-right corner of two screens, the one corner a thumb cannot reach on a
  tall phone. It is now the third branch of the shell — Servers · Search ·
  Settings — which also puts the design's 3-destination bar back after
  Storage left a gap. Its sub-pages are nested **inside** the branch, so the
  navigation bar stays up while the user is in them and leaving is another
  thumb-press rather than a reach for the back arrow. `SettingsIndexPage`
  therefore draws no back arrow: there is nothing behind it to pop.
- **The detail screens pin their primary action to the foot of the scaffold**
  on compact widths only (`ItemPrimaryActionBar`). The action row sits under a
  268dp backdrop, so Play landed mid-display on a phone and scrolled away
  entirely once the user read the overview. The inline row is passed
  `primary: false` there so Play is not drawn twice; at 600dp and up the bar
  is absent and the row is whole, because nothing holds a tablet in one hand
  and the design puts the row under the backdrop.
- **Search is a FAB on the two browse screens**, not an app-bar action — it is
  the frequent one, so it gets the thumb's arc. Grid size stays in the app bar
  because it is set once. The Cast button beside it was **removed rather than
  moved**: it was a `_notYet` stub, and casting needs a resolved stream and a
  position, so it belongs to the player.

**The rail and the drawer are unchanged.** Design non-negotiable 4 fixes
`NavigationBar` < 600, `NavigationRail` 600–1239, `NavigationDrawer` ≥ 1240,
and a tablet or a desktop window is not held in one hand — so every change
above is either compact-only or a routing change that all three share. The one
thing the wider layouts did lose is their separate Settings affordance: it is
a destination in the rail and the drawer too, which is what "same routes, same
state" asks for anyway.

**Still reaching, and deliberately left alone:** the library grid's five-tab
scrolling `TabBar` and the season tabs on a series both sit at the top. Moving
tabs to the bottom is the most debatable change of the set — it costs the
at-a-glance row and is not a pattern M3 offers — so it is a decision to take
on purpose rather than a thing to slip in. The sort and filter sheets are
already bottom sheets and need nothing.

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
3. One player screen serves every source. Only one kind is left, so the rule
   now bites one level up: the player talks to `MediaSource` and not to
   Jellyfin, which is what would let another server's driver land beside it
   without the player noticing. Do not fork it per server.
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

Flutter 3.44 · Riverpod 3 (**hand-written providers, no codegen**) ·
go_router · media_kit · dio · xml

`drift`, `freezed` and `json_annotation` were dependencies that nothing ever
generated from — there was not a single `.g.dart` in `lib/` — and they went
with the local sources rather than waiting for a schema that is not coming.
**The only codegen left is `flutter gen-l10n`.**

## Hard-won constraints — do not undo without re-verifying

- **No `riverpod_generator`, no `riverpod_lint`, no `custom_lint`.** They
  conflicted irreconcilably with `freezed` + `drift_dev` over `analyzer`
  versions. Both of those are gone now, so the conflict is too — but providers
  stay hand-written, because every one of them already is and a half-converted
  codebase is worse than either choice.
- **`compileSdk = 37`** is pinned in `android/app/build.gradle.kts` (required by `flutter_secure_storage 11.x`; Flutter's default is 36).
- **`kotlin.incremental=false`** in `android/gradle.properties` — this host intermittently fails with "Could not close incremental caches" otherwise.
- **`dynamic_color` is held at `^1.7.0`** (Material You on the Appearance page). 2.x builds against the separate `material_ui` package, whose `ColorScheme` is a different type from Flutter's, so `DynamicColorBuilder` stops handing back anything `MaterialApp.theme` accepts. 1.7.0 in turn pins its own module to `compileSdkVersion 31`, older than the androidx artifacts it pulls in, so `android/build.gradle.kts` raises that one subproject to 36 — without it every Android build fails at `checkReleaseAarMetadata` with 24 issues. Register the `afterEvaluate` **inside** a name check, not around one: `:app` is already evaluated by the block above and Gradle rejects a late registration.
- Linux builds need system libmpv: `sudo apt install libmpv-dev mpv`.

## Launcher icons

`icon.svg` at the app root is the design source — the blue squircle with the white play
triangle and the cast waves, kept in sync with `../logo/mplayer-logo/`. Regenerate with:

```bash
dart run flutter_launcher_icons          # Android, iOS, Windows, macOS
```

Four PNGs under `assets/icon/` feed it, and each exists for a reason:

- `icon.png` — the rounded squircle, used for Windows, macOS and the legacy Android mipmaps.
- `icon_background.png` / `icon_foreground.png` — the Android adaptive layers. The
  background is a **full-bleed gradient with no rounding** (the launcher applies the mask);
  the foreground is the marks alone on transparent, scaled to **66%** so nothing lands
  outside the 72/108dp safe zone. The foreground doubles as the monochrome layer.
- `icon_ios.png` — a **square, un-rounded, already-opaque** copy. iOS applies its own
  continuous-curvature squircle, which reaches slightly further into the corners than the
  artwork's circular one; feeding it the rounded source leaves white slivers there.

Only `icon.png` and `icon_256.png` are bundled as Flutter assets — the rest are build-time
sources.

Linux is not covered by that tool — its icons live in `linux/packaging/icons/hicolor/` alongside the `.desktop` file, regenerated from `icon.svg` by hand when the artwork changes.

## CI / release

`.github/workflows/release.yml` builds Android APKs, a Windows installer and a Linux
`.deb`, publishes a GitHub release and posts to Telegram. **There has never been a macOS
job.**

Desktop ships installers, not portable archives:

- **Windows** — `windows/packaging/mplayer.iss`, compiled by Inno Setup's `ISCC` into
  `<base>-windows-x64-setup.exe`. **Per-user only** (`PrivilegesRequired=lowest`,
  installs under `%LOCALAPPDATA%\Programs`), so the in-app updater can run it silently
  without UAC. The release `AppId` GUID must never change — it is what makes a new
  installer an upgrade. A dev build (`/DDev`) has its own AppId, name and folder.
  Before `flutter build windows`, `windows/packaging/prefetch-native.ps1` fetches
  media_kit's libmpv/ANGLE and our full libmpv into `build/windows/x64` with
  retries and checksums (read from the CMake files), behind an `actions/cache`.
  media_kit's own download is one try and fails the build on a truncated file
  ("Integrity check failed"); a matching file there makes CMake skip it.
- **Linux** — `linux/packaging/build-deb.sh` into `<base>-linux-x64.deb`: bundle in
  `/opt/<package>`, launcher on PATH, `.desktop` and hicolor icons. `Depends` comes from
  `dpkg-shlibdeps`, not a hand-written list (libmpv's package follows its soname). A dev
  build is package `mplayer-dev` with its own folder, command, `.desktop` and **icon
  names** — two packages owning one path is a dpkg error.
- The asset suffixes are matched by `assetFor` in `core/update_check.dart`; renaming one
  side without the other leaves the desktop updater finding nothing.

The desktop jobs pass `--build-name <version><version_name_suffix>`: Android gets
`-dev-<sha>` through Gradle, desktop has no such hook, and without it a dev desktop build
reports plain `1.0.0` and its updater follows the stable channel.

- `release` cannot simply `needs:` a skipped job, or it skips too (all builds skip when
  "Already built?" finds the tag), so it checks results by name. **All three platforms
  must succeed**: a release missing the desktop installers is never rebuilt — the next run
  sees the tag — and the desktop updater, finding no asset, stays put in silence.
- The release-notes table prints a platform's row only when that job succeeded. A row
  naming a file nobody can download is worse than no row.
- The Telegram message builds its download links the same way. `notify` lists `windows`
  and `linux` in `needs` purely so it can *read* their results — its own `if` already
  tolerates them skipping, and deliberately still fires when a build fails, because a
  silent pipeline is worse than a noisy one.

Watch for a **second `if:` further down a job**: `notify` already had one, and adding
another produced a duplicate YAML key where the later silently wins. The workflow parses
clean now; a duplicate-key scan is the way to check after editing it.

- **`main` is the only production branch**; every other ref builds as a dev channel —
  application id gets `.canary` and the app names itself **mPlayer (Dev)** (so both
  installs coexist and are told apart in the launcher), version name and artifact name
  get `-dev-<short-sha>`, and the release is marked prerelease.
- Signing comes from repository secrets: `KEYSTORE` / `KEYSTORE_PASSWORD` / `KEY_ALIAS` /
  `KEY_PASSWORD` on main, the `*_DEV` set elsewhere. The keystore is base64 in the secret,
  decoded to `android/app/ci-keystore.jks` and deleted afterwards.
- `android/app/build.gradle.kts` reads `KEYSTORE_PATH`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`,
  `KEY_PASSWORD`, `APP_ID_SUFFIX` and `VERSION_NAME_SUFFIX` **from the environment**. With
  none set it falls back to debug signing, so local release builds still work.
- Never select secrets with `cond && secrets.A || secrets.B` — that operator falls through
  to `B` when `A` is empty, which would sign a main build with the dev key silently. The
  workflow passes both sets and chooses in shell.
- Android ships **one APK per ABI** from a single job, `flutter build apk
  --split-per-abi --target-platform android-arm,android-arm64`, renamed to
  `<base>-android-<abi>.apk` (arm64-v8a, armeabi-v7a). **No x86_64 APK** since
  2026-11-10 (it served only emulators and a few Chromebooks); an x86_64 device
  whose ABI list has no ARM entry finds no update. Split again since
  2026-11-08; releases from 2026-11-02 to 11-08 carried one
  `<base>-android-universal.apk` instead (~25–30 MB heavier: media_kit bundles an
  11–15 MB `libmpv.so` per ABI). No universal APK is built now.
- **versionCode**: `--build-number` is `run_number + 5000`, and `--split-per-abi` adds
  Flutter's 1000 × ABI number on top (armeabi-v7a 1, arm64-v8a 2). The 5000
  keeps every split APK above the universal ones (run + 5000, no ABI offset) — a lower
  versionCode is a downgrade Android refuses. Never lower it. Going back to universal
  would need run + 9000 or more to clear the split builds.
- The android job's `abis` output lists the APKs the rename step actually found; the
  release-notes rows and the Telegram links are built from it, so neither names an APK
  that was not produced.
- `assetFor` takes the first of the device's ABIs (most preferred first) that the
  release has an APK for, and falls back to `-android-universal.apk` for the
  2026-11-02..08 releases.
- Missing keystore secrets do not fail the build; the APKs are debug-signed and both the
  release notes and the Telegram message say so.

## Media servers (Jellyfin)

`lib/servers/` is the data layer, and the screens and the player are wired to
it. Three rules it keeps:

- **Domain types, not the design's.** `core/models/library_models.dart` holds strings the
  design already shaped ("2h 16m", "48m · watched") and an `IconData`. A network client
  producing those would put date formatting and translation behind HTTP. The screens map
  `ServerItem` onto them instead.
- **Parsing is a separate, pure file.** `jellyfin_dto.dart` imports nothing but the
  models, so the whole protocol is tested against captured responses with no server —
  the same split `parsePropfind` follows.
- **Errors are sentences.** A 401 is flagged `isUnauthorised`, because it is the one
  failure with an answer nothing else has: ask for the password again.

Four things that are easy to get wrong and are already handled:

1. **Ticks.** Jellyfin counts in 100-nanosecond units — ten thousand to the millisecond.
   Getting this wrong yields a runtime out by 10,000× that still looks plausible.
2. **The auth header must be percent-encoded.** `dart:io` *throws* on a header value
   above 0x7F, so a phone named "Điện thoại của Nam" fails every request before it is
   sent. Encoding also handles the quotes and commas the header's grammar cannot escape.
3. **Emby is refused at the probe** (support removed 2026-11-01). It answers
   `/System/Info/Public` like Jellyfin, so `isEmbyPublicInfo` checks `ProductName` and,
   because **Emby 4.9 omits it**, falls back to `RemoteAddresses`. A stored profile with
   `"kind": "emby"` is dropped on load.
4. **A `TranscodingUrl` on the media source means the server chose to re-encode**,
   whatever `SupportsDirectPlay` says — those flags describe what is possible, not what
   was decided. The direct-play URL carries the token as `ApiKey` in the
   query, because libmpv fetches it itself and cannot be handed a header —
   and that is also what makes the URL castable, since a header could not
   travel to a television either. See Casting.

## The library screen's tabs

Screen 1e carries a scrolling `TabBar`: **Movies/Shows · Suggestions · Favourites ·
Collections · Playlists**, in the order Jellyfin's own clients use. The design's 1e
predates them and describes the grid alone; the tabs are an addition, built out of stock
M3 the way 1g's season tabs already are.

- The **first tab is named after what the library holds** — `CollectionType` decides
  between Movies, Shows and All. "All" over a shelf of films says less than "Movies" does.
- **Tabs belong to a library view, not to everything the screen can show.**
  `LibraryBrowse` distinguishes a library from a drill-down into one box set
  (`?browse=collection`) or one playlist (`?browse=playlist`), and a drill-down draws no
  tab bar: four of the five could never fill. A playlist also cannot be listed by
  `parentId` — only `/Playlists/{id}/Items` keeps the order it was put in.
- **Suggestions is four shelves, not a grid**: Continue watching and Next up scoped to
  this library (`resumable`/`nextUp` take a `viewId` for exactly this — a film left
  half-watched has no place inside the shows library), Recently added, then the server's
  own `/Movies/Recommendations` rows. That route is movies-only; there is no
  `/Shows/Recommendations`, so a shows library gets the first three and nothing is
  missing that could have been there.
- **A recommendation's reason and its subject travel separately** — `SimilarToRecentlyPlayed`
  plus `Dune` — so "Because you watched Dune" is assembled on the screen, where there is a
  locale to assemble it in. `_shelfTitle` falls back to a plain heading when the server
  named no subject, rather than a sentence with a hole in it.
- **Playlists are not scoped to a library** and the tab does not pretend they are: a
  playlist holds whatever was put in it, from wherever, so the same list appears under
  every library.
- **Favourites lists the same item types the grid does** (Movie, Series, Video, BoxSet).
  A favourited *episode* is real and deliberately absent: every tile here opens a detail
  screen and there is none an episode on its own belongs on.
- Each empty tab **says what is missing**. Blank space where a grid should be reads as a
  failure, and four tabs that can each be legitimately empty is four chances to look broken.

`features/servers/shelves.dart` holds `ServerCardShelf` and `ServerPosterShelf`, shared
with the server home (1d) — the two screens draw the same rows from different queries, and
the ink-inset arithmetic in them is not worth having twice. `openServerItem` in
`server_library.dart` is likewise the one place that decides where tapping an item goes.

## Music libraries

`docs/MUSIC_PLAN.md` is the plan; M1 and M2 are built, and have not been on a device yet. A library
whose `CollectionType` is `music` swaps its tabs for **Albums · Artists · Songs · Playlists ·
Genres** (`_LibraryTab.forKind`), and `lib/features/music/` holds those listings and the
album and artist screens.

- **These listings page, the film grid does not.** `MusicListingView` asks for one
  `musicPageProvider` page after another as it scrolls. **Random is one page only**, because
  the server deals a new order per request and a second page would repeat and skip.
- **A genre tile opens `?browse=musicAlbums`**, not `collection`: the collection grid asks for
  films and would come back empty.
- **Album art is square.** `MusicTile` gives `PosterTile` a square; the grid still sizes with
  `mainAxisExtent`.
- **Nobody "watches" a song.** No watched toggle, no tick on a tile, and Sort & filter offers
  Favourites alone with no features or certificates. `createPlaylist(audio:)` files a playlist
  made from a track as audio.
- **`PlaybackQueue` is an explicit list with a `kind`** (`single`, `series`, `music`). A music
  queue rolls on whatever "Auto-play next episode" says and never shows the next-up pill; a
  song always starts at zero. Shuffle keeps `unshuffled` so it can be turned off, and the
  changes (`playingNext`, `appended`, `moved`, `removedAt`) are pure, tested in
  `test/playback_queue_test.dart`.
- **One player, two faces.** `AudioSession` (`features/music/audio_session.dart`) owns the
  decoder while music plays, in place of the `/player` route: notification, its buttons, the
  background rule. `AudioSession.present` is the one place that decides between it and
  `/player`, by `PlayableMedia.isAudio`. Its one way out is the controller's `stop`.
- **A video takes the decoder.** `PlayerPage` awaits `AudioSession.end()` before opening. And
  anything opening waits on a `stop` in flight (`_stopping`), so a song tapped just after leaving
  a film is not wiped by that film's teardown finishing behind it.
- **A queue sent to a receiver is cut to a window** (`RemoteCommand.playQueue`, 300 around the
  current song, titles clipped): a remote message has a 64 KB limit. `itemId` still names the song,
  so a receiver that predates the queue plays that one. Casting has no queue: a song plays on
  the device and stops there.
- **The notification fetches its own cover** (`PlaybackService.loadArt`), off the main thread, sampled
  to 512 px because a bitmap crosses a binder transaction. It redraws when the cover lands, and
  only if the song has not moved on.
- **The mini player has two hosts.** A phone's shell draws it above the navigation bar;
  `MiniPlayerHost`, beside the navigator in `app.dart`, draws it everywhere else, because
  `/library` and its album and artist pages sit above the shell. It has no tooltips: beside the
  navigator there is no overlay for one to open in.

## Sorting and filtering the library grid

The chip row over the grid is Unwatched · the sort · a filter button carrying a count, and
`features/servers/library_filter_sheet.dart` holds the two sheets behind the last two.

- **The server sorts and the server filters.** Both are part of the *request*
  (`LibraryQuery` carries the sort, the direction and a `LibraryFilter`), so either
  changing refetches. Narrowing the page in hand would not merely be slow, it would be
  wrong: a listing is a hundred of however many the library has, and hiding rows out of
  those hides nothing past the hundredth while the count strip claims to describe a
  library. The Unwatched chip used to do exactly that and no longer does.
- **`LibraryFilter` has value equality, and needs it.** It is half of a provider family
  key; without it the same filter rebuilt each frame would be a new request each frame.
  `filterParams` sorts every list on the way out for the same reason — an identical filter
  has to produce an identical URL.
- **Three delimiters, not interchangeable.** `Genres`, `Tags` and `OfficialRatings` are
  pipe-separated because a comma occurs *inside* those values; `Filters` and `Years` are
  comma-separated, being closed vocabularies where it cannot. Each feature
  (`hasSubtitles`, `hasTrailer`, …) is its own boolean and is **absent** rather than false
  when unticked: `hasTrailer=false` asks for items that have none.
- **An unset direction is not the direction it stands in for.** `SortOrder?` is null until
  the user picks one, and `ServerSort.naturalOrder` supplies the rest — which is what
  makes Recently added newest-first without anyone saying so. Storing the natural one
  instead would freeze it, and the next sort chosen would inherit "ascending" and read
  oldest-first. Picking a new *field* keeps the direction: a user who chose Descending
  meant it.
- **`/Items/Filters`** supplies the filter sheet's genres, ratings, tags and years. A server that will not answer costs
  the sheet those four sections and nothing else: the watch-state and feature filters need
  no round trip.
- **Sections that cannot mean anything are absent, not disabled.** Status is shows-only (a
  film is neither continuing nor ended), the "Latest episode added" sort likewise, and a
  value section the server named nothing for is not drawn — an empty "Genres" heading reads
  as broken rather than as honest.
- **The sheet is a draft.** Nothing applies until Apply, so the grid behind it does not
  refetch on every checkbox. Each collapsed section carries the number of boxes ticked
  inside it, and the chip carries the total: a library that looks half empty has to say
  why somewhere on screen.

## Administration

`lib/servers/server_admin.dart` (types + interface), `jellyfin_admin_dto.dart` (pure
parsing) and `jellyfin_admin.dart` (the client), behind five screens in
`lib/features/admin/`: a dashboard with the sessions on it, and Libraries, Tasks,
Users, Activity and Plugins under it, plus an account editor and an item metadata
editor. The dashboard is the **only** list of these screens; Settings has one row into it.

**It is a separate client from `JellyfinSource`, and the reason is 403.** For the
catalogue, every rejection means the session is gone and the answer is to sign in again.
Here, an account that is signed in perfectly well is refused for not being an
administrator — and sending that user to a password prompt sends them somewhere that
cannot help them. That one difference in `_send` is why the plumbing is not shared.

Five things that are easy to get wrong and are already handled:

1. **`/Users/{id}/Policy` and `/System/Configuration` are replaced, not patched.** Both
   are read, changed and written **whole**. Posting `{IsDisabled: true}` alone strips
   every library grant and parental limit the account has; posting `{ServerName: …}` alone
   resets every other server setting to its default. `setUserDisabled` refuses outright
   when the server will not describe the account, rather than guessing at a policy.
2. **Plugins are addressed by id *and* version** on enable, disable and uninstall — a
   server can hold two versions of one plugin and only one of them is meant to change.
3. **`isAdministrator` is re-read on every validate**, not trusted from the stored
   profile. An administrator can be demoted, and a stale `true` is a section whose every
   screen answers 403.
4. **A restart or a shutdown kills the connection because it *worked*.** The server
   answers and is gone before the socket closes.
5. **`CanSelfShutdown` was dropped from `/System/Info` in 10.9**, so it falls back to
   `CanSelfRestart`. A server in a container can do neither — the process *is* the
   container — and both menu items are then **absent rather than disabled**, because an
   item that explains why it does nothing is an item nobody wanted.

The guard lives in one place, `AdminScaffold`, so all five screens carry it identically —
and it distinguishes "no server signed in" from "not an administrator", because the two
have different answers. It is a **courtesy, not the security boundary**: the server is
that. `runAdminAction` is the single path every button takes, so a failure always reaches
the user as the sentence the client wrote, the affected providers are always invalidated,
and a success always says so — an action whose only feedback is a list that looks
identical afterwards leaves the user pressing it again.

Sessions are **not polled on a timer**: a list refreshing itself every few seconds is a
request every few seconds, on a phone, to answer a question that is rarely urgent. Pull to
refresh gives the same information at the moment it is wanted. Note that `AdminList` builds
its empty state as a scrollable — `RefreshIndicator` needs one that reaches its edge, and a
`Column` holding one line of text silently cannot be pulled.

### Accounts (2026-11-08)

`/admin/users/:id` (`admin_user_page.dart`) edits one account: the switches Jellyfin's
own editor has for role, library access, playback, content and the parental limit, plus
Set password and Delete behind the ⋮. Add user is the FAB on the users list and opens the
new account straight away.

- **`UserPolicy` models about fifteen of the policy's forty fields.** `setUserPolicy`
  reads the server's object **at save time** (not the copy the editor opened with) and
  `applyUserPolicy` lays the modelled fields over it, so access schedules, blocked tags,
  channel grants and the rest survive. A switch the server lacks
  (`EnableCollectionManagement` before 10.9) is not sent.
- **The editor is a draft**: one write on Save, Cancel restores, Back with changes asks.
  A fresh answer from the server (first load, after a save, a pull) replaces the draft.
- **Your own account** cannot be demoted, disabled or deleted from here. An
  administrator's Disabled switch is off too: the server answers 403 to it.
- **403 is not always "not an administrator".** The policy route refuses the last
  administrator's demotion and any administrator's disabling with 403 and a sentence;
  `_send` now passes a short plain-text or problem-details reason through and keeps the
  old wording only when the body says nothing.
- Passwords go to `/Users/{id}/Password` (still served beside 10.10's `?userId=` form)
  with `NewPw` only; an administrator setting someone else's is not asked for the old
  one. Empty removes it. The server signs that account's devices out.
- Ratings come from `/Localization/ParentalRatings`, one option per score with the
  country's names joined ("PG-13 / TV-PG"). 10.11 moved the number into `RatingScore`
  with a `SubScore`; picking a rating here writes both, and a value set elsewhere that is
  not in the list is still shown as chosen.
- `confirmAdminAction` styles its button from the **dialog's** context: Delete pops the
  editor while the dialog is still animating out, and the caller's context is gone.
- **Three tabs: Profile, Devices, Activity log** (2026-11-10). Profile is the editor,
  and the Save bar shows only there. Devices is the account's devices
  (`/Devices?userId=`), each with Forget; the users list itself shows accounts only,
  and no server-wide device list remains. Activity log is the account's log:
  `/System/ActivityLog/Entries` filters by `username` from 10.11 only, so entries
  are also kept to the account's id client-side (ids compared without dashes). On an
  older server that means "this account's among the newest 100", not all of them.
  `AdminScaffold.tabs` puts a `TabBar` under the title, behind the guard. Tests that
  scroll the editor must pick the **vertical** scrollable: the `TabBarView` is one too.

### Libraries and items (2026-11-09)

- **`/admin/libraries`** (`admin_libraries_page.dart`) lists `/Library/VirtualFolders`
  with each library's paths and a progress bar while it scans. Per library: Scan,
  Refresh metadata, Rename, Remove. Rename and remove are **keyed by name**; scan and
  refresh by `ItemId` (a library missing it says so rather than scanning everything).
  Remove leaves the files on disk and says so.
- **Add library** (2026-11-11, FAB → `/admin/libraries/new`,
  `admin_add_library_page.dart`): content type, name (follows the type until typed
  over), one or more folders; Create starts the first scan. Each library's ⋮ has
  **Folders**, a sheet to add or remove the folders it reads
  (`/Library/VirtualFolders/Paths`). The thirty other library options are left to the
  server's defaults and the web dashboard.
- **Folders are picked on the server**, never typed blind: `pickServerFolder`
  (`admin_folder_picker.dart`) walks `/Environment/Drives` → `DirectoryContents`
  (folders only) → `ParentPath` (a bare JSON string, or nothing at a root, so it is
  read as plain text). A path can be typed — a network share is under no drive — and
  is **opened** first, so a wrong one fails in the picker. A drive list cannot be
  chosen; something has to be opened. Create sends the paths comma-separated, so a
  path holding a comma is added afterwards through `Paths` instead.
- **Refresh** (`POST /Items/{id}/Refresh`, `refreshQuery`) offers Jellyfin's three
  depths: scan (Default/Default), missing metadata (FullRefresh, keep), replace all
  (FullRefresh + `ReplaceAllMetadata`). Images are never replaced from here.
  `Recursive=true` is sent for servers before 10.11, which ignores it.
- **Item actions** (`admin_item_actions.dart`): Refresh metadata, Edit metadata,
  Delete from server, appended **last** to `itemActionsFor` for an administrator, so
  they land in the overflow of the glyph row and at the end of chips and ⋮ menus.
  Delete closes the page only when the route's `extra` is that item, so deleting an
  episode from its series' list leaves the series open. `invalidateItem` drops the
  item and the lists it may be in.
- **Library ⋮** (`AdminItemMenu`, 2026-11-10): in the library screen's app bar, for an
  administrator only (nothing is drawn otherwise), as the web client offers on a
  library: Scan library, Refresh metadata (the three depths), Edit metadata. A box set
  or playlist drilled into gets the last two; it has no files of its own to scan.
- **Metadata editor** (`/admin/item/:id`, `admin_item_page.dart`): title, original
  title, sort title, year, certificate, overview, genres and tags (comma-separated),
  and Lock. `POST /Items/{id}` **clears every field it is not sent** (cast, provider
  ids, dates), so `setItemMetadata` reads `/Items/{id}?userId=` at save time and
  `applyItemMetadata` lays the edited fields over it. The sort title read back is
  `ForcedSortName`, never `SortName`, which would freeze the server's derivation.
  Controllers are filled from a `ref.listenManual`, not in `build`: filling them
  notifies the fields mid-build. It pops `true` after a save.
- Dialogs with a text field are **their own `StatefulWidget`** (`_RenameDialog`):
  disposing a controller right after `showDialog` returns breaks the closing animation.

### Monitoring and keys (2026-11-10)

- **Sessions**: each playing row says Direct play / Direct stream / Transcoding
  (`PlayState.PlayMethod`, coloured by cost); a tap opens `showSessionDetails`
  (`admin_session_sheet.dart`): app and version, address, and for a transcode the
  reasons first, in words for the common ones (`transcodeReasonLabel`, the rest split
  from CamelCase), then what video and audio become, bitrate, and the encoder —
  "Software" when `HardwareAccelerationType` is `none` or absent. `TranscodeReasons`
  is a list of names on current servers and **one comma-separated string** on older
  ones (`transcodeReasonsFromJson`). An idle session has no play method even when
  `PlayState` still carries the last one.
- **Restart pending**: `HasPendingRestart` from `/System/Info` draws a card under the
  server card, with Restart only where the server can restart itself.
- **Storage** (`/admin/storage`): `/System/Info/Storage`, **10.10+**; a 404 is "this
  server cannot say", not an error — `ServerException.statusCode` (new) is what tells
  them apart. The server writes `-1` for a size it could not measure; that is null
  here, and a bar is drawn only when both free and used are known. Under 10 GB free is
  drawn in the error colour.
- **Logs** (`/admin/logs`, `/admin/logs/view?name=`): `/System/Logs` newest first;
  `Logs/Log` fetched with `ResponseType.plain` (a JSON-looking line must not be
  parsed) and cut to its **last 512 KB** at a line break (`logTail`). Lines are a
  reversed `ListView.builder`, so it opens on the newest without a jump; `[ERR]`/`[FTL]`
  and `[WRN]` lines are coloured; a filter field and a Warnings-and-errors chip; Copy
  copies the lines shown.
- **Activity log pages**: `activityPage` (`startIndex`, `limit`, `minDate`,
  `severity=Warning`) behind Load more, with Warnings-and-errors and Any time / 24 h /
  7 days chips. `severity` is 10.11 only, so problems are also filtered here, and the
  next page starts after what the server **sent** (`ActivityPage.fetched`), not what
  survived. The pages live in the screen's state with a generation counter, so a page
  landing after the filters changed is dropped.
- **API keys** (`/admin/keys`): `/Auth/Keys`. A key is **masked** (first and last
  four) and leaves the screen only through Copy. Create takes an app name and answers
  nothing, so the list is fetched again; revoke asks first.
- **Task triggers**: `Triggers` on `/ScheduledTasks` drawn under each task — "Daily at
  03:00 · When the server starts", "Only when run by hand". The weekly day comes in
  English and is put in the reader's language with `DateFormat.EEEE`.

Deliberately **not** built: installing plugins from a repository (browsing remote packages
and checking versions against the server's ABI is a job for the machine it runs on), and
the rest of `/System/Configuration` beyond the server name — Jellyfin's configuration is
some eighty fields, and a small screen is where a setup gets broken rather than fixed.

`AppSemanticColors.warning` was added for this: M3 has `error` and nothing between it and
normal, and a plugin waiting on a restart is not broken.

## Test doubles

`test/fake_library_source.dart` is a `MediaLibrarySource` that answers nothing; tests
`extend` it and override the two or three methods they are about. Before it, four test
files each carried sixty lines of "returns an empty list" stub and **every method added to
the interface broke all of them at once** — which is what adding media segments
and the library tabs did in turn. It earns its keep in both directions.

`test/fake_keychain.dart` stands in for the platform keychain. It was shared
with the share-password tests; only the server token uses it now.

## Reference material

`../refs/jellyfin-android` (GPL-2.0) — the official Android client. Kotlin, and a
WebView around a native player rather than anything to port, but it is the **reference for
what a Jellyfin client is expected to do**: media segments, trickplay, the device profile,
the quality ladder. Media segments and trickplay above follow its behaviour deliberately,
including its defaults — read `player/mediasegments/` and `player/ui/TrickplayHelper.kt`.
Still missing from mPlayer next to it: offline downloads, a server switcher, and the
Android Auto media-browse tree.

`../refs/plezy` (see its LICENSE) — a shipping Flutter client for Plex, Jellyfin and Emby
on the same Flutter version. The best reference for anything Jellyfin: points 2 and 3
above are both bugs its source caught in this one. Read `lib/services/jellyfin_*.dart`.

`../refs/NipaPlay-Reload` (MIT) — a working Flutter media client. Its `lib/services/` contains Emby (1712 lines), Jellyfin (1655), WebDAV (1617) and SMB implementations with **zero danmaku coupling**, sharing `media_server_service_base.dart`. Adapt these; do not fork the whole app (its `lib/` is ~270k lines and heavily anime-oriented).

Read-only. Never edit anything under `refs/`.

## Commands

```bash
flutter analyze
flutter test
flutter build windows --debug
flutter build apk --debug
flutter build apk --release --split-per-abi    # what CI ships (one APK per ABI)
```

**There is no `build_runner`.** `drift`, `freezed` and `json_serializable`
were dependencies that nothing ever generated from, and they have been
removed. The only generated code is the localisations:

```bash
flutter gen-l10n          # also run by flutter pub get
```
