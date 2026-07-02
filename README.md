# resources2

A Vapor server that sits in front of the Last.fm API and gives you clean JSON responses, consistent types, and [no surprises](https://www.youtube.com/watch?v=u5CVsCnxyXg). Get track and artist covers, similar artists, charts, and more. Also supports the Apple App Attestation API so you can use resources2 in your apps while ensuring the request is coming from a legitimate source.

## Why

If you have used the Last.fm API before, you know why. Here is a non-exhaustive list of the problems:

- **Numbers arrive as strings:** `"listeners": "117224"` instead of `117224`, everywhere.
- **Lists collapse:** A field with one item comes back as a bare object instead of a one-element array.
- **Tags are sometimes `""`:** Not `{"tag": []}`, an empty string, when there are none.
- **Images need a real user:** Request artist info without a `username` and you get a generic placeholder image instead of the artist's actual photo.
- **Bios come with a tracking link and license boilerplate baked into the text:** they are not separated out.
- **One track, multiple albums:** `track.getInfo` only ever returns one album association, often a generic "Greatest Hits"-style compilation instead of the release you actually care about.

resources2 handles all of it once.

## What you get

- **Normalized types:** Ints are ints, missing fields are `null`, lists are always arrays.
- **Clean text:** Bios are trimmed to just the actual writeup, with no embedded links or license paragraph.
- **Real images:** Cover URLs resolve to the artist/album/track's actual photo, not a placeholder.
- **Album resolution:** Ask for a track without an album and it finds a good match using Last.fm's own data. Ask with an album and it's honored exactly, including cases where "X" and "X - EP" are genuinely different releases.
- **Tags on every entity:** artist, album, and track all come back with their tag lists.
- **Smart caching:** Postgres backs every entity with a TTL (24h for normal catalog data, 5min for user-specific scrobble counts), so high traffic in your app won't affect the Last.fm API and you won't have to worry about rate limiting, stale data, etc.
- **Per-user scrobble counts:** User-specific play counts are tracked alongside the catalog data, refreshed independently of it when a request is made.

## Implemented methods
- [X] `artist.getInfo`
- [X] `album.getInfo`
- [X] `track.getInfo`

## Endpoints

Check out the [Swagger UI](http://localhost:8080/Swagger) for a full list of endpoints. Here are some quick examples:

### `GET /track/info`

```
GET /track/info?track=When%20the%20Sun%20Hits&artist=Slowdive&username=blueslimee
```

```json
{
  "artist": {
    "id": "352dfe99-...",
    "name": "Slowdive",
    "listeners": 2284425,
    "scrobbles": 152295425,
    "cover": {
      "defaultURL": "https://lastfm.freetls.fastly.net/i/u/300x300/....jpg",
      "template": "https://lastfm.freetls.fastly.net/i/u/{w}x{h}/....jpg"
    },
    "tags": ["dream pop", "shoegaze", "indie", "ambient", "indie rock"],
    "userScrobbles": { "playCount": 4 }
  },
  "album": {
    "id": "...",
    "name": "Souvlaki",
    "listeners": 1959397,
    "scrobbles": 94821286,
    "cover": { "defaultURL": "...", "template": "..." },
    "tags": ["dream pop", "shoegaze", "90s", "indie", "dreamy"],
    "tracks": [
      { "id": "...", "name": "Alison", "rank": 1 },
      { "id": "...", "name": "Machine Gun", "rank": 2 }
    ],
    "userScrobbles": { "playCount": 4 }
  },
  "track": {
    "id": "c10aec88-...",
    "name": "When the Sun Hits",
    "listeners": 1593978,
    "scrobbles": 27748509,
    "cover": { "defaultURL": "...", "template": "..." },
    "tags": ["dream pop", "shoegaze", "90s"],
    "userScrobbles": { "playCount": 4, "loved": false }
  }
}
```

### `GET /artist/info`

```
GET /artist/info?name=Kelela&username=blueslimee
```

```json
{
  "id": "...",
  "name": "Kelela",
  "aliases": [],
  "listeners": 648122,
  "scrobbles": 39692947,
  "cover": { "defaultURL": "...", "template": "..." },
  "tags": ["electronic", "rnb", "ambient", "trip-hop", "House"],
  "bio": {
    "summary": "Kelela Mizanekristos is an American singer...",
    "content": "Kelela Mizanekristos (born June 4, 1983) is an American singer...",
    "license": "User-contributed text is available under the Creative Commons By-SA License; additional terms may apply."
  },
  "similarArtists": [
    { "id": "...", "name": "Rochelle Jordan", "cover": { "defaultURL": "...", "template": "..." } },
    { "id": "...", "name": "FKA twigs", "cover": { "defaultURL": "...", "template": "..." } }
  ],
  "userScrobbles": { "playCount": 909 }
}
```

Endpoints return `400` for a missing/invalid username and `404` when the artist/album/track can't be found at all.

## Installation

### Using Docker

The image is available at `ghcr.io/musicorum-app/resources2`. The recommended way to run it is with Docker Compose. Here's an example:
```yaml
version: "3.9"
services:
  resources2:
    image: ghcr.io/musicorum-app/resources2:latest
    env_file:
      - .env
    ports:
      - "8080:8080"
    depends_on:
      - postgres
    command: sh -c "migrate --yes && serve --env production --hostname 0.0.0.0 --port 8080"
  postgres:
    image: postgres:18
    environment:
      - POSTGRES_PASSWORD=your-db-password
      - POSTGRES_USER=your-db-username
      - POSTGRES_DB=resources2
    volumes:
      - postgres-data:/var/lib/postgresql/data

volumes:
  postgres-data:
    driver: local
```

### Using swift run
Requires Postgres and a Last.fm API key. Start by renaming `.env.example` to `.env` and filling in the blanks. Then run:

```bash
swift run Resources migrate --yes
swift run Resources serve
```

To install Swift, check out [Vapor's installation guide](https://docs.vapor.codes).

## How the cache works

write me

