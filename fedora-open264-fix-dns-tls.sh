#!/bin/bash
# === FEDORA OPENH264 GEOBLOCK FIX v3.4 (VISIBLE PROGRESS) ===
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

# Тексты
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

    T_INTEL="Intel GPU"
    T_AMD="AMD GPU"
    T_NVIDIA="NVIDIA GPU"
    T_NO_GPU="Дискретный GPU не обнаружен"
    T_FLATPAK_MISSING="Flatpak не установлен, пропуск"
    T_SYSTEMD_MISSING="systemd-resolved не найден"
    T_DETECTED="Обнаружено: Fedora %s (%s)"
    T_UPDATING="⏳ Обновление системы (это может занять время)..."
    T_WAITING="⏳ Подождите..."
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

    T_INTEL="Intel GPU"
    T_AMD="AMD GPU"
    T_NVIDIA="NVIDIA GPU"
    T_NO_GPU="No discrete GPU detected"
    T_FLATPAK_MISSING="Flatpak not installed, skipping"
    T_SYSTEMD_MISSING="systemd-resolved not found"
    T_DETECTED="Detected: Fedora %s (%s)"
    T_UPDATING="⏳ Updating system (this may take a while)..."
    T_WAITING="⏳ Please wait..."
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
    echo -e "\n${PURPLE}📦 $(printf '%02d' $n)/$TOTAL ${STEPS[$((n-1))]}...${NC}"
}

mark_ok() { echo -e "   ${GREEN}✓ OK${NC}"; L "Step $1: OK"; }
mark_warn() { echo -e "   ${YELLOW}⚠ Warning${NC}"; L "Step $1: Warning"; }
mark_fail() { echo -e "   ${RED}✗ FAILED${NC}"; L "Step $1: FAILED"; }

# ========================================
# ЗАГОЛОВОК
# ========================================
echo -e "${PURPLE}═══════════════════════════════════════════════${NC}"
echo -e "${PURPLE} ${T_HEADER}${NC}"
echo -e "${PURPLE} ${T_TARGET}${NC}"
echo -e "${PURPLE}═══════════════════════════════════════════════${NC}"
echo -e "Lang: $LNG | Log: ${CYAN}$LOG${NC}"
echo ""
L "=== Script started | Lang=$LNG ==="

# ========================================
# OS DETECTION
# ========================================
if [[ ! -f /etc/os-release ]]; then
    echo -e "${RED}Error: /etc/os-release not found${NC}"
    exit 1
fi
source /etc/os-release

if [[ "$ID" != "fedora" ]]; then
    printf "${YELLOW}${T_OS_WARN}${NC}" "$ID"
    read -r
    [[ ! "$REPLY" =~ ^[Yy]$ ]] && exit 1
fi

IS_ATOMIC=false
if [[ "$VARIANT_ID" =~ ^(silverblue|kinoite|sericea|cosmic)$ ]]; then
    IS_ATOMIC=true
    printf "${YELLOW}${T_ATOMIC}${NC}\n" "$VARIANT_ID"
fi

FEDORA_VER=$(rpm -E %fedora)
printf "${BLUE}${T_DETECTED}${NC}\n" "$FEDORA_VER" "${VARIANT_ID:-standard}"

# Install dnf-plugins-core
if [[ "$IS_ATOMIC" != true ]]; then
    dnf install -y dnf-plugins-core >> "$LOG" 2>&1
fi

# ========================================
# STEP 1: DISABLE CISCO REPO
# ========================================
print_step 1
if [[ "$IS_ATOMIC" == true ]]; then
    [[ -f /etc/yum.repos.d/fedora-cisco-openh264.repo ]] && \
        sed -i 's/^enabled=.*/enabled=0/' /etc/yum.repos.d/fedora-cisco-openh264.repo
else
    dnf config-manager --set-disabled fedora-cisco-openh264 >> "$LOG" 2>&1
fi
[[ $? -eq 0 ]] && mark_ok 1 || mark_warn 1

# ========================================
# STEP 2: REPLACE OPENH264
# ========================================
print_step 2
if [[ "$IS_ATOMIC" == true ]]; then
    rpm-ostree install noopenh264 -y --override-remove=openh264 >> "$LOG" 2>&1
else
    dnf swap '*openh264*' noopenh264 --allowerasing -y >> "$LOG" 2>&1
fi
[[ $? -eq 0 ]] && mark_ok 2 || mark_warn 2

# ========================================
# STEP 3: SYSTEM UPDATE (ИСПРАВЛЕНО!)
# ========================================
print_step 3
echo -e "   ${CYAN}${T_UPDATING}${NC}"
echo -e "   ${YELLOW}${T_WAITING}${NC}\n"

if [[ "$IS_ATOMIC" == true ]]; then
    rpm-ostree upgrade -y | tee -a "$LOG"
    RC=${PIPESTATUS[0]}
else
    dnf update -y | tee -a "$LOG"
    RC=${PIPESTATUS[0]}
fi

if [[ $RC -eq 0 ]]; then
    mark_ok 3
else
    mark_warn 3
fi

# ========================================
# STEP 4: ENABLE RPM FUSION
# ========================================
print_step 4
FREE_URL="https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm"
NONFREE_URL="https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm"

if [[ "$IS_ATOMIC" == true ]]; then
    rpm-ostree install -y "$FREE_URL" "$NONFREE_URL" >> "$LOG" 2>&1
else
    dnf install -y "$FREE_URL" "$NONFREE_URL" >> "$LOG" 2>&1
fi

sleep 2
if dnf repolist 2>/dev/null | grep -qi "rpmfusion"; then
    mark_ok 4
else
    echo -e "   ${RED}${T_RPMFAIL}${NC}"
    mark_fail 4
    exit 1
fi

# ========================================
# STEP 5: SWAP FFMPeg
# ========================================
print_step 5
if [[ "$IS_ATOMIC" == true ]]; then
    rpm-ostree override remove libavcodec-free libavfilter-free libavformat-free \
        libavutil-free libpostproc-free libswresample-free libswscale-free \
        --install ffmpeg -y >> "$LOG" 2>&1
else
    dnf swap ffmpeg-free ffmpeg --allowerasing -y >> "$LOG" 2>&1
fi
[[ $? -eq 0 ]] && mark_ok 5 || mark_warn 5

# ========================================
# STEP 6: MULTIMEDIA
# ========================================
print_step 6
if [[ "$IS_ATOMIC" == true ]]; then
    rpm-ostree install -y @multimedia --exclude=PackageKit-gstreamer-plugin >> "$LOG" 2>&1
else
    dnf group install multimedia --exclude=PackageKit-gstreamer-plugin -y >> "$LOG" 2>&1
fi
[[ $? -eq 0 ]] && mark_ok 6 || mark_warn 6

# ========================================
# STEP 7: LIBAVCODEC FREEWORLD
# ========================================
print_step 7
if [[ "$IS_ATOMIC" == true ]]; then
    rpm-ostree install -y libavcodec-freeworld >> "$LOG" 2>&1
else
    dnf install -y libavcodec-freeworld >> "$LOG" 2>&1
fi
[[ $? -eq 0 ]] && mark_ok 7 || mark_warn 7

# ========================================
# STEP 8: EXCLUDE OPENH264
# ========================================
print_step 8
mkdir -p /etc/dnf/libdnf5.conf.d /etc/dnf/conf.d 2>/dev/null
cat > /etc/dnf/libdnf5.conf.d/99-exclude-openh264.conf <<'EOF'
[main]
exclude=openh264*
EOF
[[ -f /etc/dnf/libdnf5.conf.d/99-exclude-openh264.conf ]] && mark_ok 8 || mark_fail 8

# ========================================
# STEP 9: MASK FLATPAK
# ========================================
print_step 9
if command -v flatpak &>/dev/null; then
    flatpak mask org.freedesktop.Platform.openh264 >> "$LOG" 2>&1 && \
        mark_ok 9 || mark_warn 9
else
    echo -e "   ${YELLOW}${T_FLATPAK_MISSING}${NC}"
    mark_warn 9
fi

# ========================================
# STEP 10: GPU DRIVERS
# ========================================
print_step 10
GPU_LINE=$(lspci 2>/dev/null | grep -i "vga\|3d" | head -1)
if echo "$GPU_LINE" | grep -qi "intel"; then
    echo -e "   ${BLUE}${T_INTEL}${NC}"
    [[ "$IS_ATOMIC" == true ]] && rpm-ostree install -y intel-media-driver libva-utils >> "$LOG" 2>&1 || \
        dnf install -y intel-media-driver libva-utils >> "$LOG" 2>&1
elif echo "$GPU_LINE" | grep -qiE "amd|radeon"; then
    echo -e "   ${BLUE}${T_AMD}${NC}"
    [[ "$IS_ATOMIC" == true ]] && rpm-ostree install -y mesa-va-drivers-freeworld >> "$LOG" 2>&1 || \
        dnf install -y mesa-va-drivers-freeworld --allowerasing >> "$LOG" 2>&1
elif echo "$GPU_LINE" | grep -qi "nvidia"; then
    echo -e "   ${BLUE}${T_NVIDIA}${NC}"
    [[ "$IS_ATOMIC" == true ]] && rpm-ostree install -y akmod-nvidia >> "$LOG" 2>&1 || \
        dnf install -y akmod-nvidia >> "$LOG" 2>&1
else
    echo -e "   ${YELLOW}${T_NO_GPU}${NC}"
fi
[[ $? -eq 0 ]] && mark_ok 10 || mark_warn 10

# ========================================
# STEP 11: VLC
# ========================================
print_step 11
[[ "$IS_ATOMIC" == true ]] && rpm-ostree install -y vlc >> "$LOG" 2>&1 || \
    dnf install -y vlc >> "$LOG" 2>&1
[[ $? -eq 0 ]] && mark_ok 11 || mark_warn 11

# ========================================
# STEP 12: DEFAULT VLC
# ========================================
print_step 12
[[ -n "$SUDO_USER" ]] && id "$SUDO_USER" &>/dev/null && \
    sudo -u "$SUDO_USER" xdg-mime default vlc.desktop video/mp4 2>>"$LOG"
xdg-mime default vlc.desktop video/mp4 2>>"$LOG"
mark_ok 12

# ========================================
# STEP 13: DNS OVER TLS
# ========================================
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
        *) echo -e "   ${YELLOW}${T_DNS_SKIP}${NC}"; exit 0 ;;
    esac
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
        echo -e "   ${GREEN}✓ ${T_DNS_DONE}${NC}"
        mark_ok 13
    else
        echo -e "   ${YELLOW}${T_SYSTEMD_MISSING}${NC}"
        mark_warn 13
    fi
else
    echo -e "   ${YELLOW}${T_DNS_SKIP}${NC}"
    mark_ok 13
fi

# ========================================
# SUMMARY
# ========================================
ELAPSED=$(( $(date +%s) - TIME_START ))
echo -e "\n${PURPLE}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}${T_DONE}${NC}"
[[ "$IS_ATOMIC" == true ]] && echo -e "${YELLOW}${T_REBOOT}${NC}"
echo -e "${CYAN}${T_HINT}${NC}"
echo -e "${PURPLE}═══════════════════════════════════════════════${NC}"
L "=== Script finished ==="
exit 0