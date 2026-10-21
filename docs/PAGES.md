# Inkora presentation website

The website uses Inkora's Ocean blue, amber and bundled Libre Baskerville.
It includes current phone/tablet demonstration screens and introduces the
independent [Komga Meta Manager](https://simon-verbois.github.io/komga-meta-manager/)
metadata companion. There are no runtime packages, analytics, remote fonts or
remote image requests. Screenshot enlargement is an optional native dialog;
content, language links and image links also work without JavaScript.

## Languages and editing

The site supports the same twelve languages as the app: English, French,
German, Spanish, Italian, Polish, Dutch, Portuguese (Portugal), Romanian, Greek,
Hungarian and Czech. English is at the root; the other languages have actual
`fr/index.html`, `de/index.html`, etc. files. Language selection follows ordinary
links, with no redirect, runtime translation request or server rewrite.

Edit `docs/site-template.html`, the matching 43-key dictionaries under
`docs/locales/`, `docs/styles.css` and `docs/site.js`. After changing the template
or copy, regenerate and check the committed pages:

```bash
python3 scripts/build_site.py --generate
python3 scripts/build_site.py --check
```

Do not edit generated `docs/index.html` or `docs/{locale}/index.html` directly.
Metadata and accessible labels are localized too; canonical/hreflang links use
`https://simon-verbois.github.io/inkora/`. Ordinary navigation and asset links
remain relative so the project prefix is preserved. Keep screenshots explicitly
identified as English if their language is unchanged.

## Preview locally

From the repository root, with Python 3.12 or later:

```bash
python3 scripts/build_site.py
python3 -m http.server 4173 --bind 127.0.0.1 --directory build/site
```

Open http://127.0.0.1:4173/fr/ for French, or the root for English. Use `--output`
with a fresh directory for subsequent builds; the builder preserves nonempty
destinations. It verifies committed generation, all twelve routes, local assets,
fragments and containment, rejecting root-relative paths. Its runtime artifact
contains twelve HTML pages, eight demonstration screenshots, CSS, JavaScript,
favicon, font/license and `.nojekyll`; translation/template sources are omitted.

## GitHub Pages setup

For **Deploy from a branch**, select the default branch and **/docs** in
**Settings → Pages → Build and deployment**. Every localized page and its assets
are already inside `docs/`, including `docs/fr/index.html`. Commit regenerated
pages together with their sources so branch publishing needs no custom builder.

Alternatively, select **GitHub Actions** and manually run **Inkora presentation
site** on the default branch. The workflow checks generation before building the
same twelve-language artifact. It does not repair stale source pages silently.
Choose one publishing source; the local builder never changes remote settings.

The public export allows only exact reviewed template/dictionary/page paths,
assets, this guide and the Pages workflow/builder. Internal documentation is
excluded. Both publishing modes retain the project prefix `/inkora/`, and direct
locale loads work without a fallback page. See GitHub's official
[publishing source guide](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)
and [custom workflow guide](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).

## Images and product claims

Screenshots are actual Flutter app screens with fictional books and original
sample artwork, rendered by the opt-in screenshot test. They show development;
published APKs may differ. Keep release links generic. Android is available;
native iOS validation remains pending. Never include personal server data or
credentials. Keep the bundled font/license identical to
`assets/fonts/LibreBaskerville.ttf` and `assets/fonts/OFL.txt`.
