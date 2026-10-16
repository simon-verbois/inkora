# Changelog

Changes are recorded in English. `## [Unreleased]` is the release placeholder:
add notes there as changes are made. The release script replaces it with the
new tag and date, then opens a new empty Unreleased section.

The entries under Development history describe implemented development
milestones, not published releases. Platform and reader performance acceptance
remain in progress.

## [Unreleased]

## [2026.42.2] - 2026-10-16

- Place the completed-series badge beside the book count and remove other header badges.
- Include the target volume title in the series Start/Continue reading button and remove the separate subtitle.
- Hide the catalogue search button on series detail pages.
- Keep the synopsis visible when collapsing a series description, without jumping down to the volumes.

- Center a single login wordmark and simplify its Komga-server introduction.

- Add precise local ebook bookmarks from long-pressed text, with excerpts and visible underlines.
- Default unconfigured ebooks to sepia and add manually selected reading styles, more paper colors and Libre Baskerville.

- Add customizable download-quota and interface-size sliders, and a clearer guided-setup completion screen.
- Add metadata-based catalogue and offline-shelf filters; keep grid/list switching in the shared toolbar and tighten library-selector spacing.
- Show download progress and pause/resume/cancel controls directly on Downloads, replacing the separate queue page.
- Add EPUB margin presets with space above and below the text, and remove the redundant ebook panel from About.

## [2026.42.1] - 2026-10-15

### Added

- Publish signed Android APKs, release notes and SHA-256 checksums as GitHub Release assets.
- Reuse the existing Forgejo GITHUBPAT_TOKEN convention for GitHub publication, with default repository and public author settings.
- Keep local Android distribution keys and prepared CI secrets outside version control.
- Connect to multiple Komga servers using API keys or username/password authentication, with secure account sessions.
- Browse and search libraries, series, books, collections and reading lists using a local-first catalogue.
- Read manga, comics and webtoons with fullscreen controls, reading profiles, page layouts and adaptive preloading.
- Read EPUB and PDF books with document navigation, text search, local bookmarks and adjustable EPUB typography.
- Download books for offline reading, manage storage and transfer queues, and synchronize reading progress with Komga.
- Configure appearance, accessibility, reading gestures and library defaults through guided setup and searchable settings in twelve languages.
- Choose which accessible libraries appear for each server account; all accessible libraries are shown by default.
- Prepare a tag-only Forgejo release pipeline and package version information and this changelog for offline access from About.
- Prepare a clean GitHub source mirror with independent public history, an English project overview and reproducible app screenshots using demonstration content.

### Changed

- Reuse one release workspace and cached SDKs/dependencies, with Android setup after a single host quality pass and mode-specific native preparation.
- Present ebooks as individual books alongside comic series throughout Home, browsing and downloads.
- Open every Continue reading card directly in its selected book and restore Home when leaving the reader.
- Separate reading preferences into responsive, format-aware controls and offer per-format image quality settings.
- Keep F-Droid publication disabled while release preparation continues.

### Fixed

- Admit ordinary background transfers when a borrowed stream starts first, preserving foreground priority and byte limits.
- Regenerate native plugin registration for release after host tests, avoiding integration_test Java compilation failures.
- Verify recovered downloads independently of concurrent page completion order.
- Read Android signing values from Forgejo variables or secrets and validate distribution configuration before SDK setup.
- Start decoding prepared webtoon strips during fast scrolling and use available memory for the requested preparation distance.
- Release the image handle used to observe reader decode readiness.
- Preserve the intended catalogue history when Android predictive back leaves the reader.
- Keep settings transitions and shared surfaces consistent across appearance palettes.
- Allow EPUB/PDF entry routes and available books with no raster page count to open the appropriate reader.

## [Development history]

### 2026-10-15

- Integrated Readium EPUB and PDFium-based PDF reading with the existing download, settings and progress boundaries.
- Added individual ebook presentation, direct Continue reading entry, responsive reader settings tabs and library visibility selection.
- Verified the available Android functional scenarios; iOS native validation and full physical performance acceptance remain open.

### 2026-10-14

- Added guided setup, searchable settings, twelve-language UI support and the maintained translation workflow.
- Refined reading gestures, appearance palettes, format-specific image controls and settings navigation.
- Fixed Android predictive-back history handling, including covered and inactive routes.

### 2026-10-13

- Added coordinated discovery shelves and responsive tablet navigation and volume layouts.
- Improved catalogue scrolling, cache/work scheduling and database watcher behavior.
- Removed the experimental favorites feature and preserved existing account data during migration.

### 2026-10-12

- Recorded the initial Komga reader and offline foundation in Git, including catalogue browsing, raster readers, resumable downloads and durable progress synchronization.
- Added Home reading shelves, descriptive catalogue metadata and account-owned reading defaults.
- Established repository setup, architecture documentation and repeatable quality checks.
