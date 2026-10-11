# Fedora OpenH264 Geoblock Fix & DNS-over-TLS

<p align="center">
  <a href="#-english">English</a> •
  <a href="#-русский">Русский</a>
</p>

![Fedora](https://img.shields.io/badge/Fedora-43%2B-51A2DA?logo=fedora&logoColor=white)
![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnubash&logoColor=white)
![Atomic](https://img.shields.io/badge/Atomic-supported-blue)

---

## 🇺🇸 English

A small script for Fedora Linux that fixes `403 Forbidden` errors from Cisco's OpenH264 repository (geoblocked in some countries, including Russia) and, optionally, enables encrypted DNS (DNS-over-TLS) with verification and automatic rollback.

> Based on the original work by [supertico](https://github.com/supertico/fedora-open264-geoblock-fix), which only fixes the OpenH264 geoblock. This fork adds DNS-over-TLS, Atomic Fedora support, safety checks and rollback.

### The problem

Fedora ships `openh264` from Cisco's servers. When Cisco blocks your region, `dnf` / `rpm-ostree` updates fail on the `fedora-cisco-openh264` repository, and Flatpak cannot fetch `org.freedesktop.Platform.openh264`.

### What the script does

**OpenH264 fix**
1. Disables the `fedora-cisco-openh264` repository.
2. Replaces `openh264` with the stub package `noopenh264` (`rpm-ostree override` on Atomic).
3. Pins the exclusion so dnf does not bring `openh264` back.
4. Masks the Flatpak `org.freedesktop.Platform.openh264` runtime.

**DNS-over-TLS (optional, your choice)**

Without flags the script asks in the console (default: leave DNS unchanged):

```
1) Keep current DNS (default)
2) Cloudflare 1.1.1.1
3) Quad9 9.9.9.9 — blocks malicious domains
4) Google 8.8.8.8
```

- **Before enabling:** checks that port 853 is reachable and that the server's TLS certificate is valid. If not, DNS is left untouched.
- **After enabling:** checks that the settings were applied, names resolve and a TLS connection on port 853 was really established. If not, the config is **rolled back automatically**.
- Uses a `systemd-resolved` drop-in (`/etc/systemd/resolved.conf.d/99-openh264-fix-dns.conf`), IPv4 + IPv6 servers, and `Domains=~.` so this DNS is primary rather than a fallback after DHCP DNS.
- **Opportunistic mode (default):** queries are encrypted, but the server certificate is not verified; if port 853 gets blocked, DNS keeps working unencrypted.
- **Strict mode (`--dns-strict`):** the certificate is verified on every query. Safer, but DNS stops working on networks that block port 853.

### Requirements

- Fedora 43+ (Workstation, Server, spins) or Atomic (Silverblue, Kinoite, ...)
- `sudo` / root
- `curl` (to download the script)
- For DNS-over-TLS: active `systemd-resolved` (Fedora default); `openssl` is used for the certificate check

### Quick start

Recommended: download, then run.

```bash
curl -fsSLO https://raw.githubusercontent.com/Maesev/fedora-open264-fix-dns-tls/main/fedora-open264-fix-dns-tls.sh
sudo bash fedora-open264-fix-dns-tls.sh
```

One-liner (the DNS question still works in the terminal):

```bash
curl -fsSL https://raw.githubusercontent.com/Maesev/fedora-open264-fix-dns-tls/main/fedora-open264-fix-dns-tls.sh | sudo bash
```

With flags through a pipe:

```bash
curl -fsSL https://raw.githubusercontent.com/Maesev/fedora-open264-fix-dns-tls/main/fedora-open264-fix-dns-tls.sh | sudo bash -s -- --dns=quad9
```

> Piping a script into `sudo bash` runs code you have not reviewed. Prefer the first variant.

### Options

| Option | Description |
|---|---|
| *(none)* | OpenH264 fix, then asks about DNS-over-TLS |
| `--fix-only` | OpenH264 fix only |
| `--dns-only` | DNS-over-TLS only |
| `--dns=cloudflare\|quad9\|google\|none` | Choose the DNS provider without a prompt |
| `--no-dns` | Do not ask about DNS (same as `--dns=none`) |
| `--dns-strict` | Strict DNS-over-TLS: verify the certificate on every query |
| `--revert-dns` | Remove the DNS-over-TLS configuration |
| `-h`, `--help` | Show help |

Examples:

```bash
sudo bash fedora-open264-fix-dns-tls.sh --fix-only
sudo bash fedora-open264-fix-dns-tls.sh --dns-only --dns=cloudflare --dns-strict
sudo bash fedora-open264-fix-dns-tls.sh --revert-dns
```

### Verify

```bash
rpm -q noopenh264                  # installed
dnf repolist --all | grep cisco    # shows "disabled"
resolvectl status | grep -E 'DNS Server|DNSOverTLS'
ss -tn state established '( dport = :853 )'   # live TLS connection to the DNS server
```

### Revert DNS

```bash
sudo bash fedora-open264-fix-dns-tls.sh --revert-dns
```

### Atomic Fedora

OpenH264 changes are layered into a new deployment, so **reboot** when the script finishes.

### Notes

- `dnf swap --allowerasing` may remove `mozilla-openh264` and `gstreamer1-plugin-openh264`. They need the real `openh264` and would not work without Cisco access anyway.
- With DNS-over-TLS, your queries go to the company you chose instead of your ISP. Pick a provider you trust.
- `Domains=~.` sends **all** queries to the chosen servers. Local names (e.g. `router.lan`) and some VPN-provided domains may stop resolving. Use `--revert-dns` if that happens.
- If `systemd-resolved` is inactive or `/etc/resolv.conf` does not point to it, the script warns and leaves DNS unchanged.
- Log file: `/tmp/openh264-fix-<pid>.log`. Exit code is `1` if any step failed.
- The script is idempotent: running it again is safe.

### License

Add your license here (e.g. MIT).

---

## 🇷🇺 Русский

Небольшой скрипт для Fedora Linux: устраняет ошибки `403 Forbidden` от репозитория Cisco OpenH264 (геоблок в ряде стран, включая Россию) и, по желанию, включает шифрованный DNS (DNS-over-TLS) с проверкой и автоматическим откатом.

> Основан на работе [supertico](https://github.com/supertico/fedora-open264-geoblock-fix), где решён только геоблок OpenH264. В этом форке добавлены DNS-over-TLS, поддержка Atomic Fedora, проверки безопасности и откат.

### Проблема

Fedora берёт `openh264` с серверов Cisco. Если регион заблокирован, обновления `dnf` / `rpm-ostree` падают на репозитории `fedora-cisco-openh264`, а Flatpak не может скачать `org.freedesktop.Platform.openh264`.

### Что делает скрипт

**Фикс OpenH264**
1. Отключает репозиторий `fedora-cisco-openh264`.
2. Заменяет `openh264` на пакет-заглушку `noopenh264` (на Atomic — через `rpm-ostree override`).
3. Закрепляет исключение, чтобы dnf не вернул `openh264`.
4. Маскирует Flatpak-рантайм `org.freedesktop.Platform.openh264`.

**DNS-over-TLS (опционально, по вашему выбору)**

Без флагов скрипт спросит в консоли (по умолчанию DNS не меняется):

```
1) Не менять DNS (по умолчанию)
2) Cloudflare 1.1.1.1
3) Quad9 9.9.9.9 — блокирует вредоносные домены
4) Google 8.8.8.8
```

- **До включения:** проверяет, что порт 853 доступен и TLS-сертификат сервера корректен. Если нет, DNS не трогается.
- **После включения:** проверяет, что настройки применились, имена разрешаются и TLS-соединение на порту 853 реально установлено. Если нет, конфиг **автоматически откатывается**.
- Используется drop-in для `systemd-resolved` (`/etc/systemd/resolved.conf.d/99-openh264-fix-dns.conf`), серверы IPv4 + IPv6 и `Domains=~.`, чтобы этот DNS был основным, а не запасным после DNS из DHCP.
- **Режим opportunistic (по умолчанию):** запросы шифруются, но сертификат сервера не проверяется; если порт 853 заблокируют, DNS продолжит работать без шифрования.
- **Строгий режим (`--dns-strict`):** сертификат проверяется при каждом запросе. Надёжнее, но DNS перестанет работать в сетях, где закрыт порт 853.

### Требования

- Fedora 43+ (Workstation, Server, спины) или Atomic (Silverblue, Kinoite, ...)
- `sudo` / root
- `curl` (для загрузки скрипта)
- Для DNS-over-TLS: активный `systemd-resolved` (по умолчанию в Fedora); для проверки сертификата используется `openssl`

### Быстрый старт

Рекомендуется: скачать, затем запустить.

```bash
curl -fsSLO https://raw.githubusercontent.com/Maesev/fedora-open264-fix-dns-tls/main/fedora-open264-fix-dns-tls.sh
sudo bash fedora-open264-fix-dns-tls.sh
```

Одной строкой (вопрос про DNS всё равно работает в терминале):

```bash
curl -fsSL https://raw.githubusercontent.com/Maesev/fedora-open264-fix-dns-tls/main/fedora-open264-fix-dns-tls.sh | sudo bash
```

С флагами через конвейер:

```bash
curl -fsSL https://raw.githubusercontent.com/Maesev/fedora-open264-fix-dns-tls/main/fedora-open264-fix-dns-tls.sh | sudo bash -s -- --dns=quad9
```

> Запуск через `| sudo bash` выполняет непроверенный код. Лучше использовать первый вариант.

### Опции

| Опция | Описание |
|---|---|
| *(без опций)* | Фикс OpenH264, затем вопрос про DNS-over-TLS |
| `--fix-only` | Только фикс OpenH264 |
| `--dns-only` | Только DNS-over-TLS |
| `--dns=cloudflare\|quad9\|google\|none` | Выбрать DNS-провайдера без вопроса |
| `--no-dns` | Не спрашивать про DNS (то же, что `--dns=none`) |
| `--dns-strict` | Строгий DNS-over-TLS: сертификат проверяется при каждом запросе |
| `--revert-dns` | Удалить настройку DNS-over-TLS |
| `-h`, `--help` | Справка |

Примеры:

```bash
sudo bash fedora-open264-fix-dns-tls.sh --fix-only
sudo bash fedora-open264-fix-dns-tls.sh --dns-only --dns=cloudflare --dns-strict
sudo bash fedora-open264-fix-dns-tls.sh --revert-dns
```

### Проверка

```bash
rpm -q noopenh264                  # установлен
dnf repolist --all | grep cisco    # должен быть disabled
resolvectl status | grep -E 'DNS Server|DNSOverTLS'
ss -tn state established '( dport = :853 )'   # живое TLS-соединение с DNS-сервером
```

### Откат DNS

```bash
sudo bash fedora-open264-fix-dns-tls.sh --revert-dns
```

### Atomic Fedora

Изменения OpenH264 попадают в новый деплой, поэтому после завершения скрипта нужна **перезагрузка**.

### Примечания

- `dnf swap --allowerasing` может удалить `mozilla-openh264` и `gstreamer1-plugin-openh264`. Им нужен настоящий `openh264`, и без доступа к Cisco они всё равно не работают.
- При DNS-over-TLS ваши запросы идут выбранной компании вместо провайдера. Выбирайте того, кому доверяете.
- `Domains=~.` отправляет **все** запросы на выбранные серверы. Локальные имена (например, `router.lan`) и часть доменов из VPN могут перестать резолвиться. В этом случае используйте `--revert-dns`.
- Если `systemd-resolved` не активен или `/etc/resolv.conf` не ведёт на него, скрипт предупредит и не изменит DNS.
- Лог: `/tmp/openh264-fix-<pid>.log`. При ошибках код выхода — `1`.
- Скрипт идемпотентен: повторный запуск безопасен.

### Лицензия

Укажите здесь свою лицензию (например, MIT).
