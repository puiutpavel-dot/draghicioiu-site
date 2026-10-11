#!/usr/bin/env python3
"""Completează fișa App Store a aplicației Utilități (română + engleză, iPhone) prin App Store Connect API.

Folosește cheia din integrarea Codemagic (variabilele de mediu
APP_STORE_CONNECT_ISSUER_ID, APP_STORE_CONNECT_KEY_IDENTIFIER, APP_STORE_CONNECT_PRIVATE_KEY).

Utilizare:
  python3 store/asc_publica.py metadata            # texte, URL-uri, categorie, copyright, review, build
  python3 store/asc_publica.py screenshots DIR     # DIR/iphone/*.png -> 6.9" (limba principală)
  python3 store/asc_publica.py verifica | trimite  # verificare / trimitere la review (lansare MANUALĂ după aprobare)
"""
import hashlib
import json
import os
import sys
import time
from pathlib import Path

import jwt
import requests

BUNDLE_ID = "ro.draghicioiu.utilitati"
API = "https://api.appstoreconnect.apple.com/v1"
META = json.loads((Path(__file__).parent / "metadata.json").read_text(encoding="utf-8"))


def private_key():
    """Cheia .p8 poate veni ca text PEM, cu \\n literale, ca base64, ca cale de fișier sau fără antet."""
    import base64
    raw = os.environ.get("APP_STORE_CONNECT_PRIVATE_KEY", "")
    v = raw.strip().strip('"').strip("'")
    if v.startswith("@file:"):
        v = v[len("@file:"):]
    if v and len(v) < 1024 and os.path.isfile(os.path.expanduser(v)):
        v = Path(os.path.expanduser(v)).read_text()
    v = v.replace("\\n", "\n").replace("\r", "")
    if "BEGIN" not in v:
        try:
            dec = base64.b64decode(v + "=" * (-len(v) % 4)).decode("utf-8")
            if "BEGIN" in dec:
                v = dec
        except Exception:
            pass
    if "BEGIN" not in v:
        body = "".join(v.split())
        v = "-----BEGIN PRIVATE KEY-----\n" + "\n".join(body[i:i + 64] for i in range(0, len(body), 64)) + "\n-----END PRIVATE KEY-----\n"
    else:
        # repară PEM-uri pe un singur rând: antet și corp separate prin spații
        if "\n" not in v.strip():
            head, rest = v.split("-----", 2)[1], v.split("-----", 2)[2]
            body, _, tail = rest.partition("-----END")
            body = "".join(body.split())
            v = f"-----{head}-----\n" + "\n".join(body[i:i + 64] for i in range(0, len(body), 64)) + f"\n-----END{tail}"
    return v


def diagnose():
    raw = os.environ.get("APP_STORE_CONNECT_PRIVATE_KEY", "")
    print("Diagnostic cheie: lungime", len(raw),
          "| are BEGIN", "BEGIN" in raw,
          "| are \\n literal", "\\n" in raw,
          "| are newline", "\n" in raw,
          "| e fișier", bool(raw) and len(raw) < 1024 and os.path.isfile(os.path.expanduser(raw.strip())),
          "| key id setat", bool(os.environ.get("APP_STORE_CONNECT_KEY_IDENTIFIER")),
          "| issuer setat", bool(os.environ.get("APP_STORE_CONNECT_ISSUER_ID")))


def token():
    key = private_key()
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["APP_STORE_CONNECT_ISSUER_ID"], "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
        key,
        algorithm="ES256",
        headers={"kid": os.environ["APP_STORE_CONNECT_KEY_IDENTIFIER"], "typ": "JWT"},
    )


def call(method, path, body=None, params=None, ok=(200, 201, 204)):
    url = path if path.startswith("http") else API + path
    r = requests.request(method, url, params=params, json=body,
                         headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"})
    if r.status_code not in ok:
        print(f"!! {method} {path} -> {r.status_code}\n{r.text[:2000]}")
        r.raise_for_status()
    return r.json() if r.content else {}



def app_id():
    data = call("GET", "/apps", params={"filter[bundleId]": BUNDLE_ID})["data"]
    if not data:
        sys.exit("Nu există fișă în App Store Connect pentru " + BUNDLE_ID)
    return data[0]["id"]


def editable_version(aid):
    versions = call("GET", f"/apps/{aid}/appStoreVersions", params={"filter[platform]": "IOS"})["data"]
    for v in versions:
        if v["attributes"]["appStoreState"] in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"):
            return v
    sys.exit("Nu există o versiune editabilă: " + ", ".join(v["attributes"]["appStoreState"] for v in versions))


def version_localizations(vid):
    return {l["attributes"]["locale"]: l for l in call("GET", f"/appStoreVersions/{vid}/appStoreVersionLocalizations")["data"]}


def metadata():
    aid = app_id()
    version = editable_version(aid)
    vid = version["id"]
    print("App", aid, "versiune", version["attributes"]["versionString"], version["attributes"]["appStoreState"])

    # 1. App info: categorii, nume, subtitlu, politică de confidențialitate pe fiecare limbă
    infos = call("GET", f"/apps/{aid}/appInfos")["data"]
    info = next((i for i in infos if i["attributes"].get("appStoreState") != "READY_FOR_DISTRIBUTION"), infos[0])
    rel = {
        "primaryCategory": {"data": {"type": "appCategories", "id": META["primaryCategory"]}},
        "secondaryCategory": {"data": {"type": "appCategories", "id": META["secondaryCategory"]}},
    }
    call("PATCH", f"/appInfos/{info['id']}", {"data": {"type": "appInfos", "id": info["id"], "relationships": rel}})
    print("✓ categorii")
    existing = {l["attributes"]["locale"]: l for l in call("GET", f"/appInfos/{info['id']}/appInfoLocalizations")["data"]}
    for loc, t in META["locales"].items():
        attrs = {"name": t["name"], "subtitle": t["subtitle"], "privacyPolicyUrl": t["privacyPolicyUrl"]}
        if loc in existing:
            call("PATCH", f"/appInfoLocalizations/{existing[loc]['id']}", {"data": {
                "type": "appInfoLocalizations", "id": existing[loc]["id"], "attributes": attrs}})
        else:
            call("POST", "/appInfoLocalizations", {"data": {
                "type": "appInfoLocalizations", "attributes": {"locale": loc, **attrs},
                "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info["id"]}}}}})
        print("✓ nume + subtitlu", loc)

    # 2. Texte pe versiune, pe fiecare limbă
    vlocs = version_localizations(vid)
    for loc, t in META["locales"].items():
        attrs = {k: t[k] for k in ("description", "keywords", "promotionalText", "supportUrl")}
        if loc in vlocs:
            call("PATCH", f"/appStoreVersionLocalizations/{vlocs[loc]['id']}", {"data": {
                "type": "appStoreVersionLocalizations", "id": vlocs[loc]["id"], "attributes": attrs}})
        else:
            call("POST", "/appStoreVersionLocalizations", {"data": {
                "type": "appStoreVersionLocalizations", "attributes": {"locale": loc, **attrs},
                "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
        print("✓ descriere + cuvinte cheie", loc)

    # 3. Copyright + lansare manuală după aprobare
    call("PATCH", f"/appStoreVersions/{vid}", {"data": {
        "type": "appStoreVersions", "id": vid,
        "attributes": {"copyright": META["copyright"], "releaseType": "MANUAL"}}})
    print("✓ copyright, lansare manuală")

    # 3b. Clasificare de vârstă: fără conținut sensibil (4+)
    try:
        ard = call("GET", f"/appInfos/{info['id']}/ageRatingDeclaration")["data"]
        call("PATCH", f"/ageRatingDeclarations/{ard['id']}", {"data": {
            "type": "ageRatingDeclarations", "id": ard["id"], "attributes": META["ageRating"]}})
        print("✓ clasificare de vârstă 4+")
    except Exception as e:
        print("! clasificarea de vârstă trebuie completată manual:", e)

    # 4. Date pentru echipa de review
    rv = META["review"]
    ex = call("GET", f"/appStoreVersions/{vid}/appStoreReviewDetail", ok=(200, 404)).get("data")
    if ex:
        call("PATCH", f"/appStoreReviewDetails/{ex['id']}", {"data": {
            "type": "appStoreReviewDetails", "id": ex["id"], "attributes": rv}})
    else:
        call("POST", "/appStoreReviewDetails", {"data": {
            "type": "appStoreReviewDetails", "attributes": rv,
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
    print("✓ date de contact și note pentru review")

    # 5. Build-ul cel mai nou, procesat
    builds = call("GET", "/builds", params={
        "filter[app]": aid, "filter[processingState]": "VALID", "sort": "-uploadedDate", "limit": 1})["data"]
    if builds:
        b = builds[0]
        if b["attributes"].get("usesNonExemptEncryption") is None:
            call("PATCH", f"/builds/{b['id']}", {"data": {
                "type": "builds", "id": b["id"], "attributes": {"usesNonExemptEncryption": False}}}, ok=(200, 409))
        call("PATCH", f"/appStoreVersions/{vid}/relationships/build", {"data": {"type": "builds", "id": b["id"]}})
        print("✓ build atașat:", b["attributes"]["version"])
    else:
        print("! niciun build procesat încă — rulează din nou după procesare")


def upload_set(loc_id, display_type, files):
    sets = call("GET", f"/appStoreVersionLocalizations/{loc_id}/appScreenshotSets")["data"]
    sset = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == display_type), None)
    if sset is None:
        sset = call("POST", "/appScreenshotSets", {"data": {
            "type": "appScreenshotSets", "attributes": {"screenshotDisplayType": display_type},
            "relationships": {"appStoreVersionLocalization": {"data": {
                "type": "appStoreVersionLocalizations", "id": loc_id}}}}})["data"]
    sid = sset["id"]
    for old in call("GET", f"/appScreenshotSets/{sid}/appScreenshots")["data"]:
        call("DELETE", f"/appScreenshots/{old['id']}")
    print(display_type, "— încarc", len(files))
    for f in files:
        data = f.read_bytes()
        shot = call("POST", "/appScreenshots", {"data": {
            "type": "appScreenshots", "attributes": {"fileName": f.name, "fileSize": len(data)},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": sid}}}}})["data"]
        for op in shot["attributes"]["uploadOperations"]:
            chunk = data[op["offset"]:op["offset"] + op["length"]]
            headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
            requests.request(op["method"], op["url"], data=chunk, headers=headers).raise_for_status()
        call("PATCH", f"/appScreenshots/{shot['id']}", {"data": {
            "type": "appScreenshots", "id": shot["id"],
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
        print("  ✓", f.name)
    return sid


def screenshots(folder):
    aid = app_id()
    vid = editable_version(aid)["id"]
    loc = version_localizations(vid)[META["primaryLocale"]]
    sids = []
    for sub, dtype in (("iphone", "APP_IPHONE_67"),):
        files = sorted((Path(folder) / sub).glob("*.png"))
        if files:
            sids.append(upload_set(loc["id"], dtype, files))
    time.sleep(25)
    for sid in sids:
        for s in call("GET", f"/appScreenshotSets/{sid}/appScreenshots")["data"]:
            st = s["attributes"].get("assetDeliveryState") or {}
            print(s["attributes"]["fileName"], st.get("state"), st.get("errors") or "")


def verifica(aid, version):
    vid = version["id"]
    probleme = []
    vlocs = version_localizations(vid)
    for loc in META["locales"]:
        a = (vlocs.get(loc) or {}).get("attributes", {})
        for camp in ("description", "keywords", "supportUrl"):
            if not a.get(camp):
                probleme.append(f"lipsește {camp} ({loc})")
    p = vlocs.get(META["primaryLocale"])
    nr = 0
    if p:
        for s in call("GET", f"/appStoreVersionLocalizations/{p['id']}/appScreenshotSets")["data"]:
            shots = call("GET", f"/appScreenshotSets/{s['id']}/appScreenshots")["data"]
            ok = [x for x in shots if (x["attributes"].get("assetDeliveryState") or {}).get("state") == "COMPLETE"]
            print(f"  capturi {s['attributes']['screenshotDisplayType']}: {len(ok)}/{len(shots)} procesate")
            nr += len(ok)
    if nr == 0:
        probleme.append("nicio captură de ecran procesată")
    build = call("GET", f"/appStoreVersions/{vid}/build").get("data")
    if not build:
        probleme.append("niciun build atașat")
    else:
        print("  build atașat:", build["attributes"]["version"], build["attributes"].get("processingState"))
    if not call("GET", f"/appStoreVersions/{vid}/appStoreReviewDetail", ok=(200, 404)).get("data"):
        probleme.append("lipsesc datele pentru review")
    if not version["attributes"].get("copyright"):
        probleme.append("lipsește copyright")
    return probleme


def trimite():
    aid = app_id()
    version = editable_version(aid)
    vid = version["id"]
    print("Verific versiunea", version["attributes"]["versionString"], version["attributes"]["appStoreState"])
    probleme = verifica(aid, version)
    if probleme:
        sys.exit("Nu trimit, lipsesc: " + "; ".join(probleme))
    # Lansare MANUALĂ: după aprobare, aplicația apare în App Store doar când apeși „Release”.
    call("PATCH", f"/appStoreVersions/{vid}", {"data": {
        "type": "appStoreVersions", "id": vid, "attributes": {"releaseType": "MANUAL"}}})
    subs = call("GET", "/reviewSubmissions", params={
        "filter[app]": aid, "filter[platform]": "IOS", "filter[state]": "READY_FOR_REVIEW"})["data"]
    sub = subs[0] if subs else call("POST", "/reviewSubmissions", {"data": {
        "type": "reviewSubmissions", "attributes": {"platform": "IOS"},
        "relationships": {"app": {"data": {"type": "apps", "id": aid}}}}})["data"]
    if not call("GET", f"/reviewSubmissions/{sub['id']}/items")["data"]:
        call("POST", "/reviewSubmissionItems", {"data": {
            "type": "reviewSubmissionItems",
            "relationships": {
                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub["id"]}},
                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
    res = call("PATCH", f"/reviewSubmissions/{sub['id']}", {"data": {
        "type": "reviewSubmissions", "id": sub["id"], "attributes": {"submitted": True}}})
    print("✓ TRIMIS LA REVIEW — stare:", res["data"]["attributes"].get("state"))


if __name__ == "__main__":
    diagnose()
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "verifica":
        aid = app_id()
        print("Probleme:", verifica(aid, editable_version(aid)) or "niciuna")
    elif cmd == "trimite":
        trimite()
    elif cmd == "metadata":
        metadata()
    elif cmd == "screenshots" and len(sys.argv) >= 3:
        screenshots(sys.argv[2])
    else:
        sys.exit(__doc__)
