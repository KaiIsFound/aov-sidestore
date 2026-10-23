#!/bin/bash
set -euo pipefail
mkdir -p build/MenuSmoke.app
SDK_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path)
ARCH=$(uname -m)
xcrun --sdk iphonesimulator clang++ \
  -target "${ARCH}-apple-ios13.0-simulator" -isysroot "$SDK_PATH" \
  -std=c++20 -fobjc-arc -Wno-deprecated-declarations -I. \
  tests/MenuSmoke.mm OllieMenu.mm -framework UIKit -framework Foundation \
  -o build/MenuSmoke.app/MenuSmoke
cat > build/MenuSmoke.app/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.ollie.MenuSmoke</string>
  <key>CFBundleExecutable</key><string>MenuSmoke</string>
  <key>CFBundleName</key><string>MenuSmoke</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>MinimumOSVersion</key><string>13.0</string>
  <key>LSRequiresIPhoneOS</key><true/>
  <key>UILaunchScreen</key><dict/>
</dict></plist>
PLIST
codesign --force --sign - build/MenuSmoke.app
xcrun simctl list devices available -j > build/devices.json
DEVICE_ID=$(python3 - <<'PY'
import json
devices = json.load(open('build/devices.json'))['devices']
print(next(d['udid'] for runtime, group in devices.items() if '.iOS-' in runtime for d in group if 'iPhone' in d['name']))
PY
)
xcrun simctl boot "$DEVICE_ID" || true
xcrun simctl bootstatus "$DEVICE_ID" -b
xcrun simctl install "$DEVICE_ID" build/MenuSmoke.app
# Bound the run, capture assertion output, and require the success marker.
python3 - "$DEVICE_ID" <<'PY'
import subprocess, sys
result = subprocess.run(
    ['xcrun', 'simctl', 'launch', '--console', '--terminate-running-process', sys.argv[1], 'local.ollie.MenuSmoke'],
    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=90)
print(result.stdout)
with open('build/menu-smoke.log', 'w') as log:
    log.write(result.stdout)
if result.returncode or 'MENU_SMOKE_PASSED' not in result.stdout or 'MENU_SMOKE_FAILED' in result.stdout:
    sys.exit(1)
PY
