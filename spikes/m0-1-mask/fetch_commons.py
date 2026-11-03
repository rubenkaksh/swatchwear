"""Fetch test portraits from Wikimedia Commons (free licenses only). Attribution goes to portraits/SOURCES.csv."""
import csv, json, re, sys, urllib.parse, urllib.request
from pathlib import Path
API = "https://commons.wikimedia.org/w/api.php"
UA = {"User-Agent": "swatchwear-spike/0.1 (personal test; ruben.kaksh@gmail.com)"}
CASES = [
 ("plain_light", "woman portrait white t-shirt studio"),
 ("plain_color", "man portrait blue shirt smiling"),
 ("pattern_stripe", "portrait striped shirt person"),
 ("pattern_floral", "woman portrait floral blouse"),
 ("dark_black", "portrait black sweater person"),
 ("dark_jacket", "portrait black leather jacket"),
 ("jacket_over_shirt", "man portrait blazer shirt"),
 ("long_sleeve_knit", "woman portrait knit sweater"),
 ("hair_shoulders", "woman long hair portrait shirt"),
 ("lowlight", "portrait person indoor dim light shirt"),
]
def get(params):
    url = API + "?" + urllib.parse.urlencode({**params, "format": "json"})
    return json.load(urllib.request.urlopen(urllib.request.Request(url, headers=UA)))
dest = Path(__file__).parent / "portraits"; dest.mkdir(exist_ok=True)
rows, seen = [], set()
for tag, q in CASES:
    d = get({"action": "query", "generator": "search", "gsrsearch": f"{q} filetype:bitmap", "gsrnamespace": 6, "gsrlimit": 20,
             "prop": "imageinfo", "iiprop": "url|size|mime|extmetadata", "iiurlwidth": 1024})
    pages = sorted(d.get("query", {}).get("pages", {}).values(), key=lambda p: p["index"])
    for p in pages:
        ii = p["imageinfo"][0]; md = ii.get("extmetadata", {})
        lic = md.get("LicenseShortName", {}).get("value", "")
        if ii["mime"] != "image/jpeg" or ii["width"] < 800 or ii["height"] < ii["width"] * 0.8: continue
        if not re.match(r"(CC BY|CC0|Public domain|PD)", lic, re.I) or "NC" in lic or "ND" in lic: continue
        if p["title"] in seen: continue
        seen.add(p["title"])
        fn = dest / f"{len(rows)+1:02d}_{tag}.jpg"
        fn.write_bytes(urllib.request.urlopen(urllib.request.Request(ii["thumburl"], headers=UA)).read())
        rows.append([fn.name, p["title"], lic, re.sub("<[^>]+>", "", md.get("Artist", {}).get("value", "")), ii["descriptionurl"]])
        print(fn.name, p["title"], lic); break
    else: print("none for", tag)
with open(dest / "SOURCES.csv", "w", newline="") as f:
    csv.writer(f).writerows([["file", "title", "license", "author", "url"]] + rows)
