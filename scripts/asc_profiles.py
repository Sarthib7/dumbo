#!/usr/bin/env python3
"""Create and install App Store provisioning profiles via the App Store Connect API.

Usage: asc_profiles.py KEY_PATH BUNDLE_ID [BUNDLE_ID ...]
Env: ASC_KEY_ID, ASC_ISSUER_ID. Profiles are named "Dumbo AppStore <bundle id>".
"""
import base64, json, os, plistlib, subprocess, sys, time, urllib.error, urllib.parse, urllib.request

API = "https://api.appstoreconnect.apple.com"
KEY_PATH = sys.argv[1]


def b64(b):
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def token():
    now = int(time.time())
    head = b64(json.dumps({"alg": "ES256", "kid": os.environ["ASC_KEY_ID"], "typ": "JWT"}).encode())
    body = b64(json.dumps({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"}).encode())
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", KEY_PATH], input=f"{head}.{body}".encode(),
                         capture_output=True, check=True).stdout
    i = 4 if der[1] & 0x80 else 2

    def part(i):
        n = der[i + 1]
        return der[i + 2:i + 2 + n].lstrip(b"\0").rjust(32, b"\0"), i + 2 + n

    r, i = part(i)
    s, _ = part(i)
    return f"{head}.{body}.{b64(r + s)}"


def call(method, path, body=None):
    req = urllib.request.Request(API + path, method=method, data=json.dumps(body).encode() if body else None,
                                 headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        sys.exit(f"{method} {path}: {e.code} {e.read().decode()[:500]}")


def query(path, **params):
    return call("GET", path + "?" + urllib.parse.urlencode(params))["data"]


certs = [c["id"] for c in query("/v1/certificates", **{"filter[certificateType]": "DISTRIBUTION,IOS_DISTRIBUTION", "limit": 200})]
if not certs:
    sys.exit("No Apple Distribution certificate on the team")

dirs = [os.path.expanduser(p) for p in ("~/Library/MobileDevice/Provisioning Profiles",
                                         "~/Library/Developer/Xcode/UserData/Provisioning Profiles")]
for bundle in sys.argv[2:]:
    ids = [b["id"] for b in query("/v1/bundleIds", **{"filter[identifier]": bundle}) if b["attributes"]["identifier"] == bundle]
    if not ids:
        sys.exit(f"Bundle ID {bundle} is not registered")
    name = f"Dumbo AppStore {bundle}"
    for p in query("/v1/profiles", **{"filter[name]": name}):
        call("DELETE", f"/v1/profiles/{p['id']}")
    profile = call("POST", "/v1/profiles", {"data": {"type": "profiles",
        "attributes": {"name": name, "profileType": "IOS_APP_STORE"},
        "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": ids[0]}},
                          "certificates": {"data": [{"type": "certificates", "id": c} for c in certs]}}}})
    content = base64.b64decode(profile["data"]["attributes"]["profileContent"])
    uuid = profile["data"]["attributes"]["uuid"]
    for d in dirs:
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, f"{uuid}.mobileprovision"), "wb") as f:
            f.write(content)
    plist = plistlib.loads(content[content.index(b"<?xml"):content.index(b"</plist>") + 8])
    print(f"{name}: groups={plist['Entitlements'].get('com.apple.security.application-groups', [])}")
