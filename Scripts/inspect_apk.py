#!/usr/bin/env python3
"""Static ZIP inventory only. Does not extract/execute APK code or grant reuse rights."""
import argparse
import csv
import hashlib
import json
from collections import Counter
from pathlib import Path
from zipfile import ZipFile


def category(name):
    lower = name.lower()
    suffix = Path(lower).suffix
    if suffix == '.dex': return 'android-bytecode'
    if suffix == '.so': return 'native-library'
    if suffix in {'.ttf', '.otf', '.woff', '.woff2'}: return 'font'
    if suffix in {'.onnx', '.tflite', '.pt', '.pth', '.bin'}: return 'possible-model-or-binary'
    if Path(lower).name in {'ofl.txt', 'copyright', 'copyright.txt'} or any(word in lower for word in ('license', 'licence', 'notice', 'copying')): return 'license-candidate'
    if any(word in lower for word in ('preset', 'effect', 'template', 'shader', 'vhs', 'glitch', 'rife')): return 'effect-preset-template-candidate'
    if suffix in {'.py', '.pyc', '.js'}: return 'script'
    return 'other'


def inventory(apk, output):
    output.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256()
    with apk.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''): digest.update(block)
    counts = Counter()
    files = []
    with ZipFile(apk) as archive:
        for info in archive.infolist():
            if info.is_dir(): continue
            kind = category(info.filename)
            counts[kind] += 1
            files.append(dict(path=info.filename, category=kind, size=info.file_size,
                compressed_size=info.compress_size, crc32=f'{info.CRC:08x}',
                license='unknown', reuse='blocked-pending-license-review'))
    with (output / 'inventory.csv').open('w', newline='', encoding='utf-8') as stream:
        writer = csv.DictWriter(stream, fieldnames=['path', 'category', 'size', 'compressed_size', 'crc32', 'license', 'reuse'])
        writer.writeheader()
        writer.writerows(files)
    summary = dict(apk=apk.name, sha256=digest.hexdigest(), files=len(files), categories=dict(counts),
        limitations=['Categories are filename heuristics, not verified features or exact effect counts.',
                      'Binary AndroidManifest.xml and DEX require additional static analysis.',
                      'Screens/accessibility require authorized runtime observation.',
                      'No resource is approved for reuse by this inventory.'])
    (output / 'summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    parser.add_argument('--output', type=Path, default=Path('analysis/apk'))
    args = parser.parse_args()
    inventory(args.apk, args.output)
