#!/bin/bash
# Capturi App Store pentru iPhone 6.9" (portret, română), din simulator.
set -e
APP=build/Build/Products/Debug-iphonesimulator/ComparatorUtilitati.app
BUNDLE=ro.draghicioiu.utilitati
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
L=(-AppleLanguages "(ro)" -AppleLocale ro_RO)
shot() { # $1 nume, restul: argumente de lansare
  n=$1; shift
  xcrun simctl terminate "$U" $BUNDLE 2>/dev/null || true
  xcrun simctl launch "$U" $BUNDLE "${L[@]}" "$@"
  sleep 9
  xcrun simctl io "$U" screenshot "storeshots/iphone/$n.png"
}
# prima pornire: descarcă datele (cache)
xcrun simctl launch "$U" $BUNDLE "${L[@]}" -codPostal 060042; sleep 15
shot 01-bucuresti -codPostal 060042
shot 02-curent    -codPostal 400001 -captura curent
shot 03-gaz       -codPostal 700259 -captura gaz
shot 04-mobil     -codPostal 060042 -captura mobil
shot 05-consum    -codPostal 300001 -capturaSetari YES
xcrun simctl terminate "$U" $BUNDLE || true
python3 -c "
from PIL import Image; import glob
for f in sorted(glob.glob('storeshots/iphone/*.png')):
    im = Image.open(f); print(f, im.size)
    im.convert('RGB').save(f)
"
