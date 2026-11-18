#!/system/bin/sh
cd /data/local/tmp || exit 1
LOG=/data/local/tmp/ksu2_shell.log
: > $LOG
exec >>$LOG 2>&1
echo "=== ksu2 $(date) boot=$(cat /proc/sys/kernel/random/boot_id)"
printf 'sh /data/local/tmp/do_ksu2.sh\nexit\n' | ./timer-yk shell 2>&1
echo "=== KSU2_DONE"
