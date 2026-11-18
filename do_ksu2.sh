#!/system/bin/sh
LOG=/data/local/tmp/ksu2.log
echo "[k2] uid=$(id -u) ctx=$(cat /proc/self/attr/current 2>/dev/null)" >"$LOG"
KSUD=$(pm path me.weishu.kernelsu 2>/dev/null | head -1 | cut -d: -f2 | xargs dirname)/lib/arm64/libksud.so
echo "[k2] ksud=$KSUD" >>"$LOG"
chmod 755 "$KSUD" 2>/dev/null
"$KSUD" late-load --kmi android16-6.12 --allow-shell --package-name me.weishu.kernelsu >>"$LOG" 2>&1
echo "[k2] rc=$?" >>"$LOG"
grep -i kernelsu /proc/modules >>"$LOG" 2>&1
echo "[k2] done" >>"$LOG"
