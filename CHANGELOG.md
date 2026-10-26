# Changelog

Changes are recorded in English. `## [Unreleased]` is the release placeholder:
add notes there as changes are made. The release script replaces it with the
new tag and date, then opens a new empty Unreleased section.

The entries under Development history describe implemented development
milestones, not published releases. Platform and reader performance acceptance
remain in progress.

## [Unreleased]

## [2026.44.1] - 2026-10-26

- Simplify ebook backgrounds to White, subtle textured Paper, Sepia, Gray, Night and Black; preserve older saved colors through compatible aliases.
- Fade the moving EPUB divider at its top and bottom.
- Align the EPUB layout divider switch with the form’s right edge and keep template font samples on one line at large text.

- Default ebooks to publisher fonts and styles, refine six reading templates and keep the font menu compact.
- Make the subtle EPUB divider adapt to the paper color and move with sliding pages; align native publication bounds to physical pixels.

- Fit reader preference panels to their contents and align document switches; remove the automatic-saving caption.
- Organize EPUB preferences into Appearance, Page layout, Navigation and Templates, with a compact scope selector beside More and separate tab resets.

- Bound each development Android emulator to 2 GiB guest RAM, 5 GiB host RAM and 1 GiB swap in a separate systemd scope.

- Expand EPUB fonts with five bundled families and a font-preview dropdown, rename reading styles to Templates and keep text size at 100% without a zoom slider.
- Draw the EPUB page divider only at the center of a two-page view, keeping the outer edges clear.

- Lower the wide Home toolbar's side controls toward the covers while detached, retaining their raised position when attached to the header.

- Fit the narrow Home quick-filter button to its content, aligned left with the tools menu at the right edge of the toolbar.

- Add the official Buy Me a Coffee support button to the website introduction, README opening and app About page.

- Add Mark read and Mark unread to Continue reading cover menus, targeting the exact saved book and synchronizing changes when connected.

- Support explicitly entered HTTP server addresses alongside HTTPS for authentication, reading and downloads.
- Recover saved connections when their secure account index is missing or malformed.
- Wake offline synchronization from pending work and retry deadlines, stopping periodic work when queues are idle.

- Stabilize manga page pairing across merged double-page scans; add automatic and forced alignment choices with remembered per-volume analysis and manual priority.

- Adapt Home quick filters to narrow windows with a current-status selector and a Downloaded option, keeping all choices accessible at large text sizes.

- Align Home toolbar backgrounds and outlines around their controls, remove the dark join seam and keep the extensions rigid when pulling beyond the list boundaries.

- Disable tap-to-turn by default in the Android EPUB reader; add an optional layout setting while retaining swipe navigation.

- Return directly to Home from tablet settings categories and keep sidebar selection backgrounds stable during back gestures.

- Continue directly into the next available series volume when turning beyond the final comic or manga page, including single pages, spreads and all reading directions.

## [2026.43.7] - 2026-10-23

- Strengthen public release checks to exclude private AI configuration, editor settings and agent instructions before GitHub publication, including checks of prepared files and public history.

## [2026.43.6] - 2026-10-23

- Refresh the twelve-language presentation website and README with thirteen current phone/tablet demonstration captures and expanded feature coverage.
- Match sort menus to the library selector, opening below the button with a checked choice and no full-row selected background.

- Fit the lateral Home toolbar backgrounds to 36 dp with no outer vertical padding and align them at the header edge, more clearly mute completed covers, hide the current-volume jump in ebook author pages and float selection controls over unchanged detail panes.
- Add spacing below the saved-server heading.

- Fade Home toolbar attachments into a continuous header outline, inset their side groups, add adaptive side margins and preserve scroll when quick filters change.
- Add Mint and Lavender light themes, page-specific confirmed resets and a full-width Settings search field that covers Back while active.
- Use one image scaling/filter choice for all formats and place upscaling controls directly in Rendering.
- Group saved-server editing, library selection and removal on each server row; show only enabled libraries in reading-profile overrides.

- Give pinned Home tools three rounded extensions joined to the header, keep their background hidden before attachment and let Home covers use the full available width.

- Arrange metadata website buttons in rows of three, remove the tablet detail overscroll indicator and align reader page/progress labels and action buttons.

- Open metadata websites from their names with confirmation before leaving the app.
- Replace the large selection panel with a compact action row, add reader sheet drag handles and position More menus above their buttons.
- Fade truncated synopsis text progressively across its last three lines, soften covers behind the Home header and attach its evenly padded tools directly below it.

- Remove the contrasting ebook metadata panel so synopsis and publication facts share the cover background.

- Keep the current reader beneath Series and Author details so Back resumes the same position.
- Enlarge ebook covers on wide detail pages, move titles and reading actions above the right-hand description, and slightly widen series information panes.
- Bottom-align and lower wide Home tools closer to covers, and remove the reader slider/action separator.

- Focus ebook information in the left series pane on the first tap; read the focused book on the next tap or through its orange action.

- Give ebook details the same softened cover background as series, remove format pills, and label ebook reader catalogue shortcuts Author.
- Reduce the gap above Home covers on landscape tablets and bring reader action labels closer to their icons.

- Keep mobile Home filters on one row with library, sort and view submenus; lower wide side controls and let covers scroll behind the header.
- Add individual ebook detail pages with explicit reading and download actions, and hide metadata tags by default with an Appearance switch.
- Apply shared translucency to reader controls; show current-book details in an overlay and provide a separate Series button.
- Align series quick filters to the left, remove the detail header scroll rule and tighten the reading-status dialog.

- Simplify the portrait Home library selector and move header actions into a menu when space is limited; align portrait series and mobile download quick filters to the left.
- Show more of series descriptions in portrait and label reading buttons with Start or Resume followed by the book title.
- Add whole-series or unread/in-progress download choices and an optional per-series rule to remove finished local copies after at least 24 hours, at a later launch or foreground return, while retaining reading progress and open books.
- Use centered choice dialogs outside the reader and add a direct Mark read action to volume rows, with confirmation for books already in progress.
- Keep Android pages stationary during predictive Back gestures while preserving cancellation and navigation ownership.

## [2026.43.5] - 2026-10-21

- Add optional Fit content for Manga and Comics: detect embedded white margins progressively, fit the drawing area in single/double-page layouts, and preserve original files and reading positions.

- Keep page-pairing offset effective after double-width scans instead of returning to identical pairs with either offset state.

- Make rapid page-pairing offset toggles reliable, expose the offset in library reading defaults, and let each book override the manga default of keeping the first page alone.

- Keep series quick filters and view/sort/selection controls on one row, using a checked filter menu when the available width or text size cannot fit the chips.

- Center search text vertically and widen header search in landscape, hiding the other header actions in both orientations until search is closed while preserving input and focus during rotation.

## [2026.43.4] - 2026-10-21

- Redesign the GitHub Pages website in all twelve application languages, with static locale pages, project-relative navigation, current phone/tablet screenshots and a link to Komga Meta Manager.

- Replace global catalogue density with independent Home cover counts: 2/3/4 in portrait and 5/6/7 in landscape, selected by window orientation, including Continue reading; keep other views independently sized and preserve saved choices and backups.
- Fix framed header and modal-sheet opacity at 96% and remove the opacity setting.

- Extend the phone series artwork backdrop from the screen top behind the Back button through the reading actions up to the tabs, keep the content below on a uniform background, show only the book title in reading buttons, and limit series hero pills to the localized book count and publication status on every screen size.

## [2026.43.3] - 2026-10-21

- Give Settings, Downloads and History the same short horizontal fade when opened from Home, including the complete tablet settings menu, and preserve Home geometry during navigation.

- Keep series filters and volume controls pinned at the top of the tablet right pane, with jump-to-current positioned beneath them.

- Slim rounded buttons and quick filters to a shared 40 dp minimum surface, align neighboring controls, and retain 48 dp touch regions and text scaling.

- Lightly mute completed-volume covers and titles in series lists and grids while keeping their actions available.

- Make Home the primary page, replace bottom navigation with Settings and Downloads actions beside history in the header, and return to the retained catalogue with Back.

- Remove the tablet volume-pane heading and its divider, bringing filters and books closer to the top.

- Keep visible descriptions in place when Show less collapses them, including the tablet series pane.

- Remove the series progress panel above reading actions on every screen size, and extend tablet series artwork and the pane divider to the top edge.

- Use one column and larger covers in series volume lists; show book titles throughout browsing, history and reader controls, with a simpler Continue button.
- Hide removed catalogue entries by default after refresh, while retaining the optional unavailable-items filter and historical/offline references.

- Replace the library selector bottom sheet with a compact anchored choice menu.

- Move reading history into an icon-only Home header action beside search.

- Move catalogue and Downloads search into the top header and align quick controls to a shared 48 dp height.

- Give tablets the same logo header and centered floating bottom navigation as phones, with a compact 420 dp bar at normal text size.

- Center quick reading filters across the toolbar and display the localized label of each active filter beside its icon.

- Refine Android system-bar integration, replace browsing search with an animated keyboard-focused button, and use accessible reading-filter icons.
- Remove the Home Up next shelf, open reading history through its own action and reveal, and keep storage totals in settings rather than the downloaded-book list.
- Show published book titles in series lists, compact tablet series headers, and separate confirmed whole-series download and reading-status actions. Simplify reference links and publication details, with book/volume counts appropriate to the content.
- Simplify server/account and file-transfer pages; remove QR transfer and camera permissions/dependencies.
- Prepare EPUB spread margins before native pagination to avoid moving text on chapter entry.

- Keep the series selection Download action visible on phones by placing it full width below Mark read / Mark unread.

- Unify reading progress text: covers, Continue reading, series details, downloads and reader labels share one format such as "Vol. 01 · 92 %", "8 %", "Up next", "In progress", "Read" or "Unread", without raw file names.
- Replace the per-cover menu button with standard cover badges (volume, read, progress, offline, unavailable) and a long-press menu for reading, details and downloads; screen readers hear one combined description.
- Use one sheet, confirmation dialog and notification style across the app, including reader and ebook sheets, with danger-colored destructive confirmations.
- Show consistent empty and error states and static loading placeholders instead of full-screen spinners in catalogue, downloads and history.
- Introduce shared spacing, corner-radius, type and semantic color tokens with a contrast check across all appearances; buttons and chips become pill shaped.
- Give every screen a single header: the Inkora wordmark now appears only on Home, in a header that slides away once you scroll; sub-pages, settings sections, add server and setup share one header with Back and title.
- Give library, collection and reading-list details the same floating Back button as series details; scrolled content no longer slides under it, and the page title appears in a bar once you scroll.
- Use a navigation rail with the Inkora wordmark on windows at least 840 pixels wide, with the settings menu beside it; the floating bottom bar setting now applies to narrow windows only.
- Redesign series details: a blurred cover header with volume count, publication status and publisher, a segmented series progress bar, a "Continue · Vol. 03 · p. 11" button and a download button; phones show About and Volumes tabs, wide windows show About and volumes side by side.
- Show volumes as a list with thumbnails, reading state, progress and download state (two columns on wide windows), with an optional cover grid, All/Unread/In progress/Downloaded filters, reverse order and a jump to the current volume.
- Mark volumes read or unread, alone or by selection, and mark all previous volumes as read; changes appear immediately, work offline and sync to Komga, with confirmation for several volumes. Several volumes can also be downloaded from the selection.
- Genre chips on a series open the catalogue filtered by that genre.
- Give library, collection and reading-list details the series page layout with a Browse button and a cover grid of their series or books.
- Show one filter bar in libraries, Home and Downloads: a visible search field, scrollable All/Unread/In progress/Completed chips with a separate Downloaded chip, a sort button that names the active order (such as "A–Z") with the current choice checked, and a filters button with an active-filter count. Series volume filters use the same chips.
- Rebuild the filters sheet with chips for format, publication status, genres, tags, authors, publisher, language and age rating; long lists can be searched and expanded, and the button shows the number of matching results before applying.
- Add an Up next shelf on Home for the next unread volume of series you are reading, and a View all link from Continue reading to the reading history.
- Show a storage summary at the top of Downloads (space used of the quota, downloads, temporary reservations and page cache) with a link to download settings.
- Show the download queue on Downloads only while downloads are queued, running, paused or failed, with one progress ring, "Downloading · 40 %" style statuses, counts, pause, resume, retry and cancel; queued downloads use an hourglass instead of the history clock.
- List downloads by series ("3 volumes · 412 MiB · 1/3 read") and individual books by format and size; the cover grid stays available. Long press offers removal with confirmation, and downloaded volumes use the series volume rows.
- Reading history now combines books opened on this device with reading progress from Komga, grouped into Today, Yesterday, This week and Earlier, with progress and time; older server entries load on demand and remain available offline. Clear history only removes this device's entries and is disabled when there are none.
- Reader controls show the series title with the volume and page ("Vol. 01 · p. 169/184") at the top, the page and what is left ("p. 169", "92 % · 15 pages left") above the slider, and one row of actions: Pages (Contents in ebooks), Bookmarks, Settings and More. More holds Finish volume, Reading progress and Refresh book (Search in book for ebooks); the details button uses an info icon. Comic and ebook readers share the same loading and error screens.
- Reading settings apply as soon as you choose them, with no Save or Cancel: This book, Series, Library or Global at the top, chips for mode, direction, fit and page layout, colour swatches for the background and a spacing slider. Reset to default and Apply to all series and books ask for confirmation.
- Two pages side by side are now the default only in landscape windows and on tablets, including for manga; phones in portrait show one page unless you choose Two pages.
- Settings are grouped into Account, Reading, Application and Data, each page with its own icon, current value where useful (server, theme, language, gestures) and a title matching the menu. One search field finds settings and shows where they are, such as "Reading › Gestures".
- Make touch targets at least 48 dp (including the catalogue search field) and give icon-only controls a spoken label; the compact library selector and the reader page surface ("Reading controls") are now announced by screen readers.
- Respect reduced motion when switching series tabs and reading-settings tabs.
- On wide windows, the Global defaults reading page now shows its title and a Back button beside the settings menu.
- The series page no longer re-reads its volume progress for every page saved while the reader covers it; it refreshes once when you return.
- Remove the unused placeholder sheet, the former series batch-download sheet and stray technical entries from the translation catalogues and the repeated Import / export heading; refresh the public screenshots.

## [2026.43.2] - 2026-10-19

- Move the presentation website into docs with self-contained assets for GitHub Pages branch publishing.

## [2026.43.1] - 2026-10-19

- Keep ebook text stationary when showing reader controls and retain a central gutter between EPUB pages with custom margins.
- Move Guided setup into the About settings page.

- Hide tablet settings scrollbars, separate the menu from its page and expand search from its icon over the Settings heading, opening the keyboard immediately.

- Keep the Inkora wordmark in the tablet settings header and remove its section-title Back button.

- Move enlargement and sharpening controls to a dedicated Upscaling tab in Quality, including guided setup.
- Remove enclosing panel backgrounds from settings and download configuration.

- Remove incomplete QR code export; retain file backups and import of existing settings QR codes.

- Label navigation benchmark reports with their actual debug/profile runtime mode.

- Align reading history with Continue reading and combine library selection, quick filters and catalogue tools in one sticky row. Center wide-screen chips and use a quick-filter popup in compact windows.
- Keep the catalogue scroll position while changing sort order, including already loaded result windows.
- Remove global header search and its modal route; retain search within each catalogue.

- Remove the shared background frame behind guided setup Back/Next buttons.

- Refresh the public README, current product documentation and six reproducible demonstration screenshots.
- Add an Inkora-style static presentation website with accessible screenshot previews and a manual GitHub Pages workflow.
- Preserve Material label typography when emphasizing filled-button text.

- Add batch volume downloads, quick reading/offline filters and comic archive format filtering.
- Add manga/comic/webtoon bookmarks, a page overview, scrub previews, end-of-volume handoff and local reading history.
- Add account-safe settings/bookmark file backup and native scanning of existing portable settings QR codes.

- Make tablet settings continuation visible with a persistent scrollbar, compact category rows and a guided-setup action below the list.

- Choose separate default light and dark themes when following system appearance.
- Add Pearl, Rose, Midnight and Plum palettes and regroup compact theme previews for phones and tablets.

- Use a persistent category pane and compact headings for tablet-landscape settings; show setup steps beside the active page, with paired controls and fixed navigation actions.
- Preserve reading-setting drafts across resizing and refresh adaptive layouts when the system text size changes.

- Add phone/tablet ebook margin presets and independent custom edges in a dialog, with camera-safe text placement.
- Default image enhancement to Balanced and panel opacity to 94%; include reading Quality after library defaults in guided setup.
- Keep a floating Back button on series details and place synopsis and metadata below the cover/title area.

- Install Android debug/profile and local development test builds as a separate Inkora Dev app, preserving the installed distribution app and its data.

## [2026.42.4] - 2026-10-18

- Document reusable mobile usability, adaptive-layout, accessibility and performance review practices.

- Extend the reader's rounded-panel style to application headers, settings and guided setup, with optional floating navigation and adjustable overlay opacity.
- Open live catalogue search in a keyboard-safe overlay, preserving the current screen when dismissed.
- Let reopened guided setup close directly to Settings while retaining saved choices.

- Replace the Home dashboard with the library cover grid and Continue reading carousel, with bottom navigation on phones and tablets.
- Unify quick tab fades, eased detail transitions and sheet motion while preserving reduced motion and Android predictive back.
- Add optional image sharpening for enlarged covers, comic pages and document images, with three strengths saved on the device.
- Keep the reader open when a Bluetooth keyboard connects, sleeps or disconnects on Android.
- Fix blocked navigation after leaving a direct-entry reader for its series page.
- Start catalogue loading earlier during setup and keep library defaults pending until the first refresh completes, with retry after failure.

## [2026.42.3] - 2026-10-17

- Refresh reader controls with compact floating panels, direct reading actions and ebook progress seeking.
- Add reader shortcuts to the current series or saved book details, optional page-turn animation and an EPUB center divider.

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
