#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild -project NovaEditor.xcodeproj -scheme NovaEditor \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' build
python3 Scripts/package_ipa.py build/DerivedData/Build/Products/Release-iphoneos/NovaEditor.app build/NovaEditor-iOS-unsigned.ipa
