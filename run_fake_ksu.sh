#!/system/bin/sh
cd /data/local/tmp || exit 1
LOG=/data/local/tmp/fake_ksu.log
: > $LOG
exec >>$LOG 2>&1
echo "=== run $(date) boot=$(cat /proc/sys/kernel/random/boot_id)"
./timer-yk3 fake 2>&1
echo "=== FAKE_KSU_DONE"
