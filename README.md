# DirXplore

**A lightweight iOS file browser for HTTP directory listings — built for BDIX servers and beyond.**

DirXplore parses Apache/nginx directory index pages into a clean file explorer interface, with proxy support, background downloads, bookmarks, and search.

## Features

- **Directory browsing** — Navigate Apache/nginx index pages with sorting by name, size, and date
- **SOCKS5 proxy** — Route traffic through a SOCKS5 proxy with optional auth; pure C engine for reliable `poll()`-based timeouts
- **Download manager** — Background downloads, pause/resume, Wi-Fi-only mode, Live Activities, progress notifications
- **Bookmarks** — Save frequently accessed paths
- **Search** — Filter files and folders by name in real time
- **Navigation** — Back/forward history stack
- **Dark mode** — System light/dark toggle
- **Sorting** — Tap column headers to sort ascending/descending

## Motivation

BDIX (Bangladesh Internet Exchange) servers host vast public file archives accessible via local intranet, but most have no mobile-optimized UI. DirXplore turns raw Apache listings into a native browsing experience, with proxy support for servers not on the local network.

## Architecture

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI |
| Networking | `URLSession` + custom `URLProtocol` |
| Proxy | Pure C (`Socks5Core.c`) — `socket`, `connect`, `poll`, `send`, `recv` |
| Parsing | `NSRegularExpression` on Apache HTML |
| Storage | `UserDefaults` + file system |

The SOCKS5 tunnel runs entirely in C to avoid `Network.framework` timer races. A single `socks5_fetch()` call handles TCP connect, SOCKS5 handshake, and HTTP send/receive with a precise `poll()`-based timeout.

## Requirements

- iOS 17.0+
- Xcode 15.4+ (for development)
- Sideload via unsigned IPA or developer signing

## Building

```bash
git clone https://github.com/rakibshorkar2/dixploreswift1.git
cd dixploreswift1/DirXplore
open DirXplore.xcodeproj
# Select your team, build & run
```

An unsigned IPA is built automatically via GitHub Actions on each tag.

## Usage

1. Enter a URL (e.g. `http://172.16.50.4`) in the address bar
2. Enable the SOCKS5 proxy in settings if the server is behind a proxy
3. Tap files to download, folders to navigate
4. Bookmark frequently used paths for quick access

## License

MIT
