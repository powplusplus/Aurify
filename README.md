# Aurify

Aurify is a native SwiftUI movie and TV app for iOS 26 and later. It follows Z-Stream's public catalog/provider contracts without embedding the website or using a `WKWebView`. Catalog screens are SwiftUI, playback is AVFoundation, credentials are stored in Keychain, and watch state stays on device.

## Open and run

1. Open `Aurify.xcodeproj` in Xcode 27 or later.
2. Select the **Aurify** target, choose your Apple Developer team, and change the bundle identifier if required.
3. Run on an iOS 26+ device or simulator.
4. If Z-Stream's runtime configuration does not expose a TMDB credential, open **Settings → Catalog** and paste your own TMDB Read Access Token. A free token is available from TMDB account settings.

You can also set `TMDB_READ_TOKEN` as a user-defined build setting. Never commit a private token.

## Native features

- Trending, popular, top-rated, multi-search, movie details, TV seasons, and episodes
- Native Z-Stream provider carousel with Granite and VidLink, ordered fallback, live status, and a custom resolver option
- Automatic provider handoff when a resolved source fails during AVFoundation playback
- Native HLS/MP4 playback, quality switching, playback speed, AirPlay, and Picture in Picture
- Provider and external VTT/SRT subtitles with language preference and styling
- Per-movie and per-episode resume progress, completion state, history, and watchlist
- iOS 26 Liquid Glass controls; Xcode 27 builds automatically adopt the refreshed iOS 27 appearance
- Keychain credentials, privacy manifest, no analytics, and no global ATS bypass

## Custom resolver contract

Set **Settings → Streaming → Provider** to **Custom Resolver** and provide an HTTPS endpoint. Aurify sends these query parameters:

`tmdbId`, `type` (`movie` or `tv`), and, for TV, `season` and `episode`.

The response is JSON:

```json
{
  "sources": [
    {
      "url": "https://media.example/master.m3u8",
      "quality": "auto",
      "type": "hls",
      "name": "Adaptive",
      "headers": { "Referer": "https://media.example/" }
    }
  ],
  "subtitles": [
    {
      "url": "https://media.example/en.vtt",
      "language": "en",
      "label": "English",
      "format": "vtt"
    }
  ]
}
```

## Distribution note

Aurify does not host video. Before distributing it, confirm that your metadata and streaming providers allow your use, supply a privacy policy and support URL, and ensure you have rights to every title offered in your region. Provider availability can change independently of the app.
