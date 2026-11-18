import zipfile, re, subprocess, os
base = r"C:\Users\patri\AppData\Local\Temp\opencode"
apk = r"C:\Users\patri\Desktop\Nova pasta\work\shizuku-13.5.4.apk"
dex = os.path.join(base, "shiz1354.dex")
dump = os.path.join(base, "shiz1354.dump")
z = zipfile.ZipFile(apk)
open(dex, "wb").write(z.read("classes.dex"))
dexdump = r"C:\Users\patri\AppData\Local\Android\Sdk\build-tools\34.0.0\dexdump.exe"
with open(dump, "w", encoding="utf-8", errors="replace") as f:
    subprocess.run([dexdump, dex], stdout=f, stderr=subprocess.STDOUT)
lines = open(dump, encoding="utf-8", errors="replace").read().splitlines()
cls = ""
for i, ln in enumerate(lines):
    m = re.search(r"Class descriptor\s*:\s*'([^']+)'", ln)
    if m:
        cls = m.group(1)
    if re.search(r"name\s*:\s*'main'", ln) and "[Ljava/lang/String;)V" in "\n".join(lines[i:i+3]):
        print(i + 1, cls)
