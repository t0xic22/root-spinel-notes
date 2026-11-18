#!/system/bin/sh
cd /data/local/tmp || exit 1
LOG=/data/local/tmp/orig_fake.log
: > $LOG
exec >>$LOG 2>&1
echo "=== orig fake $(date) boot=$(cat /proc/sys/kernel/random/boot_id)"
./timer-orig fake 2>&1
echo "=== ORIG_FAKE_DONE"
