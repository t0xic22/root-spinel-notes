import zipfile, re
z = zipfile.ZipFile(r"C:\Users\patri\Desktop\Nova pasta\work\shizuku-13.5.4.apk")
d = z.read("classes.dex")
for pat in [rb"app_process[\x20-\x7e]{0,220}", rb"CLASSPATH[\x20-\x7e]{0,220}", rb"shizuku[\x20-\x7e]{0,180}"]:
    print("===", pat)
    seen = set()
    for m in re.findall(pat, d):
        s = m.decode("ascii", "replace")
        if s not in seen:
            seen.add(s)
            print(s)
            if len(seen) > 12:
                break
