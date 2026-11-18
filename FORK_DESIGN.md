# Fork ghostlock-app → spinel (root via CVE-2026-98260)

## Objetivo
Fazer o app do YuKongA (que hoje só suporta kernels com CVE-2026-43499) funcionar
no **Redmi Note 15 4G / spinel**, usando o root que já conquistamos no kernel
`6.12.69-android16-6-g014ca48a80ee-ab15889839-4k` via **CVE-2026-98260**
(exploit YuKongA `timer.c`, `timer_spinel_v5`).

## Descoberta-chave (por que é simples)
O app **não usa JNI**: `GhostlockUserService.kt` (Shizuku UserService, uid 2000,
Seccomp=0) executa `libghostlock.so` como **ELF executável** via `ProcessBuilder`,
com argv `--ghostlock-app-call --enable-status-record`, stdin = blob GLK1
(length-prefixed), stdout redirecionado para `.ghostlock_native.log`, e espera o
exit code. Linhas com `\x1eGLK_STATUS` são opcionais (ACK via stdin).

Consequência: **podemos substituir somente o binário nativo** pelo nosso exploit,
mantendo 100% do Kotlin/UI. Nosso exploit já escreve logs no stdout ✓ e não
precisa ler o stdin GLK1 ✓ (o Kotlin escreve e fecha).

## O que o root child já faz (adaptado de `src/core/attack/ops.cpp`)
O modo `fake` do nosso `timer.c` (v5) executa `/data/local/tmp/ksu_stage.sh`
com o contexto `u:r:kernel:s0` (conseguido via `task->security @0xCD8` —
offset extraído do BTF do device; `cred@0x900` bate com o perfil ✓).
O script embutido faz:
1. localizar `libksud.so` de qualquer manager da lista (KernelSU, SukiSU, ...);
2. derivar `KMI = android16-6.12` de `uname -r`;
3. `cat /sys/fs/selinux/policy > /data/local/tmp/glk_policy.bin` + `load_policy`;
4. `ksud late-load --kmi $KMI`;
5. checar `kernelsu` em `/proc/modules` → `KSU_LOADED` / `KSU_MISSING` no
   `/data/local/tmp/ksu.log`.

## Plano de implementação (L-level — design antes do código, conforme AGENTS.md)
1. **Fork**: copiar `work/ghostlock-app/` → `work/ghostlock-spinel/` (mantém
   histórico e licença Apache-2.0; mudar nome do pacote/applicationId para
   `com.ghostlock.spinel` para coexistir com o original).
2. **Native**: trocar a saída de `prepareGhostlockJniLibs` por
   `timer_spinel_v5` renomeado `libghostlock.so` (arm64-v8a). Fontes em
   `work/cve98260/timer/timer.c` — compilar com NDK 28.2.13676358,
   `aarch64-linux-android35-clang`.
3. **Gate de kernel**: `isKernelSupported()` em
   `AndroidGhostlockRepository.kt` usa profiles HOCON por `uname -r`. Registrar
   um profile spinel mínimo em `app/src/main/assets/kernel_profiles/index.conf`
   + `<release>.conf` (ou usar o `forceAttack` existente na UI) — validar qual
   caminho é menos intrusivo.
4. **Documentação**: README do fork explicando que o backend é CVE-2026-98260
   e que o device precisa do Shizuku ativo + manager KSU instalado.
5. **Verificação**: `./gradlew :app:assembleDebug`, instalar no device, abrir,
   conceder Shizuku, tap Run, checar `ksu.log` = KSU_LOADED e `su -c id` = 0.

## Estado atual (antes do fork)
- KernelSU manager v3.3.1 instalado (`me.weishu.kernelsu`) ✓
- BTF do kernel extraído (`work/fw/btf.bin`, 6.7 MB) → `task->security @0xCD8` ✓
- `timer_spinel_v5` compilado com `fake_security` + handoff KSU ✓
- Teste de KSU em andamento (driver `work/try_ksu.ps1`)
