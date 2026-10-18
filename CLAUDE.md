# mPlayer

Cross-platform **client** for a Jellyfin/Emby media server: browse a library,
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

Real, end to end: sign in to a Jellyfin/Emby server, browse its libraries,
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

1. Downloads (screen 1i) is still parked on sample data. It is now a *server*
   feature — an offline copy of a server item — and the player can play one,
   so it is worth building rather than dropping.
2. English literals remain where Localisation says.
3. Dropped on purpose: **NFS**, **network scanning**, **preview thumbnails**
   generated locally (the server's trickplay covers it), and now every local
   source.

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
entry, or none while nothing is signed in.

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

`PlaybackState.chapters` prefers the source list when it is non-empty. Container chapters
fall back to a title heuristic (`_looksLikeIntro`) — a false positive costs the user one
ignorable pill. **A server chapter never goes through that heuristic**: a server that
knows what an intro is says so through media segments instead, and letting a chapter
called "Opening" claim it too would put two pills on the screen.

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

- **Emby is never asked** and a 404 is swallowed: `segments()` is the one call that
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
  than the thing being skipped lasted.
- `PlaybackState.currentIntro` returns null the moment `segments` is non-empty. That is
  what keeps the container heuristic and the server's own answer from both drawing a pill.

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
   Jellyfin, which is what would let an Emby or Plex driver land beside it
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

`.github/workflows/release.yml` builds Android APKs, a Windows zip and a Linux tarball,
publishes a GitHub release and posts to Telegram. Runs on push to `main` or `dev`, or
manually on any branch. **There has never been a macOS job.**

**The Windows and Linux jobs are temporarily switched off** — `if: false` on each, and
both jobs are left whole so turning one back on is that one line. Three things moved with
them, and all three are worth keeping even after they come back:

- `release` cannot simply `needs:` a skipped job, or it skips too, so it checks results by
  name instead. Only `prepare` and `android` are named: a desktop build that did not run
  must not stop a release, and it cannot fail while it does not run.
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
- Android builds with `--split-per-abi`, so the release carries three APKs named
  `<base>-android-<abi>.apk` (`arm64-v8a`, `armeabi-v7a`, `x86_64`) instead of one fat
  one — media_kit bundles an 11–15 MB `libmpv.so` per ABI. Flutter's Gradle plugin
  offsets the version code per ABI automatically; the rename loop and the release-notes
  table both spell the three ABIs out, so adding or dropping one means touching both.
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
3. **Emby 4.9 omits `ProductName`.** Detecting the dialect from that field alone files
   every modern Emby as Jellyfin, which then gets called on routes it does not have.
   `RemoteAddresses` is the fallback signal. Note also that Emby only accepts the
   pre-10.9 `/Users/{userId}/…` spelling of the user-scoped routes this client uses.
4. **A `TranscodingUrl` on the media source means the server chose to re-encode**,
   whatever `SupportsDirectPlay` says — those flags describe what is possible, not what
   was decided. The direct-play URL carries the token as `api_key` in the
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
- **`/Items/Filters` is Jellyfin's alone.** Emby answers 404 and serves the four facets
  separately — and the ratings one is `/OfficialRatings`, not the `/Items/OfficialRatings`
  its siblings suggest. Every facet needs `recursive=true` or the server only considers the
  view's direct children and all four come back empty. A server that will not answer costs
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
`lib/features/admin/`: a dashboard with the sessions on it, and Tasks, Users & devices,
Activity and Plugins under it.

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
flutter build apk --release --split-per-abi    # what CI ships
```

**There is no `build_runner`.** `drift`, `freezed` and `json_serializable`
were dependencies that nothing ever generated from, and they have been
removed. The only generated code is the localisations:

```bash
flutter gen-l10n          # also run by flutter pub get
```
