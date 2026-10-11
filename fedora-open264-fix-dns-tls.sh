#!/usr/bin/env bash
# === FEDORA OPENH264 GEOBLOCK FIX + DNS-over-TLS  v6.0 ===
# Две задачи:
#   1) обход геоблока репозитория Cisco OpenH264 (актуально для РФ);
#   2) DNS-over-TLS — только по вашему выбору, с проверкой и автооткатом.
#
# Использование:
#   sudo bash fedora-openh264-fix.sh [флаги]
#
# Флаги:
#   --fix-only         только фикс openh264, без DNS
#   --dns-only         только DNS-over-TLS
#   --dns=ИМЯ          cloudflare | quad9 | google | none
#                      Без флага спросит в консоли (по умолчанию — не менять).
#                      Перед включением проверяет порт 853 и TLS-сертификат,
#                      после — что TLS-соединение реально установилось;
#                      если нет — автоматически откатывает.
#   --no-dns           не спрашивать про DNS (то же, что --dns=none)
#   --dns-strict       строгий режим: сертификат проверяется при каждом запросе.
#                      Надёжнее, но DNS не работает там, где закрыт порт 853.
#                      (по умолчанию opportunistic: шифрование есть, сертификат
#                      не проверяется, при блокировке порта DNS работает без шифрования)
#   --revert-dns       убрать настройку DNS-over-TLS
#   -h, --help         справка

[ -z "${BASH_VERSION:-}" ] && exec bash "$0" "$@"
set -o pipefail

TAG="openh264-fix"
DNS_FILE="/etc/systemd/resolved.conf.d/99-${TAG}-dns.conf"
OLD_DNS_FILE="/etc/systemd/resolved.conf.d/dot.conf"   # файл прежних версий скрипта

DO_FIX=1; DO_DNS=1; DNS_CHOICE=""; DNS_STRICT=0; REVERT=0
SELF=""
[[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]] && SELF="${BASH_SOURCE[0]}"

# ---------- Язык ----------
LNG=EN; [[ "${LC_ALL:-${LANG:-}}" =~ ^ru ]] && LNG=RU
t(){ if [[ $LNG == RU ]]; then printf '%s' "$1"; else printf '%s' "$2"; fi; }

# ---------- Вывод ----------
if [[ -t 1 ]]; then
  C_G=$'\e[32m'; C_Y=$'\e[33m'; C_R=$'\e[31m'; C_B=$'\e[1m'; C_0=$'\e[0m'
else
  C_G=''; C_Y=''; C_R=''; C_B=''; C_0=''
fi
FAILS=0; NEED_REBOOT=0
LOG="/tmp/${TAG}-$$.log"
L()   { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }
step(){ printf '\n%s==> %s%s\n' "$C_B" "$*" "$C_0"; L "== $*"; }
ok()  { printf '  %s✔%s %s\n' "$C_G" "$C_0" "$*"; L "OK: $*"; }
warn(){ printf '  %s!%s %s\n' "$C_Y" "$C_0" "$*"; L "WARN: $*"; }
info(){ printf '  %s→%s %s\n' "$C_B" "$C_0" "$*"; }
bad() { printf '  %s✘%s %s\n' "$C_R" "$C_0" "$*"; L "FAIL: $*"; FAILS=$((FAILS+1)); }
die() { printf '%s✘ %s%s\n' "$C_R" "$*" "$C_0" >&2; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }
# Команда с логом и реальным кодом возврата
run() { L "RUN: $*"; "$@" >>"$LOG" 2>&1; }

usage(){
  if [[ -n "$SELF" ]]; then awk 'NR>1 && /^#/{sub(/^# ?/,""); print; next} NR>1{exit}' "$SELF"
  else echo "Flags: --fix-only --dns-only --dns=cloudflare|quad9|google|none --no-dns --dns-strict --revert-dns"; fi
  exit 0
}

for a in "$@"; do
  case "$a" in
    --fix-only)   DO_DNS=0 ;;
    --dns-only)   DO_FIX=0 ;;
    --dns=*)      DNS_CHOICE="${a#--dns=}" ;;
    --no-dns)     DNS_CHOICE="none" ;;
    --dns-strict) DNS_STRICT=1 ;;
    --revert-dns) REVERT=1; DO_FIX=0 ;;
    -h|--help)    usage ;;
    *) die "$(t "Неизвестный параметр: $a (см. --help)" "Unknown option: $a (see --help)")" ;;
  esac
done
case "$DNS_CHOICE" in ""|none|cloudflare|quad9|google) ;; *) die "--dns=cloudflare|quad9|google|none" ;; esac

if (( EUID != 0 )); then
  [[ -n "$SELF" ]] || die "$(t "Нужен root: curl ... | sudo bash -s -- <флаги>" "Root required: curl ... | sudo bash -s -- <flags>")"
  exec sudo -E bash "$SELF" "$@"
fi

# ---------- Терминал для вопросов ----------
# При «curl | sudo bash» stdin — не терминал, а /dev/tty внутри sudo не связан с
# клавиатурой. Ищем настоящий терминал вызвавшего пользователя среди предков.
TTY_IN=""
find_tty(){
  TTY_IN=""
  if [[ -t 0 ]]; then TTY_IN="/dev/stdin"; return 0; fi
  local mine1 mine2 pid t fd i
  mine1=$(readlink /proc/self/fd/1 2>/dev/null || true)
  mine2=$(readlink /proc/self/fd/2 2>/dev/null || true)
  pid=$$
  for i in 1 2 3 4 5 6 7 8; do
    pid=$(awk '/^PPid:/{print $2}' "/proc/$pid/status" 2>/dev/null || true)
    [[ "$pid" =~ ^[0-9]+$ ]] && (( pid > 1 )) || break
    for fd in 0 1 2; do
      t=$(readlink "/proc/$pid/fd/$fd" 2>/dev/null || true)
      case "$t" in
        /dev/pts/*|/dev/tty[0-9]*)
          [[ "$t" == "$mine1" || "$t" == "$mine2" ]] && continue
          if [[ -n "${SUDO_UID:-}" && "$(stat -c %u "$t" 2>/dev/null || echo x)" != "$SUDO_UID" ]]; then continue; fi
          [[ -r $t ]] || continue
          TTY_IN="$t"; return 0 ;;
      esac
    done
  done
  if ( : </dev/tty ) 2>/dev/null; then TTY_IN="/dev/tty"; return 0; fi
  return 1
}

# ============================================================
#  ЧАСТЬ 1. OPENH264
# ============================================================
fix_openh264(){
  local repo found=0
  step "$(t "Фикс геоблока OpenH264" "OpenH264 geoblock fix")"

  info "$(t "1/4 Отключаю репозиторий Cisco" "1/4 Disabling the Cisco repo")"
  for repo in /etc/yum.repos.d/*cisco*openh264*.repo; do
    [[ -f $repo ]] || continue
    found=1
    # enabled меняется только внутри секций [*openh264*]
    if sed -i '/^\[.*openh264.*\]/,/^\[/ s/^enabled=.*/enabled=0/' "$repo"; then ok "$(basename "$repo")"
    else bad "$(t "не удалось изменить" "cannot edit") $repo"; fi
  done
  (( found )) || ok "$(t "файла репозитория нет — нечего отключать" "repo file absent — nothing to disable")"

  info "$(t "2/4 openh264 → noopenh264" "2/4 openh264 → noopenh264")"
  if rpm -q noopenh264 &>/dev/null && ! rpm -q openh264 &>/dev/null; then
    ok "$(t "уже заменён" "already replaced")"
  elif [[ -f /run/ostree-booted ]] && have rpm-ostree; then
    if rpm -q openh264 &>/dev/null; then
      run rpm-ostree override remove openh264 --install=noopenh264 && ok "override" || bad "rpm-ostree override"
    else
      run rpm-ostree install --idempotent -y noopenh264 && ok "noopenh264" || bad "rpm-ostree install"
    fi
    NEED_REBOOT=1
  else
    # --allowerasing уберёт mozilla-openh264 / gstreamer1-plugin-openh264:
    # без доступа к Cisco они всё равно нерабочие
    if rpm -q openh264 &>/dev/null; then
      if run dnf swap -y --allowerasing openh264 noopenh264 || run dnf install -y --allowerasing noopenh264; then ok "swap"
      else bad "$(t "dnf swap не удался (см. лог)" "dnf swap failed (see log)")"; fi
    else
      run dnf install -y --allowerasing noopenh264 && ok "noopenh264" || bad "dnf install noopenh264"
    fi
  fi

  info "$(t "3/4 Закрепляю исключение в dnf" "3/4 Pinning the exclusion in dnf")"
  if [[ -f /run/ostree-booted ]]; then
    ok "$(t "закреплено через rpm-ostree override" "pinned by rpm-ostree override")"
  else
    install -d -m 0755 /etc/dnf/libdnf5.conf.d
    printf '[main]\nexcludepkgs=openh264,mozilla-openh264,gstreamer1-plugin-openh264\n' \
      > /etc/dnf/libdnf5.conf.d/99-exclude-openh264.conf \
      && ok "/etc/dnf/libdnf5.conf.d/99-exclude-openh264.conf" || bad "exclude file"
  fi

  info "$(t "4/4 Flatpak: маскирую openh264" "4/4 Flatpak: masking openh264")"
  if have flatpak; then
    if flatpak list --system --runtime 2>/dev/null | grep -q 'org.freedesktop.Platform.openh264'; then
      run flatpak uninstall --system -y --noninteractive org.freedesktop.Platform.openh264 || true
    fi
    run flatpak mask --system org.freedesktop.Platform.openh264 && ok "mask" || warn "mask failed"
  else
    ok "$(t "flatpak не установлен — пропуск" "flatpak not installed — skipped")"
  fi
}

# ============================================================
#  ЧАСТЬ 2. DNS-over-TLS
# ============================================================
DNS_SERVERS=""; DNS_PROBE_IP=""; DNS_PROBE_HOST=""
dns_provider(){
  case "$1" in
    cloudflare)
      DNS_SERVERS="1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com 2606:4700:4700::1111#cloudflare-dns.com 2606:4700:4700::1001#cloudflare-dns.com"
      DNS_PROBE_IP="1.1.1.1"; DNS_PROBE_HOST="cloudflare-dns.com" ;;
    quad9)
      DNS_SERVERS="9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net 2620:fe::fe#dns.quad9.net 2620:fe::9#dns.quad9.net"
      DNS_PROBE_IP="9.9.9.9"; DNS_PROBE_HOST="dns.quad9.net" ;;
    google)
      DNS_SERVERS="8.8.8.8#dns.google 8.8.4.4#dns.google 2001:4860:4860::8888#dns.google 2001:4860:4860::8844#dns.google"
      DNS_PROBE_IP="8.8.8.8"; DNS_PROBE_HOST="dns.google" ;;
  esac
}

# Вопрос в консоли (по умолчанию — не менять)
ask_dns(){
  [[ -z "$DNS_CHOICE" ]] || return 0
  if ! find_tty; then
    warn "$(t "Нет терминала для вопроса — DNS не меняется (задайте --dns=cloudflare|quad9|google)" \
               "No terminal to ask — DNS unchanged (use --dns=cloudflare|quad9|google)")"
    DNS_CHOICE="none"; return 0
  fi
  step "$(t "DNS-over-TLS (по желанию)" "DNS-over-TLS (optional)")"
  {
    echo "  $(t "Шифрованный DNS скрывает запросы от провайдера, но отправляет их выбранной компании." \
               "Encrypted DNS hides queries from your ISP but sends them to the chosen company.")"
    echo "    1) $(t "Не менять DNS (по умолчанию)" "Keep current DNS (default)")"
    echo "    2) Cloudflare 1.1.1.1"
    echo "    3) Quad9 9.9.9.9 — $(t "блокирует вредоносные домены" "blocks malicious domains")"
    echo "    4) Google 8.8.8.8"
  } >&2
  info "$(t "Введите номер и нажмите Enter (жду 60 с; без ответа DNS не изменится)" \
             "Type a number and press Enter (60 s; no answer = DNS unchanged)")"
  local ans="" rc=0
  read -r -t 60 -p "  [1-4, Enter = 1]: " ans < "$TTY_IN" || rc=$?
  if (( rc > 128 )); then
    echo >&2; warn "$(t "Ответ не получен за 60 с — DNS без изменений" "No answer in 60 s — DNS unchanged")"
    DNS_CHOICE="none"; return 0
  fi
  case "${ans//[[:space:]]/}" in
    2) DNS_CHOICE=cloudflare ;;
    3) DNS_CHOICE=quad9 ;;
    4) DNS_CHOICE=google ;;
    *) DNS_CHOICE=none ;;
  esac
}

# Проверка ДО включения: порт 853 и TLS-сертификат. 0 — можно применять.
dns_precheck(){
  local ip=$DNS_PROBE_IP host=$DNS_PROBE_HOST out
  if ! timeout 5 bash -c "exec 3<>/dev/tcp/$ip/853" 2>/dev/null; then
    warn "$(t "Порт 853 ($ip) недоступен: сеть или провайдер блокируют DNS-over-TLS" \
               "Port 853 ($ip) unreachable: network or ISP blocks DNS-over-TLS")"
    return 1
  fi
  ok "$(t "Порт 853 доступен" "Port 853 reachable") ($ip)"
  if have openssl; then
    out=$(echo | timeout 10 openssl s_client -connect "$ip:853" -servername "$host" -verify_hostname "$host" 2>/dev/null || true)
    if grep -q 'Verify return code: 0' <<<"$out"; then
      ok "$(t "TLS-сертификат корректен" "TLS certificate valid") ($host)"
    else
      warn "$(t "TLS-сертификат $host не прошёл проверку — DNS не меняем" "TLS certificate of $host failed — DNS unchanged")"
      return 1
    fi
  else
    warn "$(t "openssl не найден — проверка сертификата пропущена" "openssl not found — certificate check skipped")"
  fi
  return 0
}

rollback_dns(){
  rm -f -- "$DNS_FILE"
  run systemctl restart systemd-resolved || true
  sleep 2
  if have resolvectl && timeout 8 resolvectl query example.com >/dev/null 2>&1; then
    ok "$(t "DNS возвращён к прежним настройкам и работает" "DNS restored and working")"
  else
    warn "$(t "Проверьте DNS вручную: resolvectl status" "Check DNS manually: resolvectl status")"
  fi
}

# Проверка ПОСЛЕ включения: настройки применились, имена разрешаются и
# TLS-соединение (порт 853) реально установлено. Иначе — откат.
verify_dns(){
  step "$(t "Проверка DNS-over-TLS" "Verifying DNS-over-TLS")"
  local d i resolved=0 tls=0 applied=0 status
  sleep 2
  status=$(resolvectl status 2>/dev/null || true)
  if grep -qF "${DNS_PROBE_IP}#${DNS_PROBE_HOST}" <<<"$status" \
     && grep -qE '(^|[ =])(\+DNSOverTLS|DNSOverTLS=(opportunistic|yes))' <<<"$status"; then
    applied=1; ok "$(t "Настройки применились" "Settings applied"): ${DNS_PROBE_IP}#${DNS_PROBE_HOST}"
  else
    warn "$(t "В resolvectl не видно новых настроек DNS-over-TLS" "New DNS-over-TLS settings not visible in resolvectl")"
  fi
  have resolvectl && resolvectl flush-caches >/dev/null 2>&1 || true
  for d in example.com iana.org fedoraproject.org; do
    if have resolvectl; then timeout 8 resolvectl query "$d" >/dev/null 2>&1 && resolved=1
    else timeout 8 getent hosts "$d" >/dev/null 2>&1 && resolved=1; fi
  done
  for i in 1 2 3 4 5; do
    if [[ -n "$(ss -Htn state established '( dport = :853 )' 2>/dev/null)" ]]; then tls=1; break; fi
    sleep 1
  done
  if (( applied && resolved && tls )); then
    ok "$(t "Имена разрешаются, TLS-соединение установлено — DNS-over-TLS работает" \
            "Names resolve and the TLS connection is established — DNS-over-TLS works")"
    if (( DNS_STRICT )); then ok "$(t "Строгий режим: сертификат проверяется при каждом запросе" "Strict mode: certificate verified on every query")"
    else warn "$(t "Режим opportunistic: запросы шифруются, но сертификат не проверяется (строго: --dns-strict)" \
                    "Opportunistic mode: encrypted but certificate not verified (use --dns-strict)")"; fi
    warn "$(t "Домены локальной сети (router.lan и т.п.) могут не разрешаться — DNS из DHCP больше не основной" \
               "Local-network names (router.lan etc.) may stop resolving — DHCP DNS is no longer primary")"
    return 0
  fi
  (( resolved )) || warn "$(t "Имена не разрешаются с новыми настройками" "Names do not resolve with the new settings")"
  (( tls ))      || warn "$(t "TLS-соединение (порт 853) не установлено — запросы шли бы без шифрования" "No TLS connection on port 853 — queries would be unencrypted")"
  (( applied ))  || warn "$(t "systemd-resolved не подхватил настройки" "systemd-resolved did not pick up the settings")"
  warn "$(t "Откатываю настройки DNS" "Rolling back DNS settings")"
  rollback_dns
  bad "$(t "DNS-over-TLS не включён" "DNS-over-TLS not enabled")"
}

setup_dns(){
  ask_dns
  [[ -n "$DNS_CHOICE" && "$DNS_CHOICE" != none ]] || { step "DNS-over-TLS"; ok "$(t "DNS не меняется" "DNS unchanged")"; return 0; }
  step "DNS-over-TLS ($DNS_CHOICE)"
  dns_provider "$DNS_CHOICE"

  if ! systemctl is-active systemd-resolved >/dev/null 2>&1; then
    warn "$(t "systemd-resolved не активен — DNS не меняем (включить: systemctl enable --now systemd-resolved)" \
               "systemd-resolved is not active — DNS unchanged (enable: systemctl enable --now systemd-resolved)")"
    return 0
  fi
  if ! readlink -f /etc/resolv.conf | grep -q '/systemd/resolve/'; then
    warn "$(t "/etc/resolv.conf не ведёт на systemd-resolved — настройка не подействует. Исправить: ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf" \
               "/etc/resolv.conf does not point to systemd-resolved — setting would have no effect. Fix: ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf")"
    return 0
  fi
  dns_precheck || { warn "$(t "DNS не изменён. Попробуйте другого провайдера: --dns=quad9 или --dns=google" "DNS unchanged. Try another provider: --dns=quad9 or --dns=google")"; return 0; }

  local mode=opportunistic; (( DNS_STRICT )) && mode=yes
  info "$(t "Режим DNS-over-TLS" "DNS-over-TLS mode"): $mode"
  rm -f -- "$OLD_DNS_FILE"                       # конфиг старых версий скрипта
  install -d -m 0755 "$(dirname "$DNS_FILE")"
  # Формат DNS=IP#имя (имя нужно для SNI и проверки сертификата).
  # Domains=~. — чтобы этот DNS был основным, а не запасным после DNS из DHCP.
  cat > "$DNS_FILE" <<EOF
[Resolve]
DNS=${DNS_SERVERS}
DNSOverTLS=${mode}
Domains=~.
EOF
  chmod 0644 "$DNS_FILE"
  ok "$(t "создан" "created") $DNS_FILE"
  run systemctl restart systemd-resolved || warn "restart systemd-resolved"
  verify_dns
}

revert_dns(){
  step "$(t "Откат DNS-over-TLS" "Revert DNS-over-TLS")"
  local f removed=0
  for f in "$DNS_FILE" "$OLD_DNS_FILE"; do
    [[ -e $f ]] && { rm -f -- "$f"; ok "$(t "удалён" "removed") $f"; removed=1; }
  done
  (( removed )) || ok "$(t "настройки DNS-over-TLS не найдены" "no DNS-over-TLS config found")"
  run systemctl restart systemd-resolved && ok "systemd-resolved restarted" || warn "restart systemd-resolved"
}

# ============================================================
main(){
  [[ -t 0 ]] || exec </dev/null
  echo "${C_B}Fedora openh264 geoblock fix + DNS-over-TLS v6.0${C_0}   log: $LOG"
  L "started: $*"

  step "$(t "Проверка системы" "System check")"
  exec 9>"/run/${TAG}.lock"
  flock -n 9 || die "$(t "Скрипт уже запущен" "Already running")"
  [[ -r /etc/os-release ]] || die "no /etc/os-release"
  # shellcheck disable=SC1091
  . /etc/os-release
  if [[ "${ID:-}" != fedora ]]; then
    warn "$(t "Это не Fedora" "Not Fedora") (ID=${ID:-?})"
    if find_tty; then
      local a=""; read -r -p "  $(t "Продолжить? (y/N): " "Continue? (y/N): ")" a < "$TTY_IN" || true
      [[ "$a" =~ ^[Yy]$ ]] || exit 1
    else exit 1; fi
  fi
  if have systemd-detect-virt && systemd-detect-virt --container -q 2>/dev/null; then
    die "$(t "Контейнер: здесь это не нужно" "Container: not applicable")"
  fi
  if [[ -f /run/ostree-booted ]]; then ok "Fedora ${VERSION_ID:-?} Atomic (rpm-ostree)"; else ok "Fedora ${VERSION_ID:-?} (dnf)"; fi

  if (( REVERT )); then revert_dns; fi
  if (( DO_FIX )); then fix_openh264; fi
  if (( DO_DNS && ! REVERT )); then setup_dns; fi

  step "$(t "Итог" "Summary")"
  if (( FAILS == 0 )); then ok "$(t "Готово" "Done")"; else bad "$(t "Ошибок" "Errors"): $FAILS"; fi
  (( NEED_REBOOT )) && warn "$(t "Нужна перезагрузка (Atomic)" "Reboot required (Atomic)")"
  info "$(t "Лог" "Log"): $LOG"
  info "$(t "Отключить DNS-over-TLS" "Disable DNS-over-TLS"): sudo bash ${SELF:-fedora-openh264-fix.sh} --revert-dns"
  L "finished fails=$FAILS"
  (( FAILS == 0 ))
}

# Всё выполнение внутри main: bash сначала целиком читает функцию, и команды
# вроде dnf не «съедают» остаток скрипта из stdin при curl | bash.
main "$@"
