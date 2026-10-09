# 🚀 Antigravity Nix Flake

[![Nix Flake](https://img.shields.io/badge/Nix-Flake-blue.svg?logo=nixos&logoColor=white)](https://nixos.org)
[![Patched with Open Antigravity](https://img.shields.io/badge/Patched-Open%20Antigravity-brightgreen.svg)](https://github.com/QNIX-Dev/eligibility-antigravity-patcher)
[![License: Unfree](https://img.shields.io/badge/License-Google%20Proprietary%20%2F%20Unfree-orange.svg)](#)

Ready-to-use Nix Flake providing pre-patched **Google Antigravity 2.0 (Desktop)** and **Antigravity CLI (`agy`)** for NixOS and Linux distributions running Nix.

## ✨ Ключевые особенности (Features)

* **Open Antigravity Patcher**: Никаких сторонних DNS (`xbox-dns.ru`) или промежуточных прокси! Патчинг байтов проверки региона и авторизации (`hasValidAuth=true`, снятие eligibility gates) происходит нативно и автономно внутри Nix-деривации на базе чистого Python-скрипта (логика [Open-AG-Patcher / QNIX-Dev](https://github.com/QNIX-Dev/eligibility-antigravity-patcher)).
* **Двойные профили (Dual Profiles)**:
  * 🍃 **Antigravity (Personal)**: Изолированный профиль для личных проектов с зеленой иконкой.
  * 💼 **Antigravity (Workspace)**: Изолированный профиль для рабочих задач со стильной рабочей иконкой.
* **Dual-Boot NTFS / Btrfs Sync**: Автоматическая синхронизация токенов (`jetski-standalone-oauth-token`, `google_accounts.json`) между общим диском данных (`/vault/Документы/Antigravity/...`) и локальной файловой системой Linux.
* **Изоляция D-Bus / Keyring**: Принудительное хранение токенов в файлах, исключающее затирание сессий между разными профилями.
* **Поддержка Wayland & X11**: Автоматический проброс флагов Ozone Platform и Wayland.

---

## 📦 Что включено (Packages)

| Пакет / Атрибут | Описание | Команда запуска |
| :--- | :--- | :--- |
| `packages.x86_64-linux.agy` (default) | Консольный интерфейс Antigravity CLI | `agy` / `antigravity-cli` |
| `packages.x86_64-linux.antigravity` | Десктопное приложение Antigravity 2.0 | `antigravity`, `antigravity-personal`, `antigravity-workspace` |

---

## ⚡ Быстрый запуск без установки (Quick Run)

### Antigravity CLI:
```bash
nix run github:MrLogiousBanana/antigravity-nix#agy -- --version
```

### Antigravity 2.0 Desktop:
```bash
# Личный профиль (Personal)
nix run github:MrLogiousBanana/antigravity-nix#antigravity-personal

# Рабочий профиль (Workspace)
nix run github:MrLogiousBanana/antigravity-nix#antigravity-workspace
```

---

## 🛠️ Интеграция в NixOS Configuration (Flakes)

Добавьте репозиторий в inputs вашего системного `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    antigravity-nix = {
      url = "github:MrLogiousBanana/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, antigravity-nix, ... }: {
    nixosConfigurations.surface = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        antigravity-nix.nixosModules.default
        {
          # Включение модуля Antigravity
          programs.antigravity = {
            enable = true;
            enableCLI = true;      # Устанавливает agy в систему
            enableDesktop = true;  # Устанавливает десктопное приложение и .desktop ярлыки
          };

          # Разрешение unfree пакетов Google
          nixpkgs.config.allowUnfree = true;
        }
      ];
    };
  };
}
```

Либо добавьте пакеты напрямую через `environment.systemPackages`:

```nix
environment.systemPackages = with pkgs; [
  antigravity-nix.packages.${pkgs.system}.agy
  antigravity-nix.packages.${pkgs.system}.antigravity
];
```

---

## 🌿 Интеграция с Home Manager

```nix
{ inputs, pkgs, ... }:

{
  home.packages = [
    inputs.antigravity-nix.packages.${pkgs.system}.agy
    inputs.antigravity-nix.packages.${pkgs.system}.antigravity
  ];
}
```

---

## 🧩 Структура репозитория

```
antigravity-nix/
├── flake.nix                       # Определение Flake (packages, apps, modules, overlays)
├── default.nix                     # Совместимость с традиционным nix-build
├── pkgs/
│   ├── agy/
│   │   └── default.nix             # Деривация CLI с автопатчем Google Cloud Storage tarball
│   └── antigravity/
│       ├── default.nix             # Деривация Electron Desktop с библиотеками и обертками
│       ├── launcher.sh             # Многопрофильный лаунчер с NTFS sync
│       ├── antigravity.desktop     # Системный десктоп-файл
│       ├── antigravity-personal.desktop
│       └── antigravity-workspace.desktop
├── modules/
│   └── nixos.nix                   # Нативный модуль NixOS (programs.antigravity)
├── patches/
│   └── patch_eligibility.py        # Автономный Python-патчер Open Antigravity (zero-deps)
└── assets/
    ├── antigravity.svg             # Личная векторная иконка
    └── antigravity-workspace.svg   # Рабочая векторная иконка
```

---

## 🛡️ Безопасность и конфиденциальность

* Исходные бинарные файлы скачиваются напрямую из официальных репозиториев Google Cloud Storage / GitHub Release.
* Репозиторий **не содержит** проприетарных исполняемых файлов $>100$ MB в истории коммитов git.
* Патчер не выполняет внешних сетевых запросов и не обращается к сторонним прокси-серверам.
