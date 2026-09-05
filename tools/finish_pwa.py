#!/usr/bin/env python3
"""
Sidewalk Kings - finish the exported web manifest.

Godot's web export offers icon slots at 144, 180 and 512 only. Chrome will not offer to
install a site unless the manifest declares an icon of at least 192 AND one of 512, so a
Godot PWA is not installable out of the box: the manifest is generated, the browser reads
it, and the install option simply never appears. Nothing warns you.

This runs after the export and completes the manifest in place: adds the 192, adds a
maskable icon for Android's circular crop, and fills in the fields Godot does not write.

Run from the project root, after exporting:  python tools/finish_pwa.py web
"""
import json
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_ICONS = os.path.join(ROOT, "assets", "pwa")

# Chrome's installability rule is the reason this file exists. Keep both.
REQUIRED_SIZES = ("192x192", "512x512")

EXTRA = {
    "short_name": "Sidewalk Kings",
    "description": "An original 2D side-scrolling beat-'em-up RPG set in Riverbend.",
    "theme_color": "#16131f",
    "scope": "./",
    "categories": ["games"],
}


def main() -> int:
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "web"
    out_dir = os.path.abspath(out_dir)
    manifest_path = os.path.join(out_dir, "index.manifest.json")
    if not os.path.exists(manifest_path):
        print("no manifest at %s: is the PWA export enabled?" % manifest_path)
        return 1

    with open(manifest_path, encoding="utf-8") as f:
        manifest = json.load(f)

    # Copy the icons Godot has no slot for.
    for src_name, out_name, size, purpose in [
        ("icon-192.png", "index.192x192.png", "192x192", "any"),
        ("icon-512-maskable.png", "index.512x512-maskable.png", "512x512", "maskable"),
    ]:
        src = os.path.join(SRC_ICONS, src_name)
        if not os.path.exists(src):
            print("missing source icon %s" % src)
            return 1
        shutil.copyfile(src, os.path.join(out_dir, out_name))
        entry = {"src": out_name, "sizes": size, "type": "image/png"}
        if purpose != "any":
            entry["purpose"] = purpose
        if not any(i.get("src") == out_name for i in manifest.get("icons", [])):
            manifest.setdefault("icons", []).append(entry)

    for key, value in EXTRA.items():
        manifest.setdefault(key, value)

    manifest["icons"].sort(key=lambda i: (int(i["sizes"].split("x")[0]), i.get("purpose", "")))

    with open(manifest_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, indent=1, sort_keys=True)

    declared = {i["sizes"] for i in manifest["icons"]}
    missing = [s for s in REQUIRED_SIZES if s not in declared]
    if missing:
        print("manifest still missing required icon sizes: %s" % ", ".join(missing))
        return 1

    print("manifest completed: icons %s" % ", ".join(sorted(declared)))
    print("  name=%s display=%s orientation=%s scope=%s" % (
        manifest.get("name"), manifest.get("display"),
        manifest.get("orientation"), manifest.get("scope")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
