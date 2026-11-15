#!/usr/bin/env bash
set -euo pipefail

FILE_ID="${1:-1aAqIKizvgiU1zd7PV3f8ivri4ZcDgwrj}"
TMP_ZIP="/tmp/shortzz_source.zip"

echo "1/3 Downloading Shortzz source archive from Google Drive..."
python3 - "$FILE_ID" "$TMP_ZIP" <<'PY'
import sys, urllib.request, urllib.parse, re, html

file_id, out_path = sys.argv[1], sys.argv[2]
url = f"https://drive.google.com/uc?export=download&id={file_id}"
req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
resp = urllib.request.urlopen(req)
ctype = resp.headers.get("Content-Type", "")
data = resp.read()

if b"<!DOCTYPE html" in data[:200] or "text/html" in ctype:
    text = data.decode("utf-8", errors="replace")
    action_m = re.search(r'action="([^"]+)"', text)
    inputs = re.findall(r'<input[^>]*name="([^"]+)"[^>]*value="([^"]*)"', text)
    if action_m and inputs:
        action = html.unescape(action_m.group(1))
        params = urllib.parse.urlencode(inputs)
        dl_url = f"{action}?{params}"
        req2 = urllib.request.Request(dl_url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req2) as r2, open(out_path, "wb") as f:
            while True:
                chunk = r2.read(1024 * 1024)
                if not chunk:
                    break
                f.write(chunk)
    else:
        raise RuntimeError("Could not parse Google Drive download confirmation page.")
else:
    with open(out_path, "wb") as f:
        f.write(data)
print("Downloaded:", out_path)
PY

echo "2/3 Extracting missing files into backend/, flutter_app/, and shortzz_database.sql (preserving patched files)..."
python3 - "$TMP_ZIP" <<'PY'
import sys, zipfile, io, os

zip_path = sys.argv[1]
added = 0

def write_if_missing(dest, content):
    global added
    if os.path.exists(dest):
        return
    os.makedirs(os.path.dirname(dest) or ".", exist_ok=True)
    with open(dest, "wb") as f:
        f.write(content)
    added += 1

with zipfile.ZipFile(zip_path) as outer:
    names = outer.namelist()
    sql_entry = next((n for n in names if n.endswith("shortzz_database.sql")), None)
    backend_entry = next((n for n in names if n.endswith("shortzz_backend.zip")), None)
    flutter_entry = next((n for n in names if n.endswith("Shortzz_flutter.zip")), None)

    if sql_entry:
        write_if_missing("shortzz_database.sql", outer.read(sql_entry))

    if backend_entry:
        with zipfile.ZipFile(io.BytesIO(outer.read(backend_entry))) as bz:
            for info in bz.infolist():
                if info.is_dir():
                    continue
                rel = info.filename
                if rel.startswith("shortzz_backend/"):
                    rel = rel[len("shortzz_backend/"):]
                if (
                    rel.startswith("vendor/")
                    or rel.startswith("storage/framework/views/")
                    or rel.endswith(".DS_Store")
                    or rel in (".env", "mysqlbackup")
                ):
                    continue
                write_if_missing(os.path.join("backend", rel), bz.read(info.filename))

    if flutter_entry:
        with zipfile.ZipFile(io.BytesIO(outer.read(flutter_entry))) as fz:
            for info in fz.infolist():
                if info.is_dir():
                    continue
                rel = info.filename
                if rel.startswith("Shortzz/"):
                    rel = rel[len("Shortzz/"):]
                if (
                    rel.startswith("android/app/.cxx/")
                    or rel.startswith("android/build/")
                    or rel.startswith(".idea/")
                    or "/xcuserdata/" in rel
                    or rel.endswith(".DS_Store")
                ):
                    continue
                write_if_missing(os.path.join("flutter_app", rel), fz.read(info.filename))

print(f"Added {added} missing files.")
PY

rm -f "$TMP_ZIP"

echo "3/3 Committing and pushing to GitHub..."
git add -A
if git diff --cached --quiet; then
  echo "No new changes to commit."
else
  git commit -m "Add complete Shortzz backend routes, views, Flutter app, and SQL schema"
  git push
fi
echo "Done! Trigger Railway redeploy and GitHub Actions APK build now."
