# retry_app.ps1 - tentativa do exploit pelo app SEM reboot (force-stop apenas)
# Uso:powershell -ExecutionPolicy Bypass -File retry_app.ps1 [-Perm]
param([switch]$Perm)
$ErrorActionPreference = "Continue"
$A = "C:\Users\patri\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$dev = "kbrov8pjvw89kbqg"

function Sh($cmd) { & $A -s $dev shell $cmd 2>$null | Out-String }
function NativeAlive {
    $p = Sh 'ps -A'
    return ($p -split "`n" | Where-Object { $_ -match 'libghostlock' }).Count -gt 0
}
function FreshLog {
    Sh 'rm -f /data/local/tmp/ksu.log /data/local/tmp/glk_policy.bin; touch /data/local/tmp/ksu.log /data/local/tmp/glk_policy.bin; chmod 666 /data/local/tmp/ksu.log /data/local/tmp/glk_policy.bin; logcat -c' | Out-Null
}
function UiText {
    Sh 'uiautomator dump /sdcard/retry_ui.xml >/dev/null 2>&1; cat /sdcard/retry_ui.xml'
}

if ($Perm) {
    Write-Host "[*] perm (SELinux Permissive)"
    & $A -s $dev shell 'cd /data/local/tmp && ./timer-yk perm 2>&1' |
        Select-String -Pattern 'enforcing cleared|done' | ForEach-Object { $_.Line }
}
if ((Sh 'getenforce').Trim() -ne 'Permissive') {
    Write-Host "[!] SELinux nao esta Permissive - rode com -Perm"
}

[void](Sh 'am force-stop com.ghostlock.app')
Start-Sleep -Seconds 2
if (NativeAlive) {
    Write-Host "[!] nativo ainda vivo apos force-stop; esperando..."
    Start-Sleep -Seconds 3
}
[void](Sh 'monkey -p com.ghostlock.app 1')

# espera a UI ficar pronta (ate 20s)
$ready = $false
for ($i = 0; $i -lt 10; $i++) {
    Start-Sleep -Seconds 2
    $x = UiText
    if ($x -match 'Shizuku pronto' -and $x -match 'Suportada') { $ready = $true; break }
}
if (-not $ready) { Write-Host "[!] UI nao ficou pronta"; exit 1 }
Write-Host "[*] UI pronta"

# abre o registro e LOCALIZA o botao Correr dinamicamente
[void](Sh 'input swipe 540 1900 540 600 400')
Start-Sleep -Seconds 2
$x = UiText
$m = [regex]::Match($x, '<node[^>]*text="Correr"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"')
if ($m.Success) {
    $cx = [int](([int]$m.Groups[1].Value + [int]$m.Groups[3].Value) / 2)
    $cy = [int](([int]$m.Groups[2].Value + [int]$m.Groups[4].Value) / 2)
    Write-Host "[*] Correr em $cx,$cy"
} else {
    $cx = 540; $cy = 2248
    Write-Host "[!] Correr nao encontrado; usando padrao $cx,$cy"
}

FreshLog
$bid0 = (Sh 'cat /proc/sys/kernel/random/boot_id').Trim()
Write-Host "[*] boot=$bid0 - disparando"
[void](Sh "input tap $cx $cy")

for ($t = 0; $t -lt 18; $t++) {
    Start-Sleep -Seconds 10
    $bid = (Sh 'cat /proc/sys/kernel/random/boot_id').Trim()
    if ($bid -ne $bid0) { Write-Host "[!] PANIC/REBOOT"; break }
    $kl = Sh 'cat /data/local/tmp/ksu.log 2>/dev/null'
    if ($kl -match 'KSU_LOADED') { Write-Host "=== KSU LOADED ==="; Write-Host $kl; break }
    if ($kl -match 'KSU_MISSING|\[k\] DONE') { Write-Host "--- handoff terminou (sem KSU) ---"; Write-Host $kl; break }
    if (-not (NativeAlive)) {
        Write-Host "[*] nativo saiu"
        $x = UiText
        if ($x -match 'exit code=(\d+)') { Write-Host "exit=$($Matches[1])" }
        break
    }
}
Write-Host "=== retry_app fim ==="
