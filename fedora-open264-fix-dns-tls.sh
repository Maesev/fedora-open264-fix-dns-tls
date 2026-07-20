#!/bin/bash
# === FEDORA OPENH264 GEOBLOCK FIX v3.5 ===
# Исправлено: cosmic не Atomic, видимый прогресс, версия при запуске

# Защита от sh
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi

# Цвета
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
BLUE='\e[34m'
PURPLE='\e[35m'
CYAN='\e[36m'
NC='\e[0m'

SCRIPT_VERSION="v3.5"

clear

# Проверка root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Run as root (sudo) / Запустите через sudo${NC}"
    exit 1
fi

# ============================================================
# ЯЗЫК
# ============================================================
LNG="EN"
[[ "${LANG:-} ${LC_ALL:-} ${LANGUAGE:-}" =~ ru ]] && LNG="RU"

# Тексты RU/EN
if [[ "$LNG" == "RU" ]]; then
    T_HEADER="СНЯТИЕ ГЕОБЛОКА CISCO OPENH264 & МЕДИА КОДЕКИ"
    T_TARGET="для FEDORA LINUX 43/44/45"
    T_OS_WARN="Предупреждение: Не Fedora (найдено: %s). Продолжить? (y/N): "
    T_ATOMIC="Atomic Fedora (%s) обнаружена. Потребуется перезагрузка."
    T_RPMFAIL="КРИТИЧНО: RPM Fusion не включён!"
    T_DNS_PROMPT="Настроить DNS-over-TLS? (y/N): "
    T_DNS_SELECT="Выбор: 1) Quad9  2) Google  3) Cloudflare"
    T_DNS_DONE="DNS-over-TLS настроен"
    T_DNS_SKIP="Пропущено"
    T_REBOOT="⚠ Требуется перезагрузка для Atomic Fedora"
    T_HINT="Перезапустите браузеры, включите аппаратное ускорение"
    T_DONE="ВСЁ ГОТОВО"
    T_RUNNING="▶ Выполняется..."
    T_DETECTED="Обнаружено: Fedora %s (%s)"
    T_INTEL="Intel GPU"
    T_AMD="AMD GPU"
    T_NVIDIA="NVIDIA GPU"
    T_NO_GPU="Дискретный GPU не обнаружен"
    T_FLATPAK_MISSING="Flatpak не установлен, пропуск"
    T_SYSTEMD_MISSING="systemd-resolved не найден"

    S1="Отключение репозитория Cisco"
    S2="Замена openh264 → noopenh264"
    S3="Обновление системы"
    S4="Включение RPM Fusion"
    S5="Замена ffmpeg-free → ffmpeg"
    S6="Установка медиа кодеков"
    S7="Добавление libavcodec-freeworld"
    S8="Исключение openh264 из DNF"
    S9="Маскировка Flatpak openh264"
    S10="Установка GPU драйверов"
    S11="Установка VLC"
    S12="VLC по умолчанию"
    S13="DNS-over-TLS (опц.)"
else
    T_HEADER="CISCO OPENH264 GEOBLOCK FIX & MULTIMEDIA CODECS"
    T_TARGET="for FEDORA LINUX 43/44/45"
    T_OS_WARN="Warning: Not Fedora (found: %s). Continue? (y/N): "
    T_ATOMIC="Atomic Fedora (%s) detected. Reboot required after."
    T_RPMFAIL="CRITICAL: RPM Fusion not enabled!"
    T_DNS_PROMPT="Configure DNS-over-TLS? (y/N): "
    T_DNS_SELECT="Select: 1) Quad9  2) Google  3) Cloudflare"
    T_DNS_DONE="DNS-over-TLS configured"
    T_DNS_SKIP="Skipped"
    T_REBOOT="⚠ Reboot required for Atomic Fedora"
    T_HINT="Restart browsers, enable hardware acceleration"
    T_DONE="ALL DONE"
    T_RUNNING="▶ Running..."
    T_DETECTED="Detected: Fedora %s (%s)"
    T_INTEL="Intel GPU"
    T_AMD="AMD GPU"
    T_NVIDIA="NVIDIA GPU"
    T_NO_GPU="No discrete GPU detected"
    T_FLATPAK_MISSING="Flatpak not installed, skipping"
    T_SYSTEMD_MISSING="systemd-resolved not found"

    S1="Disable Cisco repo (geoblock fix)"
    S2="Replace openh264 → noopenh264"
    S3="Full system update"
    S4="Enable RPM Fusion repositories"
    S5="Swap ffmpeg-free → full ffmpeg"
    S6="Install multimedia codecs"
    S7="Add libavcodec-freeworld"
    S8="Exclude openh264 from DNF"
    S9="Mask Flatpak openh264"
    S10="Install GPU drivers"
    S11="Install VLC"
    S12="Set VLC as default"
    S13="DNS-over-TLS (optional)"
fi

# Массив шагов
STEPS=("$S1" "$S2" "$S3" "$S4" "$S5" "$S6" "$S7" "$S8" "$S9" "$S10" "$S11" "$S12" "$S13")
TOTAL=${#STEPS[@]}

# ЛОГ
LOG="/tmp/fedora-open264-fix-$$.log"
TIME_START=$(date +%s)
L() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

print_step() {
    local n="$1"
    echo -e "\n${PURPLE}📦 $(printf '%02d' $n)/$TOTAL ${STEPS[$((n-1))]}${NC}"
    echo -e "${CYAN}   ${T_RUNNING}${NC}"
    echo ""
}

mark_ok()    { echo -e "\n   ${GREEN}✓ OK${NC}";      L "Step $1: OK"; }
mark_warn()  { echo -e "\n   ${YELLOW}⚠ Warning${NC}"; L "Step $1: Warning"; }
mark_fail()  { echo -e "\n   ${RED}✗ FAILED${NC}";    L "Step $1: FAILED"; }

# ============================================================
# ЗАГОЛОВОК С ВЕРСИЕЙ
# ============================================================
echo -e "${PURPLE}═══════════════════════════════════════════════════${NC}"
echo -e "${PURPLE}  ${T_HEADER}${NC}"
echo -e "${PURPLE}  ${T_TARGET}${NC}"
echo -e "${PURPLE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Version: ${SCRIPT_VERSION}${NC}"
echo -e "${BLUE}  Lang: ${LNG}${NC}"
echo -e "${BLUE}  Log:  ${LOG}${NC}"
echo -e "${PURPLE}═══════════════════════════════════════════════════${NC}"
echo ""
L "=== Script ${SCRIPT_VERSION} started | Lang=$LNG ==="

# ============================================================
# ОПРЕДЕЛЕНИЕ ОС
# ============================================================
if [[ ! -f /etc/os-release ]]; then
    echo -e "${RED}Error: /etc/os-release not found${NC}"
    exit 1
fi
source /etc/os-release
L "OS: $ID $VERSION_ID ($VARIANT_ID)"

if [[ "$ID" != "fedora" ]]; then
    printf "${YELLOW}${T_OS_WARN}${NC}" "$ID"
    read -r
    [[ ! "$REPLY" =~ ^[Yy]$ ]] && exit 1
fi

# ИСПРАВЛЕНО: cosmic НЕ Atomic! Только silverblue/kinoite/sericea
IS_ATOMIC=false
if [[ "$VARIANT_ID" =~ ^(silverblue|kinoite|sericea)$ ]]; then
    IS_ATOMIC=true
    printf "${YELLOW}${T_ATOMIC}${NC}\n" "$VARIANT_ID"
    L "Atomic mode: $VARIANT_ID"
fi

FEDORA_VER=$(rpm -E %fedora)
printf "${BLUE}${T_DETECTED}${NC}\n" "$FEDORA_VER" "${VARIANT_ID:-workstation}"
L "Fedora version: $FEDORA_VER"

# ============================================================
# STEP 1: ОТКЛЮЧЕНИЕ CISCO REPO
# ============================================================
print_step 1
if [[ "$IS_ATOMIC" == true ]]; then
    if [[ -f /etc/yum.repos.d/fedora-cisco-openh264.repo ]]; then
        sed -i 's/^enabled=.*/enabled=0/' /etc/yum.repos.d/fedora-cisco-openh264.repo
        echo "  Disabled: fedora-cisco-openh264.repo"
    fi
    mark_ok 1
else
    if dnf config-manager --set-disabled fedora-cisco-openh264 2>&1 | tee -a "$LOG"; then
        mark_ok 1
    elif [[ -f /etc/yum.repos.d/fedora-cisco-openh264.repo ]]; then
        sed -i 's/^enabled=.*/enabled=0/' /etc/yum.repos.d/fedora-cisco-openh264.repo
        echo "  Manual disable: sed enabled=0"
        mark_ok 1
    else
        echo "  Repo not found, skipping"
        mark_warn 1
    fi
fi

# ============================================================
# STEP 2: ЗАМЕНА openh264 → noopenh264
# ============================================================
print_step 2
if [[ "$IS_ATOMIC" == true ]]; then
    rpm-ostree install noopenh264 -y 2>&1 | tee -a "$LOG"
    rpm-ostree override remove openh264 -y 2>&1 | tee -a "$LOG"
    [[ ${PIPESTATUS[0]} -eq 0 ]] && mark_ok 2 || mark_warn 2
else
    if dnf swap '*openh264*' noopenh264 --allowerasing -y 2>&1 | tee -a "$LOG"; then
        mark_ok 2
    elif dnf install noopenh264 -y 2>&1 | tee -a "$LOG" && \
         dnf remove openh264 -y 2>&1 | tee -a "$LOG"; then
        mark_ok 2
    else
        mark_warn 2
    fi
fi

# ============================================================
# STEP 3: ОБНОВЛЕНИЕ СИСТЕМЫ (видимый прогресс!)
# ============================================================
print_step 3
if [[ "$IS_ATOMIC" == true ]]; then
    rpm-ostree upgrade -y 2>&1 | tee -a "$LOG"
    RC=${PIPESTATUS[0]}
else
    dnf update -y 2>&1 | tee -a "$LOG"
    RC=${PIPESTATUS[0]}
fi
[[ $RC -eq 0 ]] && mark_ok 3 || mark_warn 3

# ============================================================
# STEP 4: RPM FUSION
# ============================================================
print_step 4
FREE_URL="https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm"
NONFREE_URL="https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm"

if [[ "$IS_ATOMIC" == true ]]; then
    rpm-ostree install -y "$FREE_URL" "$NONFREE_URL" 2>&1 | tee -a "$LOG"
else
    dnf install -y "$FREE_URL" "$NONFREE_URL" 2>&1 | tee -a "$LOG"
fi

echo "  Checking RPM Fusion repos..."
sleep 2
if dnf repolist 2>/dev/null | grep -qi "rpmfusion"; then
    echo "  RPM Fusion: ACTIVE"
    mark_ok 4
else
    echo "  RPM Fusion not detected, attempting fix..."
    if [[ "$IS_ATOMIC" != true ]]; then
        dnf config-manager setopt rpmfusion-free.enabled=1 2>&1 | tee -a "$LOG" || true
        dnf config-manager setopt rpmfusion-free-updates.enabled=1 2>&1 | tee -a "$LOG" || true
        dnf config-manager setopt rpmfusion-nonfree.enabled=1 2>&1 | tee -a "$LOG" || true
        dnf config-manager setopt rpmfusion-nonfree-updates.enabled=1 2>&1 | tee -a "$LOG" || true
        dnf config-manager setopt rpmfusion-free-rawhide.enabled=0 2>&1 | tee -a "$LOG" || true
        dnf config-manager setopt rpmfusion-nonfree-rawhide.enabled=0 2>&1 | tee -a "$LOG" || true
    fi
    if dnf repolist 2>/dev/null | grep -qi "rpmfusion"; then
        echo "  RPM Fusion: FIXED & ACTIVE"
        mark_ok 4
    else
        echo -e "   ${RED}${T_RPMFAIL}${NC}"
        mark_fail 4
        echo -e "\n${RED}═══════════════════════════════════════════════${NC}"
        echo -e "${RED}Cannot continue without RPM Fusion.${NC}"
        echo -e "${CYAN}Log: $LOG${NC}"
        exit 1
    fi
fi

# ============================================================
# STEP 5: SWAP ffmpeg-free → ffmpeg
# ============================================================
print_step 5
if [[ "$IS_ATOMIC" == true ]]; then
    rpm-ostree override remove \
        libavcodec-free libavfilter-free libavformat-free \
        libavutil-free libpostproc-free libswresample-free libswscale-free \
        --install ffmpeg -y 2>&1 | tee -a "$LOG"
    [[ ${PIPESTATUS[0]} -eq 0 ]] && mark_ok 5 || mark_warn 5
else
    if dnf swap ffmpeg-free ffmpeg --allowerasing -y 2>&1 | tee -a "$LOG"; then
        mark_ok 5
    elif dnf install ffmpeg --allowerasing -y 2>&1 | tee -a "$LOG"; then
        mark_ok 5
    else
        mark_warn 5
    fi
fi

# ============================================================
# STEP 6: МУЛЬТИМЕДИЙНЫЕ КОДЕКИ
# ============================================================
print_step 6
if [[ "$IS_ATOMIC" == true ]]; then
    rpm-ostree install -y @multimedia \
        --exclude=PackageKit-gstreamer-plugin \
        --exclude=gstreamer1-plugin-openh264 2>&1 | tee -a "$LOG"
    [[ ${PIPESTATUS[0]} -eq 0 ]] && mark_ok 6 || mark_warn 6
else
    if dnf group install multimedia --exclude=PackageKit-gstreamer-plugin -y 2>&1 | tee -a "$LOG"; then
        mark_ok 6
    elif dnf groupinstall -y @multimedia --exclude=PackageKit-gstreamer-plugin 2>&1 | tee -a "$LOG"; then
        mark_ok 6
    else
        mark_warn 6
    fi
fi

# ============================================================
# STEP 7: libavcodec-freeworld
# ============================================================
print_step 7
if [[ "$IS_ATOMIC" == true ]]; then
    rpm-ostree install -y libavcodec-freeworld 2>&1 | tee -a "$LOG"
else
    dnf install -y libavcodec-freeworld 2>&1 | tee -a "$LOG"
fi
[[ ${PIPESTATUS[0]} -eq 0 ]] && mark_ok 7 || mark_warn 7

# ============================================================
# STEP 8: ИСКЛЮЧЕНИЕ openh264 ИЗ DNF
# ============================================================
print_step 8
if [[ "$IS_ATOMIC" == true ]]; then
    echo "  Handled by override in Step 2"
    mark_ok 8
else
    mkdir -p /etc/dnf/libdnf5.conf.d /etc/dnf/conf.d 2>/dev/null

    echo "[main]
exclude=openh264*" > /etc/dnf/libdnf5.conf.d/99-exclude-openh264.conf
    echo "[main]
exclude=openh264*" > /etc/dnf/conf.d/99-exclude-openh264.conf

    echo "  Written: /etc/dnf/libdnf5.conf.d/99-exclude-openh264.conf"
    echo "  Written: /etc/dnf/conf.d/99-exclude-openh264.conf"

    if [[ -f /etc/dnf/libdnf5.conf.d/99-exclude-openh264.conf ]] || \
       [[ -f /etc/dnf/conf.d/99-exclude-openh264.conf ]]; then
        mark_ok 8
    else
        mark_fail 8
    fi
fi

# ============================================================
# STEP 9: МАСКИРОВКА FLATPAK OPENH264
# ============================================================
print_step 9
if command -v flatpak &>/dev/null; then
    if flatpak mask org.freedesktop.Platform.openh264 2>&1 | tee -a "$LOG"; then
        mark_ok 9
    else
        mark_warn 9
    fi
else
    echo -e "   ${YELLOW}${T_FLATPAK_MISSING}${NC}"
    mark_warn 9
fi

# ============================================================
# STEP 10: GPU ДРАЙВЕРЫ
# ============================================================
print_step 10
GPU_LINE=$(lspci 2>/dev/null | grep -i "vga\|3d" | head -1)
L "GPU line: $GPU_LINE"

if echo "$GPU_LINE" | grep -qi "intel"; then
    echo -e "   ${BLUE}${T_INTEL}${NC}"
    if [[ "$IS_ATOMIC" == true ]]; then
        rpm-ostree install -y intel-media-driver libva-utils 2>&1 | tee -a "$LOG"
    else
        dnf install -y intel-media-driver libva-utils 2>&1 | tee -a "$LOG"
    fi
elif echo "$GPU_LINE" | grep -qiE "amd|radeon"; then
    echo -e "   ${BLUE}${T_AMD}${NC}"
    if [[ "$IS_ATOMIC" == true ]]; then
        rpm-ostree install -y mesa-va-drivers-freeworld 2>&1 | tee -a "$LOG"
    else
        dnf install -y mesa-va-drivers-freeworld --allowerasing 2>&1 | tee -a "$LOG"
    fi
elif echo "$GPU_LINE" | grep -qi "nvidia"; then
    echo -e "   ${BLUE}${T_NVIDIA}${NC}"
    if [[ "$IS_ATOMIC" == true ]]; then
        rpm-ostree install -y akmod-nvidia 2>&1 | tee -a "$LOG"
    else
        dnf install -y akmod-nvidia 2>&1 | tee -a "$LOG"
    fi
else
    echo -e "   ${YELLOW}${T_NO_GPU}${NC}"
fi
[[ ${PIPESTATUS[0]} -eq 0 ]] && mark_ok 10 || mark_warn 10

# ============================================================
# STEP 11: VLC
# ============================================================
print_step 11
if [[ "$IS_ATOMIC" == true ]]; then
    rpm-ostree install -y vlc 2>&1 | tee -a "$LOG"
else
    dnf install -y vlc 2>&1 | tee -a "$LOG"
fi
[[ ${PIPESTATUS[0]} -eq 0 ]] && mark_ok 11 || mark_warn 11

# ============================================================
# STEP 12: VLC ПО УМОЛЧАНИЮ
# ============================================================
print_step 12
VIDEO_MIMES="video/mp4 video/x-matroska video/webm video/avi video/quicktime video/x-flv"
SET_OK=false

if [[ -n "$SUDO_USER" ]] && id "$SUDO_USER" &>/dev/null; then
    if sudo -u "$SUDO_USER" xdg-mime default vlc.desktop $VIDEO_MIMES 2>&1 | tee -a "$LOG"; then
        SET_OK=true
    fi
fi
if [[ "$SET_OK" != true ]]; then
    xdg-mime default vlc.desktop video/mp4 2>&1 | tee -a "$LOG" && SET_OK=true
fi
[[ "$SET_OK" == true ]] && mark_ok 12 || mark_warn 12

# ============================================================
# STEP 13: DNS-OVER-TLS (ОПЦИОНАЛЬНО)
# ============================================================
print_step 13
echo -ne "${T_DNS_PROMPT}"
read -r </dev/tty

if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    echo -e "${T_DNS_SELECT}"
    read -p "> " DNS_CHOICE </dev/tty
    case "$DNS_CHOICE" in
        1) DNS_SRV="9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net" ;;
        2) DNS_SRV="8.8.8.8#dns.google 8.8.4.4#dns.google" ;;
        3) DNS_SRV="1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com" ;;
        *) DNS_SRV="" ;;
    esac
    if [[ -n "$DNS_SRV" ]]; then
        if systemctl list-unit-files systemd-resolved.service &>/dev/null; then
            mkdir -p /etc/systemd/resolved.conf.d
            cat > /etc/systemd/resolved.conf.d/dot.conf <<DOTEOF
[Resolve]
DNS=$DNS_SRV
DNSOverTLS=yes
Domains=~.
DOTEOF
            ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf 2>>"$LOG" || true
            systemctl enable systemd-resolved --now 2>>"$LOG" || true
            systemctl restart systemd-resolved 2>>"$LOG" || true
            echo "  systemd-resolved configured with DNS-over-TLS"
            echo -e "   ${GREEN}✓ ${T_DNS_DONE}${NC}"
            mark_ok 13
        else
            echo -e "   ${YELLOW}${T_SYSTEMD_MISSING}${NC}"
            mark_warn 13
        fi
    else
        echo -e "   ${YELLOW}${T_DNS_SKIP}${NC}"
        mark_warn 13
    fi
else
    echo -e "   ${YELLOW}${T_DNS_SKIP}${NC}"
    mark_ok 13
fi

# ============================================================
# ИТОГИ
# ============================================================
ELAPSED=$(( $(date +%s) - TIME_START ))

echo ""
echo -e "${PURPLE}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ${T_DONE}${NC}"
echo -e "${BLUE}  Time: ${ELAPSED}s${NC}"
echo -e "${BLUE}  Log:  ${LOG}${NC}"
if [[ "$IS_ATOMIC" == true ]]; then
    echo -e "${YELLOW}  ${T_REBOOT}${NC}"
fi
echo -e "${CYAN}  ${T_HINT}${NC}"
echo -e "${PURPLE}═══════════════════════════════════════════════════${NC}"

L "=== Script ${SCRIPT_VERSION} finished | Time=${ELAPSED}s ==="
exit 0