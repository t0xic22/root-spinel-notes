import re
p = r"C:\Users\patri\AppData\Local\Temp\opencode\shizuku_dexdump.txt"
lines = open(p, encoding="utf-8", errors="replace").read().splitlines()
cls = ""
found = []
for i, ln in enumerate(lines):
    m = re.search(r"Class descriptor\s*:\s*'([^']+)'", ln)
    if m:
        cls = m.group(1)
    if re.search(r"name\s*:\s*'main'", ln):
        window = "\n".join(lines[i:i+3])
        if "[Ljava/lang/String;)V" in window:
            found.append((i+1, cls))
for n, c in found[:20]:
    print(n, c)
print("total:", len(found))
