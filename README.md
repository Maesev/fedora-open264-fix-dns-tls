# Fedora OpenH264 Geoblock Fix & DNS-over-TLS

<p align="center">
  <a href="#-english">English</a> •
  <a href="#-русский">Русский</a>
</p>


---

## 🇺🇸 English

A small script for Fedora Linux that fixes `403 Forbidden` errors from Cisco's OpenH264 repository (geoblocked in some countries, including Russia) and, optionally, enables encrypted DNS (DNS-over-TLS).

> Based on the original work by [supertico](https://github.com/supertico/fedora-open264-geoblock-fix), which only fixes the OpenH264 geoblock. This fork adds DNS-over-TLS, Atomic Fedora support, safety checks and rollback.

### The problem

Fedora ships `openh264` from Cisco's servers. When Cisco blocks your region, `dnf` / `rpm-ostree` updates fail on the `fedora-cisco-openh264` repository, and Flatpak cannot fetch `org.freedesktop.Platform.openh264`.

### What the script does

**OpenH264 fix**
1. Disables the `fedora-cisco-openh264` repository.
2. Replaces `openh264` with the stub package `noopenh264` (`rpm-ostree override` on Atomic).
3. Pins the exclusion so dnf does not bring `openh264` back.
4. Masks the Flatpak `org.freedesktop.Platform.openh264` runtime.

**DNS-over-TLS (optional)**
- Configures `systemd-resolved` with Quad9, Google or Cloudflare.
- Checks that port 853 is reachable **before** changing anything.
- Verifies name resolution afterwards and **rolls back automatically** if it fails.
- Backs up your previous `resolv.conf`.

### Requirements

- Fedora 43+ (Workstation, Server, spins) or Atomic (Silverblue, Kinoite, ...)
- `sudo` / root
- `curl` (to download the script)

### Quick start

Recommended: download, read, then run.

```bash
curl -fsSLO https://raw.githubusercontent.com/Maesev/fedora-open264-fix-dns-tls/main/fedora-open264-fix-dns-tls.sh
less fedora-open264-fix-dns-tls.sh
sudo bash fedora-open264-fix-dns-tls.sh
```

One-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/Maesev/fedora-open264-fix-dns-tls/main/fedora-open264-fix-dns-tls.sh | sudo bash
```

> Piping a script into `sudo bash` runs code you have not reviewed. Prefer the first variant.

### Options

| Option | Description |
|---|---|
| *(none)* | OpenH264 fix, then asks whether to set up DNS-over-TLS |
| `--fix-only` | OpenH264 fix only |
| `--dns-only` | DNS-over-TLS only |
| `--dns=quad9\|google\|cloudflare\|none` | Choose the DNS provider without prompts |
| `--revert-dns` | Remove the DNS-over-TLS configuration |
| `-h`, `--help` | Show help |

Examples:

```bash
sudo bash fedora-open264-fix-dns-tls.sh --fix-only
sudo bash fedora-open264-fix-dns-tls.sh --dns-only --dns=quad9
sudo bash fedora-open264-fix-dns-tls.sh --revert-dns
```

### Verify

```bash
rpm -q noopenh264                  # installed
dnf repolist --all | grep cisco    # shows "disabled"
resolvectl status | grep -E 'DNS Server|DNSOverTLS'
```

### Atomic Fedora

Changes are layered into a new deployment, so **reboot** when the script finishes.

### Notes

- `dnf swap --allowerasing` may remove `mozilla-openh264` and `gstreamer1-plugin-openh264`. They need the real `openh264` and would not work without Cisco access anyway.
- `Domains=~.` sends **all** queries to the chosen DoT servers. Local names and some VPN-provided domains may stop resolving. Use `--revert-dns` if that happens.
- If your network blocks port 853, the script detects it and leaves DNS untouched.
- Log file: `/tmp/fedora-openh264-fix-<pid>.log`. Exit code is `1` if any step failed.
- The script is idempotent: running it again is safe.

---

## 🇷🇺 Русский

Небольшой скрипт для Fedora Linux: устраняет ошибки `403 Forbidden` от репозитория Cisco OpenH264 (геоблок в ряде стран, включая Россию) и, по желанию, включает шифрованный DNS (DNS-over-TLS).

> Основан на работе [supertico](https://github.com/supertico/fedora-open264-geoblock-fix), где решён только геоблок OpenH264. В этом форке добавлены DNS-over-TLS, поддержка Atomic Fedora, проверки безопасности и откат.

### Проблема

Fedora берёт `openh264` с серверов Cisco. Если регион заблокирован, обновления `dnf` / `rpm-ostree` падают на репозитории `fedora-cisco-openh264`, а Flatpak не может скачать `org.freedesktop.Platform.openh264`.

### Что делает скрипт

**Фикс OpenH264**
1. Отключает репозиторий `fedora-cisco-openh264`.
2. Заменяет `openh264` на пакет-заглушку `noopenh264` (на Atomic — через `rpm-ostree override`).
3. Закрепляет исключение, чтобы dnf не вернул `openh264`.
4. Маскирует Flatpak-рантайм `org.freedesktop.Platform.openh264`.

**DNS-over-TLS (опционально)**
- Настраивает `systemd-resolved` на Quad9, Google или Cloudflare.
- **До** изменений проверяет, что порт 853 доступен.
- После настройки проверяет резолвинг и **автоматически откатывает** конфиг при сбое.
- Делает бэкап прежнего `resolv.conf`.

### Требования

- Fedora 43+ (Workstation, Server, спины) или Atomic (Silverblue, Kinoite, ...)
- `sudo` / root
- `curl` (для загрузки скрипта)

### Быстрый старт

Рекомендуется: скачать, посмотреть, запустить.

```bash
curl -fsSLO https://raw.githubusercontent.com/Maesev/fedora-open264-fix-dns-tls/main/fedora-open264-fix-dns-tls.sh
less fedora-open264-fix-dns-tls.sh
sudo bash fedora-open264-fix-dns-tls.sh
```

Одной строкой:

```bash
curl -fsSL https://raw.githubusercontent.com/Maesev/fedora-open264-fix-dns-tls/main/fedora-open264-fix-dns-tls.sh | sudo bash
```

> Запуск через `| sudo bash` выполняет непроверенный код. Лучше использовать первый вариант.

### Опции

| Опция | Описание |
|---|---|
| *(без опций)* | Фикс OpenH264, затем вопрос про DNS-over-TLS |
| `--fix-only` | Только фикс OpenH264 |
| `--dns-only` | Только DNS-over-TLS |
| `--dns=quad9\|google\|cloudflare\|none` | Выбрать DNS-провайдера без вопросов |
| `--revert-dns` | Удалить настройку DNS-over-TLS |
| `-h`, `--help` | Справка |

Примеры:

```bash
sudo bash fedora-open264-fix-dns-tls.sh --fix-only
sudo bash fedora-open264-fix-dns-tls.sh --dns-only --dns=quad9
sudo bash fedora-open264-fix-dns-tls.sh --revert-dns
```

### Проверка

```bash
rpm -q noopenh264                  # установлен
dnf repolist --all | grep cisco    # должен быть disabled
resolvectl status | grep -E 'DNS Server|DNSOverTLS'
```

### Atomic Fedora

Изменения попадают в новый деплой, поэтому после завершения скрипта нужна **перезагрузка**.

### Примечания

- `dnf swap --allowerasing` может удалить `mozilla-openh264` и `gstreamer1-plugin-openh264`. Им нужен настоящий `openh264`, и без доступа к Cisco они всё равно не работают.
- `Domains=~.` отправляет **все** запросы на выбранные DoT-серверы. Локальные имена и часть доменов из VPN могут перестать резолвиться. В этом случае используйте `--revert-dns`.
- Если сеть блокирует порт 853, скрипт это определит и не тронет DNS.
- Лог: `/tmp/fedora-openh264-fix-<pid>.log`. При ошибках код выхода — `1`.
- Скрипт идемпотентен: повторный запуск безопасен.
