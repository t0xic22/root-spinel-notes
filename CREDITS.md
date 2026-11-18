# Créditos

Documentação e scripts do projeto de root no Redmi Note 15 4G (spinel).
O conhecimento aqui foi construído sobre o trabalho de terceiros — créditos devidos:

## Exploit e app

- **[YuKongA/CVE-2026-98260](https://github.com/YuKongA/CVE-2026-98260)** — exploit
  timer LPE (MIT) e perfis de kernel por `uname -r`.
- **[woshigenm/CVE-2026-98260](https://github.com/woshigenm/CVE-2026-98260)** —
  `src/uid0.c` / `src/poc.c` (MIT), base do `timer.c`.
- **[YuKongA/ghostlock-app](https://github.com/YuKongA/ghostlock-app)** — app
  GhostLock original (UI, profiles HOCON, Shizuku UserService).

## Shizuku

- **[RikkaApps/Shizuku](https://github.com/RikkaApps/Shizuku)** — API e serviço
  (issue [#1198](https://github.com/RikkaApps/Shizuku/issues/1198) documenta o bug
  do MediaTek no `LoadedApk.makeApplicationInner`).
- **[thedjchi/Shizuku](https://github.com/thedjchi/Shizuku)** — fork v13.7.0 usado
  no device (corrige o NPE do UserService em ROMs MediaTek).
- `wess09/shizuku-m` e `hwangsihu/Shizuku` — forks avaliados na investigação.

## Kernel / BTF

- BTF extraído do kernel do device (`fw/btf.bin`) e interpretado com
  [`parse_btf.py`](parse_btf.py) — estruturas do `pahole`/BTF do Linux.
- Comunidade KernelSU — documentação de `late-load`, KMI e `u:r:kernel:s0`.

## Personalização HyperOS

- **[Mods-Center](https://github.com/Mods-Center)** — módulos HyperOS avaliados
  (launcher com stacked recents, disable APK signature verification, blur).
- Comunidade [r/HyperOS](https://www.reddit.com/r/HyperOS/) — comandos
  `service call miui.mqsas.IMQSNative 21 ... setprop` e
  `settings put global/secure task_stack_view_layout_style 2`.

## Repos irmãos

- [`ghostlock-spinel`](https://github.com/t0xic22/ghostlock-spinel)
- [`cve98260-spinel`](https://github.com/t0xic22/cve98260-spinel)

Todos os arquivos de terceiros mantêm suas licenças originais (MIT / Apache-2.0).
