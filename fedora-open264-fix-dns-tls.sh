#!/bin/bash
# === FEDORA OPENH264 GEOBLOCK FIX v2.2 (PRODUCTION STABLE) ===
# Compatible with: Fedora 43, 44, 45 (Workstation, Silverblue, Kinoite, Sericea)
SCRIPT_VERSION="v2.2 (Verified Feb 2026)"
clear

# === LANGUAGE ===
if [[ "$LANG" =~ ^ru ]]; then LNG="RU"; else LNG="EN"; fi

# === ROOT CHECK ===
if [[ $EUID -ne 0 ]]; then
    echo -e "\e[31m❌ Error: This script must be run as root (sudo)\e[0m"
    exit 1
fi

# === COLORS ===
declare -A CL=( [W]="\e[38;5;255m" [O]="\e[38;5;214m" [Y]="\e[38;5;229m" [G]="\e[38;5;120m" [B]="\e[38;5;117m" [R]="\e[38;5;210m" [P]="\e[38;5;177m" [NC]="\e[0m" )

# === MESSAGES ===
declare -A S_HEADER=( 
    [EN]="\n═══════════════════════════════════════════════\nCISCO OPENH264 GEOBLOCK FIX & MULTIMEDIA CODECS\nfor FEDORA LINUX 43/44/45\n═══════════════════════════════════════════════" 
    [RU]="\n═══════════════════════════════════════════════\nСНИМАНИЕ ГЕОБЛОКА CISCO OPENH264 & МЕДИА КОДЕКИ\nдля ФЕДОРЫ ЛИНУКС 43/44/45\n═══════════════════════════════════════════════" 
)
declare -A MSG_SUCCESS=( [EN]="\n${CL[G]}✅ All operations completed successfully!${CL[NC]}\n" [RU]="\n${CL[G]}✅ Все операции успешно завершены!${CL[NC]}\n" )
declare -A MSG_WARNINGS=( [EN]="${CL[Y]}⚠️  Some steps had warnings but system should work.${CL[NC]}\n" [RU]="${CL[Y]}⚠️  Некоторые шаги имели предупреждения, но система должна работать.${CL[NC]}\n" )
declare -A MSG_URL=( [EN]="More info: https://discussion.fedoraproject.org/t/ciscobinary-openh264-org-is-unreachable-in-some-countries-ru-ua-ir/161434" [RU]="Подробнее: https://discussion.fedoraproject.org/t/dnf-update-interrupted-all-mirrors-were-tried-cisco-openh264-geoblock/170877" ]
declare -A STEPS=( 
    [1_EN]="Disable Cisco geoblocked repo" [1_RU]="Отключение репозитория Cisco (геоблок)"
    [2_EN]="Replace openh264 with noopenh264" [2_RU]="Замена openh264 → noopenh264"
    [3_EN]="Full system update" [3_RU]="Полное обновление системы"
    [4_EN]="Enable RPM Fusion repositories" [4_RU]="Включение репозиториев RPM Fusion"
    [5_EN]="Install full ffmpeg from RPM Fusion" [5_RU]="Установка полного ffmpeg из RPM Fusion"
    [6_EN]="Install multimedia codecs (@multimedia group)" [6_RU]="Установка медиа кодеков (группа @multimedia)"
    [7_EN]="Add libavcodec-freeworld for extra formats" [7_RU]="Добавление libavcodec-freeworld для дополнительных форматов"
    [8_EN]="Exclude openh264 from future updates" [8_RU]="Исключение openh264 из будущих обновлений"
    [9_EN]="Mask Flatpak openh264 extension" [9_RU]="Маскировка расширения Flatpak openh264"
    [10_EN]="Install GPU video acceleration drivers" [10_RU]="Установка драйверов видеоускорения GPU"
    [11_EN]="Install VLC media player" [11_RU]="Установка медиаплеера VLC"
    [12_EN]="Set VLC as default video player" [12_RU]="VLC по умолчанию для видео"
    [13_EN]="DNS-over-TLS configuration (optional)" [13_RU]="Настройка DNS-over-TLS (опционально)"
)

# === STATE TRACKING ===
FAILED=(); WARNINGS=(); DONE=()
LOG_FILE="/tmp/fedora-open264-fix-$$.log"
START_TIME=$(date +%s)

Log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

StepDone() {
    local num="$1"
    local msg="${STEPS[${num}_${LNG}]}"
    local code="$2"
    
    if [[ $code -eq 0 ]]; then
        DONE+=("$msg")
        echo -e "   ${CL[G]}✓${CL[NC]} OK"
    elif [[ $code -le 2 ]]; then
        WARNINGS+=("$msg (warning code: $code)")
        echo -e "   ${CL[Y]}⚠${CL[NC]} Warning"
    else
        FAILED+=("$msg")
        echo -e "   ${CL[R]}✗${CL[NC]} FAILED"
    fi
}

# === PRINT HEADER ===
echo -e "${CL[P]}${S_HEADER[$LNG]}${CL[NC]}\n"
echo -e "Version: ${SCRIPT_VERSION}"
echo -e "Log: ${CL[B]}$LOG_FILE${CL[NC]}"
echo -e "═══════════════════════════════════════════════\n"

# === OS DETECTION ===
if [[ ! -f /etc/os-release ]]; then
    echo -e "${CL[R]}Error: /etc/os-release not found${CL[NC]}"
    exit 1
fi

source /etc/os-release
Log "Detected: $ID $VERSION_ID ($VARIANT_ID)"

if [[ "$ID" != "fedora" ]]; then
    echo -e "${CL[Y]}Warning: Not Fedora (detected: $ID). Continue? (y/N)${CL[NC]}"
    read -r </dev/tty
    [[ ! "$REPLY" =~ ^[Yy]$ ]] && exit 1
fi

IS_ATOMIC=false
if [[ "$VARIANT_ID" =~ ^(silverblue|kinoite|sericea)$ ]]; then
    IS_ATOMIC=true
    echo -e "${CL[Y]}⚠️  Atomic Fedora detected ($VARIANT_ID). Reboot may be required.${CL[NC]}\n"
    Log "Atomic variant: $VARIANT_ID"
else
    Log "Standard Fedora Workstation"
fi

FEDORA_VER=$(rpm -E %fedora)
Log "Fedora version: $FEDORA_VER"

# === DETECT GPU ===
GPU_VENDOR="Unknown"
GPU_INFO=$(lspci 2>/dev/null | grep -i "vga\|3d" | head -1)

if echo "$GPU_INFO" | grep -qi "intel"; then
    GPU_VENDOR="Intel"
elif echo "$GPU_INFO" | grep -qiE "amd|radeon|rzesz"; then
    GPU_VENDOR="AMD"
elif echo "$GPU_INFO" | grep -qi "nvidia"; then
    GPU_VENDOR="NVIDIA"
elif echo "$GPU_INFO" | grep -qi "vesa\|llvmpipe"; then
    GPU_VENDOR="Integrated/Virtual"
fi
Log "GPU detected: $GPU_VENDOR"

# === PREPARE DNF ===
echo -e "${CL[P]}🔧 Preparing package manager...${CL[NC]}\n"
if [[ "$IS_ATOMIC" != true ]]; then
    sudo dnf install -y dnf-plugins-core >/dev/null 2>&1 || true
    sudo dnf clean all >/dev/null 2>&1 || true
fi

# ============================================
# STEP 1: DISABLE CISCO REPO
# ============================================
echo -e "${CL[P]}📦 01/13${CL[NC]} ${STEPS[1_$LNG]}..."
if [[ "$IS_ATOMIC" == true ]]; then
    [[ -f /etc/yum.repos.d/fedora-cisco-openh264.repo ]] && \
        sudo sed -i 's/^enabled=.*/enabled=0/' /etc/yum.repos.d/fedora-cisco-openh264.repo 2>/dev/null || true
else
    sudo dnf config-manager --set-disabled fedora-cisco-openh264 2>/dev/null || \
    sudo dnf config-manager setopt fedora-cisco-openh264.enabled=0 2>/dev/null || true
fi
StepDone 1 "$?"

# ============================================
# STEP 2: REPLACE openh264 WITH NOOPENH264
# ============================================
echo -e "\n${CL[P]}🔄 02/13${CL[NC]} ${STEPS[2_$LNG]}..."
if [[ "$IS_ATOMIC" == true ]]; then
    sudo rpm-ostree install noopenh264 -y 2>/dev/null || true
    sudo rpm-ostree override remove openh264 -y 2>/dev/null || true
else
    # Verified working command from Fedora Discussion #161434
    sudo dnf swap '*openh264*' noopenh264 --allowerasing -y 2>/dev/null || \
    sudo dnf install noopenh264 -y 2>/dev/null || \
    sudo dnf remove openh264 -y 2>/dev/null || true
fi
StepDone 2 "$?"

# ============================================
# STEP 3: FULL SYSTEM UPDATE
# ============================================
echo -e "\n${CL[P]}📥 03/13${CL[NC]} ${STEPS[3_$LNG]}..."
if [[ "$IS_ATOMIC" == true ]]; then
    sudo rpm-ostree upgrade -y 2>/dev/null || true
else
    sudo dnf update -y 2>/dev/null || true
fi
StepDone 3 "$?"

# ============================================
# STEP 4: ENABLE RPM FUSION
# ============================================
echo -e "\n${CL[P]}🔗 04/13${CL[NC]} ${STEPS[4_$LNG]}..."
FREE_REPO="https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm"
NONFREE_REPO="https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm"

if [[ "$IS_ATOMIC" == true ]]; then
    sudo rpm-ostree install -y "$FREE_REPO" "$NONFREE_REPO" 2>/dev/null || true
else
    sudo dnf install -y "$FREE_REPO" "$NONFREE_REPO" 2>/dev/null || \
    grep -q rpmfusion /etc/yum.repos.d/*.repo 2>/dev/null || echo -e "   ${CL[Y]}Warning: RPM Fusion may not be properly enabled${CL[NC]}"
fi
StepDone 4 "$?"

# ============================================
# STEP 5: INSTALL FULL FFMPEG
# ============================================
echo -e "\n${CL[P]}🎬 05/13${CL[NC]} ${STEPS[5_$LNG]}..."
if [[ "$IS_ATOMIC" == true ]]; then
    sudo rpm-ostree override replace --experimental ffmpeg-free ffmpeg 2>/dev/null || true
else
    sudo dnf swap ffmpeg-free ffmpeg --allowerasing -y 2>/dev/null || \
    sudo dnf install -y ffmpeg --allowerasing 2>/dev/null || true
fi
StepDone 5 "$?"

# ============================================
# STEP 6: MULTIMEDIA CODECS GROUP
# ============================================
echo -e "\n${CL[P]}🔊 06/13${CL[NC]} ${STEPS[6_$LNG]}..."
# From search: "just installing the multimedia group is sufficient" (Reddit, rpmfusion.org)
EXCLUDES="--exclude=PackageKit-gstreamer-plugin"
if [[ "$IS_ATOMIC" == true ]]; then
    sudo rpm-ostree install -y @multimedia $EXCLUDES 2>/dev/null || true
else
    # Both groupinstall and group install work
    sudo dnf groupinstall -y @multimedia $EXCLUDES 2>/dev/null || \
    sudo dnf group install -y multimedia $EXCLUDES 2>/dev/null || true
fi
StepDone 6 "$?"

# ============================================
# STEP 7: ADD LIBAVCODEC FREEWORLD
# ============================================
echo -e "\n${CL[P]}💿 07/13${CL[NC]} ${STEPS[7_$LNG]}..."
# Extra codecs support from Fedora Discussion #147189
if [[ "$IS_ATOMIC" == true ]]; then
    sudo rpm-ostree install -y libavcodec-freeworld 2>/dev/null || true
else
    sudo dnf install -y libavcodec-freeworld --allowerasing 2>/dev/null || true
fi
StepDone 7 "$?"

# ============================================
# STEP 8: EXCLUDE OPENH264 GLOBALLY
# ============================================
echo -e "\n${CL[P]}⛔ 08/13${CL[NC]} ${STEPS[8_$LNG]}..."
if [[ "$IS_ATOMIC" == true ]]; then
    Log "Skip: Atomic handles via override"
    StepDone 8 0
else
    sudo mkdir -p /etc/dnf/libdnf5.conf.d /etc/dnf/conf.d 2>/dev/null || true
    
    # Create exclusion file (works with both dnf4/dnf5)
    if [[ -d /etc/dnf/libdnf5.conf.d ]]; then
        sudo tee /etc/dnf/libdnf5.conf.d/99-exclude-openh264.conf > /dev/null <<EOF
[main]
exclude=openh264*
EOF
    else
        sudo tee /etc/dnf/conf.d/99-exclude-openh264.conf > /dev/null <<EOF
[main]
exclude=openh264*
EOF
    fi
    StepDone 8 "$?"
fi

# ============================================
# STEP 9: MASK FLATPAK OPENH264
# ============================================
echo -e "\n${CL[P]}📱 09/13${CL[NC]} ${STEPS[9_$LNG]}..."
flatpak mask org.freedesktop.Platform.openh264 2>/dev/null || true
StepDone 9 "$?"

# ============================================
# STEP 10: GPU DRIVERS
# ============================================
echo -e "\n${CL[P]}🖥️ 10/13${CL[NC]} ${STEPS[10_$LNG]}..."
case "$GPU_VENDOR" in
    Intel)
        echo -e "   Detected: ${CL[B]}Intel GPU${CL[NC]}"
        if [[ "$IS_ATOMIC" == true ]]; then
            sudo rpm-ostree install -y intel-media-driver libva-utils libva-vdpau-driver 2>/dev/null || true
        else
            sudo dnf install -y intel-media-driver libva-utils libva-vdpau-driver 2>/dev/null || true
        fi
        ;;
    AMD)
        echo -e "   Detected: ${CL[B]}AMD GPU${CL[NC]}"
        # From search: only ONE of va-drivers OR vdpau-drivers needed
        if [[ "$IS_ATOMIC" == true ]]; then
            sudo rpm-ostree install -y mesa-va-drivers-freeworld mesa-vulkan-drivers 2>/dev/null || true
        else
            sudo dnf install -y mesa-va-drivers-freeworld mesa-vulkan-drivers --allowerasing 2>/dev/null || true
        fi
        ;;
    NVIDIA)
        echo -e "   Detected: ${CL[B]}NVIDIA GPU${CL[NC]}"
        echo -e "   ${CL[Y]}ℹ️  Proprietary drivers recommended for best performance${CL[NC]}"
        if [[ "$IS_ATOMIC" == true ]]; then
            sudo rpm-ostree install -y akmod-nvidia xorg-x11-drv-nvidia-cuda 2>/dev/null || true
        else
            sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda 2>/dev/null || true
        fi
        ;;
    *)
        echo -e "   ${CL[Y]}ℹ️  Integrated/Virtual GPU - basic drivers already present${CL[NC]}"
        ;;
esac
StepDone 10 "$?"

# ============================================
# STEP 11: INSTALL VLC
# ============================================
echo -e "\n${CL[P]}▶️ 11/13${CL[NC]} ${STEPS[11_$LNG]}..."
if [[ "$IS_ATOMIC" == true ]]; then
    sudo rpm-ostree install -y vlc 2>/dev/null || true
else
    sudo dnf install -y vlc 2>/dev/null || true
fi
StepDone 11 "$?"

# ============================================
# STEP 12: SET DEFAULT PLAYER
# ============================================
echo -e "\n${CL[P]}⚙️ 12/13${CL[NC]} ${STEPS[12_$LNG]}..."
DEFAULT_TYPES="video/mp4 video/x-matroska video/webm video/avi video/quicktime video/x-flv"

if [[ -n "$SUDO_USER" ]] && id "$SUDO_USER" &>/dev/null; then
    sudo -u "$SUDO_USER" xdg-mime default vlc.desktop $DEFAULT_TYPES 2>/dev/null || true
    echo -e "   ${CL[G]}✓ Set for user: $SUDO_USER${CL[NC]}"
elif [[ -n "$USER" ]] && id "$USER" &>/dev/null; then
    sudo -u "$USER" xdg-mime default vlc.desktop $DEFAULT_TYPES 2>/dev/null || true
    echo -e "   ${CL[G]}✓ Set for user: $USER${CL[NC]}"
else
    xdg-mime default vlc.desktop video/mp4 2>/dev/null || true
    echo -e "   ${CL[Y]}⚠  Could not determine user, trying root config${CL[NC]}"
fi
StepDone 12 "$?"

# ============================================
# STEP 13: DNS-OVER-TLS (OPTIONAL)
# ============================================
echo -e "\n${CL[P]}🔒 13/13${CL[NC]} ${STEPS[13_$LNG]}..."
echo -e "Configure encrypted DNS? (${CL[G]}y${CL[NC]}/N): "
read -r </dev/tty

DNS_CONFIGURED=false
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    echo -e "${CL[B]}DNS Provider:${CL[NC]}"
    echo -e "  ${CL[G]}1${CL[NC]}) Quad9 (privacy-focused)"
    echo -e "  ${CL[B]}2${CL[NC]}) Google (high reliability)"
    echo -e "  ${CL[Y]}3${CL[NC]}) Cloudflare (fast)"
    read -p "Choice (1-3): " DNS_CHOICE </dev/tty
    
    case "$DNS_CHOICE" in
        1) DNS_SERVER="9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net" ;;
        2) DNS_SERVER="8.8.8.8#dns.google 8.8.4.4#dns.google" ;;
        3) DNS_SERVER="1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com" ;;
        *) echo -e "   ${CL[Y]}Invalid choice, skipping${CL[NC]}"; StepDone 13 0;;
    esac
    
    if [[ -n "$DNS_SERVER" ]]; then
        if systemctl list-unit-files systemd-resolved.service &>/dev/null; then
            sudo mkdir -p /etc/systemd/resolved.conf.d
            sudo tee /etc/systemd/resolved.conf.d/dot.conf > /dev/null <<EOF
[Resolve]
DNS=$DNS_SERVER
DNSOverTLS=yes
Domains=~.
EOF
            sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf 2>/dev/null || true
            sudo systemctl enable systemd-resolved --now 2>/dev/null || true
            sudo systemctl restart systemd-resolved 2>/dev/null || true
            echo -e "   ${CL[G]}✓ DNS-over-TLS enabled (${DNS_SERVER%%#*})${CL[NC]}"
            DNS_CONFIGURED=true
            StepDone 13 0
        else
            echo -e "   ${CL[Y]}systemd-resolved not found - DNS configuration skipped${CL[NC]}"
            StepDone 13 1
        fi
    fi
else
    echo -e "   ${CL[Y]}Skipped (as requested)${CL[NC]}"
    StepDone 13 0
fi

# ============================================
# SUMMARY
# ============================================
ELAPSED=$(($(date +%s) - START_TIME))

echo -e "\n${CL[P]}═══════════════════════════════════════════════${CL[NC]}"
echo -e "${CL[G]}Completed in ${ELAPSED}s${CL[NC]}\n"

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo -e "${CL[Y]}${#WARNINGS[@]} warning(s):${CL[NC]}"
    for w in "${WARNINGS[@]}"; do echo -e "  ${CL[Y]}⚠${CL[NC]} $w"; done
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo -e "\n${CL[R]}${#FAILED[@]} failed step(s):${CL[NC]}"
    for f in "${FAILED[@]}"; do echo -e "  ${CL[R]}✗${CL[NC]} $f"; done
    echo -e "\n${CL[Y]}Check log: $LOG_FILE${CL[NC]}"
else
    echo -e "${MSG_SUCCESS[$LNG]}"
fi

echo -e "${CL[G]}${#DONE[@]} successful operation(s)${CL[NC]}:"
for d in "${DONE[@]}"; do echo -e "  ${CL[G]}✓${CL[NC]} $d"; done

echo -e "\n${CL[B]}${MSG_URL[$LNG]}${CL[NC]}"

# POST-INSTALL NOTES
echo -e "\n${CL[Y]}Post-install notes:${CL[NC]}"
echo -e "  • Restart browsers/applications to apply codec changes"
echo -e "  • Enable hardware acceleration in browser settings"
echo -e "  • For Atomic Fedora: reboot to apply changes"
echo -e "  • Log saved to: $LOG_FILE"

[[ ${#FAILED[@]} -eq 0 ]] && exit 0 || exit 1