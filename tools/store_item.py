#!/usr/bin/env python3
"""Write the AutoBleem Store's descriptor for one platform's package of the OpenBOR App (autobleem-repo
CLAUDE.md, "The AutoBleem Store's catalog"), next to the package and its picture, ready for
`repo_publish.sh store <platform> ...`:

    tools/store_item.py dist/openbor-psc-7533-1.zip   -> dist/store/psc/openbor.item.json
                                                         + openbor.png + the zip

The id is app/openbor on every platform - the RetroBoot App's, so it is updated in place on psc. Only the
standard library is needed.
"""
import json
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

ITEM = {
    "title": "OpenBOR",
    "author": "OpenBOR by the OpenBOR Team (ChronoCrash); Beats of Rage by Senile Team",
    "licence": "BSD-3-Clause",
    "description": "The open-source Beats of Rage engine for side-scrolling beat 'em ups. Copy a game's .pak "
                   "file into Apps/openbor/Paks.",
}


def main(argv):
    if len(argv) != 2:
        print(__doc__)
        return 2
    package = argv[1]
    m = re.match(r"^openbor-(?P<key>[a-z0-9]+)-(?P<version>.+)\.zip$", os.path.basename(package))
    if not m:
        print("not an openbor-<key>-<version>.zip: %s" % package)
        return 1
    key, version = m.group("key"), m.group("version")
    out = os.path.join(os.path.dirname(package), "store", key)
    os.makedirs(out, exist_ok=True)
    shutil.copy(package, out)
    shutil.copy(os.path.join(ROOT, "resources", "app", "icon.png"), os.path.join(out, "openbor.png"))
    item = {
        "id": "app/openbor",
        "kind": "app",
        "title": ITEM["title"],
        "version": version,
        "author": ITEM["author"],
        "licence": ITEM["licence"],
        "description": ITEM["description"],
        "image": "openbor.png",
        "files": [{"name": os.path.basename(package)}],
    }
    with open(os.path.join(out, "openbor.item.json"), "w", encoding="utf-8") as f:
        json.dump(item, f, indent=2)
        f.write("\n")
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
