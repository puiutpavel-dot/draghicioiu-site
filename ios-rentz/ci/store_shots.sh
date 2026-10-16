#!/bin/bash
# Capturi App Store pentru iPhone 6.9" (portret, română), din simulator.
# Fiecare scenă pornește aplicația cu o partidă demonstrativă jucată automat (vezi Demo în RentzApp.swift).
set -e
APP=build/Build/Products/Debug-iphonesimulator/Rentz.app
BUNDLE=ro.draghicioiu.rentz
U=$(xcrun simctl list devices available -j | python3 -c "
import json, sys, re
best = None
for rt, devs in json.load(sys.stdin)['devices'].items():
    if 'iOS' not in rt: continue
    ver = tuple(int(x) for x in re.findall(r'(\d+)', rt.split('iOS')[-1])[:2])
    for dev in devs:
        if re.search('iPhone.*Pro Max', dev['name']):
            key = (ver, dev['name'])
            if best is None or key > best[0]: best = (key, dev['udid'], dev['name'])
print(best[1]); print(best[2], file=sys.stderr)")
xcrun simctl boot "$U" || true
xcrun simctl bootstatus "$U" -b
xcrun simctl status_bar "$U" override --time 9:41 --dataNetwork wifi --wifiBars 3 --cellularBars 4 --batteryState charged --batteryLevel 100 || true
xcrun simctl install "$U" "$APP"
mkdir -p storeshots/iphone
A=(-AppleLanguages "(ro)" -AppleLocale ro_RO -demo YES)
shot() { # $1 nume, $2 scenă
  xcrun simctl terminate "$U" $BUNDLE 2>/dev/null || true
  xcrun simctl launch "$U" $BUNDLE "${A[@]}" -scena "$2"
  sleep 7
  xcrun simctl io "$U" screenshot "storeshots/iphone/$1.png"
}
shot 01-joc    joc
shot 02-rentz  rentz
shot 03-alege  alege
shot 04-scor   scor
shot 05-start  start
xcrun simctl terminate "$U" $BUNDLE || true
CRASH=$(ls ~/Library/Logs/DiagnosticReports/ 2>/dev/null | grep -i rentz || true)
if [ -n "$CRASH" ]; then echo "CRASH: $CRASH"; for f in $CRASH; do head -c 4000 ~/Library/Logs/DiagnosticReports/$f; done; exit 1; fi
python3 -c "
from PIL import Image; import glob
for f in sorted(glob.glob('storeshots/iphone/*.png')):
    im = Image.open(f); print(f, im.size)
    im.convert('RGB').save(f)
"
