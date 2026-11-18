#!/system/bin/sh
LOG=/data/local/tmp/ksu.log
POL=/data/local/tmp/glk_policy.bin
echo "[k] start uid=$(id -u) ctx=$(cat /proc/self/attr/current 2>/dev/null)" >"$LOG"
grep -E '^(Cap|Seccomp)' /proc/self/status >>"$LOG" 2>/dev/null
KSUD=''
for PKG in me.weishu.kernelsu.pr me.weishu.kernelsu com.sukisu.ultra com.resukisu.resukisu org.bakasu.bakasu com.kowx712.supermanager; do
  APK=$(pm path "$PKG" 2>/dev/null | head -1 | cut -d: -f2)
  [ -n "$APK" ] && KSUD="$(dirname "$APK")/lib/arm64/libksud.so"
  [ -x "$KSUD" ] && break
done
[ -x "$KSUD" ] || KSUD=/data/local/tmp/ksud
[ -x "$KSUD" ] || KSUD=/data/adb/ksu/bin/ksud
if [ ! -x "$KSUD" ]; then echo '[k] ksud missing' >>"$LOG"; echo KSU_MISSING >>"$LOG"; exit 1; fi
echo "[k] ksud=$KSUD" >>"$LOG"
KVER=$(uname -r | cut -d. -f1-2)
AVER=$(uname -r | grep -o 'android[0-9]*' | head -1)
KMI="${AVER}-${KVER}"
echo "[k] kmi=$KMI" >>"$LOG"
cat /sys/fs/selinux/policy >"$POL" 2>/dev/null
if [ -s "$POL" ]; then
  load_policy "$POL" >>"$LOG" 2>&1
  echo "[k] load_policy rc=$?" >>"$LOG"
else
  echo '[k] policy dump failed' >>"$LOG"
fi
grep -q kernelsu /proc/modules 2>/dev/null || "$KSUD" late-load --kmi "$KMI" >>"$LOG" 2>&1
echo "[k] late-load rc=$?" >>"$LOG"
i=0; while [ $i -lt 50 ]; do grep -q kernelsu /proc/modules 2>/dev/null && break; i=$((i+1)); sleep 0.1; done
if grep -q kernelsu /proc/modules 2>/dev/null; then echo KSU_LOADED >>"$LOG"; else echo KSU_MISSING >>"$LOG"; fi
echo 1 > /sys/fs/selinux/enforce 2>/dev/null
echo "[k] enforce=$(getenforce)" >>"$LOG"
echo '[k] DONE' >>"$LOG"
