#!/bin/bash
S_VERSION="v.1.05 (Mesa Sync Fix)"; clear
#set -euo pipefail  # Exit on error, unset vars, pipe failures
if [[ "$LANG" =~ ^ru ]]; then
    LNG="RU"
else
    LNG="EN"
fi

# === Language and Message Declarations ===
declare -A S_HEADER=( [EN]="\nCISCO OPENH264 'ERROR 403' GEOBLOCK REMOVAL and \nmultimedia codecs installation script for FEDORA LINUX \nby Andrei Manzhov, " [RU]="Скрипт снятия блокировки обновлений из-за CISCO OPENH264 \nи установки необходимых мультимедиа кодеков для ФЕДОРЫ ЛИНУКС \n  Андрей Маньжов, " )
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
declare -A MSG_GPU_INTEL=( [EN]="Intel Media Driver installed (hardware acceleration)" [RU]="Установлен Intel Media Driver (аппаратное ускорение)" )
declare -A MSG_GPU_AMD=( [EN]="mesa-va-drivers-freeworld installed (hardware acceleration)" [RU]="Установлены mesa-va-drivers-freeworld (аппаратное ускорение)" )
declare -A MSG_VLC_DEFAULT=( [EN]="VLC set as default player" [RU]="VLC установлен плеером по умолчанию" )
declare -A MSG_BROWSERS=( [EN]="SUGGESTION: ENABLE HARDWARE ACCELERATION IN APPLICATIONS" [RU]="СОВЕТ: ВКЛЮЧИТЕ HARDWARE ACCELERATION В ПРИЛОЖЕНИЯХ" )
declare -A MSG_DONE_HEADER=( [EN]="What was done:" [RU]="Что было сделано:" ) 
declare -A MSG_OS_WARNING=( [EN]="Warning: This script is designed for Fedora Linux, but detected '%s'." [RU]="Предупреждение: Этот скрипт предназначен для Fedora Linux, но обнаружен '%s'." )
declare -A MSG_EXITING=( [EN]="Exiting." [RU]="Выход." )
declare -A MSG_OS_ERROR=( [EN]="Error: Cannot detect OS. /etc/os-release not found." [RU]="Ошибка: Не удается определить ОС. /etc/os-release не найден." )
declare -A MSG_URL=( [EN]="All finished! For further updates on cisco geoblock issue check the thread at: \n - https://discussion.fedoraproject.org/t/ciscobinary-openh264-org-is-unreachable-in-some-countries-ru-ua-ir/." [RU]="Система готова к использованию! \nВопросы, связанные с этим кодеком, обсуждаются на сайте проекта по адресу: \n - https://discussion.fedoraproject.org/t/dnf-update-interrupted-all-mirrors-were-tried-cisco-openh264-geoblock/170877" )
declare -A MSG_OS_PROMPT=( [EN]="Do you want to continue anyway? (y/N): " [RU]="Хотите продолжить в любом случае? (y/N): " )
declare -A MSG_ATOMIC_WARNING=( [EN]="Warning: Atomic Fedora (%s) detected. Some commands require layering. Continue? (y/N): " [RU]="Предупреждение: Обнаружена Atomic Fedora (%s). Некоторые команды требуют layering. Продолжить? (y/N): " )
declare -A MSG_DNS_PROMPT=( [EN]="Do you want to configure DNS-over-TLS? (y/N): " [RU]="Хотите настроить DNS-over-TLS? (y/N): " )
declare -A MSG_DNS_SELECT=( [EN]="Select DNS provider:\n1) Quad9 (Privacy & Security)\n2) Google (Speed & Stability)\n3) Cloudflare (Speed & Privacy)\nEnter choice (1-3): " [RU]="Выберите DNS-провайдера:\n1) Quad9 (Приватность и безопасность)\n2) Google (Скорость и стабильность)\n3) Cloudflare (Скорость и приватность)\nВведите номер (1-3): " )
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
FAILED=();
DONE=()

echo -e "${CL[P]}${S_HEADER[$LNG]}${S_VERSION}"
echo -e "═══════════════════════════════════════════════════════════${CL[NC]}"
echo -e ""

if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    if [[ "$ID" != "fedora" ]]; then
        printf "${CL[R]}${MSG_OS_WARNING[$LNG]}" "$ID"
        echo
        read -p "${MSG_OS_PROMPT[$LNG]} " -r </dev/tty
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "${MSG_EXITING[$LNG]}"
            exit 1
        fi
    elif [[ "$VARIANT_ID" =~ ^(silverblue|kinoite|sericea)$ ]]; then  # Atomic variants
        printf "${CL[Y]}${MSG_ATOMIC_WARNING[$LNG]}${CL[NC]}" "$VARIANT_ID"
        read -p " " -r </dev/tty
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then exit 1; fi
        IS_ATOMIC=true
    else
        IS_ATOMIC=false  # Traditional Fedora
    fi
else
    echo "${MSG_OS_ERROR[$LNG]}"
    exit 1
fi

echo -e "\n${CL[P]}🟪🟪  01 / 12  🟪🟪  ${STEP_1[$LNG]}...🔧${CL[NC]}\n"

# 1. Disable the Cisco repo that is blocking update chain:
if [[ "$IS_ATOMIC" == true ]]; then
    if [ -f /etc/yum.repos.d/fedora-cisco-openh264.repo ]; then
        CMD="sudo sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/fedora-cisco-openh264.repo"
    else
        CMD="echo 'ℹ️ Cisco repo not found'"
    fi
else
    CMD="sudo dnf config-manager setopt fedora-cisco-openh264.enabled=0"
fi
eval "$CMD"
SaveResult "${STEP_1[$LNG]}" "$?"

echo -e "\n${CL[P]}🟪🟪  02 / 12  🟪🟪  ${STEP_2[$LNG]}...🔧${CL[NC]}\n"

# 2. Replace openh264 with noopenh264:
if [[ "$IS_ATOMIC" == true ]]; then
    CMD="sudo rpm-ostree override remove '*openh264*' --install noopenh264 -y"    
else
    CMD="sudo dnf swap '*openh264*' noopenh264 --allowerasing -y"
fi
eval "$CMD"
SaveResult "${STEP_2[$LNG]}" "$?"

echo -e "\n${CL[P]}🟪🟪  03 / 12  🟪🟪  ${STEP_3[$LNG]}...🔧${CL[NC]}\n"

# 3. Update the system:
if [[ "$IS_ATOMIC" == true ]]; then
    CMD="rpm-ostree upgrade -y"  
else
    CMD="sudo dnf update -y"
fi
eval "$CMD"
SaveResult "${STEP_3[$LNG]}" "$?"

echo -e "\n${CL[P]}🟪🟪  04 / 12  🟪🟪  ${STEP_4[$LNG]}...🔧${CL[NC]}\n"

# 4. Enable RPM Fusion (with a fallback check if already installed)
if [[ "$IS_ATOMIC" == true ]]; then
    CMD="rpm-ostree install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-\$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-\$(rpm -E %fedora).noarch.rpm"
else
    CMD="sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-\$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-\$(rpm -E %fedora).noarch.rpm || (sudo dnf repolist | grep -q 'rpmfusion-free')"
fi
eval "$CMD"
SaveResult "${STEP_4[$LNG]}" "$?"

echo -e "\n${CL[P]}🟪🟪  05 / 12  🟪🟪  ${STEP_5[$LNG]}...🔧${CL[NC]}\n"

# 5. Replace limited ffmpeg-free with full-featured ffmpeg from RPM Fusion
if [[ "$IS_ATOMIC" == true ]]; then
    CMD="rpm-ostree override replace -y ffmpeg-free ffmpeg"
else
    CMD="sudo dnf swap ffmpeg-free ffmpeg --allowerasing -y"
fi
eval "$CMD"
SaveResult "${STEP_5[$LNG]}" "$?"

echo -e "\n${CL[P]}🟪🟪  06 / 12  🟪🟪  ${STEP_6[$LNG]}...🔧${CL[NC]}\n"

# 6. Install necessary GStreamer plugins and codecs
if [[ "$IS_ATOMIC" == true ]]; then
    CMD="rpm-ostree install -y @multimedia --exclude=PackageKit-gstreamer-plugin"
else
    CMD="sudo dnf install @multimedia --exclude=PackageKit-gstreamer-plugin -y"
fi
eval "$CMD"
SaveResult "${STEP_6[$LNG]}" "$?"

echo -e "\n${CL[P]}🟪🟪  07 / 12  🟪🟪  ${STEP_7[$LNG]}...🔧${CL[NC]}\n"

# 7. Add global exception for openh264, creating a drop-in to the DNF config:
if [[ "$IS_ATOMIC" == true ]]; then
    CMD="echo 'Skipped on Atomic'"
else
    sudo mkdir -p /etc/dnf/libdnf5.conf.d
    sudo tee /etc/dnf/libdnf5.conf.d/99-exclude-openh264.conf > /dev/null << 'EOF'
[main]
exclude=openh264*
EOF
    CMD="true"
fi
eval "$CMD"
SaveResult "${STEP_7[$LNG]}" "$?"

echo -e "\n${CL[P]}🟪🟪  08 / 12  🟪🟪  ${STEP_8[$LNG]}...🔧${CL[NC]}\n"

# 8. Disable the Cisco codec that breaks Flatpak updates:
CMD="sudo flatpak mask org.freedesktop.Platform.openh264"
eval "$CMD"
SaveResult "${STEP_8[$LNG]}" "$?"

echo -e "\n${CL[P]}🟪🟪  09 / 12  🟪🟪  ${STEP_9[$LNG]}...🔧${CL[NC]}\n"

# 9. Install relevant hardware drivers with testing-repo fallback for AMD/Mesa desyncs
CMD="true"
GPU_VENDOR=$(lspci | grep -i "vga\|3d" | grep -oE "Intel|AMD|NVIDIA" | head -1 || echo "Unknown")
if [ "$GPU_VENDOR" = "Intel" ]; then
    if [[ "$IS_ATOMIC" == true ]]; then
        CMD="rpm-ostree install -y intel-media-driver libva-vdpau-driver"
    else
        CMD="sudo dnf install -y intel-media-driver libva-vdpau-driver"
    fi
elif [ "$GPU_VENDOR" = "AMD" ]; then
    if [[ "$IS_ATOMIC" == true ]]; then
        CMD="rpm-ostree install -y libva-mesa-driver && rpm-ostree override replace -y mesa-va-drivers mesa-va-drivers-freeworld && rpm-ostree override replace -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld"
    else
        # 64-bit drivers with testing repo fallback if standard swap fails
        CMD="sudo dnf install -y libva-mesa-driver && "
        CMD="$CMD (sudo dnf swap mesa-va-drivers mesa-va-drivers-freeworld -y || sudo dnf swap mesa-va-drivers mesa-va-drivers-freeworld -y --enablerepo=updates-testing --enablerepo=rpmfusion-free-updates-testing) && "
        CMD="$CMD (sudo dnf swap mesa-vdpau-drivers mesa-vdpau-drivers-freeworld -y || sudo dnf swap mesa-vdpau-drivers mesa-vdpau-drivers-freeworld -y --enablerepo=updates-testing --enablerepo=rpmfusion-free-updates-testing)"
        
        # 32-bit support (Steam, Wine) with testing repo fallback
        CMD="$CMD && (sudo dnf swap mesa-va-drivers.i686 mesa-va-drivers-freeworld.i686 -y --enablerepo=updates-testing --enablerepo=rpmfusion-free-updates-testing 2>/dev/null || sudo dnf swap mesa-va-drivers.i686 mesa-va-drivers-freeworld.i686 -y 2>/dev/null || true)"
        CMD="$CMD && (sudo dnf swap mesa-vdpau-drivers.i686 mesa-vdpau-drivers-freeworld.i686 -y --enablerepo=updates-testing --enablerepo=rpmfusion-free-updates-testing 2>/dev/null || sudo dnf swap mesa-vdpau-drivers.i686 mesa-vdpau-drivers-freeworld.i686 -y 2>/dev/null || true)"
    fi
elif [ "$GPU_VENDOR" = "NVIDIA" ]; then
    CMD="echo '⚠️ Manually install proprietary NVIDIA driver for better performance'"
else
    CMD="echo 'ℹ️ No specific GPU acceleration setup required for generic vendor'"
fi
eval "$CMD"
SaveResult "${STEP_9[$LNG]}" "$?"

echo -e "\n${CL[P]}🟪🟪  10 / 12  🟪🟪  ${STEP_10[$LNG]}...🔧${CL[NC]}\n"

# 10. Install VLC player
if [[ "$IS_ATOMIC" == true ]]; then
    CMD="sudo rpm-ostree install -y vlc"
else
    CMD="sudo dnf install vlc -y"
fi
eval "$CMD"
SaveResult "${STEP_10[$LNG]}" "$?"

echo -e "\n${CL[P]}🟪🟪  11 / 12  🟪🟪  ${STEP_11[$LNG]}...🔧${CL[NC]}\n"

# 11. Make VLC default player for all video formats (Configured for the actual user, not root)
if [ -n "$SUDO_USER" ]; then
    CMD="sudo -u $SUDO_USER xdg-mime default vlc.desktop video/mp4 video/x-matroska video/webm video/avi video/quicktime video/x-flv 2>/dev/null || true"
else
    sudo mkdir -p /root/.config
    CMD="xdg-mime default vlc.desktop video/mp4 video/x-matroska video/webm video/avi video/quicktime video/x-flv 2>/dev/null || true"
fi
eval "$CMD"
SaveResult "${STEP_11[$LNG]}" "$?"

echo -e "\n${CL[P]}🟪🟪  12 / 12  🟪🟪  ${STEP_DNS[$LNG]}...🔧${CL[NC]}\n"

# 12. Настройка DNS-over-TLS с интерактивным вводом через Pipe
CMD="true"
read -p "${MSG_DNS_PROMPT[$LNG]} " -r </dev/tty
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${MSG_DNS_SELECT[$LNG]}"
    read -p "> " DNS_CHOICE </dev/tty
    DNS_SERVERS=""
    case "$DNS_CHOICE" in
        1)
            DNS_SERVERS="9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net 2620:fe::fe#dns.quad9.net 2620:fe::9#dns.quad9.net"
            ;;
        2)
            DNS_SERVERS="8.8.8.8#dns.google 8.8.4.4#dns.google 2001:4860:4860::8888#dns.google 2001:4860:4860::8844#dns.google"
            ;;
        3)
            DNS_SERVERS="1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com 2606:4700:4700::1111#cloudflare-dns.com 2606:4700:4700::1001#cloudflare-dns.com"
            ;;
        *)
            echo -e "${MSG_DNS_INVALID[$LNG]}"
            CMD="false"
            ;;
    esac

    if [ -n "$DNS_SERVERS" ]; then
        sudo mkdir -p /etc/systemd/resolved.conf.d
        sudo tee /etc/systemd/resolved.conf.d/dot.conf > /dev/null << EOF
[Resolve]
DNS=$DNS_SERVERS
DNSOverTLS=yes
Domains=~.
EOF
        sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
        sudo systemctl enable systemd-resolved --now
        sudo systemctl daemon-reload
        sudo systemctl restart systemd-resolved
        CMD="true"
    fi
else
    echo -e "${MSG_DNS_SKIPPING[$LNG]}"
    CMD="true"
fi
eval "$CMD"
SaveResult "${STEP_DNS[$LNG]}" "$?"


echo -e "${CL[P]}\n${MSG_RESULTS_HEADER[$LNG]} ${CL[Y]}(GPU $GPU_VENDOR)${CL[P]}"
echo -e "══════════════════════════════════════════════\n${CL[NC]}"

PrintResults

echo -e ""
echo -e "${CL[P]}${MSG_BROWSERS[$LNG]}:"
echo -e "════════════════════════════════════════════════════════${CL[NC]}"
echo -e ""
echo -e "🌐 ${CL[B]}Firefox:${CL[NC]}"
echo -e "   1. about:config"
echo -e "   2. media.ffmpeg.enabled = true"
echo -e "   3. media.navigator.mediadatadecoder_h264_enabled = true"
echo -e ""
echo -e "🌐 ${CL[B]}Chromium:${CL[NC]}"
echo -e "   1. chrome://flags"
echo -e "   2. --> 'hardware video'"
echo -e "   3. Hardware-accelerated video decode = Enabled"
echo -e ""
echo -e "${CL[P]}${MSG_URL[$LNG]}\n"
