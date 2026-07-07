

You are a senior Apple software engineer, iOS architect, systems programmer, networking expert, download manager expert, filesystem expert, and UI/UX designer.

I have attached my existing project.

The existing application is:

**DirXplore v2.0.0**

It is currently built using:

* Flutter
* Dart
* Swift bridge
* Various Flutter plugins

I want to completely eliminate Flutter.

This is **NOT** a migration.

This is a **complete native rewrite**.

---

# Goal

Rebuild the entire application from scratch as a **100% native iOS application**.

The new project must contain:

* Swift 6
* SwiftUI
* Apple's Observation framework
* Swift Concurrency (async/await)
* Actors
* Structured Concurrency
* URLSession
* Network.framework
* AVFoundation
* WebKit
* CoreData or SwiftData
* BackgroundTasks
* FileProvider where useful
* UniformTypeIdentifiers
* Combine only if absolutely required

No Flutter.

No Dart.

No Platform Channels.

No Flutter plugins.

No dependency on the previous implementation except as a reference for behavior.

---

# Primary Objective

The native version MUST reproduce **EVERY EXISTING FEATURE** found inside the Flutter project.

Nothing may be omitted.

If the Flutter version has a feature—even if hidden or unfinished—it must be reimplemented natively.

The Flutter project is the functional specification.

The AI must inspect the entire source code and identify every feature.

---

# Functional Parity Requirements

The native app must preserve:

* all screens
* all workflows
* all navigation
* all settings
* all download functionality
* all crawler functionality
* all parsing logic
* all proxy functionality
* all torrent functionality
* all search functionality
* all bookmarks
* all history
* all favorites
* all themes
* all file handling
* all playback
* all resume logic
* all queue management
* all metadata
* all notifications
* all import/export capabilities
* every advanced option
* every hidden feature
* every developer feature
* every preference
* every optimization

Nothing should disappear.

---

# UI/UX

The UI should not resemble Flutter.

Redesign everything using native Apple design principles.

Use SwiftUI only.

The application should feel like a first-party Apple application.

Use:

* native navigation
* native animations
* native transitions
* native sheets
* native context menus
* swipe actions
* keyboard shortcuts
* drag & drop
* menus
* pointer interactions
* haptics
* SF Symbols
* Dynamic Type
* Dark Mode
* Light Mode

The UI should be smoother than the Flutter version.

---

# Architecture

Use Clean Architecture.

Example:

Presentation

↓

Domain

↓

Application

↓

Services

↓

Repositories

↓

Persistence

↓

Networking

↓

Utilities

Everything should be modular.

No God classes.

No singleton abuse.

Dependency Injection everywhere.

---

# Folder Structure

Example:

App/

Core/

Features/

Networking/

Downloader/

Crawler/

Parser/

Torrent/

Proxy/

Storage/

Models/

Services/

Utilities/

UI/

Resources/

Extensions/

System/

Tests/

---

# Supported iOS Version

Optimize for:

iPhone 15 Pro

Minimum iOS:

18+

Latest SDK

Latest Xcode

Latest Swift

---

# Performance

The native version should be significantly faster.

Requirements:

* minimal memory usage
* minimal CPU usage
* low battery consumption
* zero unnecessary allocations
* efficient caching
* lazy loading
* virtualized lists
* image caching
* parser optimization
* async pipelines
* actors for synchronization
* lock-free where possible

---

# Open Directory Browser

Reimplement every browsing capability.

Support:

Apache

Nginx

lighttpd

IIS

AutoIndex

Directory Listing

FTP

HTTP

HTTPS

Recursive browsing

Breadcrumbs

Sorting

Filtering

Searching

Preview

Navigation history

Fast rendering of directories containing tens of thousands of files.

---

# Deep Crawler

Implement an advanced crawler.

Requirements:

Recursive crawling

Background crawling

Cancellation

Pause

Resume

Retry

Maximum depth

Concurrent crawling

Duplicate detection

Loop prevention

Live progress

Queue visualization

---

# HTML Parser

Use native Swift parsing.

Support malformed HTML.

Recover gracefully.

Parse:

links

folders

icons

timestamps

sizes

metadata

---

# Download Manager

This is the heart of the application.

Implement an enterprise-grade download manager.

Support:

Pause

Resume

Retry

Cancel

Restart

Integrity verification

Concurrent downloads

Sequential downloads

Queue priorities

Bandwidth throttling

Speed calculation

ETA

Persistent queue

Crash recovery

Background downloads

Resume after reboot

Automatic retries

Checksum support

Duplicate detection

Large file support

Multi-GB downloads

Streaming downloads

Partial downloads

Disk space validation

---

# Torrent Engine

The Flutter version includes torrent functionality.

Reimplement it.

Use native Swift if practical.

If necessary, integrate:

C

C++

Objective-C

libtorrent

or another mature torrent engine.

Wrap it cleanly for Swift.

Maintain:

torrent adding

magnet links

tracker support

peer management

resume

pause

download priorities

seeding

metadata

piece verification

progress

---

# Proxy Manager

Rebuild proxy support.

Support:

HTTP Proxy

HTTPS Proxy

SOCKS4

SOCKS5

Authenticated proxies

Proxy profiles

Import/export

Quick switching

Validation

Connection testing

Persistent storage

---

# Media Support

Native playback.

Support:

video

audio

images

text

PDF

streaming

preview

Use AVFoundation where appropriate.

---

# Storage

Support:

Bookmarks

Favorites

Recent

History

Settings

Downloads database

Crawler database

Torrent database

Cache

Import

Export

Backup

Restore

---

# Background Execution

Downloads continue while backgrounded.

Crawler resumes correctly.

Notifications remain accurate.

Recover from termination whenever iOS permits.

---

# Networking

Use URLSession.

Network.framework.

Support:

HTTP

HTTPS

Redirects

Cookies

Compression

Chunked transfer

Authentication

Timeouts

Retries

Range requests

Caching

---

# Security

Use:

App Sandbox

Keychain

Secure storage

Certificate validation

Graceful TLS handling

No insecure coding.

---

# Native Integrations

Implement:

Share Sheet

Document Picker

Quick Look

Context Menus

File Import

File Export

Drag & Drop

Clipboard

Universal Links where useful

---

# Code Quality

Every file should contain:

clear documentation

MARK sections

small functions

SOLID principles

protocol-oriented design

testable code

---

# Testing

Include:

Unit Tests

Integration Tests

UI Tests

Performance Tests

Downloader Tests

Crawler Tests

Parser Tests

---

# Build Quality

No warnings.

No TODOs.

No placeholder code.

No mock implementations.

No "implement later".

Everything production quality.

---

# Migration Strategy

Analyze the Flutter project.

For every feature found:

1. Understand its behavior.
2. Design the native equivalent.
3. Implement it.
4. Verify parity.
5. Improve performance.

Do not blindly translate Dart.

Instead, redesign using native Apple APIs.

---

# Deliverables

Produce:

* Complete Xcode project
* Native Swift source code
* Native SwiftUI interface
* Native architecture
* Native downloader
* Native crawler
* Native parser
* Native torrent engine
* Native proxy engine
* Persistence layer
* Tests
* Documentation

---

# Implementation Rules

* Do not remove any existing functionality.
* Do not simplify features.
* Do not skip advanced options.
* Prefer native Apple frameworks over third-party libraries whenever possible.
* Only use Objective-C, C, or C++ where they provide clear advantages (for example, integrating libtorrent or other mature native libraries).
* If an existing Flutter feature is poorly designed, preserve its behavior while implementing it in a cleaner native architecture.
* Since this project is for **personal sideloading only** and **will not be submitted to the App Store**, prioritize functionality and performance over App Store compliance where appropriate, while still following good engineering and iOS security practices.

---

## Final Success Criteria

The finished application should feel like a professional, first-party iOS app rather than a Flutter port. Every feature from the current DirXplore project must be present, with equal or better functionality, improved performance, a fully native SwiftUI interface, and a clean, maintainable Swift architecture suitable for long-term development.
