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

Prepared here; no deployment is performed by building or pushing the source.
In the **public GitHub repository**, open **Settings → Pages → Build and deployment**
and select **GitHub Actions**. Then run **Actions → Inkora presentation site → Run
workflow** on the default branch. The workflow is manual only, builds the reviewed
assets and deploys through the `github-pages` environment. Branch protection and
environment approval rules can be configured in GitHub. A successful workflow
reports the actual public URL; no URL is claimed live in this repository.

GitHub's branch-based source supports only the repository root or `/docs`.
A custom Actions workflow supports our dedicated `site/` source, so internal
project documentation never becomes a website artifact. See the official
[publishing source documentation](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)
and [custom workflow documentation](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).

## Content and maintenance

Update source files in this directory and the shared images in `docs/screenshots/`;
do not edit build output. The screenshots are actual Flutter app screens with
fictional catalogue data and original sample artwork, rendered by the repository's
opt-in screenshot test. They represent development, which may be ahead of releases.
Keep release links generic unless a version has been verified published. Android
is tested; iOS native validation remains pending. Do not add personal server data,
credentials or private documentation to the site. Font license is copied into the
site from `assets/fonts/OFL.txt`.
