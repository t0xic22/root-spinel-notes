# Root Spinel — Redmi Note 15 4G (MT6789, Android 16)

Documentação, scripts e ferramentas開発ados para obter **root (uid 0)** no
Redmi Note 15 4G (`spinel`), kernel `6.12.69-android16-6-g014ca48a80ee-ab15889839-4k`,
usando o **CVE-2026-98260** (YuKongA) e um fork do GhostLock via Shizuku.

## Repositórios relacionados

| Repo | Conteúdo |
|---|---|
| [`cve98260-spinel`](https://github.com/t0xic22/cve98260-spinel) | Exploit timer LPE com perfil do spinel e varsões v2–v25 |
| [`ghostlock-spinel`](https://github.com/t0xic22/ghostlock-spinel) | Fork do app GhostLock (perfil do kernel + binário do exploit) |
| `root-spinel-notes` (este) | Documentação, scripts de automação, starters do Shizuku, ferramentas |

## Estado final

- ✅ **Root funcional**: `uid=0`, `Seccomp=0`, contexto `u:r:shell:s0`
- ✅ **App GhostLock modificado**: abre sem pedir perfil, executa o exploit via Shizuku
- ⚠️ **KernelSU não carrega**: `late-load rc=0` mas sem `CAP_SYS_MODULE`
- ⚠️ **Blur/recientes empilhados**: parcial (limitações de `setprop persist.sys.*` no domínio shell)

## Como obter root

1. Instale o Shizuku (**fork `thedjchi` v13.7.0** — a 13.6.0 oficial quebra o UserService
   no MediaTek por `LoadedApk.makeApplicationInner` NPE, issue #1198).
2. Inicie o servidor:
   ```sh
   APK=$(pm path moe.shizuku.privileged.api | cut -d: -f2)
   timeout 8 /data/local/tmp/libshizuku.so --apk=$APK
   monkey -p moe.shizuku.privileged.api 1   # manager precisa estar vivo
   ```
3. Abra o GhostLock → **Correr**. O root child executa `/data/local/tmp/ksu_stage.sh`
   como uid 0.

## Scripts

| Arquivo | Função |
|---|---|
| `retry_app.ps1` | Um disparo do exploit pelo app (force-stop → abrir → Correr → checar log) |
| `auto_retry.ps1` | Detecta plant travado (`futex_wait`) e reinicia automaticamente |
| `try_ksu*.ps1`, `do_ksu*.sh` | Tentativas de handoff KernelSU |
| `perm_stage_custom.sh` | Script do modo `perm` (SELinux Permissivo) |
| `libshizuku*.so` | Starters extraídos das várias versões do Shizuku testadas |
| `fw/btf.bin` | BTF extraído do kernel do device |
| `parse_btf.py` | Extrai offsets de `task_struct` do BTF |
| `setstack/` | Tentativa de escrever `task_stack_view_layout_style=2` direto no SQLite |

## Limitações do root (testadas)

- `CapEff=0` — sem `CAP_SYS_ADMIN`/`CAP_SYS_MODULE`/`CAP_NET_ADMIN`
- `setprop persist.sys.*` negado ao domínio `shell` (mesmo uid 0)
- `dmesg` e `/proc/kallsyms` só funcionam após `./timer-yk perm`
- `pm grant` falha na transação Binder
- Matar nativo preso gera **panic** — única limpeza segura é reboot

Ver `HANDOFF.md` para o histórico completo de descobertas e tentativas.

## Créditos

Créditos completos a todos os projetos e autores usados: [CREDITS.md](CREDITS.md).

