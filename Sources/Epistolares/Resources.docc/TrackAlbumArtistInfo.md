# Track, Album & Artist Info

Look up a single track, album, or artist, with clean/normalized data and (optionally) a user's scrobble counts for it.

## Overview

These three endpoints follow the same shape: give it enough to identify the entity, get back its catalog data plus an optional `username` for personalized scrobble counts. See <doc:GettingStarted> for the shared `cover` object and error codes.

### `GET /track/info`

| Param | Required | Notes |
|---|---|---|
| `track` | yes | Track name |
| `artist` | yes | Artist name |
| `album` | no | If omitted, the album is discovered automatically from Last.fm's own data. If given, it's honored exactly (including cases like `"X"` vs `"X - EP"` being genuinely different releases). |
| `username` | no | Adds `userScrobbles` to `track`/`album`/`artist` |

```
GET /track/info?track=When%20the%20Sun%20Hits&artist=Slowdive&username=blueslimee
```

Returns `{ track, album, artist }`, each an entity object with `id`, `name`, `listeners`, `scrobbles`, `cover`, `tags`, and (if `username` given) `userScrobbles: { playCount }`. `track`'s `userScrobbles` additionally has `loved: Bool` — never nullable, `false` when Last.fm has no love/unlove data for it. `album` also includes `tracks: [{ id, name, rank }]` (its full tracklist) and is `null` if no album could be resolved at all.

### `GET /artist/info`

| Param | Required | Notes |
|---|---|---|
| `id` | one of `id`/`name` | Internal artist id (from a previous response) |
| `name` | one of `id`/`name` | Artist name |
| `username` | no | |

```
GET /artist/info?name=Kelela&username=blueslimee
```

Returns the artist entity plus `aliases`, `bio: { summary, content, license } | null` (all three fields are guaranteed present whenever `bio` isn't `null`), and `similarArtists: [{ id, name, cover }]`.

### `GET /album/info`

| Param | Required | Notes |
|---|---|---|
| `id` | one of `id`/(`name`+`artist`) | Internal album id |
| `name` + `artist` | one of `id`/(`name`+`artist`) | Album name and its artist's name |
| `username` | no | |

```
GET /album/info?name=Hallucinogen&artist=Kelela&username=blueslimee
```

Returns the album entity (same shape as `/track/info`'s `album`), plus `artist: "Kelela"` (the artist name) and `bio` (same nullable-all-or-nothing shape as `/artist/info`'s).
