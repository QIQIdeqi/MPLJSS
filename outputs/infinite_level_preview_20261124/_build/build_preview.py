from pathlib import Path
import json
import re
import subprocess

BUILD = Path(__file__).resolve().parent
OUT = BUILD.parent
CHROME = Path("C:/Program Files/Google/Chrome/Application/chrome.exe")

def build():
    template = (BUILD / "page.html").read_text(encoding="utf-8")
    data = json.loads((BUILD / "assets.json").read_text(encoding="utf-8"))
    result = template.replace("__ASSETS_JSON__", json.dumps(data, ensure_ascii=False, separators=(",", ":")))
    result = result.replace("__CONTENT_JS__", (BUILD / "content.js").read_text(encoding="utf-8"))
    result = result.replace("__WORLD_JS__", (BUILD / "world.js").read_text(encoding="utf-8"))
    assert not re.search(r"__(ASSETS_JSON|CONTENT_JS|WORLD_JS)__", result)
    target = OUT / "五关玩法预览.html"
    target.write_text(result, encoding="utf-8")
    return target

def chrome(args, log):
    result = subprocess.run([
        str(CHROME), "--headless=new", "--disable-gpu", "--no-first-run",
        "--no-default-browser-check", "--disable-background-networking",
        "--disable-extensions", "--hide-scrollbars", "--allow-file-access-from-files",
        "--force-device-scale-factor=1", "--no-pings",
        "--user-data-dir=" + str(BUILD / "chrome-profile"),
        "--crash-dumps-dir=" + str(BUILD / "crash-dumps"), *args
    ], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60)
    (BUILD / log).write_bytes(result.stderr)
    if result.returncode:
        raise RuntimeError(result.stderr.decode("utf-8", errors="replace")[-1800:])
    return result.stdout.decode("utf-8", errors="replace")

if __name__ == "__main__":
    target = build()
    chrome(["--window-size=1920,1080", "--virtual-time-budget=2200",
            "--screenshot=" + str(OUT / "五关玩法总览.png"),
            target.as_uri() + "?overview=1"], "render.log")
    print("Built offline HTML and overview PNG")
