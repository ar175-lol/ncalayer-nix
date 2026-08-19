# NCALayer for Nix / NixOS

A Nix flake that packages [NCALayer](https://pki.gov.kz) — the software
for working with electronic digital signatures of the National Certification
Authority of the Republic of Kazakhstan (NCA RK).

The official NCALayer distribution (`ncalayer.zip` from `ncl.pki.gov.kz`, pinned
by sha256) is fetched and unpacked at build time. The application jar (embedded
in the self-extracting `ncalayer.sh`), the bundled JRE 8, accessory tools and
certificates all come from that archive, so no binaries are versioned in this
repo:

- `ncalayer.nix` — the package derivation (fetches + repackages NCALayer)
- `ncalayer.sh` — a small launcher (not the old installer)
- `modules/` — NixOS / home-manager modules (systemd units, pcscd, fonts)
- `flake.nix` — the flake entry point

## Quick start

```bash
# Run without installing
nix run .#ncalayer
nix run .#   # same, default app

# Or add to a NixOS configuration:
#   inputs.ncalayer.url = "github:ar175-lol/ncalayer-nix";
#   imports = [ inputs.ncalayer.nixosModules.default ];
#   services.ncalayer.enable = true;
```

## NixOS module

```nix
services.ncalayer = {
  enable = true;                      # add package + systemd user unit
  enablePcsc = true;                  # pcscd daemon for smartcard readers
  autostart = true;                   # start with the graphical session
  enableFonts = true;                 # Cyrillic fonts for the Java GUI
  package = pkgs.ncalayer;            # optional, default: this flake's package
};
```

This installs a systemd *user* service named `ncalayer` that starts NCALayer
with your graphical session. Manage it with:

```bash
systemctl --user status ncalayer
systemctl --user restart ncalayer
```

## home-manager module

```nix
imports = [ inputs.ncalayer.homeModules.default ];
services.ncalayer.enable = true;
```

`pcscd` is a system-level daemon, so enable it at the NixOS level:

```nix
services.pcscd.enable = true;
```

## Launcher

The `ncalayer` binary is a thin wrapper around the application jar:

```text
ncalayer            start NCALayer
ncalayer --stop     stop the running instance
ncalayer --restart  restart the running instance
ncalayer --version  print version
ncalayer --help     show help
```

When run under the systemd user service, `--stop`/`--restart` delegate to
`systemctl --user`; otherwise they manage the Java process directly.

## Development

Two development shells are provided:

```bash
nix develop .#shell   # tooling for hacking on the packaging
nix develop .#app     # FHS environment to run the app manually
```

The contributor shell ships the tools used by this repo: `nix`, `git`,
`unzip`/`zip`, `file`, `binutils`, `patchelf`, `jq`, `ripgrep`,
`nixfmt-rfc-style`/`alejandra`, `shellcheck`, and `shfmt`.

## Tests

```bash
nix flake check             # build + run the test suite

# or run only the tests:
nix build .#checks.<system>.default
```

The check (`checks.nix`) verifies the packaged output:

- the application jar is a valid zip archive
- the bundled JRE 8 runs under the patched dynamic loader
- the launcher reports its version
- all expected files (jar, JRE, accessory tools, certificates, icon,
  desktop entry) are present
- the desktop entry points at the launcher
- the jar actually boots without jar-parse or class-loading errors

<details>
<summary><b>Русский</b></summary>

Nix-флейк, упаковывающий NCALayer — программу для работы с ЭЦП НУЦ РК.

Официальный инсталлятор (`ncalayer.sh` был самораспаковывающимся jar с
установочной логикой) разобран на обычные, воспроизводимые Nix-артефакты:

```bash
nix run .#ncalayer            # запуск
```

В конфигурации NixOS:

```nix
imports = [ inputs.ncalayer.nixosModules.default ];
services.ncalayer.enable = true;
```

Запускается пользовательский systemd-сервис `ncalayer`:

```bash
systemctl --user status ncalayer
```

Для разработчиков:

```bash
nix develop .#shell        # инструменты для работы над упаковкой
nix flake check              # сборка + тесты
```

</details>

<details>
<summary><b>Қазақ тілі</b></summary>

NCALayer — ҚР ҰУО ЭЦҚ-пен жұмыс істеуге арналған бағдарлама Nix-флейк
ретінде қапталды.

```bash
nix run .#ncalayer            # іске қосу
```

NixOS конфигурациясында:

```nix
imports = [ inputs.ncalayer.nixosModules.default ];
services.ncalayer.enable = true;
```

`ncalayer` пайдаланушы systemd-сервисі ретінде іске қосылады:

```bash
systemctl --user status ncalayer
```

</details>
