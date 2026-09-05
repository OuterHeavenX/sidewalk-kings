#!/usr/bin/env python3
"""Fail if the exported web build is not installable.

Chrome offers no install option unless the manifest declares an icon of at least 192 and
one of 512 and uses an app-like display mode. There is no warning when it does not: the
site simply behaves like an ordinary page, which is exactly how this shipped.
"""
import json
import sys

REQUIRED = ("192x192", "512x512")
INSTALLABLE_DISPLAY = ("standalone", "fullscreen", "minimal-ui")


def main() -> int:
    out = sys.argv[1] if len(sys.argv) > 1 else "web"
    with open("%s/index.manifest.json" % out, encoding="utf-8") as f:
        m = json.load(f)
    sizes = {i["sizes"] for i in m.get("icons", [])}
    missing = [s for s in REQUIRED if s not in sizes]
    if missing:
        print("::error::manifest is missing icon sizes %s, so Chrome will not offer to install"
              % ", ".join(missing))
        return 1
    if m.get("display") not in INSTALLABLE_DISPLAY:
        print("::error::manifest display=%r is not an installable mode" % m.get("display"))
        return 1
    if not (m.get("name") or m.get("short_name")):
        print("::error::manifest has no name")
        return 1
    print("PWA manifest OK: icons %s, display %s" % (sorted(sizes), m["display"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
