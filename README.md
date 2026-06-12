# Fedora Open264 Fix & DNS-over-TLS Setup

<p align="center">
  <a href="#-english">English</a> •
  <a href="#-русский">Русский</a>
</p>

---

## 🇺🇸 English

### 📌 Description
This repository provides an automated solution for Fedora Linux users facing issues with downloading or updating Cisco's `open264` library due to **403 Forbidden** geoblocking. Additionally, it configures secure **DNS-over-TLS (DoT)** to enhance privacy, security, and bypass DNS-based restrictions.

> **Note:** This project is a fork/extension based on the original work by [supertico](https://github.com/supertico/fedora-open264-geoblock-fix.git), which only fixes the open264 geoblock issue without DNS-over-TLS setup.

### 🛠️ Features
- **Bypasses Cisco Geoblock:** Resolves the `403 Forbidden` error when fetching `open264` components.
- **DNS-over-TLS (DoT) Setup:** Automatically configures `systemd-resolved` to encrypt DNS traffic.
- **Privacy & Security:** Safeguards your DNS queries from snooping and ISP tampering.
- **One-Line Execution:** Fast and interactive setup directly from the terminal.

### 📋 Prerequisites
- Fedora Linux (Workstation, Silverblue, or spins)
- `curl` installed (`sudo dnf install curl`)
- Sudo privileges

### 🚀 How to Run
Open your terminal and execute the following command:

```bash
curl -sSL https://raw.githubusercontent.com/Maesev/fedora-open264-fix-dns-tls/main/fedora-open264-fix-dns-tls.sh | sudo bash
```

---

## 🇷🇺 Русский

### 📌 Описание
Этот репозиторий предоставляет автоматическое решение для пользователей Fedora Linux, сталкивающихся с проблемами при загрузке или обновлении библиотеки Cisco `open264` из-за геоблокировки **403 Forbidden**. Дополнительно он настраивает безопасный протокол **DNS-over-TLS (DoT)** для повышения приватности, безопасности и обхода ограничений на уровне DNS.

> **Примечание:** Этот проект является форком/расширением, основанным на оригинальной работе [supertico](https://github.com/supertico/fedora-open264-geoblock-fix.git), в которой реализован только обход геоблока для open264 без настройки DNS-over-TLS.

### 🛠️ Возможности
- **Обход геоблока Cisco:** Решает ошибку `403 Forbidden` при получении компонентов `open264`.
- **Настройка DNS-over-TLS (DoT):** Автоматически конфигурирует `systemd-resolved` для шифрования DNS-трафика.
- **Приватность и безопасность:** Защищает ваши DNS-запросы от слежки и вмешательства провайдера (ISP).
- **Запуск в одну строку:** Быстрая и интерактивная настройка прямо из терминала.

### 📋 Требования
- Fedora Linux (Workstation, Silverblue или другие спины)
- Установленный `curl` (`sudo dnf install curl`)
- Права администратора (`sudo`)

### 🚀 Как запустить
Откройте терминал и выполните следующую команду:

```bash
curl -sSL https://raw.githubusercontent.com/Maesev/fedora-open264-fix-dns-tls/main/fedora-open264-fix-dns-tls.sh | sudo bash
```
