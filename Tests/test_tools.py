import importlib.util
import json
import plistlib
import tempfile
import unittest
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]


def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'Scripts' / (name + '.py'))
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


class ToolTests(unittest.TestCase):
    def test_unsigned_package_layout_and_device_guard(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            app = root / 'NovaEditor.app'
            app.mkdir()
            info = dict(CFBundleSupportedPlatforms=['iPhoneOS'], CFBundleExecutable='NovaEditor')
            (app / 'Info.plist').write_bytes(plistlib.dumps(info))
            binary = app / 'NovaEditor'
            binary.write_bytes(b'fixture only, not a Mach-O')
            binary.chmod(0o755)
            (app / 'embedded.mobileprovision').write_text('fixture')
            (app / '_CodeSignature').mkdir()
            (app / '_CodeSignature/CodeResources').write_text('fixture')
            output = root / 'unsigned.ipa'
            module('package_ipa').package(app, output)
            with ZipFile(output) as archive:
                self.assertEqual(set(archive.namelist()), {'Payload/NovaEditor.app/Info.plist', 'Payload/NovaEditor.app/NovaEditor'})
                self.assertTrue((archive.getinfo('Payload/NovaEditor.app/NovaEditor').external_attr >> 16) & 0o111)
            self.assertTrue((app / 'embedded.mobileprovision').exists())
            info['CFBundleSupportedPlatforms'] = ['iPhoneSimulator']
            (app / 'Info.plist').write_bytes(plistlib.dumps(info))
            with self.assertRaises(ValueError): module('package_ipa').package(app, output)

    def test_inventory_does_not_approve_licenses(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            apk = root / 'fixture.apk'
            with ZipFile(apk, 'w') as archive:
                archive.writestr('classes.dex', b'fixture')
                archive.writestr('assets/effects/test.json', '{}')
                archive.writestr('assets/fonts/example.ttf', b'fixture')
                archive.writestr('../outside', b'not extracted')
            module('inspect_apk').inventory(apk, root / 'report')
            result = json.loads((root / 'report/summary.json').read_text())
            self.assertEqual(result['files'], 4)
            self.assertEqual(result['categories']['font'], 1)
            self.assertIn('blocked-pending-license-review', (root / 'report/inventory.csv').read_text())
            self.assertFalse((root / 'outside').exists())


if __name__ == '__main__':
    unittest.main()
