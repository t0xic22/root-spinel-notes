import re
p = r"C:\Users\patri\AppData\Local\Temp\opencode\shiz1354.dump"
txt = open(p, encoding="utf-8", errors="replace").read()
for pat in [r"app_process[^\n]{0,200}", r"CLASSPATH[^\n]{0,200}", r"moe\.shizuku\.starter\.ServiceStarter[^\n]{0,160}", r"ShizukuService[^\n]{0,160}"]:
    print("=== ", pat)
    for m in re.findall(pat, txt)[:8]:
        print(m.strip())
