#!/usr/bin/env python3
"""Decode manifest metadata only. Optional analysis dependency: pyaxmlparser==0.3.31."""
import argparse
import json
from pathlib import Path
from zipfile import ZipFile


def decode(apk, output):
    from pyaxmlparser.axmlprinter import AXMLPrinter
    from lxml import etree
    with ZipFile(apk) as archive:
        root = etree.fromstring(AXMLPrinter(archive.read('AndroidManifest.xml')).get_xml())
    ns = '{http://schemas.android.com/apk/res/android}'
    app = root.find('application')
    sdk = root.find('uses-sdk')
    data = dict(package=root.get('package'), versionName=root.get(ns + 'versionName'),
        versionCode=root.get(ns + 'versionCode'), sdk=dict(sdk.attrib) if sdk is not None else {},
        permissions=[e.get(ns + 'name') for e in root.findall('uses-permission')],
        components=[dict(type=e.tag, name=e.get(ns + 'name'), exported=e.get(ns + 'exported'),
            intentActions=[a.get(ns + 'name') for a in e.findall('./intent-filter/action')])
            for e in app if e.tag in {'activity', 'activity-alias', 'service', 'receiver', 'provider'}])
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    print(output)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    parser.add_argument('--output', type=Path, default=Path('analysis/apk/manifest-summary.json'))
    args = parser.parse_args()
    decode(args.apk, args.output)
