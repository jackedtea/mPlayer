# Music — Implementation Plan

> Status: **M1 is built** (2026-11-07), steps 1–5 of the order of work below.
> Not yet tried on a device. The controller's `queueNext`, `addToQueue`,
> `moveInQueue` and `removeFromQueue` wait for the M2 queue sheet. The section
> "Where the app stands today" describes the app before step 1. `../CLAUDE.md`
> stays the description of the code as it is.

## Where the app stands today

A Jellyfin **music** library is listed by `/UserViews` and gets an icon
(`server_library.dart` → `library_music_rounded`), and nothing else works:

| Place | What it does to music now |
|---|---|
| `JellyfinSource.items` | `includeItemTypes=Movie,Series,Video,BoxSet` — a music library opens as an **empty grid** |
| `ServerItemKind` | No album, artist or track. `_kindFrom` maps `MusicAlbum`/`Audio`/`MusicArtist` to `unknown` |
| `serverLatestProvider` | Filters music out of "Recently added" on purpose |
| `deviceProfileFor` (`jellyfin_dto.dart`) | Declares only `Type: Video` direct-play/transcode profiles — a track's `PlaybackInfo` has no audio profile to match |
| `createPlaylist` | Forces `MediaType: Video` |
| `PlaybackController` / `QueueableSource` | Queue = the episodes of a series, `PlaybackQueue.isSeries` |
| `PlayerPage` | The decoder lives and dies with the `/player` route: `dispose` calls `_playback.stop()` |
| `PlaybackService.kt` | Notification has title + subtitle, **no artwork** |

What carries over untouched: libmpv plays every audio container Jellyfin
serves; background audio, the media session, audio focus and headset keys
already exist; progress reporting, favourites, downloads (original file),
DLNA/Chromecast casting and the phone remote all speak in item ids.

**The one structural problem** is the last two rows of the table: music is
*listened to while doing something else in the app*. A track cannot stop
because the user went back to the library. Everything else is additive.

## Decisions to take up front

1. **One player, two faces.** Do not fork the player (design rule 3). The
   decoder and `PlaybackController` already sit in a global
   `NotifierProvider`; what changes is **who owns the session's lifetime**.
   For video the `/player` route keeps owning it, exactly as now. For audio a
   new `AudioSession` owner (no widget) keeps it, and two faces read it: a
   **mini player** docked above the navigation bar and a full-screen
   **Now playing** route. Video playing while music plays stops the music —
   one decoder.
2. **The queue becomes an explicit list**, not "whatever `siblingsOf`
   answers". Music needs play album / play from track N / shuffle / play
   next / add to queue / reorder / remove. `PlaybackQueue` grows a `kind`
   (`series | music | single`) replacing `isSeries`, plus mutation methods on
   the controller. The video path keeps calling `loadSiblingQueue`.
3. **Stream through `PlaybackInfo` with an audio device profile**, not the
   `/Audio/{id}/universal` shortcut — one code path for resolve, transcode
   decision, `PlaySessionId` and reporting. The profile adds `Type: Audio`
   direct play for `mp3,aac,m4a,flac,alac,opus,ogg,vorbis,wav,wma,ape`
   (whatever libmpv decodes, i.e. everything) and an `aac`/`mp3` HTTP
   transcoding profile used only when the quality cap bites.
4. **Gapless**: mpv's `gapless-audio` is already a setting; true gapless
   needs the next track appended to mpv's own playlist (`loadfile … append`)
   rather than `open()` after `completed`. Phase M3, not M1.
5. **Server first** (see memory: prefer server storage): queue *contents* are
   local session state, but favourites, play counts, playlists and instant
   mixes all go to the server. Nothing music-specific in `shared_preferences`
   except UI choices (grid/list, last music tab).

## Phases

### M1 — Browse and play (the minimum that makes a music library not empty)

Data layer (`lib/servers/`):
- `ServerItemKind`: add `musicAlbum`, `musicArtist`, `audio` (track),
  `playlist` if not already modelled. `isBrowsable` stays false for album
  and artist — they open detail screens.
- `ServerItem`: add `album`, `albumId`, `artists` (list), `albumArtist`,
  `albumArtistId`, `indexNumber` (track no.), `parentIndexNumber` (disc no.).
  Parse in `jellyfin_dto.dart`; extend `_fields` only where cheap
  (`AlbumArtist`, `Artists`, `AlbumId` come by default on `Audio`).
- `MediaLibrarySource` + `JellyfinSource`:
  - `musicItems(viewId, {kind: albums|artists|tracks, sort, filter, paging})`
    — `includeItemTypes=MusicAlbum` / `/Artists/AlbumArtists?parentId=` /
    `Audio`.
  - `albumTracks(albumId)` — `AlbumIds=` + `SortBy=ParentIndexNumber,IndexNumber,SortName`
    (plezy's choice: `ParentId` breaks on tag-based albums sharing a folder).
  - `artistAlbums(artistId)` — `AlbumArtistIds=`, newest first.
  - `artistTopTracks(artistId)` — `ArtistIds=`, `SortBy=PlayCount`.
- `deviceProfileFor`: audio direct-play + transcoding profiles (decision 3).
  Test against captured `PlaybackInfo` for an mp3 and a flac.
- `createPlaylist`: take `MediaType` from the items (`Audio` for tracks).
- `jellyfin_media_source.dart`: `resolve` fills `PlayableMedia` with album
  art URL, artist and album so the player and notification have them.

Screens (`lib/features/music/`):
- **Music library view** — `library_grid_page.dart` branches on
  `CollectionType == 'music'` to tabs **Albums · Artists · Songs · Playlists ·
  Genres** (same stock `TabBar`, same filter/sort dialog where it applies:
  sort by name / artist / year / date added / random).
- **Album detail** — square art, title, artist (tappable), year, track list
  grouped by disc, total runtime; Play / Shuffle pinned at the foot on a
  phone (`ItemPrimaryActionBar`, one-handed rule); favourite, download,
  add to playlist via the existing `ItemActionIcons`.
- **Artist detail** — backdrop, top tracks (5, "see all"), albums shelf,
  "appears on", similar artists (`/Artists/{id}/Similar`).
- `openServerItem` routes the new kinds. `PosterTile` gets a square variant
  (album art is 1:1, the grid uses `mainAxisExtent` — layout rule).

Playback:
- `PlaybackQueue.kind` + `playQueue(List<MediaRef>, {start, shuffle})` on the
  controller.
- **`AudioSession` owner**: when the media is audio, opening does *not* push
  `/player`; the controller keeps the decoder, and leaving any screen does
  not stop it. Stop = explicit (mini player ✕, notification dismiss, or a
  video starting).
- **Mini player** in `AdaptiveScaffold` above the bar/rail content: art,
  title · artist, play/pause, next, thin progress. Tap → Now playing.
  Hidden on the video player and on Home's server chooser.
- **Now playing** route: large art, seek bar, prev/play/next, shuffle,
  repeat (off/all/one), favourite, queue button. Wide windows: art left,
  queue right. Keyboard/remote keys reuse `_handleKey` semantics.
- Report progress exactly as video does (`ProgressReporting`) — Jellyfin
  counts a play at the end and keeps `PlayCount`/`LastPlayedDate`.

Tests: DTO parsing for the three item types, device-profile snapshot,
queue mutation unit tests, `screens_test.dart` covering the new routes at all
three breakpoints (no overflow), `l10n_test` (new keys in both ARBs).

### M2 — Queue, platform integration, home

- **Queue sheet**: reorder (drag), remove, "play next", "add to queue" from
  every track/album/artist menu, clear. Shuffle keeps the original order to
  restore.
- **Notification / lock screen art**: `NowPlayingChannel` passes an art URL;
  `PlaybackService.kt` fetches it (or Dart sends bytes) into
  `METADATA_KEY_ALBUM_ART` + `setLargeIcon`; add `METADATA_KEY_ALBUM`.
  Kotlin still decides nothing.
- **Windows SMTC / Linux MPRIS**: media keys work today only while focused;
  a system media overlay is the desktop equivalent of the notification.
  Evaluate `audio_service`-free options (`smtc_windows`, `mpris_service`)
  against the "no needless dependency" habit — or defer.
- **Home**: a "Recently added in Music" row (album squares) instead of
  dropping music in `serverLatestProvider`; "Recently played" from
  `SortBy=DatePlayed&IncludeItemTypes=Audio`. Still respects
  `LatestItemsExcludes`.
- **Search**: a Songs / Albums / Artists section in `kind_sections.dart`.
- **Instant mix**: `/Items/{id}/InstantMix` from a track, album, artist or
  genre → replaces the queue.
- **Remote & cast**: `RemoteSnapshot` gains artist/album and queue length;
  "play an item" sends a queue (`serverId + itemIds + index`). DLNA DIDL
  `upnp:class` becomes `object.item.audioItem.musicTrack` with
  `upnp:albumArtURI`; Chromecast `MediaMetadata` type `MUSIC_TRACK`.

### M3 — Polish

- **Gapless / crossfade-free transitions**: pre-append the next resolved URL
  to mpv's playlist; keep the controller's queue index in sync on
  `playlist-pos` change.
- **Lyrics**: `/Audio/{id}/Lyrics` (10.9+), synced (LRC timestamps) scroll
  with the position on Now playing; plain lyrics as text; 404 = no tab.
- **ReplayGain / normalisation**: mpv `replaygain=track|album` setting in
  Audio settings (Jellyfin passes the file untouched on direct play, so the
  tags are there).
- **Downloads for music**: "Download album" (count prompt like
  "Download all" on a series); offline queue walks downloaded tracks of the
  album, mirroring offline episodes. Original file only, unchanged rules.
- **Sleep timer** already exists in the More sheet — expose it on Now
  playing, plus "stop after this track".
- **Android Auto / media browse tree** (named as missing in CLAUDE.md
  "Reference material"): a `MediaBrowserService` over albums/playlists.
  Largest platform item; only once M1–M2 are proven on a device.

## Deliberately out of scope

- Music videos (`musicvideos` collection) — they are videos; they already
  play through the video path once `includeItemTypes` admits `MusicVideo`.
  One-line follow-up, not part of this plan.
- Editing tags / metadata, audiobooks and podcasts (different progress model:
  resume-per-book), live radio.
- A local music library — local sources stay removed.

## Risks and open questions

1. **Decoder ownership** is the riskiest change: the comments in
   `player_page.dart` dispose ordering exist because a leaked audio thread
   was a real bug. The audio session must have one clear teardown path and a
   test that a video open after music stops the music first.
2. `PlaybackService.kt` and the PiP/background-audio lifecycle check assume
   a visible player; with no `/player` route the ~400 ms deferred pause must
   not fire for audio (background audio is the *point*).
3. Album art fetching in Kotlin needs the token in the URL (`api_key`), same
   as streams — fine, already how images are built.
4. Large libraries: Songs tab must page (the grid already pages at 100) and
   Artists come from `/Artists/AlbumArtists`, which ignores some filters.
5. Unverified until tried on real hardware: Android notification art, TV
   remote on Now playing, DLNA audio on a TV.

## Suggested order of work (each a reviewable change)

1. Item kinds + DTO fields + music listing endpoints (+ tests).
2. Audio device profile + resolve with art/artist (+ snapshot test).
3. Music library tabs, album and artist screens.
4. Queue model change (`kind`, explicit list, play/shuffle).
5. Audio session ownership + mini player + Now playing.
6. M2 items one by one; M3 as wanted.
