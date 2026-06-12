#!/bin/bash
S_VERSION="v.1.09 (AMD/Intel Pure 64-bit Only)"; clear
#set -euo pipefail

if [[ "$LANG" =~ ^ru ]]; then
    LNG="RU"
else
    LNG="EN"
fi

# === Language and Message Declarations ===
declare -A S_HEADER=( [EN]="\nCISCO OPENH264 'ERROR 403' GEOBLOCK REMOVAL and \nmultimedia codecs installation script for FEDORA LINUX \nby Andrei Manzhov " [RU]="Скрипт снятия блокировки обновлений из-за CISCO OPENH264 \nи установки необходимых мультимедиа кодеков для ФЕДОРЫ ЛИНУКС \n  Андрей Маньжов " )
declare -A MSG_SUCCESS=( [EN]="✅ Installation completed!\n" [RU]="✅ Установка завершена!" )
declare -A MSG_FAILURE_HEADER=( [EN]="❌ Failed Steps:" [RU]="❌ Не удалось:" )
declare -A MSG_FAILURE_FOOTER=( [EN]="  Check system logs or rerun the script for details." [RU]="   Проверьте системные логи или перезапустите скрипт для деталей." )
declare -A MSG_RESULTS_HEADER=( [EN]="INSTALLATION RESULTS:" [RU]="ОТЧЁТ ОБ УСТАНОВКЕ:" )
declare -A STEP_1=( [EN]="Cisco repository disabled (geoblock issue resolved)" [RU]="Отключен репозиторий Cisco (решена проблема с геоблоком)" )
declare -A STEP_2=( [EN]="openh264 replaced with noopenh264" [RU]="Заменён openh264 на noopenh264" )
declare -A STEP_3=( [EN]="System updates installed" [RU]="Установлены системные обновления" )
declare -A STEP_4=( [EN]="RPM Fusion repository enabled" [RU]="Включен репозиторий RPM Fusion" )
declare -A STEP_5=( [EN]="Limited ffmpeg-free replaced with full ffmpeg from RPM Fusion" [RU]="Урезанный ffmpeg-free заменён на полный ffmpeg из RPM Fusion" )
declare -A STEP_6=( [EN]="All GStreamer codecs installed" [RU]="Установлены все GStreamer кодеки" )
declare -A STEP_7=( [EN]="Global openh264 exclusion added (drop-in)" [RU]="Добавлено глобальное исключение openh264 (drop-in)" )
declare -A STEP_8=( [EN]="Cisco openh264 disabled, which was blocking Flatpak updates" [RU]="Отключен openh264, блокировавший обновления Flatpak" )
declare -A STEP_9=( [EN]="Drivers for hardware video acceleration installed" [RU]="Установлены драйвера для аппаратного ускорения видео" )
declare -A STEP_10=( [EN]="Multimedia player VLC installed (plays everything)" [RU]="Установлен мультимедиа-плеер VLC (проигрывает всё)" )
declare -A STEP_11=( [EN]="VLC set as default video player" [RU]="VLC сделан видеоплеером по умолчанию" )
declare -A STEP_DNS=( [EN]="DNS-over-TLS configured strictly (Domains=~.)" [RU]="Строго настроен зашифрованный DNS-over-TLS (Domains=~.)" )
declare -A MSG_BROWSERS=( [EN]="SUGGESTION: ENABLE HARDWARE ACCELERATION IN APPLICATIONS" [RU]="СОВЕТ: ВКЛЮЧИТЕ HARDWARE ACCELERATION В ПРИЛОЖЕНИЯХ" )
declare -A MSG_DONE_HEADER=( [EN]="What was done:" [RU]="Что было сделано:" ) 
declare -A MSG_OS_WARNING=( [EN]="Warning: This script is designed for Fedora Linux, but detected '%s'." [RU]="Предупреждение: Этот скрипт предназначен для Fedora Linux, но обнаружен '%s'." )
declare -A MSG_EXITING=( [EN]="Exiting." [RU]="Выход." )
declare -A MSG_OS_ERROR=( [EN]="Error: Cannot detect OS. /etc/os-release not found." [RU]="Ошибка: Не удается определить ОС. /etc/os-release не найден." )
declare -A MSG_URL=( [EN]="All finished! For further updates check: \n - https://discussion.fedoraproject.org/t/ciscobinary-openh264-org-is-unreachable-in-some-countries-ru-ua-ir/." [RU]="Система готова к использованию! \nВопросы обсуждаются на сайте проекта по адресу: \n - https://discussion.fedoraproject.org/t/dnf-update-interrupted-all-mirrors-were-tried-cisco-openh264-geoblock/170877" )
declare -A MSG_OS_PROMPT=( [EN]="Do you want to continue anyway? (y/N): " [RU]="Хотите продолжить в любом случае? (y/N): " )
declare -A MSG_ATOMIC_WARNING=( [EN]="Warning: Atomic Fedora (%s) detected. Continue? (y/N): " [RU]="Предупреждение: Обнаружена Atomic Fedora (%s). Продолжить? (y/N): " )
declare -A MSG_DNS_PROMPT=( [EN]="Do you want to configure DNS-over-TLS? (y/N): " [RU]="Хотите настроить DNS-over-TLS? (y/N): " )
declare -A MSG_DNS_SELECT=( [EN]="Select DNS provider:\n1) Quad9\n2) Google\n3) Cloudflare\nEnter choice (1-3): " [RU]="Выберите DNS-провайдера:\n1) Quad9 (Приватность)\n2) Google (Стабильность)\n3) Cloudflare (Скорость)\nВведите номер (1-3): " )
declare -A MSG_DNS_SKIPPING=( [EN]="Skipping DNS-over-TLS configuration." [RU]="Пропуск настройки DNS-over-TLS." )
declare -A MSG_DNS_INVALID=( [EN]="Invalid choice, skipping DNS configuration." [RU]="Неверный выбор, пропуск настройки DNS." )

# === Color Definitions ===
declare -A CL=( [W]="\e[38;5;255m" [O]="\e[38;5;214m" [Y]="\e[38;5;229m" [G]="\e[38;5;120m" [B]="\e[38;5;117m" [R]="\e[38;5;210m" [P]="\e[38;5;177m" [NC]="\e[0m" )

# === Functions ===
SaveResult() {
    local Step_Message="$1"
    local Exit_Code="$2"
    if [[ $Exit_Code -ne 0 ]]; then
        FAILED+=("$Step_Message")
    else
        DONE+=("$Step_Message")
    fi
}
PrintResults() {
    if [[ ${#FAILED[@]} -eq 0 ]]; then
        echo -e "${MSG_SUCCESS[$LNG]}"
    else
        echo -e "${CL[R]}${MSG_FAILURE_HEADER[$LNG]}"
        for step in "${FAILED[@]}"; do
            echo -e "  ❌ $step"
        done
        echo -e "${MSG_FAILURE_FOOTER[$LNG]}\n${CL[NC]}"
    fi
    echo -e "${CL[G]}   ${MSG_DONE_HEADER[$LNG]}"
    for step in "${DONE[@]}"; do
        echo -e "   ${CL[G]}✔${CL[NC]} $step"
    done
}

# === Main Script Logic ===
FAILED=(); DONE=()
echo -e "${CL[P]}${S_HEADER[$LNG]}${S_VERSION}"
echo -e "═══════════════════════════════════════════════════════════${CL[NC]}\n"

if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    if [[ "$ID" != "fedora" ]]; then
        printf "${CL[R]}${MSG_OS_WARNING[$LNG]}" "$ID"
        echo
        read -p "${MSG_OS_PROMPT[$LNG]} " -r </dev/tty
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then echo "${MSG_EXITING[$LNG]}"; exit 1; fi
    elif [[ "$VARIANT_ID" =~ ^(silverblue|kinoite|sericea)$ ]]; then
        printf "${CL[Y]}${MSG_ATOMIC_WARNING[$LNG]}${CL[NC]}" "$VARIANT_ID"
        read -p " " -r </dev/tty
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then exit 1; fi
        IS_ATOMIC=true
    else
        IS_ATOMIC=false
    fi
else
    echo "${MSG_OS_ERROR[$LNG]}"; exit 1
fi

# 1. Disable Cisco Repo
echo -e "\n${CL[P]}🟪🟪  01 / 12  🟪🟪  ${STEP_1[$LNG]}...🔧${CL[NC]}\n"
if [[ "$IS_ATOMIC" == true ]]; then
    [ -f /etc/yum.repos.d/fedora-cisco-openh264.repo ] && sudo sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/fedora-cisco-openh264.repo
else
    sudo dnf config-manager setopt fedora-cisco-openh264.enabled=0
fi
SaveResult "${STEP_1[$LNG]}" "$?"

# 2. Swap openh264
echo -e "\n${CL[P]}🟪🟪  02 / 12  🟪🟪  ${STEP_2[$LNG]}...🔧${CL[NC]}\n"
if [[ "$IS_ATOMIC" == true ]]; then
    sudo rpm-ostree override remove '*openh264*' --install noopenh264 -y
else
    sudo dnf swap '*openh264*' noopenh264 --allowerasing -y
fi
SaveResult "${STEP_2[$LNG]}" "$?"

# 3. System Update
echo -e "\n${CL[P]}🟪🟪  03 / 12  🟪🟪  ${STEP_3[$LNG]}...🔧${CL[NC]}\n"
if [[ "$IS_ATOMIC" == true ]]; then rpm-ostree upgrade -y; else sudo dnf update -y; fi
SaveResult "${STEP_3[$LNG]}" "$?"

# 4. Enable RPM Fusion
echo -e "\n${CL[P]}🟪🟪  04 / 12  🟪🟪  ${STEP_4[$LNG]}...🔧${CL[NC]}\n"
if [[ "$IS_ATOMIC" == true ]]; then
    rpm-ostree install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
else
    sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm || (sudo dnf repolist | grep -q 'rpmfusion-free')
fi
SaveResult "${STEP_4[$LNG]}" "$?"

# 5. Swap ffmpeg
echo -e "\n${CL[P]}🟪🟪  05 / 12  🟪🟪  ${STEP_5[$LNG]}...🔧${CL[NC]}\n"
if [[ "$IS_ATOMIC" == true ]]; then rpm-ostree override replace -y ffmpeg-free ffmpeg; else sudo dnf swap ffmpeg-free ffmpeg --allowerasing -y; fi
SaveResult "${STEP_5[$LNG]}" "$?"

# 6. GStreamer Codecs
echo -e "\n${CL[P]}🟪🟪  06 / 12  🟪🟪  ${STEP_6[$LNG]}...🔧${CL[NC]}\n"
if [[ "$IS_ATOMIC" == true ]]; then rpm-ostree install -y @multimedia --exclude=PackageKit-gstreamer-plugin; else sudo dnf install @multimedia --exclude=PackageKit-gstreamer-plugin -y; fi
SaveResult "${STEP_6[$LNG]}" "$?"

# 7. Global DNF Exception
echo -e "\n${CL[P]}🟪🟪  07 / 12  🟪🟪  ${STEP_7[$LNG]}...🔧${CL[NC]}\n"
if [[ "$IS_ATOMIC" == true ]]; then
    true
else
    sudo mkdir -p /etc/dnf/libdnf5.conf.d && \
    sudo tee /etc/dnf/libdnf5.conf.d/99-exclude-openh264.conf > /dev/null << 'EOF'
[main]
exclude=openh264*
EOF
fi
SaveResult "${STEP_7[$LNG]}" "$?"

# 8. Flatpak Mask
echo -e "\n${CL[P]}🟪🟪  08 / 12  🟪🟪  ${STEP_8[$LNG]}...🔧${CL[NC]}\n"
sudo flatpak mask org.freedesktop.Platform.openh264
SaveResult "${STEP_8[$LNG]}" "$?"

# 9. GPU Drivers (Pure AMD/Intel 64-bit Only)
echo -e "\n${CL[P]}🟪🟪  09 / 12  🟪🟪  ${STEP_9[$LNG]}...🔧${CL[NC]}\n"
GPU_VENDOR=$(lspci | grep -i "vga\|3d" | grep -oE "Intel|AMD" | head -1)
[ -z "$GPU_VENDOR" ] && GPU_VENDOR="Unknown"

if [ "$GPU_VENDOR" = "Intel" ]; then
    if [[ "$IS_ATOMIC" == true ]]; then 
        rpm-ostree install -y intel-media-driver libva-vdpau-driver
    else 
        sudo dnf install -y intel-media-driver libva-vdpau-driver
    fi
elif [ "$GPU_VENDOR" = "AMD" ]; then
    if [[ "$IS_ATOMIC" == true ]]; then
        rpm-ostree override replace -y mesa-va-drivers mesa-va-drivers-freeworld && \
        rpm-ostree override replace -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld
    else
        # Pure 64-bit drivers installation with updates-testing fallback
        sudo dnf install -y mesa-va-drivers-freeworld mesa-vdpau-drivers-freeworld --allowerasing || \
        sudo dnf install -y mesa-va-drivers-freeworld mesa-vdpau-drivers-freeworld --allowerasing --enablerepo=updates-testing --enablerepo=rpmfusion-free-updates-testing
    fi
else
    echo "ℹ️ Vendor is not AMD or Intel ($GPU_VENDOR). Skipping GPU acceleration steps."
fi
SaveResult "${STEP_9[$LNG]}" "$?"

# 10. Install VLC
echo -e "\n${CL[P]}🟪🟪  10 / 12  🟪🟪  ${STEP_10[$LNG]}...🔧${CL[NC]}\n"
if [[ "$IS_ATOMIC" == true ]]; then rpm-ostree install -y vlc; else sudo dnf install vlc -y; fi
SaveResult "${STEP_10[$LNG]}" "$?"

# 11. VLC Default (MIME fixed for real user)
echo -e "\n${CL[P]}🟪🟪  11 / 12  🟪🟪  ${STEP_11[$LNG]}...🔧${CL[NC]}\n"
if [ -n "$SUDO_USER" ]; then
    sudo -u $SUDO_USER xdg-mime default vlc.desktop video/mp4 video/x-matroska video/webm video/avi video/quicktime video/x-flv 2>/dev/null
else
    sudo mkdir -p /root/.config && \
    xdg-mime default vlc.desktop video/mp4 video/x-matroska video/webm video/avi video/quicktime video/x-flv 2>/dev/null
fi
SaveResult "${STEP_11[$LNG]}" "$?"

# 12. DNS-over-TLS Configuration
echo -e "\n${CL[P]}🟪🟪  12 / 12  🟪🟪  ${STEP_DNS[$LNG]}...🔧${CL[NC]}\n"
read -p "${MSG_DNS_PROMPT[$LNG]} " -r </dev/tty
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${MSG_DNS_SELECT[$LNG]}"
    read -p "> " DNS_CHOICE </dev/tty
    DNS_SERVERS=""
    case "$DNS_CHOICE" in
        1) DNS_SERVERS="9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net" ;;
        2) DNS_SERVERS="8.8.8.8#dns.google 8.8.4.4#dns.google" ;;
        3) DNS_SERVERS="1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com" ;;
        *) echo -e "${MSG_DNS_INVALID[$LNG]}"; false ;;
    esac
    case_status=$?

    if [ $case_status -eq 0 ] && [ -n "$DNS_SERVERS" ]; then
        sudo mkdir -p /etc/systemd/resolved.conf.d && \
        sudo tee /etc/systemd/resolved.conf.d/dot.conf > /dev/null << EOF
[Resolve]
DNS=$DNS_SERVERS
DNSOverTLS=yes
Domains=~.
EOF
        sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf && \
        sudo systemctl enable systemd-resolved --now && \
        sudo systemctl daemon-reload && \
        sudo systemctl restart systemd-resolved
    fi
else
    echo -e "${MSG_DNS_SKIPPING[$LNG]}"
    true
fi
SaveResult "${STEP_DNS[$LNG]}" "$?"

# === Summary ===
echo -e "${CL[P]}\n${MSG_RESULTS_HEADER[$LNG]} ${CL[Y]}(GPU $GPU_VENDOR)${CL[P]}"
echo -e "══════════════════════════════════════════════\n${CL[NC]}"
PrintResults
