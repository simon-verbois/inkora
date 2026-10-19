# Inkora presentation website

The site uses Inkora's Ocean blue, amber accents and bundled Libre Baskerville.
Its HTML, CSS and optional screenshot viewer have no runtime package dependencies,
analytics, external fonts or external image requests. Links work without JavaScript;
JavaScript adds a keyboard-accessible native screenshot dialog.

## Preview locally

From the repository root, with Python 3:

```bash
python3 scripts/build_site.py
python3 -m http.server 4173 --bind 127.0.0.1 --directory build/site
```

Open http://127.0.0.1:4173. Choose a fresh directory with `--output` for a new
build; the builder refuses to overwrite a nonempty destination. Only four site
source files, six demonstration screenshots and the licensed bundled font are
copied. Relative paths also work under a GitHub project prefix such as `/inkora/`.
The build checks local HTML assets and section links.

## GitHub Pages setup

The website entry point is `docs/index.html`; all required assets are inside
`docs/`, so the public GitHub repository can publish directly from that folder.
In **Settings → Pages → Build and deployment**, select **Deploy from a branch**,
then the default branch and **/docs**. Save to start GitHub's Pages deployment.
The public export contains only reviewed website files and demonstration images;
internal project documentation is excluded.

Alternatively, select **GitHub Actions** and manually run **Inkora presentation
site** on the default branch. That workflow builds the same reviewed static
artifact. Choose one publishing source; no remote Pages configuration is changed
by the local builder or release script.

See GitHub's official
[publishing source documentation](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)
and [custom workflow documentation](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).

## Content and maintenance

Update source files in this directory and the shared images in `docs/screenshots/`;
do not edit build output. The screenshots are actual Flutter app screens with
fictional catalogue data and original sample artwork, rendered by the repository's
opt-in screenshot test. They represent development, which may be ahead of releases.
Keep release links generic unless a version has been verified published. Android
is tested; iOS native validation remains pending. Do not add personal server data,
credentials or private documentation to the site. Keep `docs/fonts/LibreBaskerville.ttf` and `docs/font-license.txt` identical to
the canonical `assets/fonts/LibreBaskerville.ttf` and `assets/fonts/OFL.txt`.
