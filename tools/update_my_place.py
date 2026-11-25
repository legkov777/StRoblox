"""Вставить свежие скрипты из src/ в твоё место (.rbxlx) с твоими самолётами.

    python3 tools/build_place.py
    python3 tools/update_my_place.py "путь/к/FlyCrash_my_planes.rbxlx"

Меняется только текст скриптов FlyCrashServer, OutbreakServer, WorldBuilder,
TrafficServer, FlyCrashClient, FlyCrashShared. Модели и всё остальное не трогаются.
Перед записью делается копия *.bak.
"""
import collections, shutil, sys, xml.etree.ElementTree as ET
from pathlib import Path

ET.register_namespace("xmime", "http://www.w3.org/2005/05/xmlmime")
ET.register_namespace("xsi", "http://www.w3.org/2001/XMLSchema-instance")
ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = ("Script", "LocalScript", "ModuleScript")


def name(it):
    p = it.find("Properties")
    if p is None:
        return None
    for s in p.findall("string"):
        if s.get("name") == "Name":
            return s.text


def main(path):
    path = Path(path)
    fresh = ET.parse(ROOT / "FlyCrash.rbxlx").getroot()
    src = {name(it): it.find("Properties/ProtectedString").text
           for it in fresh.iter("Item") if it.get("class") in SCRIPTS}
    shutil.copy(path, path.with_suffix(path.suffix + ".bak"))
    tree = ET.parse(path)
    n = 0
    for it in tree.getroot().iter("Item"):
        if it.get("class") in SCRIPTS and name(it) in src:
            it.find("Properties/ProtectedString[@name='Source']").text = src[name(it)]
            n += 1
    tree.write(path, encoding="utf-8", xml_declaration=False)
    # проверка: Roblox не открывает файл с повторяющимися UniqueId/HistoryId
    root = ET.parse(path).getroot()
    dup = 0
    for field in ("UniqueId", "HistoryId"):
        c = collections.Counter(
            (e.text or "").strip() for it in root.iter("Item") if it.find("Properties") is not None
            for e in it.find("Properties") if e.get("name") == field)
        dup += sum(1 for v, k in c.items() if k > 1 and v != "0" * 32)
    print(f"обновлено скриптов: {n}; повторяющихся id: {dup}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
