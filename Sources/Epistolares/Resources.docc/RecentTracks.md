# Recent Tracks

A user's scrobble history, including what they're listening to right now.

## Overview

Each entry is resolved through the exact same sync path as `/track/info` (see <doc:TrackAlbumArtistInfo>), plus `nowPlaying` and `playedAt` per entry. `album`/`artist` are lighter than a standalone `/album/info` or `/artist/info` lookup though — no `tags`, and no album tracklist — since a scrobble-history feed doesn't need either; only `track` carries `tags`.

Unlike <doc:Charts>, this endpoint's response is **never cached** — every request hits Last.fm fresh, since it's meant to reflect what's happening right now (including the currently-playing track). Only the underlying entity data (artist/album/track catalog info) benefits from the normal cache.

### `GET /user/recent-tracks`

| Param | Required | Notes |
|---|---|---|
| `username` | yes | |
| `limit` | no | Default `5`, capped at `100` |
| `page` | no | Default `1` |

```
GET /user/recent-tracks?username=blueslimee&limit=2
```

```json
{
  "page": 1,
  "totalPages": 53133,
  "total": 159399,
  "items": [
    {
      "nowPlaying": true,
      "playedAt": null,
      "track": { "id": "...", "name": "1 Thing", "listeners": ..., "scrobbles": ..., "cover": { ... }, "tags": [...], "userScrobbles": { "playCount": 2, "loved": false } },
      "album": { "id": "...", "name": "Touch", "listeners": ..., "scrobbles": ..., "cover": { ... }, "userScrobbles": { "playCount": 2 } },
      "artist": { "id": "...", "name": "Amerie", "listeners": ..., "scrobbles": ..., "cover": { ... }, "userScrobbles": { "playCount": 17 } }
    },
    {
      "nowPlaying": false,
      "playedAt": "2026-07-02T00:49:50Z",
      "track": { "id": "...", "name": "Toxic", ... },
      "album": { "id": "...", "name": "In the Zone", ... },
      "artist": { "id": "...", "name": "Britney Spears", ... }
    }
  ]
}
```

`playedAt` is `null` exactly when `nowPlaying` is `true` — Last.fm doesn't give a timestamp for the track currently playing. `album` is `null` for a scrobble with no album (rare, but happens for some singles).

Unlike <doc:TrackAlbumArtistInfo>, `userScrobbles` is never `null` here (on `track`, `album`, or `artist`) — `username` is required for this endpoint, so there's always a user to have scrobble counts for.
