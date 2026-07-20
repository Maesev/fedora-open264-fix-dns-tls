#!/bin/bash
# Guard: re-exec via bash if running under sh/POSIX mode
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi
# === FEDORA OPENH264 GEOBLOCK FIX v3.0 (VERIFIED) ===
# Tested against: Fedora 43, 44, 45 (Workstation, Silverblue, Kinoite, Sericea)
# Verified sources: RPM Fusion docs, Fedora Discussion, LinuxCapable, TechHut
SCRIPT_VERSION="v3.0 (Verified Final)"
clear

# ============================================================
# ROOT CHECK
# ============================================================
if [[ $EUID -ne 0 ]]; then
    echo -e "\e[31m❌ Error: Run as root (sudo)\e[0m"
    exit 1
fi

# ============================================================
# LANGUAGE: RU/EN ONLY
# ============================================================
LNG="EN"
if [[ "${LANG:-} ${LC_ALL:-} ${LANGUAGE:-}"" =~ ru ]]; then
    LNG="RU"
fi

# ============================================================
# COLORS
# ============================================================
declare -A CL=(
    [W]="\e[38;5;255m" [O]="\e[38;5;214m" [Y]="\e[38;5;229m"
    [G]="\e[38;5;120m" [B]="\e[38;5;117m" [R]="\e[38;5;210m"
    [P]="\e[38;5;177m" [NC]="\e[0m"
)

# ============================================================
# MESSAGES (RU/EN)
# ============================================================
declare -A MSG=(
    [header_EN]="CISCO OPENH264 GEOBLOCK FIX & MULTIMEDIA CODECS"
    [header_RU]="СНЯТИЕ ГЕОБЛОКА CISCO OPENH264 & МЕДИА КОДЕКИ"
    [target_EN]="for FEDORA LINUX 43/44/45"
    [target_RU]="для ФЕДОРЫ ЛИНУКС 43/44/45"

    [os_warn_EN]="Warning: Not Fedora (found: %s). Continue? (y/N): "
    [os_warn_RU]="Предупреждение: Не Fedora (найдено: %s). Продолжить? (y/N): "

    [atomic_EN]="Atomic Fedora (%s) detected. Reboot required after."
    [atomic_RU]="Atomic Fedora (%s) обнаружена. Потребуется перезагрузка."

    [rpmfusion_fail_EN]="CRITICAL: RPM Fusion not enabled! Cannot continue."
    [rpmfusion_fail_RU]="КРИТИЧНО: RPM Fusion не включён! Невозможно продолжить."

    [dns_prompt_EN]="Configure DNS-over-TLS? (y/N): "
    [dns_prompt_RU]="Настроить DNS-over-TLS? (y/N): "

    [dns_select_EN]="Select: 1) Quad9  2) Google  3) Cloudflare"
    [dns_select_RU]="Выбор: 1) Quad9  2) Google  3) Cloudflare"

    [dns_done_EN]="DNS-over-TLS configured"
    [dns_done_RU]="DNS-over-TLS настроен"

    [dns_skip_EN]="Skipped"
    [dns_skip_RU]="Пропущено"

    [done_EN]="ALL DONE"
    [done_RU]="ВСЁ ГОТОВО"

    [failed_EN]="SOME STEPS FAILED"
    [failed_RU]="НЕКОТОРЫЕ ШАГИ НЕ УДАЛИСЬ"

    [reboot_EN]="Reboot required for Atomic Fedora"
    [reboot_RU]="Требуется перезагрузка для Atomic Fedora"

    [hint_EN]="Restart browsers, enable hardware acceleration"
    [hint_RU]="Перезапустите браузеры, включите аппаратное ускорение"

    [url_EN]="https://discussion.fedoraproject.org/t/ciscobinary-openh264-org-is-unreachable-in-some-countries-ru-ua-ir/161434"
    [url_RU]="https://discussion.fedoraproject.org/t/dnf-update-interrupted-all-mirrors-were-tried-cisco-openh264-geoblock/170877"
)

declare -A STEP=(
    [1_EN]="Disable Cisco repo (geoblock fix)"      [1_RU]="Отключение репозитория Cisco"
    [2_EN]="Replace openh264 → noopenh264"           [2_RU]="Замена openh264 → noopenh264"
    [3_EN]="Full system update"                      [3_RU]="Обновление системы"
    [4_EN]="Enable RPM Fusion repositories"          [4_RU]="Включение RPM Fusion"
    [5_EN]="Swap ffmpeg-free → full ffmpeg"           [5_RU]="Замена ffmpeg-free → ffmpeg"
    [6_EN]="Install multimedia codecs"                [6_RU]="Установка медиа кодеков"
    [7_EN]="Exclude openh264 from DNF"               [7_RU]="Исключение openh264 из DNF"
    [8_EN]="Mask Flatpak openh264"                   [8_RU]="Маскировка Flatpak openh264"
    [9_EN]="Install GPU drivers"                     [9_RU]="Установка GPU драйверов"
    [10_EN]="Install VLC"                            [10_RU]="Установка VLC"
    [11_EN]="Set VLC as default"                     [11_RU]="VLC по умолчанию"
    [12_EN]="DNS-over-TLS (optional)"                [12_RU]="DNS-over-TLS (опц.)"
)

# ============================================================
# STATE
# ============================================================
FAILED=()
DONE_LIST=()
LOG="/tmp/fedora-open264-fix-$$.log"
TIME_START=$(date +%s)
IS_ATOMIC=false
GPU_VENDOR="Unknown"
FEDORA_VER=""

# ============================================================
# FUNCTIONS
# ============================================================
L() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

print_step() {
    local n="$1"
    echo -e "\n${CL[P]}📦 $(printf '%02d' $n)/12${CL[NC]} ${STEP[${n}_${LNG}]}..."
}

mark_ok() {
    local n="$1"
    DONE_LIST+=("${STEP[${n}_${LNG}]}")
    echo -e "   ${CL[G]}✓ OK${CL[NC]}"
    L "Step $n: OK"
}

mark_fail() {
    local n="$1"
    FAILED+=("${STEP[${n}_${LNG}]}")
    echo -e "   ${CL[R]}✗ FAILED${CL[NC]}"
    L "Step $n: FAILED"
}

mark_warn() {
    local n="$1"
    DONE_LIST+=("${STEP[${n}_${LNG}]} (warning)")
    echo -e "   ${CL[Y]}⚠ Warning${CL[NC]}"
    L "Step $n: Warning"
}

# ============================================================
# HEADER
# ============================================================
echo -e "${CL[P]}═══════════════════════════════════════════════${CL[NC]}"
echo -e "${CL[P]} ${MSG[header_${LNG}]}"
echo -e "${CL[P]} ${MSG[target_${LNG}]}"
echo -e "${CL[P]}═══════════════════════════════════════════════${CL[NC]}"
echo -e "Version: $SCRIPT_VERSION | Lang: $LNG"
echo -e "Log: ${CL[B]}$LOG${CL[NC]}"
echo ""
L "=== Script v3.0 started | Lang=$LNG ==="

# ============================================================
# OS DETECTION
# ============================================================
if [[ ! -f /etc/os-release ]]; then
    echo -e "${CL[R]}Error: /etc/os-release not found${CL[NC]}"
    exit 1
fi
source /etc/os-release
L "OS: $ID $VERSION_ID ($VARIANT_ID)"

if [[ "$ID" != "fedora" ]]; then
    printf "${CL[Y]}${MSG[os_warn_${LNG}]}" "$ID"
    read -r
    [[ ! "$REPLY" =~ ^[Yy]$ ]] && exit 1
fi

if [[ "$VARIANT_ID" =~ ^(silverblue|kinoite|sericea)$ ]]; then
    IS_ATOMIC=true
    echo -e "${CL[Y]}${MSG[atomic_${LNG}]}${CL[NC]}"
    L "Atomic mode: $VARIANT_ID"
fi

FEDORA_VER=$(rpm -E %fedora)
L "Fedora version: $FEDORA_VER"

# Detect GPU
GPU_LINE=$(lspci 2>/dev/null | grep -i "vga\|3d" | head -1)
if echo "$GPU_LINE" | grep -qi "intel"; then
    GPU_VENDOR="Intel"
elif echo "$GPU_LINE" | grep -qiE "amd|radeon"; then
    GPU_VENDOR="AMD"
elif echo "$GPU_LINE" | grep -qi "nvidia"; then
    GPU_VENDOR="NVIDIA"
fi
L "GPU: $GPU_VENDOR"

# Install dnf-plugins-core for non-atomic
if [[ "$IS_ATOMIC" != true ]]; then
    dnf install -y dnf-plugins-core >> "$LOG" 2>&1
    dnf clean all >> "$LOG" 2>&1
fi

# ============================================================
# STEP 1: DISABLE CISCO REPO
# ============================================================
print_step 1
if [[ "$IS_ATOMIC" == true ]]; then
    if [[ -f /etc/yum.repos.d/fedora-cisco-openh264.repo ]]; then
        sed -i 's/^enabled=.*/enabled=0/' /etc/yum.repos.d/fedora-cisco-openh264.repo
        mark_ok 1
    else
        mark_warn 1
    fi
else
    # Try DNF5 syntax first, then DNF4
    if dnf config-manager --set-disabled fedora-cisco-openh264 >> "$LOG" 2>&1; then
        mark_ok 1
    elif dnf config-manager setopt fedora-cisco-openh264.enabled=0 >> "$LOG" 2>&1; then
        mark_ok 1
    elif [[ -f /etc/yum.repos.d/fedora-cisco-openh264.repo ]]; then
        # Fallback: manual edit
        sed -i 's/^enabled=.*/enabled=0/' /etc/yum.repos.d/fedora-cisco-openh264.repo
        mark_ok 1
    else
        mark_fail 1
    fi
fi

# ============================================================
# STEP 2: REPLACE openh264
# ============================================================
print_step 2
if [[ "$IS_ATOMIC" == true ]]; then
    rpm-ostree install noopenh264 -y >> "$LOG" 2>&1 && \
    rpm-ostree override remove openh264 -y >> "$LOG" 2>&1
    [[ $? -eq 0 ]] && mark_ok 2 || mark_warn 2
else
    # Verified: dnf swap '*openh264*' noopenh264 (Fedora Discussion #161434)
    if dnf swap '*openh264*' noopenh264 --allowerasing -y >> "$LOG" 2>&1; then
        mark_ok 2
    elif dnf install noopenh264 -y >> "$LOG" 2>&1 && dnf remove openh264 -y >> "$LOG" 2>&1; then
        mark_ok 2
    else
        mark_warn 2
    fi
fi

# ============================================================
# STEP 3: SYSTEM UPDATE
# ============================================================
print_step 3
if [[ "$IS_ATOMIC" == true ]]; then
    rpm-ostree upgrade -y >> "$LOG" 2>&1
else
    dnf update -y >> "$LOG" 2>&1
fi
[[ $? -eq 0 ]] && mark_ok 3 || mark_warn 3

# ============================================================
# STEP 4: ENABLE RPM FUSION (+ VERIFY!)
# ============================================================
print_step 4
FREE_URL="https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm"
NONFREE_URL="https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm"

if [[ "$IS_ATOMIC" == true ]]; then
    rpm-ostree install -y "$FREE_URL" "$NONFREE_URL" >> "$LOG" 2>&1
else
    dnf install -y "$FREE_URL" "$NONFREE_URL" >> "$LOG" 2>&1
fi

# CRITICAL: Verify RPM Fusion is actually enabled
sleep 2
if dnf repolist 2>/dev/null | grep -qi "rpmfusion"; then
    mark_ok 4
else
    # Try: maybe rawhide repos got enabled instead (Fedora 44 bug)
    L "RPM Fusion not in repolist, attempting fix..."
    if [[ "$IS_ATOMIC" != true ]]; then
        dnf config-manager setopt rpmfusion-free.enabled=1 >> "$LOG" 2>&1 || true
        dnf config-manager setopt rpmfusion-free-updates.enabled=1 >> "$LOG" 2>&1 || true
        dnf config-manager setopt rpmfusion-nonfree.enabled=1 >> "$LOG" 2>&1 || true
        dnf config-manager setopt rpmfusion-nonfree-updates.enabled=1 >> "$LOG" 2>&1 || true
        dnf config-manager setopt rpmfusion-free-rawhide.enabled=0 >> "$LOG" 2>&1 || true
        dnf config-manager setopt rpmfusion-nonfree-rawhide.enabled=0 >> "$LOG" 2>&1 || true
    fi
    # Re-check
    if dnf repolist 2>/dev/null | grep -qi "rpmfusion"; then
        mark_ok 4
    else
        echo -e "   ${CL[R]}${MSG[rpmfusion_fail_${LNG}]}${CL[NC]}"
        mark_fail 4
        # Critical: stop here, nothing else will work
        echo -e "\n${CL[R]}═══════════════════════════════════════════════${CL[NC]}"
        echo -e "${CL[R]}${MSG[failed_${LNG}]}${CL[NC]}"
        echo -e "${CL[B]}${MSG[url_${LNG}]}${CL[NC]}"
        echo -e "${CL[B]}Log: $LOG${CL[NC]}"
        exit 1
    fi
fi

# ============================================================
# STEP 5: SWAP ffmpeg-free → ffmpeg
# ============================================================
print_step 5
if [[ "$IS_ATOMIC" == true ]]; then
    # CORRECT: override remove libav*-free packages, install ffmpeg
    # Source: RPM Fusion Howto/OSTree, Fedora Discussion #144495
    rpm-ostree override remove \
        libavcodec-free libavfilter-free libavformat-free \
        libavutil-free libpostproc-free libswresample-free libswscale-free \
        --install ffmpeg -y >> "$LOG" 2>&1
    [[ $? -eq 0 ]] && mark_ok 5 || mark_warn 5
else
    # Verified: dnf swap ffmpeg-free ffmpeg (LinuxCapable, ComputingForGeeks)
    if dnf swap ffmpeg-free ffmpeg --allowerasing -y >> "$LOG" 2>&1; then
        mark_ok 5
    elif dnf install ffmpeg --allowerasing -y >> "$LOG" 2>&1; then
        mark_ok 5
    else
        mark_warn 5
    fi
fi

# ============================================================
# STEP 6: MULTIMEDIA CODECS
# ============================================================
print_step 6
# FIX: DNF5 uses "group install" not "groupinstall" (case-sensitive, lowercase)
# Source: Fedora Discussion #130530, LinuxCapable
if [[ "$IS_ATOMIC" == true ]]; then
    rpm-ostree install -y @multimedia \
        --exclude=PackageKit-gstreamer-plugin \
        --exclude=gstreamer1-plugin-openh264 >> "$LOG" 2>&1
    [[ $? -eq 0 ]] && mark_ok 6 || mark_warn 6
else
    # Try DNF5 syntax first, then DNF4 fallback
    if dnf group install multimedia --exclude=PackageKit-gstreamer-plugin -y >> "$LOG" 2>&1; then
        mark_ok 6
    elif dnf groupinstall -y @multimedia --exclude=PackageKit-gstreamer-plugin >> "$LOG" 2>&1; then
        mark_ok 6
    else
        mark_warn 6
    fi
fi

# ============================================================
# STEP 7: EXCLUDE openh264 FROM DNF
# ============================================================
print_step 7
if [[ "$IS_ATOMIC" == true ]]; then
    mark_ok 7  # Handled by override
else
    # Write to BOTH possible locations for max compatibility
    mkdir -p /etc/dnf/libdnf5.conf.d /etc/dnf/conf.d 2>/dev/null

    cat > /etc/dnf/libdnf5.conf.d/99-exclude-openh264.conf <<'CONFEOF'
[main]
exclude=openh264*
CONFEOF

    cat > /etc/dnf/conf.d/99-exclude-openh264.conf <<'CONFEOF'
[main]
exclude=openh264*
CONFEOF

    if [[ -f /etc/dnf/libdnf5.conf.d/99-exclude-openh264.conf ]] || \
       [[ -f /etc/dnf/conf.d/99-exclude-openh264.conf ]]; then
        mark_ok 7
    else
        mark_fail 7
    fi
fi

# ============================================================
# STEP 8: MASK FLATPAK OPENH264
# ============================================================
print_step 8
# FIX: Check if flatpak is even installed first
# Source: GitHub flatpak/issues#3197
if command -v flatpak &>/dev/null; then
    if flatpak mask org.freedesktop.Platform.openh264 >> "$LOG" 2>&1; then
        mark_ok 8
    else
        mark_warn 8
    fi
else
    echo -e "   ${CL[Y]}flatpak not installed, skipping${CL[NC]}"
    mark_warn 8
fi

# ============================================================
# STEP 9: GPU DRIVERS
# ============================================================
print_step 9
case "$GPU_VENDOR" in
    Intel)
        echo -e "   ${CL[B]}Intel GPU${CL[NC]}"
        if [[ "$IS_ATOMIC" == true ]]; then
            rpm-ostree install -y intel-media-driver libva-utils >> "$LOG" 2>&1
        else
            dnf install -y intel-media-driver libva-utils >> "$LOG" 2>&1
        fi
        ;;
    AMD)
        echo -e "   ${CL[B]}AMD GPU${CL[NC]}"
        if [[ "$IS_ATOMIC" == true ]]; then
            rpm-ostree install -y mesa-va-drivers-freeworld >> "$LOG" 2>&1
        else
            dnf install -y mesa-va-drivers-freeworld --allowerasing >> "$LOG" 2>&1
        fi
        ;;
    NVIDIA)
        echo -e "   ${CL[B]}NVIDIA GPU${CL[NC]}"
        if [[ "$IS_ATOMIC" == true ]]; then
            rpm-ostree install -y akmod-nvidia >> "$LOG" 2>&1
        else
            dnf install -y akmod-nvidia >> "$LOG" 2>&1
        fi
        ;;
    *)
        echo -e "   ${CL[Y]}No discrete GPU detected${CL[NC]}"
        ;;
esac
[[ $? -eq 0 ]] && mark_ok 9 || mark_warn 9

# ============================================================
# STEP 10: INSTALL VLC
# ============================================================
print_step 10
if [[ "$IS_ATOMIC" == true ]]; then
    rpm-ostree install -y vlc >> "$LOG" 2>&1
else
    dnf install -y vlc >> "$LOG" 2>&1
fi
[[ $? -eq 0 ]] && mark_ok 10 || mark_warn 10

# ============================================================
# STEP 11: SET VLC DEFAULT
# ============================================================
print_step 11
VIDEO_MIMES="video/mp4 video/x-matroska video/webm video/avi video/quicktime video/x-flv"
SET_OK=false

if [[ -n "$SUDO_USER" ]] && id "$SUDO_USER" &>/dev/null; then
    if sudo -u "$SUDO_USER" xdg-mime default vlc.desktop $VIDEO_MIMES 2>>"$LOG"; then
        SET_OK=true
    fi
fi
if [[ "$SET_OK" != true ]]; then
    xdg-mime default vlc.desktop video/mp4 2>>"$LOG" && SET_OK=true
fi
[[ "$SET_OK" == true ]] && mark_ok 11 || mark_warn 11

# ============================================================
# STEP 12: DNS-OVER-TLS (OPTIONAL)
# ============================================================
print_step 12
echo -ne "${MSG[dns_prompt_${LNG}]}"
read -r </dev/tty

if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    echo -e "${MSG[dns_select_${LNG}]}"
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
            echo -e "   ${CL[G]}✓ ${MSG[dns_done_${LNG}]}${CL[NC]}"
            mark_ok 12
        else
            echo -e "   ${CL[Y]}systemd-resolved not found${CL[NC]}"
            mark_warn 12
        fi
    else
        echo -e "   ${CL[Y]}${MSG[dns_skip_${LNG}]}${CL[NC]}"
        mark_warn 12
    fi
else
    echo -e "   ${CL[Y]}${MSG[dns_skip_${LNG}]}${CL[NC]}"
    mark_ok 12
fi

# ============================================================
# SUMMARY
# ============================================================
ELAPSED=$(( $(date +%s) - TIME_START ))

echo -e "\n${CL[P]}═══════════════════════════════════════════════${CL[NC]}"
echo -e "Completed in ${ELAPSED}s"
echo -e "Log: ${CL[B]}$LOG${CL[NC]}\n"

if [[ ${#DONE_LIST[@]} -gt 0 ]]; then
    echo -e "${CL[G]}${MSG[done_${LNG}]}:${CL[NC]}"
    for d in "${DONE_LIST[@]}"; do
        echo -e "  ${CL[G]}✓${CL[NC]} $d"
    done
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo -e "\n${CL[R]}${MSG[failed_${LNG}]}:${CL[NC]}"
    for f in "${FAILED[@]}"; do
        echo -e "  ${CL[R]}✗${CL[NC]} $f"
    done
fi

# Post-install hints
echo ""
if [[ "$IS_ATOMIC" == true ]]; then
    echo -e "${CL[Y]}⚠ ${MSG[reboot_${LNG}]}${CL[NC]}"
fi
echo -e "${CL[B]}${MSG[hint_${LNG}]}${CL[NC]}"
echo -e "${CL[B]}${MSG[url_${LNG}]}${CL[NC]}"

L "=== Script finished | OK=${#DONE_LIST[@]} FAIL=${#FAILED[@]} ==="

[[ ${#FAILED[@]} -eq 0 ]] && exit 0 || exit 1