#!/usr/bin/env python3
"""Build the public Inkora presentation site using only reviewed static inputs."""
import argparse
from pathlib import Path
import shutil
from html.parser import HTMLParser
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent
SCREENSHOTS = (
    'phone-home', 'phone-library', 'phone-appearance', 'tablet-home',
    'phone-batch-download', 'phone-transfer',
)


class Links(HTMLParser):
    """Collect local build references without adding an HTML dependency."""

    def __init__(self) -> None:
        super().__init__()
        self.targets = []
        self.ids = set()

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        self.ids.add(attrs.get('id', ''))
        self.targets.extend(attrs[key] for key in ('src', 'href') if key in attrs)


def build(destination: Path) -> None:
    destination = destination.resolve()
    # Never delete a caller-supplied directory or copy the complete repository.
    if destination.exists() and any(destination.iterdir()):
        raise ValueError('Destination must be empty; choose a fresh build directory.')
    if destination == ROOT or destination in ROOT.parents:
        raise ValueError('Destination cannot contain the source repository.')
    destination.mkdir(parents=True, exist_ok=True)
    for name in ('index.html', 'styles.css', 'site.js', 'favicon.svg'):
        shutil.copyfile(ROOT / 'site' / name, destination / name)
    (destination / 'images').mkdir()
    for name in SCREENSHOTS:
        shutil.copyfile(ROOT / 'docs/screenshots' / f'{name}.png', destination / 'images' / f'{name}.png')
    (destination / 'fonts').mkdir()
    shutil.copyfile(ROOT / 'assets/fonts/LibreBaskerville.ttf', destination / 'fonts/LibreBaskerville.ttf')
    shutil.copyfile(ROOT / 'assets/fonts/OFL.txt', destination / 'font-license.txt')
    (destination / '.nojekyll').touch()
    links = Links()
    links.feed((destination / 'index.html').read_text())
    for target in links.targets:
        parsed = urlsplit(target)
        if parsed.scheme or parsed.netloc:
            continue
        if parsed.path and not (destination / unquote(parsed.path)).is_file():
            raise ValueError(f'Missing site asset: {target}')
        if parsed.fragment and parsed.fragment not in links.ids:
            raise ValueError(f'Missing page section: {target}')
    print(f'Built and checked {len(list(destination.rglob("*")))} public entries in {destination}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'build/site')
    args = parser.parse_args()
    build(args.output)
