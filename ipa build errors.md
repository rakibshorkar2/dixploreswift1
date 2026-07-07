# IPA Build Errors - Fixes Applied

## Fixes Applied

### 1. DownloadManager.swift - Swift 6 Concurrency
- **Issue**: `nonisolated` URLSession delegate methods accessed `@MainActor`-isolated properties (`taskIdMap`, `progressMap`, `resumeDataMap`, etc.) outside of `Task { @MainActor }`
- **Fix**: Wrapped all delegate method bodies in `Task { @MainActor }` so property accesses happen on the correct actor

### 2. HtmlParser.swift - Actor non-Sendable Property
- **Issue**: `actor HtmlParser` had a stored `DateFormatter` property which is not `Sendable`
- **Fix**: Removed the unused `dateFormatter` property (it was declared but never referenced)

### 3. ProxyManager.swift - @preconcurrency Import
- **Issue**: `import Yams` without `@preconcurrency` causes strict concurrency warnings/errors since Yams is not annotated for Swift 6
- **Fix**: Changed to `@preconcurrency import Yams`

### 4. AppTheme.swift - @MainActor on @Observable
- **Issue**: `@Observable` class `AppTheme` was not marked `@MainActor`, causing concurrency violations since `Color` is not `Sendable`
- **Fix**: Added `@MainActor` annotation

### 5. WidgetExtension - Missing Shared Model
- **Issue**: `WidgetExtension` target references `DownloadActivityAttributes` (defined in `Models/DownloadActivityAttributes.swift`) but that file was only compiled in the main app target, not the widget extension
- **Fix**: Added `Models/DownloadActivityAttributes.swift` to the WidgetExtension target's sources in both the CI workflow (`build-unsigned-ipa.yml`) and local setup script (`setup.sh`)
