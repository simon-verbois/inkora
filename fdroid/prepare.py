#!/usr/bin/env python3
"""Prepare pinned native sources inside a disposable F-Droid workspace."""

import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import shutil
import subprocess
import urllib.request
import zipfile


CONFIG = Path(__file__).with_name('native-sources.json')
MARKER = '// Inkora F-Droid: source-built archives only.'
NETWORK_BLOCK = '''  final archiveUri = Uri.parse(
    'https://github.com/bblanchon/pdfium-binaries/releases/download/'
    '$pdfiumRelease/pdfium-${target.archivePlatform}-${target.archiveArch}.tgz',
  );

  final response = await getWithRetries(archiveUri);
  if (response.statusCode != 200) {
    throw Exception(
      'Failed to download PDFium: HTTP ${response.statusCode} $archiveUri',
    );
  }
'''
LOCAL_BLOCK = '''  // Inkora F-Droid: source-built archives only.
  final directory = __ARCHIVE_DIRECTORY__;
  final archive = File(
    '$directory/pdfium-${target.archivePlatform}-${target.archiveArch}.tgz',
  );
  final archiveBytes = await archive.readAsBytes();
'''


def patch_hook(source: str, archive_directory: Path) -> str:
    """Fail on changed upstream code rather than leaving a network fallback."""
    if source.count(NETWORK_BLOCK) != 1:
        raise ValueError('Unexpected PDFium download hook; review the pinned version')
    # Native-asset hooks receive a sanitized environment. Embed the reviewed
    # source-library path in this disposable build hook, never in app code.
    literal = json.dumps(str(archive_directory.resolve())).replace('$', r'\$')
    result = source.replace(NETWORK_BLOCK, LOCAL_BLOCK.replace('__ARCHIVE_DIRECTORY__', literal))
    result = result.replace("import '../lib/src/proxy_http_client.dart';\n", '')
    result = result.replace('response.bodyBytes', 'archiveBytes')
    # Avoid shadowing the decoded Tar archive below the replacement block.
    result = result.replace('  final archive = File(', '  final archiveFile = File(')
    result = result.replace('await archive.readAsBytes()', 'await archiveFile.readAsBytes()')
    result = result.replace('$archiveUri', '${archiveFile.path}')
    if any(value in result for value in ('https://', 'getWithRetries', 'response.', 'archiveUri')):
        raise ValueError('PDFium hook still contains a remote download path')
    return result


def patch_driver(source: str) -> str:
    """Keep errexit active inside sourced build steps instead of an && list."""
    if not source.startswith('#!/bin/bash -eu\n'):
        raise ValueError('Unexpected PDFium driver header')
    result = source.replace('#!/bin/bash -eu\n', '#!/bin/bash\nset -euo pipefail\n', 1)
    result, count = re.subn(
        r'(?m)^\[ \$START_STEP -le ([0-9]+) \] && \. (steps/[0-9]{2}-[a-z-]+\.sh)$',
        lambda match: f'if [ $START_STEP -le {match[1]} ]; then\n  . {match[2]}\nfi',
        result,
    )
    if count != 11:
        raise ValueError('Unexpected PDFium driver stages')
    return result


def install_sqlite(project: Path, config: dict, archive_bytes: bytes) -> None:
    """Use the package's documented source compiler with the same SQLite version."""
    sqlite = config['sqlite']
    if len(archive_bytes) > 8 * 1024 * 1024 or hashlib.sha256(archive_bytes).hexdigest() != sqlite['sha256']:
        raise ValueError('SQLite source archive does not match the pinned checksum')
    pubspec = project / 'pubspec.yaml'
    lock = (project / 'pubspec.lock').read_text()
    package = re.search(r'(?ms)^  sqlite3:\n(.*?)(?=^  \S|\Z)', lock)
    if not package or f'    version: "{sqlite["dartVersion"]}"' not in package[1]:
        raise ValueError('SQLite package version differs from the reviewed native configuration')
    if pubspec.is_symlink():
        raise ValueError('Refusing a linked pubspec')
    original = pubspec.read_text()
    if re.search(r'^hooks:', original, re.M):
        raise ValueError('Existing native hook configuration requires review; use a fresh checkout')
    files = {}
    with zipfile.ZipFile(io.BytesIO(archive_bytes)) as archive:
        for name, expected in sqlite['files'].items():
            if name not in {'sqlite3.c', 'sqlite3.h', 'sqlite3ext.h'}:
                raise ValueError('Unexpected SQLite source member')
            member = archive.getinfo(f'{sqlite["archiveRoot"]}/{name}')
            if member.file_size > 32 * 1024 * 1024:
                raise ValueError('SQLite source member exceeds bound')
            data = archive.read(member)
            if hashlib.sha256(data).hexdigest() != expected:
                raise ValueError('SQLite source member checksum mismatch')
            files[name] = data
    destination = project / '.fdroid-native/sqlite'
    if any(path.is_symlink() for path in (destination, *destination.parents)
           if path.is_relative_to(project)):
        raise ValueError('Refusing a linked SQLite source directory')
    if any((destination / name).is_symlink() for name in files):
        raise ValueError('Refusing a linked SQLite source file')
    destination.mkdir(parents=True, exist_ok=True)
    for name, data in files.items():
        target = destination / name
        target.write_bytes(data)
    pubspec.write_text(original.rstrip() + '''

# F-Droid-only source build; retain sqlite3 package default feature options.
hooks:
  user_defines:
    sqlite3:
      source: source
      path: .fdroid-native/sqlite/sqlite3.c
''')


def prepare(project: Path, pub_cache: Path, builder: Path, config: dict) -> None:
    """Patch only reviewed package/builder files, retaining normal build inputs."""
    version = config['pdfiumDart']['version']
    hook = pub_cache / 'hosted/pub.dev' / f'pdfium_dart-{version}/hook/build.dart'
    if hook.is_symlink() or not hook.is_file():
        raise ValueError('Missing regular pinned PDFium Dart hook')
    original = hook.read_bytes()
    hook_digest = hashlib.sha256(original).hexdigest()
    if hook_digest != config['pdfiumDart']['hookSha256']:
        raise ValueError('PDFium Dart hook differs from the reviewed source; use a fresh package cache')
    patched_hook = patch_hook(original.decode(), builder)
    revision = subprocess.check_output(
        ['git', '-C', str(builder), 'rev-parse', 'HEAD'], text=True,
    ).strip()
    if revision != config['pdfium']['builderRevision']:
        raise ValueError('PDFium builder revision does not match native-sources.json')
    for name, expected in config['builderFiles'].items():
        path = builder / name
        if path.is_symlink() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError(f'Unexpected PDFium builder input: {name}')
    driver = patch_driver((builder / 'build.sh').read_text())
    checkout = builder / 'steps/02-checkout.sh'
    checkout_source = checkout.read_text()
    old = 'gclient sync -r "origin/${PDFium_BRANCH:-main}" --no-history --shallow'
    if checkout_source.count(old) != 1:
        raise ValueError('Unexpected PDFium source checkout command')
    checkout_source = checkout_source.replace(
        old, f'gclient sync -r "{config["pdfium"]["revision"]}" --no-history --shallow',
    )
    checkout_source += '''
# Build dependencies are provided by the F-Droid sudo phase, never from here.
sed -i 's|  sys.exit(main())|  sys.exit(0)|g' pdfium/build/install-build-deps.py
'''
    compile_step = builder / 'steps/06-build.sh'
    compile_source = compile_step.read_text()
    ninja = 'ninja -C "$BUILD_DIR" pdfium'
    if compile_source.count(ninja) != 1:
        raise ValueError('Unexpected PDFium compiler command')
    compile_source = compile_source.replace(
        ninja, 'ninja -j "${INKORA_PDFIUM_JOBS:-4}" -C "$BUILD_DIR" pdfium',
    )
    generated = [project / '.dart_tool/hooks_runner/shared/pdfium_dart',
                 project / '.dart_tool/hooks_runner/pdfium_dart']
    if any(path.is_symlink() for cache in generated for path in (cache, *cache.parents)
           if path.is_relative_to(project)):
        raise ValueError('Refusing a linked PDFium generated cache')
    # All checks precede mutations. Dependencies must be supplied by F-Droid's
    # isolated sudo phase; this preparation never invokes a package manager.
    install = '''#!/bin/bash -eux
export DEPOT_TOOLS_UPDATE=0
depot="$PWD/depot_tools"
if [[ ! -d "$depot/.git" ]]; then
  git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "$depot"
fi
git -C "$depot" checkout --detach DEPOT_REVISION
"$depot/ensure_bootstrap"
echo "$depot" >> "${GITHUB_PATH:-$PWD/.path}"
'''.replace('DEPOT_REVISION', config['pdfium']['depotToolsRevision'])
    (builder / 'steps/01-install.sh').write_text(install)
    (builder / 'build.sh').write_text(driver)
    checkout.write_text(checkout_source)
    compile_step.write_text(compile_source)
    # The upstream cross-platform example needs another NDK and cannot run on
    # the builder. Actual app reader tests are separate acceptance evidence.
    (builder / 'steps/09-test.sh').write_text('#!/bin/bash\nset -eu\n')
    hook.write_text(patched_hook)
    for cache in generated:
        if cache.exists():
            shutil.rmtree(cache)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=Path.cwd())
    parser.add_argument('--pub-cache', type=Path, required=True)
    parser.add_argument('--pdfium', type=Path, required=True)
    args = parser.parse_args()
    config = json.loads(CONFIG.read_text())
    project = args.project.resolve()
    if not (project / 'pubspec.yaml').is_file():
        raise ValueError('The project must be a disposable Flutter source checkout')
    # Download only reviewed C source in prebuild; no native SQLite binary.
    with urllib.request.urlopen(config['sqlite']['url'], timeout=60) as response:
        archive = response.read(8 * 1024 * 1024 + 1)
    install_sqlite(project, config, archive)
    prepare(project, args.pub_cache.resolve(), args.pdfium.resolve(), config)
    print('Prepared pinned PDFium and SQLite source builds.')


if __name__ == '__main__':
    main()
