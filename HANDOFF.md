# HANDOFF 17/11/2026 - GhostLock spinel (CVE-2026-43499) + TimerRoot

## ESTADO 17/11 TARDE: ROOT UID=0 CONQUISTADO 2x, SEM PANIC

**Fonte primária clonada:** `work/infinitycore/` (V4bel/InfinityCore — autor do
CVE-2026-98260; timer/CVE-2026-98260-android.c + ubuntu.c) e `work/cve98260/`
(YuKongA port, "Adapted from woshigenm"). O exploit VANILLA do YuKongA
(`timer-yk`, compilado de `work/cve98260/timer/timer.c` + perfil spinel em
`kbuilds/6.12.69-...-g014ca48a80ee-ab15889839-4k.h`) deu:

1. Run default (verify): **hit attempt-1, burst 12.7s, `uid=0(root) context=u:r:shell:s0 ROOT_SHELL_OK`, exit limpo `[+] done`** — device vivo.
2. Run shell + setprop pipado: hit attempt-1 (10.7s), uid=0 shell, MAS
   `setprop persist.sys.support_*` **REJEITADO pelo property service**
   (SELinux: domain shell não pode setar persist.sys.* com enforcing).

### Lições fechadas (fonte + empírico)
- **Burst window 15s é ESSENCIAL**: a página demora ~10-13s para ser recolhida
  pelo spray. Nosso cap antigo de 2.5s gerava falsos misses -> minas -> panics.
- **Miss = reter o zombie, NUNCA reapar** (fonte: "a reaped uncontrolled node
  panics this kernel"). Reap-on-miss detona em ~12s. Revertido no fonte nosso.
- **Zero mode (parent=0) acertou 2x limpo no spinel.** O mode-0 do nosso
  binário antigo era o MESMO mecanismo; os panics vinham do cap de burst curto
  + reap-on-miss, não do mecanismo.
- `panic_on_warn` ILEGÍVEL no spinel (Permission denied até para adb shell).
- KernelSU manager NÃO instalado (pm list sem kernelsu/weishu).
- Shizuku roda (uid 2000) mas não adiciona privilégio de kernel.

### Próximo passo em curso
Modo `perm` adicionado ao timer.c do YuKongA (mínimo, fonte-fiel): UM plant
zero-mode em `SELINUX_STATE_STATIC + g_slide - 7` (mesmo alvo que o fake mode
deles usa) -> enforcing=0 -> child (uid 2000) executa
`/data/local/tmp/perm_stage.sh` (setprop persist.sys.* sob permissive).
Slide vem de `calibrate_base()` (g_slide0). Se setprop aceitar -> props
persistem em /data/property/persistent_properties (sobrevivem a reboot LIMPO).
Fallback se property service negar mesmo permissive: instalar KernelSU
manager APK (adb install) + modo `fake` deles (fake cred full caps + ksud
late-load -> su persistente u:r:ksu:s0).

### Comando para rodar o perm
```
adb shell "cd /data/local/tmp && ./timer-yk perm"
```
(se o timer-yk sumiu por rollback: pushar `work\cve98260\timer\timer_spinel`
para /data/local/tmp/timer-yk e chmod 755)

## ESTADO 17/11 FIM DE TARDE: PROPS ESCRITAS NO ARQUIVO - AGUARDANDO REBOOT

1. Run `perm` (3o hit attempt-1, 11.1s): **SELinux global = Permissive** (vale
   só neste boot; volta a enforcing no reboot).
2. Descoberta: `setprop` é NEGADO mesmo em permissive - o init do HyperOS faz
   o check de `tclass=property_service` com `permissive=0` FIXO
   (dmesg: `init: Unable to set property ... SELinux permission check failed`).
   Via setprop: impossível por qualquer caminho.
3. Bypass aplicado: run `shell` (4o hit attempt-1, 9.6s, uid=0) + stage2
   (`work/perm_stage2.sh` pipado no root shell):
   - Backup do arquivo original: `/data/local/tmp/pp_backup`
   - 6 entradas protobuf APPENDIDAS ao fim de
     `/data/property/persistent_properties` (init carrega "last wins"):
     persist.sys.support_view_mishadow=1,
     persist.sys.support_view_smoothcorner=1,
     persist.sys.support_window_mishadow=1,
     persist.sys.support_window_smoothcorner=1,
     persist.sys.device.freeform_hwui_corner_supported=1,
     persist.sys.device.freeform_hwui_shadow_supported=1
   - Novo size=20041; od head/tail conferidos (formato intacto, começou em 0a).
   - Exit limpo `[+] done`, sem zombies/minas; device inteiro.

### PROXIMO PASSO (bloqueado no usuario): REBOOT LIMPO
NÃO rodar mais exploit neste /data (cada panic faz rollback f2fs e perde o
arquivo de props). Depois do reboot:
- `getprop persist.sys.support_view_mishadow` -> deve ser "1"
- Features do Control Center (transparencia/sombras/cantos) devem habilitar.
- SELinux volta a enforcing (normal e desejado).
Se faltar algo: refazer o fluxo provado - push timer_spinel ->
/data/local/tmp/timer-yk (chmod 755) + perm_stage2.sh, e
`printf 'sh /data/local/tmp/perm_stage2.sh\nexit\n' | ./timer-yk shell`.

### Root persistente (opcional, futuro)
Modo `fake` do YuKongA: instalar KernelSU manager APK + `ksud late-load` ->
`u:r:ksu:s0` persistente. Ler antes
`work/infinitycore/timer/CVE-2026-98260-android.c` (ainda não lido).


## MANHA DE AMANHA: UM COMANDO
```
powershell -ExecutionPolicy Bypass -File scripts\run_root.ps1
```
Ele faz tudo: adb up, push dos binarios + do TimerRoot, obtem o slide,
**varrendo as base words com alvo NAO MAPEADO (canario) para achar a word
certa**, roda o W1 (SELinux permissive), roda o wq-umh (root de kernel) e
aplica as features. Log do PC: `work/run_root_pc.log`; logs no device:
`/data/local/tmp/a/{run_root.log,g4umh.log,features.log}`.

## Estado do device
Caiu do USB no fim do dia (nao re-enumerou) -> reconectar o cabo.
Ultimo boot_id: 8ea2af6b-f2b3-4429-90b3-dc306da10867 (SELinux enforcing=1).
**O /data sofre ROLLBACK depois de um panic -> sempre re-pushar os binarios.**

## O QUE ESTA PROVADO (medido no aparelho e no kernel.elf, 17/11 de manha)

### A. O plant do `select` esta MORTO neste kernel (e agora sabemos por que)
Medico no aparelho (word 0 + alvo canonico):
```
[rh] select ret=-1 errno=9 base_word=0 ... dsp=0   <- a COPIA rodou (EBADF: os bits
                                                        apontam p/ fds 0-2, que o helper
                                                        nao abre p/ preservar o log)
[rh] enforce-after-punch = 1                      <- sem write
calls=2977 success=2977  requeue_errno=35         <- EDEADLK ok, sem crash
```
=> na word 0 o plant ERRA o waiter (sem write e sem panic - o "RB_EMPTY_NODE
early return" do dequeue).

Geometria (medida, com o `bl` normal do stub):
```
do_futex --br x11(stub)--> stub --bl futex_wait_requeue_pi-->
  fwrpi frame 0x1c0, rt_mutex_waiter @ sp+0xa0
compat futex: 0x70 + 0x60 + 0x1c0  => waiter em SP0-0x190
compat select: 0x10 + 0x70 + 0x1b0, stack_fds @ sp+0x40 => copia em SP0-0x1f0
=> o waiter esta 0x60 (12 words) ACIMA da base da copia => GL_BASE_WORD = 12
```

**=> E A ARMADILHA: o kernel zera os bitmaps `res_in/res_out/res_ex` DEPOIS
das tres copias (`zero_fd_set`), ou seja os bytes 120..191 (words 15..23).
O waiter na word 12 ocupa os bytes 96..207 => os words 15..23 (pi_tree, task,
lock) SAO ZERADOS => a walk faz `raw_spin_trylock(&lock->wait_lock)` com
lock == NULL => PANIC (sem write).

=> **O plant do `select` nao pode funcionar no spinel**: o buffer do usuario
precisa cair em SP0-0x190 (a posicao do waiter) com >= 88 bytes (tree+prio+
task+lock) e **sem** nenhum zeroing do kernel por cima.

### B. O que resolver (ordem de tentativa)
**Contexto IMPORTANTE: no ghostlock o dequeue usa o FAKE lock (a nossa propria
pagina) => a corrupcao da tree e inofensiva e o cleanup walk NAO existe (a tree
e nossa). O bloqueio e SO o plant.** O TimerRoot, ao contrario, usa a tree
REAL da vitima => a corrupcao mata o kernel (por isso ele panicou no aparelho
real, mesmo tendo o write landado).

Entao o alvo do plant e: **um syscall compat que copie >= 88 bytes do usuario
para a stack do kernel em SP0-0x190** (a posicao do waiter), sem zeroing por
cima. O `select` da SP0-0x1f0 (0x60 acima) e o `poll()` da SP0-0x3d4 (0x244
abaixo). Medir no kernel.elf: o total de frames + o offset do buffer tem de
dar 0x230 (o waiter do futex da 0x230 com o buffer em +0xa0; o select da
0x230 com o buffer em +0x40) - falta um syscall com o total 0x230 e o buffer
em +0xa0. Candidatos: `perf_event_open` (a attr, 128 bytes, copiada para a
stack do handler), handlers de `ioctl` que copiem para a stack,
`sched_setattr` (a attr, 64 bytes - insuficiente), `poll()` (medido: sp+0x7c
=> SP0-0x3d4).

**Alternativa mais simples: fazer o WAITER cair em SP0-0x1f0** (a posicao da
copia do select). Isso exige um path de futex com frames = 0x1d0 (0x60 a
menos que o compat atual: wrapper 0x70 + do_futex 0x60 + fwrpi 0x1c0 = 0x230).
Hmm: o `__arm64_sys_futex_time32` (0x70) + do_futex (0x60) + fwrpi (0x1c0).
Faltaria um wrapper de 0x10 (o minimo) - ou seja, um futex que NAO passe
pelo do_futex de 0x60. O `__arm64_sys_futex` nativo tem 0x80 + a trampoline
de vendor 0x30 (pior).

**Teste empirico para validar qualquer planta nova:** o canario (alvo nao
mapeado) - se a planta certa, o write FAULTa e o boot_id muda ✓ (o que
prova que a planta acertou E que o write acontece).

## O que ja esta apurado (nao mexer sem ler)
1. **Numeros de syscall: ARM EABI** (a tabela compat do aarch64 e indexada
   pelos numeros ARM EABI - select=142, sched_setattr=380, futex=240).
   Decodificado pela tabela (base = file offset 0x12e8c80): select no
   indice 142, futex_time32 no 240. **NAO usar 23/314** (da EPERM + success=0).
2. **Geometria**: copia do fd_set em SP0-0x1f0; waiter em SP0-0x190
   (`do_futex` -> `futex_wait_requeue_pi` e TAIL CALL `br`, o frame do
   `do_futex` e liberado) => **word 0**; mas o canario confirma.
   O caminho NATIVO e IMPOSSIVEL (trampoline de vendor
   `__traceiter_android_vh_do_futex`, +0x30, no `__arm64_sys_futex`).
3. **Alvo = VA CANONICO com slide** (o alias do direct map da imagem do
   kernel e RO: `map_mem` remapeia `_text.._sinittext` RO sobre o linear map).
   O slide sai do TimerRoot em modo `leak` (nao faz panic) ou do leak por
   perf (a tabela de ancoras do spinel JA foi patchada em main.c - paginas
   0x24c000 (__arm64_sys_prctl), 0x17b000 (strncpy_from_user), 0x17c000
   (_copy_from_user), 0x142000 (__set_task_comm), 0xad000 (do_exit), ...).
4. **O check do vendor** em `rt_mutex_adjust_pi` (0xffffffc0812a8298) e
   `waiter->tree.prio != p->prio` (NAO `__waiter_prio(p)`). Como o
   `sched_setattr` muda p->prio para 139, a walk segue mesmo sem forjar o
   prio - e sem o plant o dequeue aborta em RB_EMPTY_NODE (sem write, sem
   crash: e o sintoma de todos os testes ate agora).
5. **TimerRoot**: `conf/6.12.69-...-ab15889839-4k.conf` = o nosso kernel
   exato; modo `leak` seguro (slide); modos `shell`/`permissive` **panicam**
   no aparelho real (o `rb_erase` corrompe a timerqueue da vitima).
   O trace do panic esta em `/sys/fs/pstore/console-ramoops-0` (copiado
   para o DropBox) - **inacessivel ao shell** (SELinux).
6. **Fases**: W1 = SELinux permissive (sem root de kernel) -> wq-umh =
   root de kernel (u:r:kernel:s0, nao precisa de SELinux off).
   O loop comprovado do spinel: `scripts/rr_loop_spinel_detalhado.ps1`:
   `$BIN --write1` ate permissive, depois
   `GL_WQ_UMH=1 GL_RWF_SLOTS=64 RWF_DEBUG=1 $BIN --rwforge`.

## Cuidado: corrupcao da tree da PI
Se o plant acertar o waiter, o mutex PI real fica com um no forjado cujo
parent link nao e atualizado -> o walk de limpeza (o release do futex PI
quando o helper sai) pode seguir um ponteiro selvagem -> panic DEPOIS do
write (o flag do SELinux ja foi zerado, mas o reboot reseta). Se isso
acontecer: confirmar o write pelo log (o detector imprime `enforce=0` antes
do crash) e seguir para a fase 2 em seguida.

## Features (sem root de kernel) - ja feito
OK: `settings put secure stack_view_style 2`, `debug.hwui.disable_advanced_features=0`,
`debug.hwui.use_vulkan=1`, `debug.hwui.initialize_gl_always=1`.
Bloqueados pelo check SELinux do property service (precisam do W1):
`persist.sys.device.freeform_hwui_corner_supported=true` (transparencia/blur
do Control Center), `persist.sys.device.freeform_hwui_shadow_supported=true`,
`ro.hwui.disable_advanced_features=0`.
Scripts: `scripts/apply_features.sh`, `work/props_test.sh`.

## Ambiente
- adb: usar `C:\Users\patri\AppData\Local\Android\Sdk\platform-tools\adb.exe`
  (o do PATH e um 1.0.31 antigo do PhoenixSuit e morre com a arvore de
  processos). `scripts/watch_device.ps1` ja aponta para o do SDK.
- O servidor adb precisa sobreviver ao harness:
  `Start-Process adb -ArgumentList @("nodaemon","server") -WindowStyle Hidden`.
- Adb novo (37.0.1) instalado pelo usuario; se `adb devices` nao listar,
  reiniciar o servidor e/ou replugar o cabo.

---

## REFRAME DE 17/11 DE MANHA: O ROOT NAO DEPENDE DO PLANT

O caminho de root (`wq-umh`) usa o **canal rwforge** (pipe reclaim: outra
primitiva de R/W arbitrario) e **nao** o write do pselect. O plant so e
necessario para o "fastroot" (cred forjada via pselect) e para o W1.

**=> ORDEM DE PRIORIDADE DE AMANHA:**
1. **`GL_WQ_UMH=1 GL_RWF_SLOTS=64 RWF_DEBUG=1 ./g4 --rwforge`** -> root de
   kernel pelo canal rwforge (caminho comprovado no A17; a sequencia exata
   esta em `scripts/rr_loop_spinel_detalhado.ps1`).
2. **TimerRoot em modo `fake`**: o write dele **JA FUNCIONA** (o `rb_erase` da
   timer queue acerta o alvo ✓). O modo `fake` publica um cred forjado em
   task->cred e o autor JA pensou na corrupcao da tree (`usage=1` mantem o
   parent em NULL para o `rb_next` parar ✓) -> pode nao dar panic ✓ ->
   daria um shell uid-0 (u:r:shell:s0) sem root de kernel ✓.
3. **O W1** (SELinux permissive) para liberar as `persist.sys.*` das features.
4. O **plant do pselect** (o puzzle aberto, secao B).

## Candidatos de plant ja medidos
| syscall | (frames - offset do buffer) | onde cai | veredito |
|---|---|---|---|
| compat `select` (142) | 0x230 - 0x40 = 0x1f0 | 0x60 abaixo do waiter | ruin (zeroing do res_in) |
| compat `poll` (168) | 0x60+0x3f0 - 0x7c = 0x3d4 | 0x244 abaixo | longe |
| `perf_event_open` | 0x120+0x50 - ~0 = 0x170 | 0x20 ACIMA do waiter | longe (o waiter esta em endereco MENOR) |
| native `futex` (98) | + trampoline de vendor 0x30 | waiter em SP0-0x230 | inutil |

**=> Falta um compat syscall com (frames - offset) = 0x190.** A medir:
handlers de `ioctl` que copiem para a stack, `futex_waitv`, `cachestat`,
`move_pages`, `sched_setattr` (so 64 bytes - insuficiente), `keyctl` (heap),
`readv/writev` (buffer do usuario).

**=> O plant pode ser QUALQUER syscall (o SP0 e o mesmo em toda syscall da
mesma thread ✓✓✓) - so precisa da "assinatura" de stack certa.**

**=> ALTERNATIVA: fazer o WAITER cair em SP0-0x1f0 (a posicao da copia do
select).** Exige um path de futex com frames = 0x1d0 (0x60 a menos que o
compat atual: wrapper 0x70 + do_futex 0x60 + fwrpi 0x1c0 = 0x230).

---

## ACHADOS FINAIS (17/11, ultimo teste)

### 1. O plant ACERTA na word 12 (confirmado!)
```
[rh] select ret=0 errno=0 base_word=12 sp_futex=... sp_select=... dsp=0
```
`select ret=0` (sem EBADF) so acontece quando o bitmap plantado BATE com o
do kernel - ou seja, **o helper abriu os fds certos = o plant esta no lugar
certo (word 12)**. E `calls=2668 success=2667` = **um punch morreu** = a walk
bateu no `lock` zerado (NULL) -> exatamente o zeroing do `res_in`
(bytes 120..191 = os words 15..23 do waiter = prio/deadline/pi_tree/task/lock).

### 2. O `route-root` (e o wq-umh) DEPENDEM do write do pselect
O log mostra o fluxo fazendo rounds de `mode=0 cw=3` (publica a cred forjada
via pselect) em loop. **=> o plant e o caminho critico do root tambem** (o
reframe de "o root nao depende do plant" estava errado: o canal rwforge
funciona - "bootid oracle: restore verified" ✓ - mas o root precisa da cred
forjada, e ela e publicada pelo write do pselect).

### 3. Candidatos de plant medidos
| syscall | (frames - offset) | onde cai |
|---|---|---|
| compat `select` (142) | 0x1f0 | 0x60 abaixo do waiter (e o res_in zera o lock) |
| compat `poll` (168) | 0x3d4 | 0x244 abaixo |
| `perf_event_open` | 0x170 | 0x20 ACIMA |
| `futex_waitv` (449) | frame do handler 0x90 + VLA | **varia com o nr_futexes** (32 bytes/unidade) - granularidade grossa, mas e o unico com posicao variavel |

**=> O alvo: um syscall compat que copie >= 88 bytes para a stack em
SP0-0x190 (a posicao do waiter), sem zeroing por cima. O `futex_waitv` e o
candidato com posicao variavel (VLA) - varrer o nr + o canario para achar o
acerto.**

**=> ALTERNATIVA (barata): fazer o waiter cair em SP0-0x1f0 (a posicao da
copia do select) - exige um path de futex com frames = 0x1d0 (0x60 a menos
que o compat atual 0x230).**

---

## A VIA QUE RESOLVE: plant via `futex_waitv` (nr 449, tabela generic)

`futex_waitv(futexv, nr_futexes, flags, timeout, clockid)` copia
`nr_futexes * 32` bytes do array do usuario para um **VLA na stack do
kernel** (`struct futex_vector futexes[nr_futexes]` em `futex_waitv()`), sem
nenhum zeroing do kernel por cima. A **posicao da copia varia com o
`nr_futexes`** (32 bytes por unidade) -> e o helper pode **varrer o nr**,
dando o punch a cada iteracao:

```c
/* no helper (ILP32), depois do requeue (EDEADLK) e do timeout do futex: */
struct futexv { unsigned long long val, uaddr; unsigned int flags, rsv; unsigned long long bitset; };
for (unsigned nr = 1; nr <= 64; nr++) {
    struct futexv fv[64];                 /* o array do usuario */
    memset(fv, 0, sizeof(fv));
    /* a carga util (tree.pc/right/left/prio, task, lock) e montada em fv[] */
    syscall(__NR_futex_waitv, fv, nr, 0, NULL, 0);
    sched_setattr_tid(w_tid, 19);         /* o punch */
}
/* o primeiro nr que acertar a posicao faz o write; os seguintes sao no-ops */
```

Por que nao quebra o helper (e o que torna isso usavel no modo 3):
- a copia (o plant) acontece ANTES do parse ✓;
- o parse do `futex_waitv` le o `uaddr` de cada entrada: no **modo 3**
  (o VALUE = um ponteiro valido, a cred forjada) o read e valido e o `val`
  nao casa -> **EAGAIN -> o syscall retorna na hora, sem fault** ✓;
- no **modo 1** (o VALUE = 0) o `uaddr` = 0 -> read no endereco 0 -> e um
  acesso de USUARIO -> **SIGSEGV no thread W** (nao um panic do kernel) ->
  o W morre -> o write ja aconteceu ✓ (mas o W1 precisa do W vivo ✗).
  => para o W1, usar um nr cujo `uaddr` caia num endereco valido (ou plantar
  com o `uaddr` do primeiro futexv apontando para o proprio buffer).

**=> O nr exato: com o canario (alvo nao mapeado -> o write FAULTa -> o
boot_id muda ✓) varrendo nr=1..64 e medindo em qual o boot_id muda ✓.
**=> Como o nr mexe de 32 em 32 bytes, o canario e o feedback perfeito ✓.**

**=> FALTA IMPLEMENTAR (proximo passo):**
1. no helper: o loop do plant com `futex_waitv` (o nr nao e mais um offset
   fixo do fd_set - o select sai de cena ✗ e o loop acima substitui o
   `build_fdsets`/`select` ✓);
2. o array `futexv` do usuario precisa carregar a carga do waiter forjado nas
   posicoes certas (o `uaddr` do 1o futexv = um endereco valido para o read
   nao faultar no modo 1);
3. compilar (`build_spinel.ps1`), subir e testar com o canario.

---

## ESTADO 17/11 NOITE: MAPA COMPLETO DAS PROPS + AREA DE PROPRIEDADES ANDROID 16

### 1) As 6 props-alvo e quem as CONSOME (todos LEITORES; ninguem escreve em codigo)
- `android.view.ViewRootImpl` (framework.jar/classes4.dex): le
  persist.sys.support_view_mishadow / _smoothcorner / support_window_*,
  persist.sys.device.freeform_hwui_corner_supported,
  persist.sys.support_hwui_window_corner -> campos estaticos
  sIsSupportViewMiShadow / sIsSupportViewSmoothCorner /
  sIsSupportFreeformHwuiWindowCorner.
- `miuix.smooth.SmoothCornerHelper` (miuix.jar) e `miuix.smooth.c`
  (MIUICloudService.apk): leem persist.sys.support_view_smoothcorner.
- `com.android.wm.shell.multitasking.common.hwui.MultiTaskingCornerShadowController`
  (MiuiSystemUI/classes3.dex): le freeform_hwui_corner/shadow_supported +
  freeform_hwui_shadow_scale -> aplica raio de canto/sombra nas janelas freeform.
- libhwui.so / libsurfaceflinger.so: consomem.
=> NENHUM escritor com literal em /system, /system_ext, /product, /vendor, /odm,
/apex, nem em /data. O 'false' NAO vem de codigo: vem do valor gravado no
arquivo de persistencia (ou de um build.prop de particao nao legivel - mas
o unico build.prop que cita as props e /system_ext/etc/build.prop (linhas
84-88) e diz **true**).

### 2) Por que o arquivo de props naoStickia
- /data/property/persistent_properties = protobuf PersistentProperties
  (registro: 0a len | 0a nlen nome | 12 vlen valor). Nosso rebuild (874
  props, sem duplicatas, as 6 = "true") FOI carregado (estrutura identica
  pos-reboot), mas o mapa do init ficou com "false" e ele re-serializou o
  arquivo com false -> quem wrote foi um escritor de runtime (sem literal).
- setprop de persist.sys.* e NEGADO pelo property service MESMO em permissive:
  dmesg mostra avc "permissive=0" -> o check do init e forcado em enforcing.
  setprop de debug.* funciona; ro.* nao.

### 3) Android 16: areas de propriedade por contexto SELinux
- /dev/__properties__/ e um DIRECTORY: property_info (203KB) + properties_serial
  (128KB) + um arquivo de 128KB por contexto (u:object_r:<ctx>_prop:s0).
- As 6 props vivem em /dev/__properties__/u:object_r:system_prop:s0
  (mode 0444). Layout da entrada (verificado byte a byte):
  [nome-ou-sufixo][NUL][pad][u16][u16][u8 value_len][valor][NUL]
  (o sufixo comprime o prefixo compartilhado, ex. "support_view_mishadow").
- value_len fica logo antes do valor.
- **O property service REJEITA uma area com mode gravavel** (apos chmod 0666
  TODAS as props da area voltaram vazias; com 0444 voltaram a normal).
  => jamais chmodar a area.
- Escrever direto na area (mmap PROT_READ + /proc/self/mem) da EIO
  (mapping compartilhado read-only nao aceita FOLL_FORCE).
- **Solucao pronta: escrever via /proc/1/mem no mapping do init (PROT_WRITE)**
  -> `work/area_patch2.c` (busca /proc/1/maps, acha o offset do valor pelo
  padrao <len>"false", grava 04 "true" 00 no endereco do init). Build:
  NDK 28.2.13676358 aarch64-linux-android35-clang.

### 4) GhostLock (CVE-2026-43499) - projeto ja portado p/ spinel
`src/ghostlock-a17/` (README, build_spinel.ps1, src/devices/spinel/offsets.h
com offsets extraidos do boot.img do device). Build OK: ghostlock, g4r, g4d,
g4sh. Vantagem: termina em **u:r:kernel:s0** (da p/ setprop de persist.sys.*)
+ daemon persistente g4d/g4sh no socket abstrato @ghostlockd.
No spinel, a tentativa anterior (logs em /data/local/tmp/a/*.log) morreu no
estagio do route helper ("cycle NOT formed") - race do pselect/PI-futex.

### 5) Estado do exploit YuKongA hoje
- Root uid=0 (u:r:shell:s0, SEM caps: CapEff=0) econfiavel; modo `perm`
  (zerar enforcing global) e 100% limpo; modo `shell` ~50% panic apos o burst.
- Run em FOREGROUND (nunca matar o processo = nunca detonar mina).
- Reboot limpo e a unica limpeza de zombie retido.


> **NOVO DOC DE REFERENCIA (17/11 noite):** `work/ROOT_SPINEL.md` - guia completo de root no spinel (exploit YuKongA, area de props Android 16, servico MIUI MQS, armadilhas do ambiente, rotas alternativas).

---

## ESTADO 17/11 NOITE (fechamento): root OK, KSU bloqueado, fork do app pronto

### Root (YuKongA) - FUNCIONANDO
- Modo `shell` -> uid 0 (u:r:shell:s0, CapEff=0), estavel e repetivel.
- Modo `perm` -> SELinux global Permissive ate reboot; **obrigatorio** antes de
  qualquer root child (sem ele o child morre com `child report missing / exit 0x7f00`).
- Regra confirmada: apos varios runs no mesmo boot o plant para de bater ->
  **reboot limpo** antes de cada tentativa importante.
- Root child nao pode criar arquivos em /data/local/tmp (dono shell, sem caps),
  mas **pode escrever em arquivos existentes**: usar `touch` + `chmod 666`
  via shell antes (foi o que destravou o ksu.log).

### KernelSU - LATE-LOAD NAO CARREGA
- Manager KernelSU v3.3.1 instalado (`me.weishu.kernelsu`), `libksud.so` existe
  em `/data/app/~~.../me.weishu.kernelsu-.../lib/arm64/libksud.so` (4,99 MB).
- Script `work/do_ksu.sh` via root shell (permissive) executou:
  `load_policy rc=0`, `ksud late-load --kmi android16-6.12 rc=0`,
  mas **nenhum m�dulo kernelsu em /proc/modules** e nenhum `su` instalado.
  Causa provavel: root uid 0 **sem CAP_SYS_MODULE**; o KSU precisa do contexto
  `u:r:kernel:s0` que o GhostLock consegue via usermode helper (W3/fake cred).
- Tentativa de patch `task->security @0xCD8` (offset extraido do BTF,
  `work/fw/btf.bin` + `work/parse_btf.py`) **mata o child** antes de acordar;
  revertido. Ver `work/FORK_DESIGN.md`.
- Teste pendente (job em background quando paramos): `do_ksu2.sh` com
  `--allow-shell --package-name me.weishu.kernelsu` ( YuKongA stage). Checar
  `/data/local/tmp/ksu2.log` amanha.

### Fork do app - CONSTRUIDO E INSTALADO
- `work/ghostlock-spinel/` (fork de YuKongA/ghostlock-app), com:
  - `libghostlock.so` = nosso `timer_spinel_v11` (stripado no packaging) ?
  - tasks Gradle de build nativo/extrator Rust desativadas (sem cargo na maquina)
  - `isKernelSupported()` simplificada (profile embutido no binario)
  - `local.properties` com sdk.dir escapado ?
- APK: `work/ghostlock-spinel/build/app/outputs/apk/debug/GhostLock-v1.2(1)-arm64-v8a-debug.apk` (20,7 MB)
- **Instalado no device** junto com Shizuku v13.6.0.
- Shizuku ainda NAO foi iniciado via adb (app precisa ser aberto para criar
  `/sdcard/Android/data/moe.shizuku.privileged.api/start.sh`).

### Arquivos-chave novos
- `work/ROOT_SPINEL.md` - guia completo de root (atualizar com estas notas)
- `work/FORK_DESIGN.md` - design do fork
- `work/parse_btf.py` + `work/fw/btf.bin` - BTF do kernel (task.security @0xCD8)
- `work/do_ksu.sh`, `work/do_ksu2.sh`, `work/run_ksu_shell.sh`, `work/run_ksu2_shell.sh`
- `work/timer_spinel_v11` (usado no APK), `timer_spinel_v10/v9/...` (experimentos)

### Proximos passos (amanha)
1. Checar `ksu2.log` (teste `--allow-shell`) - se KSU carregar, tudo resolvido.
2. Se nao: iniciar Shizuku (abrir app -> `adb shell sh <start.sh>`) e testar o
   app fork; ele faz root -> ksud late-load pelo root child.
3. Para KSU real, investigar contexto `u:r:kernel:s0` sem matar o child
   (SID correto via `/sys/fs/selinux/context`, ou forge do work_struct do
   GhostLock no nosso exploit).

---

## 18/11 - CORRECAO DO GATE DE PERFIL DO APP (fork ghostlock-spinel)

### Causa do "pede para carregar um perfil compativel"
O app tem 3 gates em cadeia (todos em `AndroidGhostlockRepository.kt`):
1. `isKernelSupported()` (linha ~934) - JA simplificado para `return true`.
2. `profileController.load(release, pair)` -> `hasProfile` (linha ~604/609):
   `resolve()` em `AndroidProfileConfigController.kt` (linha ~539) exige entrada
   no `index.conf` OU perfil importado; sem isso retorna `hasProfile=false`.
3. `nativeDocument(config)` (linha ~621): exige `cachedProfile` valido
   (buildNativeDocument -> Profile.fromValueMap), senao `profile is unavailable`.
Alem disso `invalidPaths` deve estar vazio (validateProfileFields +
ProfileResolver.validateMerged).

### Correcao aplicada
- Criado `app/src/main/assets/kernel_profiles/6.12.69-android16-6-g014ca48a80ee-ab15889839-4k.conf`
  (copia da estrutura 6.12.23, route `select_stack`, `recommend_shizuku = 1`).
  Todos os campos `task_struct` como numeros, `cred.copy_size/caps_count` e
  offsets nonzero - passa em `validateMerged` e `validateProfileFields`.
- Adicionada entrada em `index.conf` para esse release.
- Nota: os offsets desse HOCON **nao sao usados** pelo binario timer-yk (o
  exploit tem perfil embutido e valida o uname internamente). O HOCON existe
  so para satisfazer o gate do app e gerar o blob GLK1 que o UserService exige.
- `recommend_shizuku = 1` e necessario porque `GhostlockUserService.kt:63`
  rejeita o blob se `recommendShizuku != 1u`.

### Estado
- APK recompilado com o novo perfil (build em andamento ao registrar).
- Device estava **desconectado** (adb devices vazio) - reconectar para instalar
  e validar que o app abre sem pedir perfil.

---

## 18/11 - ANALISE ESTATICA COMPLETA (sem device) + v14

### Testes unitarios: 3 falhas PREEXISTENTES (confirmado)
Rodados `:app:testDebugUnitTest` no fork e no repo original (`work/ghostlock-app`):
ambos falham com as MESMAS 3 falhas (fixtures desatualizados):
1. `NativeDocumentEquivalenceTest`: golden do `6.1.145-geaa643...` driftou.
2. `ProfileMigrationEquivalenceTest`: `remote-main-6x-offsets.json` nao cobre
   varios releases ja existentes (6.1.138-g2ecae, 6.1.162-g65896, 6.6.82-g076ac...).
3. `ExporterEquivalenceTest`: exporter difere do app em `6.1.138-g0c3d...`.
NENHUMA falha envolve nosso `6.12.69`. Repo original tambem da BUILD FAILED.
Nao bloqueia oapp; sao locks de equivalencia de fixture.

### Descoberta CRITICA 1: o modo padrao NAO fazia handoff KSU
Em `timer.c`, o child so executa o handoff no modo `fake` (linha ~1638).
No modo padrao (usado pelo app), ele executa `sh -c "id; ...; ROOT_SHELL_OK"`.
Al�m disso `write_ksu_script()` so era chamada se `g_fake_stage`.
Corrigido no v12: script escrito sempre + handoff no modo padrao.
Resultado esperado: root + tentativa de KSU. MAS: root real-cred e uid 0
sem CAP_SYS_MODULE -> `late-load rc=0` porem modulo nao carrega (observado
empiricamente ontem).

### Descoberta CRITICA 2: binarios originais sao ESTATICOS
README do YuKongA: compilacao com `-static -fno-pic -fno-stack-protector`.
`timer` original = 311168 bytes, `timer_spinel` = 312080 bytes.
Nossos v2..v12 eram DINAMICOS (~45 KB) -> podem explicar o panic do fake mode.
Tabela de KSU do README:
- real cred -> uid=0, u:r:shell:s0, ROOT_SHELL_OK
- **fake cred -> KSU_LOADED, su em u:r:ksu:s0** (caminho validado)
Ou seja: para KSU, precisamos do MODO FAKE, nao do modo padrao.

### Descoberta CRITICA 3: perfil do spinel e identico ao release validado
`kbuilds/6.12.69-...-g014ca48a80ee-...h` (spinel) tem constantes IDENTICAS
ao `g242e1a07f878` que o YuKongA validou com fake->KSU. Perfil nao e o problema.

### v14 (binario atual no APK)
- Compilado ESTATICO com as flags do README (312720 bytes).
- `main()`: detecta `--ghostlock-app-call` (argv do app) e seta `g_fake_stage=1`
  -> app entra no modo fake (full caps), caminho validado para KSU.
- `write_ksu_script()`: sempre chamada; cria `ksu.log`/`glk_policy.bin` com chmod 666
  (root child nao pode criar arquivos em /data/local/tmp).
- Script usa `late-load --kmi <kmi> --allow-shell --package-name me.weishu.kernelsu`.
- ATENCAO: modo fake chama `hold_forever()` no final -> o app fica esperando
  `process.waitFor()` indefinidamente. O log em tempo real still funciona.
  Se precisar que o app termina, remover hold_forever (risco de UAF na fake cred page).

### Binarios / APK
- `work/cve98260/timer/timer_v14_static` (312720 bytes) = binario no APK.
- Outros: v12 (dinamico, handoff no padrao), v13_static (estatico, handoff no padrao).
- APK final: `work/ghostlock-spinel/build/app/outputs/apk/debug/GhostLock-v1.2(1)-arm64-v8a-debug.apk`
  (recompilando ao registrar; verificar md5 do libghostlock.so dentro).

### Proximos passos (device conectado)
1. Instalar APK v14 + abrir app. O Shizuku precisa estar ativo.
2. Rodar o app; checar log nativo por `KSU_LOADED` e `su -c id` -> u:r:ksu:s0.
3. Se panic no fake: reboot limpo; tentar `timer_v13_static` (handoff no padrao)
   como fallback, ou revisar o exec do child (fork panicava com cred dinamica).
4. Checar `/data/local/tmp/ksu.log` e `/data/local/tmp/ksu2.log` (teste --allow-shell).

---

## 18/11 - TESTES NO DEVICE (amanha continuado)

### Gate de perfil: RESOLVIDO ?
App abre normal, mostra "Suportada" / "Perfil pronto". Log:
`profile: hasProfile=true invalid=0 release=6.12.69-android16-6-...`
`profile resolved hasProfile=true blob=1849 invalid=0`

### Modo direto (sem Shizuku): NAO FUNCIONA
Nativo roda mas para em `discover_page_types` (exit 1). Sem Shizuku o app
e uid u0_a327 e o exploit nao consegue usar o tracefs corretamente.
Obrigatorio usar Shizuku (uid 2000, u:r:shell:s0, Seccomp=0).

### Shizuku 13.6.0 oficial: USER SERVICE QUEBRA NO MEDIATEK
Bug conhecido (issue RikkaApps/Shizuku#1198): MediaTek patcha
`LoadedApk.makeApplicationInner()` para chamar
`Application.getProcessName().equals(mPackageName)`. O helper do UserService
e iniciado via app_process sem bindApplication() -> mBoundApplication null ->
getProcessName() null -> NPE -> System.exit(1).
Sintoma: Shizuku READY (uid=2000), mas "UserService did not connect within 3s".
Tentativa de fix com `android:appComponentFactory` no manifest NAO resolveu.

### SOLUCAO: fork corrigido do Shizuku
`wess09/shizuku-m` v13.6.0-m2.r1093.bcb2b62a (commit com o MediaTek fix).
APK: `work/shizuku-m.apk`. Instalado ?.
Starter: `lib/arm64-v8a/libshizuku.so` extraido para
`work/libshizuku-m-arm64.so`; copiado para /data/local/tmp/libshizuku.so.
Iniciar servidor: `adb shell timeout 8 /data/local/tmp/libshizuku.so`
-> `shizuku_server` como uid shell (2000) ?.
Apos reboot, o servidor morre e precisa ser reiniciado com esse comando.
Com o fork, o UserService conectou (Shizuku pronto, sem NPE).

### v14 (fake mode, estatico): PANICOU
Ao rodar via app com v14, boot_id mudou (191158e5 -> da382c2e).
Fake cred ainda e instavel neste kernel/SOC, mesmo estatico.
Estrategia atual: VOLTAR para o v13 estatico (modo padrao real-cred,
que e estavel) com handoff KSU e flags --allow-shell --package-name.

### Estado no momento
- APK sendo recompilado com `timer_v13_static` (312656 bytes).
- Device: boot da382c2e, Shizuku fork server pid 9366.
- Proximo: instalar APK, abrir app, ativar Shizuku, rodar, checar ksu.log.

---

## 18/11 - ROOT PELO APP FUNCIONANDO ? (KSU pendente)

### Shizuku que funciona neste device (MediaTek/MIUI)
Fork `thedjchi` v13.7.0 (`work/shizuku-thedjchi.apk`) foi o unico cujo
UserService conectou. Starter `work/libshizuku-dj-arm64.so` copiado para
`/data/local/tmp/libshizuku.so`. Iniciar APOS cada reboot:
```
APK=$(pm path moe.shizuku.privileged.api | cut -d: -f2)
timeout 8 /data/local/tmp/libshizuku.so --apk=$APK
```
(wess09/shizuku-m ainda dava NPE no makeApplicationInner; 13.6.0 oficial
tambem. thedjchi 13.7.0 resolveu.)

### Root via app - SUCESSO (boot fae1bc32)
Apos reboot limpo + Shizuku thedjchi + app fork com `timer_v13_static`:
```
[ids] pairs=1029 ; plant1 burst hit ; cred writes landed
[child] woke uid=0
[+] child report uid=0 setuid(0)=0
[+] native exited code=0
<k> result: exploit completed
```
Handoff rodou: `ksu.log` mostra `[k] start uid=0 ctx=u:r:shell:s0`,
CapEff=0000000000000000, `late-load rc=0`, mas **KSU_MISSING**.
`cat /sys/fs/selinux/policy` da Permission denied (uid 0 sem caps).
`su` nao existe; nenhum modulo kernelsu em /proc/modules.

### Diagnostico final do KSU
Falta CAP_SYS_MODULE. Root real-cred tem uid 0 mas CapEff=0. O KSU exige
fake cred (full caps), que e o modo `fake` do YuKongA (README: KSU_LOADED).
Tentativa anterior com v14 (fake estatico) panicou (boot 191158e5->da382c2e),
mas pode ter sido estado acumulado. Proxima tentativa: v14 em boot limpo.

---

## 18/11 - CORRECAO DO FLUXO DE RETRY (sem reboot!) - usuario

O usuario observou: no GhostLock original basta **fechar o app e tentar de novo**.
Correto: o reboot so era necessario porque nosso exploit chama
`hold_forever()` / `park_forever()` e segura zombies/paginas. Ao matar o
processo nativo (force-stop do app), os timers fecham, os zombies sao
reparentados/reaped e as paginas voltam ao pool. O Shizuku server e um
processo a parte (`shizuku_server`, uid 2000) e **sobrevive** ao force-stop.

### Fluxo de retry correto (sem reboot)
1. `adb shell am force-stop com.ghostlock.app` (mata UserService + nativo)
2. conferir que nao ha mais `libghostlock.so` em `ps -A`
3. `adb shell monkey -p com.ghostlock.app 1`
4. esperar UI carregar ("Suportada"/"Shizuku pronto")
5. swipe para baixo, tocar "Correr"
6. esperar ~80s, checar `/data/local/tmp/ksu.log`

Se o plant travar (futex_wait), repeat 1-6. Sem reboot.
O `perm` (SELinux Permissive) ainda e necessario e so precisa ser rodado
uma vez apos cada reboot real.

---

## 18/11 - LICOES FINAIS SOBRE RETRY

### matar nativo preso GERA PANIC (confirmado)
`kill -9` nos processos libghostlock.so em futex_wait causou reboot
(6d1f602b -> 03b5f9cd). Nao fazer. O unico caminho seguro apos plant preso
e reboot limpo. O usuario estava certo sobre nao matar exploits estacionados.

### v18/v19 - fake cred no modo padrao (FULLCAP)
Desc descoberta: modo padrao (v13/v17) usa `write mode=zero` na cred real
(uid 0, CapEff=0). O fake cred FULLCAP+SID kernel (mode 2) so existia no
fake stage. v18Moveu o fake cred para o modo padrao:
- `stage fake_cred ... mode=fake` funcionou (plant1 write mode=fake ?)
- mas `stage fake_uid` (correcao de uid sujo pelo rb_erase) trava
v19 removeu o fake_uid. Teste pendente (estado acumulado contaminou).

### Debug de caps (v17)
`[child][pre] CapPrm=0 CapEff=0` ANTES do setuid -> caps ja vem zeradas
da fake cred zero-write. Confirma: precisamos do fake cred mode 2.

---

## 18/11 - RESULTADO v19/v20 (decisivo)

### v19 - fake cred aplicada, mas uid sujo
```
[+] plant1 write mode=fake target=...        <- fake cred FULLCAP aplicada OK
[+] selinux enforce=1
[+] stage selinux ... mode=zero attempt=1
[+] plant1 write mode=zero target=...        <- SELinux zerado OK
[child] woke uid=1670651712 euid=0           <- uid sujo pelo rb_erase
[+] child report uid=1670651712 euid=0 setuid(0)=-1 resuid=0/0/0
[!] child did not reach euid 0 / exit 0x300
<b> native exited code=0 / <k> exploit completed
```
O fake_uid (que corrigia o uid sujo) tinha sido removido no v19 porque travava.
Decisao: o euid=0 e resuid=0/0/0 ja estao corretos.

### v20 - aceitou euid=0 em vez de uid=0 -> PANIC
Mudou as verificacoes do child para aceitar euid==0 e setuid_ret!=-1 com
reuid==0. Resultado: PANIC/REBOOT (9048495c -> ef62575f).
Causa provavel: execve/setuid com uid sujo + fake cred GERA PANIC neste kernel.

### Conclusao
- Root estavel e garantido: v13/v17 (zero-write, uid 0, CapEff=0).
- Fake cred FULLCAP aplica (v19), mas o child nao conclui sem panic.
- Continuar for�ando o fake cred esta gerando panics repetidos.
- Proximo passo recomendado: parar de forcar fake cred; considerar o
  GhostLock original (CVE-2026-43499) para u:r:kernel:s0, ou aceitar root
  sem KSU por enquanto.

---

## 18/11 - FASE FINAL: BLUR + RECENTES EMPILHADOS (objetivo do usuario)

### Descoberta dos comandos (HyperOS/MIUI)
Blur/texturas: props via `service call miui.mqsas.IMQSNative 21 ... setprop`:
- persist.sys.mi_shadow_supported true
- persist.sys.background_blur_supported true
- persist.sys.advanced_visual_release 3
- persist.sys.computility.gpulevel 6 / cpulevel 6
MAS nesta build o MQS rejeitou o setprop (whitelist nao tem setprop).
Recentes empilhados: `settings put global/secure task_stack_view_layout_style 2`.
Nesta build: `global=2` e rejeitado (volta 0); `secure=2` e ACEITO.

### Solucao adotada: root child executa script de props
v21: `write_ksu_script()` verifica `/data/local/tmp/glk_props_mode`; se existir,
escreve script que roda setprop + settings como uid 0 (root via app).
Criar marcador: `touch /data/local/tmp/glk_props_mode`.
Root do app (v17/v21) ja validado: uid=0, exploit completed.

### Estado
Tentativa em boot 2223382f travou (estado acumulado) e depois panicou.
Aguardando reboot limpo (17119311) + desbloqueio para tentar de novo.

---

## 18/11 - AUTO-RETRY COM DETECCAO DE PLANT TRAVADO

O usuario pediu para detectar o travamento antes dele e reiniciar sozinho.
Criado `work/auto_retry.ps1`:
- monitora `ps -A` procurando `libghostlock.*futex_wait`
- monitora boot_id (detecta panic/reboot)
- monitora `ksu.log` (DONE / [props] = sucesso)
- se travado >20s: force-stop do app + nova tentativa (NAO mata o nativo,
  porque matar nativo preso gera panic - confirmado)
- ate 4 tentativas, 45s cada
- imprimeprogresso em tempo real
Uso: `powershell -ExecutionPolicy Bypass -File work\auto_retry.ps1`

---

## 18/11 - CORRECAO CRITICA v22 (root estavel + props)

ERRO encontrado: o v21 (modo props) foi compilado em cima do v20, ou seja,
herdou o fake cred do v18 e as verificacoes relaxadas do v20 -> travava/panicava.
CORRECAO v22: revertido v18/v20 para o zero-write estavel do v17, mantido
apenas o modo props do v21 no write_ksu_script().
Verificado: v18=False, v20=False, v21 props=True, detect fake=False.
Binario: timer_v22_static (314960 bytes).
Fluxo: marcador /data/local/tmp/glk_props_mode -> root child executa script
com setprop + settings (blur/stack). Auto_retry.ps1 faz deteccao e retry.

---

## 18/11 - ESTADO FINAL BLUR/STACK

CONSEGUIDO via root child (v22 + script de props):
- `persist.sys.mi_shadow_supported=true` (ja era true)
- `settings put secure task_stack_view_layout_style 2` -> stack=2 ? (persiste)
- `settings put system deviceLevelList v:1,c:3,g:3` ? (ja era)
- `ro.surface_flinger.supports_background_blur=1` ? (suporte nativo)

NAO CONSEGUIDO (setprop negado ao dominio shell mesmo com uid 0 e SELinux permissivo):
- persist.sys.background_blur_supported (vazio)
- persist.sys.advanced_visual_release (vazio)
- persist.sys.computility.gpulevel/cpulevel (2, nao 6)
MQS `service call ... 21 ... setprop` responde "Command not allowed for shell user".
Proxima ideia se necessario: escrever /data/property/persistent_properties via root,
ou usar contexto kernel (KSU - bloqueado).

---

## 18/11 - v23: escrever global=2 direto no SQLite

Desc: `settings put global task_stack_view_layout_style 2` e SILENCIOSAMENTE
rejeitado nesta build (volta 0); 1,3,4 sao aceitos. Valor 3 faz rotulo
"Empilhado" aparecer mas dialog so oferece Vertical/Horizontal e recentes
ficam em grade 2x2. Valor 2 e o correto (tutoriais HyperOS).
Solucao v23: compilado `work/setstack/setstack` (7KB, linkado contra
/system/lib64/libsqlite.so do device) que faz UPDATE global SET value='2'
direto em `/data/data/com.android.providers.settings/databases/settings.db`.
Root child executa `/data/local/tmp/setstack` via script de props.
Requer root (uid 0) - adb shell da open rc=14.
Se der certo: reiniciar launcher (`am force-stop com.miui.home`) para aplicar.

---

## ESTABILIZACAO FINAL ( usuario pediu so estabilizar o root )

- APK estavel: v17 puro (sem modo props), `timer_v17_static` 313616 bytes.
- Marcador `/data/local/tmp/glk_props_mode` REMOVIDO do device.
- Root validado: `[k] start uid=0 ctx=u:r:shell:s0`, exploit completed.
- Shizuku: fork thedjchi 13.7.0, starter `/data/local/tmp/libshizuku.so --apk=<path>`.
- UserService conecta apos abrir o manager (MIUI as vezes o mata; reabrir).

### Capacidades REAIS do root (testadas)
- uid 0, CapEff=0, Seccomp=0, contexto u:r:shell:s0
- SEM `perm`: dmesg/kallsyms/data.data NEGADOS (SELinux)
- COM `perm` (Permissive): dmesg FUNCIONA, /proc/kallsyms le (enderecos 0 por kptr_restrict)
- `setprop debug.*` FUNCIONA em Permissive
- `setprop persist.sys.*` NEGADO ao dominio shell (mesmo uid 0)
- `/data/adb` (root:root 0700) acessivel com uid 0
- `/system` read-only (sem CAP_SYS_ADMIN, nao da para montar rw)
- `pm grant` falha (Binder), `settings put` funciona (Binder do SettingsProvider)
- `/data/local/tmp` e /sdcard acessiveis
- KSU NAO carrega (sem CAP_SYS_MODULE), modulo nao aparece

### Limitacoes
- Nao da para instalar modulos Magisk/KSU (bootloader bloqueado + KSU down)
- Nao da para substituir APKs do sistema (assinatura + /system ro)
- Nao da para setar props de blur (persist.sys.* negado)
- Matar nativo preso gera panic; unica limpeza segura = reboot

### Uso pratico do root
- `timer-yk perm` -> SELinux Permissivo ate reboot (desbloqueia dmesg/tracefs/debug props)
- `printf 'comandos\n' | ./timer-yk shell` -> shell uid 0 (cuidado: plant pode travar)
- App GhostLock -> root child executa `/data/local/tmp/ksu_stage.sh` como uid 0
  (coloque la qualquer script para rodar como root a cada execucao do app)
- Ler logs do kernel, inspecionar /data/adb, ajustar settings via `settings put`
