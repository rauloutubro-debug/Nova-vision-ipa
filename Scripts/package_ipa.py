#!/usr/bin/env python3
"""Package an unsigned device app, preserving executable permission in ZIP metadata."""
import argparse
import plistlib
import shutil
import tempfile
import zipfile
from pathlib import Path


def package(app, output):
    if app.name != 'NovaEditor.app' or not app.is_dir():
        raise ValueError('Expected an existing NovaEditor.app')
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    if info.get('CFBundleSupportedPlatforms') != ['iPhoneOS']:
        raise ValueError('Expected an iOS device build, not a simulator build')
    executable = app / info['CFBundleExecutable']
    if not executable.is_file() or not executable.stat().st_mode & 0o111:
        raise ValueError('Missing executable or execute permissions')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as temporary:
        target = Path(temporary) / 'Payload' / app.name
        shutil.copytree(app, target, symlinks=True)
        for signature in target.rglob('_CodeSignature'):
            if signature.is_dir():
                shutil.rmtree(signature)
        for profile in target.rglob('embedded.mobileprovision'):
            profile.unlink()
        with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
            for path in sorted(Path(temporary).rglob('*')):
                if path.is_symlink():
                    raise ValueError(f'Unexpected symlink: {path.name}')
                if path.is_file():
                    archive.write(path, path.relative_to(temporary))
    print(output)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('app', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    package(args.app, args.output)
