# Charts

A user's top artists, albums, or tracks over a given period.

## Overview

Each chart entry is fully resolved through the same catalog sync as <doc:TrackAlbumArtistInfo>, so entries come back with real ids, `cover`, and `playCount` — not just Last.fm's raw chart data. `items` is always ordered by `playCount` descending. The shaped response is cached for 10 minutes per `(type, username, period, limit, page)` combination, so repeat requests are fast; individual entities underneath still refresh on their own 24-hour cache.

`type` and `period` aren't echoed back in the response — you already know what you asked for.

### `GET /user/charts`

| Param | Required | Notes |
|---|---|---|
| `username` | yes | |
| `type` | yes | `artist`, `album`, or `track` |
| `period` | yes | `overall`, `7day`, `1month`, `3month`, `6month`, `12month` |
| `limit` | no | Default `50`, capped at `100` |
| `page` | no | Default `1` |

```
GET /user/charts?username=blueslimee&type=album&period=1month&limit=10
```

```json
{
  "page": 1,
  "totalPages": 15,
  "total": 143,
  "items": [
    { "id": "...", "name": "Hallucinogen", "artist": "Kelela", "cover": { "defaultURL": "...", "template": "..." }, "playCount": 12 }
  ]
}
```

`items[].artist` is `null` for `type=artist` charts (the entry *is* the artist).

> Note: `type=track` entries don't carry an album name from Last.fm's chart data itself — one is discovered the same way `/track/info` does when you omit `album`. If none can be discovered, that entry's `id` is a one-off value rather than a stable catalog id.

### `GET /user/charts/all`

Same as above but returns all three chart types in a single request — no `type` or `page` param, since it's always the first page of each.

| Param | Required | Notes |
|---|---|---|
| `username` | yes | |
| `period` | yes | Same options as above |
| `limit` | no | Default `50`, capped at `100` |

```
GET /user/charts/all?username=blueslimee&period=7day&limit=5
```

```json
{
  "artists": { "page": 1, "totalPages": ..., "total": ..., "items": [...] },
  "albums": { "page": 1, ... },
  "tracks": { "page": 1, ... }
}
```

## Topics

- <doc:RecentTracks>
