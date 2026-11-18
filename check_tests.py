import glob, re, html, os
base = os.path.join("C:\\", "Users", "patri", "Desktop", "Nova pasta", "work",
                    "ghostlock-spinel", "build", "app", "test-results",
                    "testDebugUnitTest")
for f in glob.glob(os.path.join(base, "*.xml")):
    txt = open(f, encoding="utf-8", errors="replace").read()
    for m in re.finditer(r'<testcase name="([^"]+)"[^>]*>(.*?)</testcase>', txt, re.S):
        name, body = m.group(1), m.group(2)
        fm = re.search(r'<failure message="([^"]*)"', body)
        if fm:
            msg = html.unescape(fm.group(1)).split("\n")[0][:240]
            print("FALHA:", name, "::", msg)
