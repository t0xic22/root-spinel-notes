# try_ksu.ps1 - tenta o handoff KSU via timer-yk3 (modo fake) com retry apos panic/plant preso.
$ErrorActionPreference = "Continue"
$A = "C:\Users\patri\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$dev = "kbrov8pjvw89kbqg"
$w = "C:\Users\patri\Desktop\Nova pasta\work"

function Wait-Boot {
    & $A -s $dev wait-for-device 2>&1 | Out-Null
    $n = 0
    while ($n -lt 90) {
        $b = (& $A -s $dev shell getprop sys.boot_completed 2>$null | Out-String).Trim()
        if ($b -eq "1") { return $true }
        Start-Sleep -Seconds 5; $n++
    }
    return $false
}
function Stage($src, $dst) {
    $want = (Get-FileHash $src -Algorithm MD5).Hash.ToLower()
    for ($k=0; $k -lt 3; $k++) {
        & $A -s $dev push $src $dst 2>&1 | Out-Null
        Start-Sleep -Milliseconds 400
        $have = (& $A -s $dev shell "md5sum $dst" 2>$null | Out-String).Trim().Split(' ')[0]
        if ($have -eq $want) { return $true }
    }
    Write-Host "[!] md5 fail $dst"
    return $false
}

for ($cycle = 1; $cycle -le 15; $cycle++) {
    Write-Host "===== KSU cycle $cycle ====="
    if (-not (Wait-Boot)) { Write-Host "boot timeout"; break }
    $bid = (& $A -s $dev shell cat /proc/sys/kernel/random/boot_id 2>$null | Out-String).Trim()
    Write-Host "boot_id=$bid"
    if (-not (Stage "$w\cve98260\timer\timer_spinel_v5" "/data/local/tmp/timer-yk3")) { break }
    if (-not (Stage "$w\run_fake_ksu.sh" "/data/local/tmp/run_fake_ksu.sh")) { break }
    & $A -s $dev shell 'chmod 755 /data/local/tmp/timer-yk3 /data/local/tmp/run_fake_ksu.sh; touch /data/local/tmp/ksu.log /data/local/tmp/glk_policy.bin /data/local/tmp/ksu_stage.sh; chmod 644 /data/local/tmp/ksu.log /data/local/tmp/glk_policy.bin' 2>&1 | Out-Null
    & $A -s $dev shell 'cd /data/local/tmp && nohup setsid /data/local/tmp/run_fake_ksu.sh >/dev/null 2>&1 &' 2>&1 | Out-Null
    Write-Host "[*] launched"
    $deadline = (Get-Date).AddSeconds(150)
    $done = $false
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 10
        $now = (& $A -s $dev shell cat /proc/sys/kernel/random/boot_id 2>$null | Out-String).Trim()
        if ($now -ne $bid) { Write-Host "[!] panic/reboot"; break }
        $run = (& $A -s $dev shell "cat /data/local/tmp/fake_ksu.log 2>/dev/null" 2>$null | Out-String)
        if ($run -match "FAKE_KSU_DONE") { $done = $true; break }
    }
    $log = (& $A -s $dev shell "cat /data/local/tmp/ksu.log 2>/dev/null" 2>$null | Out-String)
    Write-Host "--- ksu.log ---"
    Write-Host $log
    if ($log -match "KSU_LOADED") { Write-Host "=== KSU LOADED ==="; break }
    Write-Host "[*] rebooting for retry (done=$done)"
    & $A -s $dev reboot 2>&1 | Out-Null
    Start-Sleep -Seconds 12
}
Write-Host "=== try_ksu finished"
