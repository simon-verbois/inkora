# F-Droid packaging

Inkora is licensed under [MIT](../LICENSE). Store copy is under
`fastlane/metadata/android/`, with English fallback and French descriptions.
The screenshots reuse the original fictional catalogue from `docs/screenshots/`;
their visible interface is English. The listing icon is a PNG rendering of the
existing website favicon (`docs/favicon.svg`), rather than the provisional
Flutter launcher image. It does not replace launcher artwork. Third-party notices remain in
[NOTICE](../NOTICE) and the bundled attribution files.

## Current status

The recipe in `metadata/dev.inkora.inkora.yml` is a **submission candidate**, not
an accepted F-Droid listing. The source includes the MIT license and required
packaging files; the earlier 2026.44.2 tag predates those additions. Its build stays
disabled until the complete recipe passes in F-Droid's isolated environment and
its dependency provenance is reviewed. Use the newly tagged source release for
that verification. Do not remove the review gate merely because local builds
and scanners succeed.

The repository's existing personal-repository uploader is a separate binary
distribution path and remains disabled. Adding these files does not submit to
F-Droid or activate any repository or publication service.

## Store and version maintenance

```bash
python3 scripts/fdroid_metadata.py check
python3 scripts/fdroid_metadata.py sync
```

`sync` derives `version.properties`, the candidate recipe version/tag and the
current English changelog from VERSION and the dated CHANGELOG section. It keeps
the recipe's disable field and previous changelog files. Notes are bounded to
500 characters. The release metadata preparation command also updates these
files; the release wrapper stages them with VERSION/CHANGELOG. No release is
created by the commands above.

French listing prose reuses the already localized website copy. It falls back to
the English release notes and English screenshots. Fastlane itself is not a build
dependency. Edit descriptions for product changes and validate their lengths;
keep fictional covers and capture provenance when replacing images.

## Unsigned release output

```bash
scripts/build.sh apk --release --unsigned --target-platform=android-arm64
```

The flag produces the normal `dev.inkora.inkora` identity without a signing
configuration. It requires release APK mode and rejects development/test targets,
bundles, signing-required mode and signing credential environment variables.
Normal development and signed distribution builds retain their existing behavior.
Unsigned APKs are packaging artifacts; do not install them as development tests.
All test installations continue to use Inkora Dev.

This command alone is not proof of a source-only F-Droid build: without the recipe
preparation, the normal PDFium dependency can still download its upstream binary.

## Native dependency strategy

The pinned `pdfium_dart` build hook normally downloads PDFium from GitHub.
F-Droid's candidate instead builds that same PDFium version from source, keeping
PDF reading available. `native-sources.json` records the exact Flutter, PDFium,
source-builder and depot_tools revisions, plus reviewed input hashes.

The SQLite Dart hook also normally downloads a shared library. Preparation
downloads the official SQLite 3.53.4 amalgamation instead, verifies the archive
and each C/header checksum, and selects the package's documented `source` mode
in the disposable project's pubspec. It retains the package's default compiler
options and SQLite version, including FTS5/JSON functionality, rather than using
an older system SQLite. The normal project pubspec/lock remain unchanged.

The recipe retrieves Flutter and pdfium-binaries through F-Droid's existing
source-library definitions. In its disposable checkout, `prepare.py`:

1. Verifies the package hook hash, builder revision and affected builder files.
2. Replaces the hook's remote archive download with the fixed source-library
   directory in that disposable build hook. Native hooks sanitize environment
   variables, so this path is embedded at preparation time. Missing archives fail;
   there is no download fallback.
3. Pins PDFium source and depot_tools revisions, bootstraps tools without updating
   that revision, leaves OS package installation
   to the isolated builder's declared setup phase, and caps Ninja at four jobs
   (`INKORA_PDFIUM_JOBS` can lower it).
4. Omits the upstream cross-platform example runner, which would download another
   NDK, and removes only PDFium's compiled-hook and generated-asset caches so old binaries cannot
   satisfy the rebuilt dependency accidentally.

The prepared source driver also enables strict pipeline handling and replaces
conditional `&& source` stage calls with explicit `if` bodies. This keeps shell
error handling active inside the build stages: a failed compiler stops the build
before packaging, rather than returning a successful header-only archive.

Preparation modifies only the disposable project, package cache and source-library checkout.
It fails on changed inputs rather than applying a guessed patch. Use a fresh
checkout/cache for each preparation. The ordinary package lock and normal build
hook remain unchanged. The recipe compiles arm, arm64 and x64 archives and passes
their prepared directory to the unsigned APK build through that local-only hook.

Readium and its PDFium adapter also carry native dependencies through Maven; the
complete resolved dependency graph still needs the F-Droid scanner/provenance
review. The presence of Maven Central/JitPack or a license notice alone does not
establish acceptance. No scanner ignore rule is used to hide an application
native binary. `scandelete` covers unrelated binary/example files in the disposable
Pub cache, following existing Flutter recipes.

The SQLite source URL/checksums and matching Dart package version are recorded
beside the PDFium pins. Its source files are generated under
`.fdroid-native/sqlite/` within that disposable checkout.

For Android development tests built from an exported checkout, set
`INKORA_ANDROID_USER_HOME` to the original workspace's `.tooling/android-user`
before building. Otherwise Gradle may generate a different debug signing key.
Check the Dev APK and use the guarded runner with one explicit `-d SERIAL`.
Prebuilt runs first attempt an `adb install -t -r`; a failed retained-data install
aborts before Flutter can perform its uninstall/retry fallback. Keep unsigned
distribution artifacts away from runtime development tests.

## Submission and signatures

After a new licensed source tag and successful clean source build, copy the
candidate to `metadata/dev.inkora.inkora.yml` in an fdroiddata checkout. Run
`fdroid rewritemeta`, `fdroid lint`, `fdroid scanner --force` and
`fdroid build --force` there;
review scanner removals and exercise EPUB/PDF with the resulting native library.
Then remove the per-build disable reason and submit the reviewed metadata change.
Automatic update mode is initially None; maintainers can enable Version mode
after verifying the tag/`version.properties` contract.

The default F-Droid signing route uses its own app key. Sharing the GitHub release
signature instead requires an APK reproducibility check plus the reference
binary URL and allowed signing-certificate fingerprint in metadata. No private
signing key belongs in this repository. Those fields are intentionally absent
until byte-for-byte reproducibility has actually been established.

Official references:

- [Inclusion policy](https://f-droid.org/docs/Inclusion_Policy/)
- [Submission guide](https://f-droid.org/docs/Submitting_to_F-Droid_Quick_Start_Guide/)
- [Metadata reference](https://f-droid.org/docs/Build_Metadata_Reference/)
- [Store assets](https://f-droid.org/docs/All_About_Descriptions_Graphics_and_Screenshots/)
- [Reproducible signatures](https://f-droid.org/docs/Reproducible_Builds/)
- [Existing PDFium source-build recipe](https://gitlab.com/fdroid/fdroiddata/-/blob/master/metadata/dev.linwood.butterfly.yml)
