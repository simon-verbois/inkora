#!/usr/bin/env python3
"""Check store assets and synchronize release-derived F-Droid metadata offline."""

import argparse
import json
from pathlib import Path
import re
import struct

from release_metadata import release_notes, version_code


ROOT = Path(__file__).resolve().parent.parent
RECIPE = Path('fdroid/metadata/dev.inkora.inkora.yml')


def generated_files(root: Path, version: str, changelog: str) -> dict[Path, str]:
    """Derive only the current version; retain earlier store release notes."""
    code = version_code(version)
    notes = release_notes(changelog, version)
    notes = ' '.join(line.removeprefix('- ').strip() for line in notes.splitlines()
                     if line.strip() and not line.startswith('#'))
    if len(notes) > 500:
        notes = notes[:499].rsplit(' ', 1)[0] + '…'
    recipe = (root / RECIPE).read_text()
    if recipe.count('export INKORA_PUB_CACHE=$PWD/.fdroid-pub-cache') != 2:
        raise ValueError('Both recipe phases must retain the isolated Pub cache')
    replacements = {
        r'(?m)^(  - versionName: ).+$': version,
        r'(?m)^(    versionCode: ).+$': str(code),
        r'(?m)^(    commit: ).+$': version,
        r'(?m)^(CurrentVersion: ).+$': version,
        r'(?m)^(CurrentVersionCode: ).+$': str(code),
    }
    for pattern, value in replacements.items():
        recipe, count = re.subn(pattern, lambda match: match[1] + value, recipe)
        if count != 1:
            raise ValueError('Expected one reviewed F-Droid build block')
    return {
        Path('fdroid/version.properties'): f'versionName={version}\nversionCode={code}\n',
        Path(f'fastlane/metadata/android/en-US/changelogs/{code}.txt'): notes + '\n',
        RECIPE: recipe,
    }


def check(root: Path) -> None:
    """Reject stale versions, missing licensing and malformed public store inputs."""
    license_text = (root / 'LICENSE').read_text()
    if not license_text.startswith('MIT License\n') or 'Copyright (c) 2026 Inkora contributors' not in license_text:
        raise ValueError('The user-selected MIT project license is missing')
    version = (root / 'VERSION').read_text().strip()
    expected = generated_files(root, version, (root / 'CHANGELOG.md').read_text())
    for path, content in expected.items():
        if not (root / path).is_file() or (root / path).read_text() != content:
            raise ValueError(f'Stale F-Droid release metadata: {path}; run sync')
    base = root / 'fastlane/metadata/android'
    for locale in ('en-US', 'fr-FR'):
        for name, maximum in [('title', 50), ('short_description', 80), ('full_description', 4000)]:
            text = (base / locale / f'{name}.txt').read_text().strip()
            if not text or len(text) > maximum:
                raise ValueError(f'Invalid store field length: {locale}/{name}')
    image_root = base / 'en-US/images'
    images = [image_root / 'icon.png', *sorted((image_root / 'phoneScreenshots').glob('*.png'))]
    if len(images) < 3:
        raise ValueError('An icon and two phone screenshots are required')
    for path in images:
        with path.open('rb') as stream:
            header = stream.read(24)
        if len(header) != 24 or header[:8] != b'\x89PNG\r\n\x1a\n':
            raise ValueError(f'Invalid PNG store image: {path.name}')
        width, height = struct.unpack('>II', header[16:24])
        if not (48 <= width <= 8192 and 48 <= height <= 8192):
            raise ValueError(f'Invalid PNG dimensions: {path.name}')
    native = json.loads((root / 'fdroid/native-sources.json').read_text())
    toolchain = json.loads((root / 'toolchain.lock.json').read_text())
    if native['flutter']['version'] != toolchain['flutter']['version']:
        raise ValueError('F-Droid and project Flutter versions differ')
    recipe = (root / RECIPE).read_text()
    for revision in (native['flutter']['revision'], native['pdfium']['builderRevision']):
        if revision not in recipe:
            raise ValueError('Recipe source-library revisions are stale')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['check', 'sync'])
    args = parser.parse_args()
    if args.command == 'sync':
        version = (ROOT / 'VERSION').read_text().strip()
        files = generated_files(ROOT, version, (ROOT / 'CHANGELOG.md').read_text())
        for path, content in files.items():
            destination = ROOT / path
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(content)
    check(ROOT)
    print('F-Droid license, localized store assets, versions and source pins are current.')


if __name__ == '__main__':
    main()
