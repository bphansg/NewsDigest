# NewsDigest — AI News Curator for Mac

A native macOS app that automatically curates the most interesting tech news 24/7, ranking articles from Hacker News, RSS feeds, and Substack newsletters based on your personal topics of interest. Listen to curated digests via text-to-speech or save concise markdown reports with links.

## Quick Start — Build & Install

```bash
# One command: build app + create DMG installer
make

# Or step by step:
make build          # Compile the app
make dmg            # Build + package as DMG
make run            # Build and launch immediately
make open           # Open in Xcode
make clean          # Remove build artifacts
```

The DMG will be at `build/NewsDigest.dmg`. Double-click it, drag NewsDigest to Applications, done.

### Prerequisites

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later (install from App Store or [developer.apple.com](https://developer.apple.com/xcode/))

### Alternative: Build in Xcode

1. `open NewsDigest.xcodeproj`
2. Select the NewsDigest scheme, set destination to "My Mac"
3. ⌘R to build and run
4. To create a DMG: run `./scripts/create-dmg.sh build/NewsDigest.app` after building

## Features

- **24/7 Auto-Fetching** — Background scheduler fetches news every hour (configurable: 30 min to 6 hours)
- **Multiple Sources** — Hacker News top stories, 5 major RSS feeds (TechCrunch, Ars Technica, The Verge, MIT Tech Review, Wired), 5 top newsletters (Stratechery, Simon Willison, Astral Codex Ten, Lenny's Newsletter, The Pragmatic Engineer)
- **Topic-Based Curation** — Define topics with keywords; matching articles get boosted. Pre-seeded: AI/ML, Cloud Security, Apple/macOS, Startups/VC, Developer Tools
- **Smart Ranking** — Composite score from HN engagement, topic relevance, source quality, and recency
- **Audio Digests** — Generate top 10-20 article digests and listen via macOS text-to-speech with play/pause/stop
- **Markdown Reports** — Exportable reports with links, summaries, and metadata
- **Menu Bar Icon** — Quick access to top 5 stories without opening the full app
- **macOS Notifications** — Alerts when new articles arrive
- **Persistent Storage** — SwiftData keeps everything across launches
- **Bookmarks** — Save articles; bookmarked ones are protected from auto-cleanup

## Architecture

```
NewsDigest/
├── NewsDigestApp.swift          # App entry point, window + menu bar
├── Models/
│   ├── Topic.swift              # SwiftData model for topics
│   ├── Article.swift            # SwiftData model for articles + ranking
│   └── Digest.swift             # SwiftData model for digests
├── Services/
│   ├── HackerNewsService.swift  # HN Firebase API (async/await + TaskGroup)
│   ├── RSSService.swift         # RSS/Atom parser (zero dependencies)
│   ├── TopicMatcher.swift       # Keyword matching + ranking engine
│   ├── DigestGenerator.swift    # Audio script + markdown report builder
│   ├── SpeechService.swift      # AVSpeechSynthesizer wrapper
│   └── SchedulerService.swift   # Background timer scheduler
├── ViewModels/
│   └── NewsViewModel.swift      # State management + data coordination
├── Views/
│   ├── ContentView.swift        # NavigationSplitView + sidebar
│   ├── FeedView.swift           # Article list (search, filter, sort)
│   ├── TopicsView.swift         # Topic management (CRUD + toggle)
│   ├── DigestsView.swift        # Digest list + detail + audio player
│   ├── SettingsView.swift       # Scheduler, cleanup, source config
│   └── MenuBarView.swift        # Menu bar dropdown (top 5 stories)
├── scripts/
│   ├── build-dmg.sh             # Full build + DMG (standalone)
│   ├── create-dmg.sh            # DMG packager (from existing .app)
│   └── dmg-background.png       # DMG installer background
└── Makefile                     # One-command build system
```

## How It Works

### News Fetching
- **Hacker News**: Fetches top 60 story IDs, loads each in parallel via `TaskGroup`
- **RSS/Atom**: Custom lightweight XML parser — no third-party dependencies. Handles CDATA, HTML entities, and multiple date formats
- **Deduplication**: URL-based; re-fetching won't create duplicates

### Ranking Algorithm
Each article gets a composite score:
| Factor | Points |
|---|---|
| HN points | 1× |
| HN comments | 2× |
| Topic match | +50 |
| Newsletter source | +30 |
| Published < 6 hours ago | +20 |
| Published < 24 hours ago | +10 |

### Audio Narration
Uses macOS `AVSpeechSynthesizer` — no API keys needed. Generates a conversational script with story numbers, sources, engagement stats, and summaries.

### Background Scheduling
`Timer.scheduledTimer` fires at the configured interval. Each cycle fetches all sources, matches topics, deduplicates, and sends a notification if new articles are found.

## Customization

### Adding RSS/Substack Feeds
Edit `Services/RSSService.swift` → `defaultFeeds`:
```swift
FeedSource(name: "Your Feed", url: "https://example.com/feed/", type: .rss)
```

### Adding Topics
Use the Topics tab in the app, or edit `seedDefaultTopics()` in `ViewModels/NewsViewModel.swift`.

### Code Signing & Notarization
The `scripts/build-dmg.sh` script has commented-out sections for:
- Code signing with Developer ID
- Notarization via `notarytool` (required for distribution outside the App Store)

## Zero Dependencies

Pure Apple frameworks — SwiftUI, SwiftData, AVFoundation, UserNotifications, Foundation. No CocoaPods, no SPM packages, no API keys.
