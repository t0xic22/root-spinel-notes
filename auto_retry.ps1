# auto_retry.ps1 - detecta plant travado e reinicia o app automaticamente
# NAO mata o nativo preso (isso gera panic). Usa force-stop + novo UserService.
$ErrorActionPreference = "Continue"
$A = "C:\Users\patri\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$dev = "kbrov8pjvw89kbqg"
$maxTentativas = 4
$timeoutPorTentativa = 45   # segundos sem progresso => travado

function Sh($cmd) { & $A -s $dev shell $cmd 2>$null | Out-String }
function NativeFutex {
    $p = Sh 'ps -A'
    return ($p -split "`n" | Where-Object { $_ -match 'libghostlock.*futex_wait' }).Count -gt 0
}
function NativeCount {
    $p = Sh 'ps -A'
    return ($p -split "`n" | Where-Object { $_ -match 'libghostlock' }).Count
}
function UiText { Sh 'uiautomator dump /sdcard/auto_ui.xml >/dev/null 2>&1; cat /sdcard/auto_ui.xml' }
function FindCorrer {
    $x = UiText
    $m = [regex]::Match($x, '<node[^>]*text="Correr"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"')
    if ($m.Success) {
        return @([int](([int]$m.Groups[1].Value+[int]$m.Groups[3].Value)/2),
                 [int](([int]$m.Groups[2].Value+[int]$m.Groups[4].Value)/2))
    }
    return @(540, 2248)
}
function StartApp {
    [void](Sh 'am force-stop com.ghostlock.app')
    Start-Sleep -Seconds 2
    [void](Sh 'monkey -p com.ghostlock.app 1')
    for ($i=0; $i -lt 12; $i++) {
        Start-Sleep -Seconds 2
        $x = UiText
        if ($x -match 'Shizuku pronto' -and $x -match 'Suportada') { return $true }
    }
    return $false
}
function Fire {
    param($cx, $cy)
    [void](Sh 'input swipe 540 1900 540 600 400')
    Start-Sleep -Seconds 2
    $c = FindCorrer
    [void](Sh "input tap $($c[0]) $($c[1])")
}

$bid0 = (Sh 'cat /proc/sys/kernel/random/boot_id').Trim()
Write-Host "[*] boot=$bid0"

for ($tent = 1; $tent -le $maxTentativas; $tent++) {
    $bid = (Sh 'cat /proc/sys/kernel/random/boot_id').Trim()
    if ($bid -ne $bid0) { Write-Host "[!] reboot/panic detectado - PARANDO"; break }

    Write-Host "===== tentativa $tent ====="
    if (-not (StartApp)) { Write-Host "[!] UI nao pronta"; break }

    [void](Sh 'rm -f /data/local/tmp/ksu.log; touch /data/local/tmp/ksu.log; chmod 666 /data/local/tmp/ksu.log')
    Fire 540 2248
    Write-Host "[*] disparado"

    $inicio = Get-Date
    $travado = $false
    $sucesso = $false
    while (((Get-Date) - $inicio).TotalSeconds -lt $timeoutPorTentativa) {
        Start-Sleep -Seconds 5
        $bid = (Sh 'cat /proc/sys/kernel/random/boot_id').Trim()
        if ($bid -ne $bid0) { Write-Host "[!] PANIC/REBOOT"; $travado = $true; break }

        $kl = Sh 'cat /data/local/tmp/ksu.log 2>/dev/null'
        if ($kl -match 'DONE|KSU_LOADED|\[props\]') {
            Write-Host "=== SUCESSO ==="; Write-Host $kl; $sucesso = $true; break
        }
        if (NativeFutex) {
            # Executa ha um tempo e esta preso numa futex => plant travou
            if (((Get-Date) - $inicio).TotalSeconds -gt 20) {
                Write-Host "[!] PLANT TRAVADO detectado (futex_wait)"
                $travado = $true
                break
            }
        }
        if ((NativeCount) -eq 0) {
            Write-Host "[*] nativo saiu"
            $x = UiText
            if ($x -match 'exit code=(\d+)') { Write-Host "exit=$($Matches[1])" }
            break
        }
    }

    if ($sucesso) { break }
    if ($travado) {
        if ($bid -ne $bid0) { break }
        Write-Host "[*] reiniciando app (force-stop, sem matar nativo)..."
        continue
    }
    Write-Host "[*] timeout sem desfecho; tentando de novo"
}
Write-Host "=== auto_retry fim ==="
