#!/bin/bash
# === FEDORA OPENH264 GEOBLOCK FIX + DNS-over-TLS  v5.0 ===
# Только две задачи:
#   1) обойти геоблок репозитория Cisco OpenH264 (актуально для РФ):
#      отключить репозиторий, заменить openh264 -> noopenh264, закрепить исключение;
#   2) (опционально) включить DNS-over-TLS через systemd-resolved.
#
# Запуск:  sudo bash fedora-openh264-fix.sh [опции]
#   --fix-only             только фикс openh264, без DNS
#   --dns-only             только DNS-over-TLS
#   --dns=quad9|google|cloudflare|none   выбрать DNS без вопросов
#   --revert-dns           удалить настройку DNS-over-TLS
#   -h, --help

[ -z "$BASH_VERSION" ] && exec bash "$0" "$@"
set -o pipefail

RED='\e[31m'; GREEN='\e[32m'; YELLOW='\e[33m'; BLUE='\e[34m'; PURPLE='\e[35m'; NC='\e[0m'

DO_FIX=true; DO_DNS=true; DNS_ARG=""; REVERT=false
for a in "$@"; do
    case "$a" in
        --fix-only)   DO_DNS=false ;;
        --dns-only)   DO_FIX=false ;;
        --dns=*)      DNS_ARG="${a#--dns=}" ;;
        --revert-dns) REVERT=true; DO_FIX=false ;;
        -h|--help)    sed -n '2,15p' "$0"; exit 0 ;;
        *) echo "Unknown option: $a (see --help)"; exit 2 ;;
    esac
done

[[ $EUID -eq 0 ]] || { echo -e "${RED}❌ Run as root: sudo bash $0${NC}"; exit 1; }

# ---------- Язык ----------
if [[ "${LC_ALL:-${LANG:-}}" =~ ^ru ]]; then
    M_ATOMIC="Atomic Fedora: используется rpm-ostree, понадобится перезагрузка"
    M_STD="Обычная Fedora: используется dnf"
    M_NOTFED="Это не Fedora (%s). Продолжить? (y/N): "
    M_DNSASK="Настроить DNS-over-TLS? (y/N): "
    M_DNSSEL="1) Quad9  2) Google  3) Cloudflare  [1-3]: "
    M_DNSOK="DNS-over-TLS работает"
    M_DNSBAD="DNS-over-TLS не отвечает — настройка откатена"
    M_PORT="Порт 853 недоступен у провайдера — DoT невозможен, ничего не менял"
    M_SKIP="Пропущено"
    M_REBOOT="⚠ Перезагрузитесь, чтобы применить изменения (Atomic)"
    M_DONE="ГОТОВО"
else
    M_ATOMIC="Atomic Fedora: using rpm-ostree, reboot will be needed"
    M_STD="Standard Fedora: using dnf"
    M_NOTFED="Not Fedora (%s). Continue? (y/N): "
    M_DNSASK="Configure DNS-over-TLS? (y/N): "
    M_DNSSEL="1) Quad9  2) Google  3) Cloudflare  [1-3]: "
    M_DNSOK="DNS-over-TLS works"
    M_DNSBAD="DNS-over-TLS not responding — rolled back"
    M_PORT="Port 853 is blocked by your network — DoT impossible, nothing changed"
    M_SKIP="Skipped"
    M_REBOOT="⚠ Reboot to apply changes (Atomic)"
    M_DONE="DONE"
fi

# ---------- Помощники ----------
LOG="/tmp/fedora-openh264-fix-$$.log"
FAILS=0; NEED_REBOOT=false
L()    { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }
head_() { echo -e "\n${PURPLE}▶ $*${NC}"; }
ok()   { echo -e "   ${GREEN}✓ $*${NC}"; L "OK: $*"; }
warn() { echo -e "   ${YELLOW}⚠ $*${NC}"; L "WARN: $*"; }
bad()  { echo -e "   ${RED}✗ $*${NC}"; L "FAIL: $*"; FAILS=$((FAILS+1)); }
# Команда + лог + настоящий код возврата (не tee)
run()  { L "RUN: $*"; "$@" >>"$LOG" 2>&1; local rc=$?; [[ $rc -ne 0 ]] && L "rc=$rc"; return $rc; }
ask()  { REPLY=""; [[ -r /dev/tty ]] && read -r -p "$1" REPLY </dev/tty; return 0; }

echo -e "${PURPLE}═══ Fedora openh264 geoblock fix + DoT  v5.0 ═══${NC}"
echo -e "${BLUE}Log: $LOG${NC}"

[[ -f /etc/os-release ]] || { echo "no /etc/os-release"; exit 1; }
# shellcheck disable=SC1091
source /etc/os-release
if [[ "$ID" != "fedora" ]]; then
    # shellcheck disable=SC2059
    printf "${YELLOW}${M_NOTFED}${NC}" "$ID"; ask ""
    [[ "$REPLY" =~ ^[Yy]$ ]] || exit 1
fi

IS_ATOMIC=false
[[ -f /run/ostree-booted ]] && command -v rpm-ostree &>/dev/null && IS_ATOMIC=true
$IS_ATOMIC && echo -e "${YELLOW}$M_ATOMIC${NC}" || echo -e "${GREEN}$M_STD${NC}"

# ============================================================
#  ЧАСТЬ 1. OPENH264
# ============================================================
fix_openh264() {
    local repo
    # --- 1. Отключить репозиторий Cisco (во всех репо-файлах) ---
    head_ "1/4  Cisco OpenH264 repo → disabled"
    local found=false
    for repo in /etc/yum.repos.d/fedora-cisco-openh264.repo /etc/yum.repos.d/*cisco*openh264*.repo; do
        [[ -f $repo ]] || continue
        found=true
        # меняем enabled только внутри секции [fedora-cisco-openh264*]
        sed -i '/^\[.*openh264.*\]/,/^\[/ s/^enabled=.*/enabled=0/' "$repo" \
            && ok "disabled in $(basename "$repo")" || bad "cannot edit $repo"
    done
    $found || ok "repo file absent — nothing to disable"

    # --- 2. openh264 → noopenh264 ---
    head_ "2/4  openh264 → noopenh264"
    if rpm -q noopenh264 &>/dev/null && ! rpm -q openh264 &>/dev/null; then
        ok "already replaced"
    elif $IS_ATOMIC; then
        if rpm -q openh264 &>/dev/null; then
            run rpm-ostree override remove openh264 --install=noopenh264 \
                && ok "override applied (effective after reboot)" || bad "rpm-ostree override failed"
        else
            run rpm-ostree install --idempotent -y noopenh264 \
                && ok "noopenh264 layered" || bad "rpm-ostree install failed"
        fi
        NEED_REBOOT=true
    else
        # --allowerasing уберёт зависимые mozilla-openh264 / gstreamer1-plugin-openh264:
        # без доступа к Cisco они всё равно нерабочие
        if rpm -q openh264 &>/dev/null; then
            run dnf swap -y --allowerasing openh264 noopenh264 \
                || run dnf install -y --allowerasing noopenh264 \
                && ok "swapped" || bad "dnf swap failed (see log)"
        else
            run dnf install -y --allowerasing noopenh264 && ok "noopenh264 installed" || bad "install failed"
        fi
    fi

    # --- 3. Закрепить: dnf больше не вернёт openh264 ---
    head_ "3/4  Pin: exclude openh264 in dnf"
    if $IS_ATOMIC; then
        ok "pinned by rpm-ostree override"
    else
        # dnf5 (Fedora 41+) читает libdnf5.conf.d, dnf4 — dnf.conf
        mkdir -p /etc/dnf/libdnf5.conf.d
        printf '[main]\nexcludepkgs=openh264,mozilla-openh264,gstreamer1-plugin-openh264\n' \
            > /etc/dnf/libdnf5.conf.d/99-exclude-openh264.conf \
            && ok "/etc/dnf/libdnf5.conf.d/99-exclude-openh264.conf" || bad "cannot write exclude file"
    fi

    # --- 4. Flatpak: не тянуть openh264 с Cisco/Flathub ---
    head_ "4/4  Flatpak: mask openh264"
    if command -v flatpak &>/dev/null; then
        if flatpak list --system --runtime 2>/dev/null | grep -q 'org.freedesktop.Platform.openh264'; then
            run flatpak uninstall --system -y --noninteractive org.freedesktop.Platform.openh264 || true
        fi
        run flatpak mask --system 'org.freedesktop.Platform.openh264' \
            && ok "masked (system)" || warn "mask failed"
    else
        ok "flatpak not installed — skipped"
    fi
}

# ============================================================
#  ЧАСТЬ 2. DNS-over-TLS
# ============================================================
DOT_CONF=/etc/systemd/resolved.conf.d/dot.conf

revert_dns() {
    head_ "DNS-over-TLS → revert"
    rm -f "$DOT_CONF"
    systemctl restart systemd-resolved >>"$LOG" 2>&1 && ok "dot.conf removed, resolver restarted" || warn "restart failed"
}

setup_dns() {
    head_ "DNS-over-TLS"
    local choice="" srv="" ip1 ip2 name

    case "${DNS_ARG,,}" in
        quad9) choice=1 ;; google) choice=2 ;; cloudflare) choice=3 ;; none) choice=skip ;;
        "") ask "$M_DNSASK"
            if [[ "$REPLY" =~ ^[Yy]$ ]]; then ask "$M_DNSSEL"; choice="$REPLY"; else choice=skip; fi ;;
        *) bad "unknown --dns value: $DNS_ARG"; return ;;
    esac

    case "$choice" in
        1) ip1=9.9.9.9; ip2=149.112.112.112; name=dns.quad9.net ;;
        2) ip1=8.8.8.8; ip2=8.8.4.4;         name=dns.google ;;
        3) ip1=1.1.1.1; ip2=1.0.0.1;         name=cloudflare-dns.com ;;
        *) echo "   $M_SKIP"; return ;;
    esac
    srv="${ip1}#${name} ${ip2}#${name}"

    systemctl list-unit-files systemd-resolved.service &>/dev/null \
        || { warn "systemd-resolved not found"; return; }

    # Предпроверка: порт 853 вообще доступен?
    if ! timeout 6 bash -c "exec 3<>/dev/tcp/$ip1/853" 2>/dev/null; then
        warn "$M_PORT"; return
    fi

    # Бэкап прежнего состояния
    local bak="/root/resolv.conf.bak.$(date +%s)"
    [[ -e /etc/resolv.conf || -L /etc/resolv.conf ]] && cp -a /etc/resolv.conf "$bak" 2>/dev/null
    local prev_conf=""
    [[ -f $DOT_CONF ]] && { prev_conf="$DOT_CONF.prev"; cp -a "$DOT_CONF" "$prev_conf"; }

    mkdir -p "$(dirname "$DOT_CONF")"
    # Domains=~.  — все запросы идут на выбранные серверы (VPN/локальные имена могут не резолвиться)
    printf '[Resolve]\nDNS=%s\nDNSOverTLS=yes\nDomains=~.\n' "$srv" > "$DOT_CONF"
    ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    systemctl enable --now systemd-resolved >>"$LOG" 2>&1
    systemctl restart systemd-resolved >>"$LOG" 2>&1
    sleep 2

    if timeout 15 resolvectl query fedoraproject.org >>"$LOG" 2>&1 \
       && timeout 15 getent hosts mirrors.fedoraproject.org >>"$LOG" 2>&1; then
        ok "$M_DNSOK ($name)"
        [[ -n $prev_conf ]] && rm -f "$prev_conf"
    else
        # откат
        if [[ -n $prev_conf ]]; then mv -f "$prev_conf" "$DOT_CONF"; else rm -f "$DOT_CONF"; fi
        [[ -e $bak || -L $bak ]] && cp -a "$bak" /etc/resolv.conf 2>/dev/null
        systemctl restart systemd-resolved >>"$LOG" 2>&1
        bad "$M_DNSBAD"
    fi
}

# ============================================================
$REVERT && revert_dns
$DO_FIX && fix_openh264
$DO_DNS && ! $REVERT && setup_dns

echo -e "\n${PURPLE}═══════════════════════════════════════${NC}"
if [[ $FAILS -eq 0 ]]; then echo -e "${GREEN}  $M_DONE${NC}"; else echo -e "${RED}  Errors: $FAILS${NC}"; fi
echo -e "${BLUE}  Log: $LOG${NC}"
$NEED_REBOOT && echo -e "${YELLOW}  $M_REBOOT${NC}"
echo -e "${PURPLE}═══════════════════════════════════════${NC}"
L "finished fails=$FAILS"
[[ $FAILS -eq 0 ]]
