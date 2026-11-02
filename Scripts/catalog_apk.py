#!/usr/bin/env python3
"""Catalog declarative metadata, not shader/source content. No reuse authorization."""
import argparse
import csv
import hashlib
import json
import xml.etree.ElementTree as ET
from collections import Counter
from pathlib import Path
from zipfile import ZipFile


def catalog(apk, output):
    output.mkdir(parents=True, exist_ok=True)
    effects, templates, failures = [], [], []
    with ZipFile(apk) as archive:
        names = [i.filename for i in archive.infolist() if not i.is_dir()]
        for path in names:
            if path.startswith('assets/effects/') and path.endswith('.xml'):
                try:
                    data = archive.read(path)
                    root = ET.fromstring(data)
                    effects.append(dict(path=path, id=root.get('id', ''), title=root.get('name', ''),
                        category=root.get('category', ''), root=root.tag,
                        sha256=hashlib.sha256(data).hexdigest(),
                        preset_elements=len(root.findall('.//preset')),
                        license_status='needs-file-specific-scope-review'))
                except (ET.ParseError, ValueError) as error:
                    failures.append(dict(path=path, error=str(error)))
            elif path.startswith('assets/templates/') and path.endswith('.novatemplate'):
                try:
                    data = archive.read(path)
                    item = json.loads(data)
                    templates.append(dict(path=path, id=item.get('id'), title=item.get('nome'),
                        category=item.get('categoria'), duration_us=item.get('duracaoUs'),
                        sha256=hashlib.sha256(data).hexdigest(), license_status='unknown'))
                except (ValueError, UnicodeDecodeError) as error:
                    failures.append(dict(path=path, error=str(error)))
    for filename, rows in [('effects.csv', effects), ('templates.csv', templates)]:
        if rows:
            with (output / filename).open('w', newline='', encoding='utf-8') as stream:
                writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
                writer.writeheader()
                writer.writerows(rows)
    summary = dict(asset_groups=dict(Counter(p.split('/')[1] for p in names if p.startswith('assets/'))),
        effect_xml_parsed=len(effects), effect_ids_unique=len({e['id'] for e in effects}),
        effect_content_hashes_unique=len({e['sha256'] for e in effects}),
        effect_categories=dict(Counter(e['category'] for e in effects)),
        nested_preset_elements=sum(e['preset_elements'] for e in effects),
        preset_directory_extensions=dict(Counter(Path(p).suffix for p in names if p.startswith('assets/presets/'))),
        templates_parsed=len(templates), failures=failures,
        limitations=['Declarative entries and names do not prove working UI, renderers or unique functional presets.',
                      'No asset/source content is copied into the app by this tool.'])
    (output / 'catalog-summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    parser.add_argument('--output', type=Path, default=Path('analysis/apk'))
    args = parser.parse_args()
    catalog(args.apk, args.output)
