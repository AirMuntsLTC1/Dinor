import getpass
import json
import re
import sys
import urllib.request
import urllib.error
from pathlib import Path

source = Path("lib/main.dart").read_text()
match = re.search(r"""publishableKey\s*:\s*['"]([^'"]+)['"]""", source)
if not match:
    raise SystemExit("Could not find publishableKey in lib/main.dart.")

key = match.group(1)
base = "https://skvgbzftnbditpztqewl.supabase.co"

def post(function, body):
    req = urllib.request.Request(
        f"{base}/functions/v1/{function}",
        data=json.dumps(body).encode(),
        headers={
            "Content-Type": "application/json",
            "apikey": key,
            "Authorization": f"Bearer {key}",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, r.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()
    except Exception as e:
        return 0, str(e)

email = sys.argv[1].strip().lower() if len(sys.argv) > 1 else ""
if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email):
    raise SystemExit(
        "Usage: python test_dinor_login.py your-existing-account@example.com"
    )

print("Requesting one sign-in code...")
status, raw = post("request-email-code", {"email": email})
print("Request HTTP status:", status)
try:
    result = json.loads(raw)
except Exception:
    result = {"response": raw[:500]}
print("Response:", json.dumps(result)[:1000])

if status != 200:
    raise SystemExit("Request failed. Inspect request-email-code logs in Supabase.")

code = input("Enter the six-digit code from your email: ").strip()
if not re.fullmatch(r"\d{8}", code):
    raise SystemExit("Code must contain exactly six digits.")

print("Verifying code...")
status, raw = post("verify-email-code", {"email": email, "code": code})
print("Verification HTTP status:", status)
try:
    result = json.loads(raw)
except Exception:
    result = {}

if status == 200:
    print("Access token returned:", bool(result.get("access_token")))
    print("Refresh token returned:", bool(result.get("refresh_token")))
    print("User returned:", bool((result.get("user") or {}).get("id")))
else:
    print("Response:", json.dumps(result)[:1000])
