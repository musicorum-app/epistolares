# Getting Started

Conventions shared by every endpoint: base URL, errors, pagination, and the cover object.

## Overview

All endpoints are plain `GET` requests returning JSON. There's no authentication on the API itself — point your client at wherever you're running Resources (e.g. `http://localhost:8080`) and start making requests.

### Usernames

Most endpoints take a `username` query parameter — a real Last.fm username, used to enrich the response with that user's own scrobble counts (`userScrobbles`) alongside the shared catalog data. Two different rules apply depending on the endpoint:

- **`/track/info`, `/artist/info`, `/album/info`**: `username` is optional. Omit it and you get the catalog data with no `userScrobbles`.
- **`/user/charts`, `/user/charts/all`, `/user/recent-tracks`**: `username` is required — the whole endpoint is about that user's data.

Whenever `username` is provided (required or not) and doesn't correspond to a real Last.fm account, the request fails with `400`.

### Errors

- **`400 Bad Request`** — an invalid Last.fm username, or a request missing a required parameter (e.g. neither `id` nor `name` given to `/artist/info`).
- **`404 Not Found`** — the requested artist/album/track genuinely doesn't exist on Last.fm.

### Pagination

Endpoints that return lists (`/user/charts`, `/user/recent-tracks`) share the same two parameters:

- `limit` — how many items per page. Defaults and caps vary by endpoint (see each guide).
- `page` — 1-indexed, defaults to `1` if omitted.

The response includes `page`, `totalPages`, and `total` alongside the `items` array.

### Cover images

Every entity (artist, album, track) that has artwork returns a `cover` object instead of a bare URL:

```json
"cover": {
  "defaultURL": "https://lastfm.freetls.fastly.net/i/u/300x300/4913efca4bfb537b8ec9faafdd86cf60.jpg",
  "template": "https://lastfm.freetls.fastly.net/i/u/{w}x{h}/4913efca4bfb537b8ec9faafdd86cf60.jpg"
}
```

- `defaultURL` is a ready-to-use 300×300 image.
- `template` is the same URL with the dimensions replaced by a literal `{w}x{h}` placeholder — substitute your own size (e.g. `64x64`, `1000x1000`) if you need something other than the default.

`cover` is `null` when Last.fm has no artwork for that entity at all — show your own placeholder in that case, there's nothing to fall back to.

## Topics

- <doc:TrackAlbumArtistInfo>
- <doc:Charts>
- <doc:RecentTracks>
