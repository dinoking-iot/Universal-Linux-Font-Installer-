#!/usr/bin/env bash
# =============================================================================
#  install_fonts_universal.sh  v3.2   (one project file: new versions simply overwrite it)
#  Safe font installer + diagnostics for any Linux (BigLinux first). Fonts only.
#  Trình cài font an toàn + chẩn đoán cho mọi Linux (ưu tiên BigLinux). Chỉ dành cho font.
#
#  FIRST RUN / LẦN ĐẦU: files downloaded by a browser are NOT executable. If double-click does nothing, open a terminal in this
#  folder and run:  bash install_fonts_universal.sh   (the script then marks itself executable). Or: right-click > Properties >
#  Permissions > tick 'Is executable'.  Tải từ trình duyệt về thì file chưa có quyền chạy; nếu bấm đúp không chạy, hãy dùng lệnh trên.
#
#  USAGE / CÁCH DÙNG
#    ./install_fonts_universal.sh                    GUI: pick a font archive or folder / Chọn file nén hoặc thư mục
#    ./install_fonts_universal.sh PATH               Install fonts from archive or folder / Cài từ file nén hoặc thư mục
#    ./install_fonts_universal.sh --diagnose [--fix] Check this PC (read-only) / fix font hijacking / Chẩn đoán (+ sửa)
#    ./install_fonts_universal.sh --uninstall        Remove everything this script installed / Gỡ sạch những gì script đã cài
#    ./install_fonts_universal.sh --clean            Remove leftovers (temp, old backups) / Dọn rác tồn đọng
#    ./install_fonts_universal.sh --fix-brave-prefs  Reset Brave custom fonts (with backup) / Đặt lại font Brave
#    ./install_fonts_universal.sh --stop-logger      Stop the background logger / Dừng tiến trình ghi log nền
#  OPTIONS / TUỲ CHỌN:  --strict (also isolate cosmetic/legacy fonts)  --cli  -y|--yes  --dry-run
# =============================================================================
set -u
trap '' PIPE            # a closed progress window must never kill the script / cửa sổ tiến trình đóng không làm chết script

VERSION="3.2"
MODE="install"; INPUT=""; CLI=0; YES=0; DRY=0; FIX=0; STRICT=0
USAGE_END=19
usage() { sed -n "2,${USAGE_END}p" "$0" | sed 's/^# \{0,1\}//'; }
while [ $# -gt 0 ]; do
    case "$1" in
        --cli) CLI=1 ;;
        -y|--yes) YES=1; CLI=1 ;;
        --dry-run) DRY=1 ;;
        --strict) STRICT=1 ;;
        --diagnose) MODE="diagnose" ;;
        --fix) FIX=1 ;;
        --uninstall) MODE="uninstall" ;;
        --clean) MODE="clean" ;;
        --fix-brave-prefs) MODE="brave" ;;
        --stop-logger) MODE="stop-logger" ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "Unknown option / Tuỳ chọn không hợp lệ: $1" >&2; exit 2 ;;
        *) INPUT="$1" ;;
    esac
    shift
done

if [ "$(id -u)" -eq 0 ]; then
    echo "Do not run as root: fonts are installed for the current user. / Không chạy bằng root: font được cài cho người dùng hiện tại." >&2
    exit 1
fi

# Browsers save downloads without the executable bit, so double-click does nothing. Fix our own file once.
# Trình duyệt tải về không có quyền thực thi nên bấm đúp không chạy; tự cấp quyền cho chính file này.
_self="${BASH_SOURCE[0]:-$0}"
if [ -f "$_self" ] && [ ! -x "$_self" ]; then chmod u+x "$_self" 2>/dev/null && SELF_FIXED=1; fi

# ------------------------------- paths (always the CURRENT user) -------------
XDG_DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}"
FONT_DIR="$XDG_DATA/fonts/installed-by-script"       # scanned by fontconfig / được fontconfig quét
ISOLATED_DIR="$XDG_DATA/fonts-isolated"              # NOT scanned / KHÔNG được quét
USER_FONT_ROOTS=("$HOME/.fonts" "$HOME/.fonts_design" "$XDG_DATA/fonts")
DOCS="$(xdg-user-dir DOCUMENTS 2>/dev/null || true)"; [ -d "${DOCS:-}" ] || DOCS="$HOME/Documents"
mkdir -p "$DOCS"
LOG_FILE="$DOCS/font_install_report.log"             # single log, overwritten each run / một log, ghi đè mỗi lần
BASE_FC="${FI_BASE_FONTCONFIG:-/etc/fonts/fonts.conf}"   # testing hook / dùng để kiểm thử
MANAGED_CONF="$XDG_CONF/fontconfig/conf.d/60-install-fonts-universal.conf"
DESIGN_CONF="$XDG_CONF/fontconfig/design-fonts.conf"
WRAPPER="$HOME/.local/bin/with-design-fonts"
STATE="${XDG_RUNTIME_DIR:-/tmp}/font-installer-$(id -u)"   # tmpfs: wiped at reboot / bị xoá khi reboot
mkdir -p "$STATE"

WORK=""; ERR_COUNT=0; WARN_COUNT=0; ERR_LIST=()
cleanup() { [ -n "$WORK" ] && rm -rf "$WORK"; progress_end 2>/dev/null; }
trap cleanup EXIT

# ------------------------------- helpers -------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }
norm() { local s="${1,,}"; printf '%s' "${s//[ _-]/}"; }
ts()   { date +%H:%M:%S; }
log()  { printf '[%s] %s\n' "$(ts)" "$*" >> "$LOG_FILE"; }
# info/warn/err EN VI   (English first, Vietnamese second / tiếng Anh trước, tiếng Việt sau)
info() { printf '%s\n    %s\n' "$1" "$2"; log "[INFO] $1 | $2"; }
warn() { printf '[!] %s\n    %s\n' "$1" "$2"; log "[WARN] $1 | $2"; WARN_COUNT=$((WARN_COUNT + 1)); }
err()  { printf '[X] %s\n    %s\n' "$1" "$2" >&2; log "[ERROR] $1 | $2"; ERR_COUNT=$((ERR_COUNT + 1)); ERR_LIST+=("$1"); }
gui()  { [ "$CLI" -eq 0 ] && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && have zenity; }

# --- notifications: ONE bubble that is replaced in place + per-key throttle => no spam --------
NOTIFY_HAS_ID=0; have notify-send && notify-send --help 2>&1 | grep -q -- '--print-id' && NOTIFY_HAS_ID=1
notify() {   # notify [-f] KEY EN VI   (-f = force, for final result)
    local force=0; [ "${1:-}" = "-f" ] && { force=1; shift; }
    local key="$1" en="$2" vi="$3" now last id new
    log "[NOTIFY:$key] $en | $vi"
    now="$(date +%s)"; last="$(cat "$STATE/n_$key" 2>/dev/null || echo 0)"
    if [ "$force" -eq 0 ] && [ $((now - last)) -lt 20 ]; then return 0; fi   # same event within 20 s: skip
    printf '%s' "$now" > "$STATE/n_$key"
    [ "$CLI" -eq 0 ] && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && have notify-send || return 0
    if [ "$NOTIFY_HAS_ID" -eq 1 ]; then
        id="$(cat "$STATE/n_id" 2>/dev/null || true)"
        if [ -n "$id" ]; then new="$(notify-send -p -r "$id" -t 7000 -i preferences-desktop-font "$en" "$vi" 2>/dev/null)"
        else new="$(notify-send -p -t 7000 -i preferences-desktop-font "$en" "$vi" 2>/dev/null)"; fi
        [ -n "$new" ] && printf '%s' "$new" > "$STATE/n_id"
    else
        notify-send -t 7000 -i preferences-desktop-font "$en" "$vi" 2>/dev/null
    fi
    return 0
}

# --- progress bar (zenity window if GUI, text otherwise) -----------------------------------
PROG_ON=0; LAST_PROG_TXT=""
progress_start() {   # EN VI
    [ "$CLI" -eq 0 ] || return 0
    gui || return 0
    coproc ZPROG { zenity --progress --title="Font Installer / Trình cài font" --text="$1\n$2" \
                          --percentage=0 --auto-close --no-cancel --width=460 2>/dev/null; }
    PROG_ON=1
}
progress() {         # PCT EN VI
    local pct="$1" en="$2" vi="$3"
    if [ "$PROG_ON" -eq 1 ]; then
        printf '%s\n# %s\n' "$pct" "$en — $vi" >&"${ZPROG[1]}" 2>/dev/null || true
    fi
    if [ "$en" != "$LAST_PROG_TXT" ]; then
        printf '[%3s%%] %s — %s\n' "$pct" "$en" "$vi"; LAST_PROG_TXT="$en"
    fi
    log "[PROGRESS $pct%] $en"
}
progress_end() {
    [ "$PROG_ON" -eq 1 ] || return 0
    PROG_ON=0
    printf '100\n' >&"${ZPROG[1]}" 2>/dev/null || true
    exec {ZPROG[1]}>&- 2>/dev/null
    wait "${ZPROG_PID:-0}" 2>/dev/null || true
}

confirm() {   # confirm EN VI
    [ "$YES" -eq 1 ] && return 0
    if gui; then zenity --question --width=560 --title="Font Installer / Trình cài font" --text="$1\n\n$2" 2>/dev/null
    elif [ -t 0 ]; then local a; read -r -p "$1 / $2 [y/N] " a; [[ "$a" =~ ^[Yy] ]]
    else return 1; fi
}

# Result dialog: stays on screen until the user clicks OK (a bubble alone is easy to miss)
# Hộp thoại kết quả: giữ nguyên đến khi bấm OK (bong bóng thông báo rất dễ bị bỏ lỡ)
show_result() {   # KIND(info|warning|error) HEAD_EN HEAD_VI BODY
    local kind="$1" en="$2" vi="$3" body="${4:-}"
    gui || return 0
    zenity "--$kind" --no-markup --no-wrap --width=520 --title="Font Installer / Trình cài font" \
           --text="$en
$vi
${body:+
$body}" 2>/dev/null
}

# ------------------------- environment detection (any distro/DE/session) -------
detect_env() {
    DISTRO_ID="unknown"; DISTRO_LIKE=""; DISTRO_NAME="Linux"
    if [ -r /etc/os-release ]; then
        # read in subshells: sourcing would overwrite our own variables (e.g. VERSION) / đọc trong subshell để không ghi đè biến
        DISTRO_ID="$(. /etc/os-release; printf '%s' "${ID:-unknown}")"
        DISTRO_LIKE="$(. /etc/os-release; printf '%s' "${ID_LIKE:-}")"
        DISTRO_NAME="$(. /etc/os-release; printf '%s' "${PRETTY_NAME:-${NAME:-Linux}}")"
    fi
    DESKTOP="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-unknown}}"; SESSION="${XDG_SESSION_TYPE:-unknown}"
    IS_BIGLINUX=0; [[ "${DISTRO_ID} ${DISTRO_LIKE} ${DISTRO_NAME}" == *[Bb]ig[Ll]inux* ]] && IS_BIGLINUX=1
    IMMUTABLE=0
    { [ "$DISTRO_ID" = "steamos" ] || [ -e /run/ostree-booted ] || have rpm-ostree; } && IMMUTABLE=1
}
detect_env

pkg_manager() { for m in pacman apt-get dnf zypper; do have "$m" && { echo "$m"; return; }; done; }
priv_run() {   # run as root via polkit dialog (GUI) or sudo (terminal) / chạy quyền root qua polkit hoặc sudo
    [ "$IMMUTABLE" -eq 1 ] && return 3
    if have pkexec && { [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] || [ ! -t 0 ]; }; then pkexec "$@"
    elif have sudo && [ -t 0 ]; then sudo "$@"
    elif have pkexec; then pkexec "$@"
    else return 1; fi
}
pkg_names() {   # logical name -> package names for this distro
    case "$(pkg_manager):$1" in
        pacman:unzip) echo unzip ;;          pacman:7z) echo p7zip ;;           pacman:unrar) echo unrar ;;
        pacman:zenity) echo zenity ;;        pacman:baseline-fonts) echo "noto-fonts ttf-dejavu ttf-liberation" ;;
        apt-get:unzip) echo unzip ;;         apt-get:7z) echo p7zip-full ;;     apt-get:unrar) echo unrar-free ;;
        apt-get:zenity) echo zenity ;;       apt-get:baseline-fonts) echo "fonts-noto-core fonts-dejavu-core fonts-liberation" ;;
        dnf:unzip) echo unzip ;;             dnf:7z) echo "p7zip p7zip-plugins" ;; dnf:unrar) echo unrar ;;
        dnf:zenity) echo zenity ;;           dnf:baseline-fonts) echo "google-noto-sans-fonts google-noto-serif-fonts dejavu-sans-fonts liberation-fonts" ;;
        zypper:unzip) echo unzip ;;          zypper:7z) echo p7zip ;;           zypper:unrar) echo unrar ;;
        zypper:zenity) echo zenity ;;        zypper:baseline-fonts) echo "noto-sans-fonts dejavu-fonts liberation-fonts" ;;
        *) return 1 ;;
    esac
}
pkg_install() {   # pkg_install LOGICAL_NAME
    local pm names cmd
    if [ "$IMMUTABLE" -eq 1 ]; then
        warn "This system is read-only/immutable ($DISTRO_NAME): system packages cannot be installed here." \
             "Hệ thống chỉ-đọc/bất biến: không thể cài gói hệ thống. Hãy dùng Flatpak."; return 3
    fi
    pm="$(pkg_manager)"; names="$(pkg_names "$1")" || { err "No package mapping for '$1' on this distro." "Không có gói tương ứng cho '$1'."; return 1; }
    case "$pm" in
        pacman)  cmd=(pacman -S --needed --noconfirm) ;;
        apt-get) cmd=(apt-get install -y) ;;
        dnf)     cmd=(dnf install -y) ;;
        zypper)  cmd=(zypper --non-interactive install) ;;
    esac
    info "Installing: $names (administrator approval may be requested)" "Đang cài: $names (có thể cần xác nhận quyền quản trị)"
    # shellcheck disable=SC2086
    priv_run "${cmd[@]}" $names >> "$LOG_FILE" 2>&1 || { err "Package install failed: $names" "Cài gói thất bại: $names"; return 1; }
}

# ------------------------------- background logger (no autostart) ------------
# Starts once per boot session, dies at reboot/logout. No systemd unit, no autostart entry.
# Chạy một lần mỗi phiên khởi động, tắt khi reboot/đăng xuất. Không autostart.
logger_alive() {
    local pid; pid="$(cat "$STATE/logger.pid" 2>/dev/null || true)"
    [ -n "$pid" ] && [ -r "/proc/$pid/cmdline" ] && tr '\0' ' ' < "/proc/$pid/cmdline" | grep -q 'font-installer-logger'
}
start_logger() {
    logger_alive && { log "[BG] logger already running (pid $(cat "$STATE/logger.pid"))"; return 0; }
    # Only font-related problems and crashes: unrelated system noise is ignored / bỏ qua nhiễu của dịch vụ khác
    local pat='fontconfig|freetype|OTS parsing|font file|segfault|coredump|core dumped|SIGSEGV'
    setsid bash -c '
        LOG="$1"; PIDF="$2"; PAT="$3"
        echo $$ > "$PIDF"; trap "exit 0" TERM INT
        if command -v journalctl >/dev/null 2>&1; then
            declare -A last=()
            journalctl --user -f -n 0 -o short-iso --no-pager 2>/dev/null \
              | grep --line-buffered -iE "$PAT" | grep --line-buffered -vE "install_fonts_universal|font-installer" \
              | while IFS= read -r line; do
                    key="${line#* * }"; now=$(printf "%(%s)T" -1)
                    [ $((now - ${last[$key]:-0})) -lt 300 ] && continue     # same message within 5 min: skip
                    last[$key]=$now; printf "[bg-journal] %s\n" "$line" >> "$LOG"
                done &
        fi
        while sleep 120; do      # keep the log small: keep the last 3000 lines when above 8 MB
            sz=$(stat -c %s "$LOG" 2>/dev/null || echo 0)
            [ "$sz" -gt 8388608 ] && { tail -n 3000 "$LOG" > "$LOG.tmp" && cat "$LOG.tmp" > "$LOG"; rm -f "$LOG.tmp"; }
        done
    ' font-installer-logger "$LOG_FILE" "$STATE/logger.pid" "$pat" >/dev/null 2>&1 < /dev/null &
    disown 2>/dev/null
    for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$STATE/logger.pid" ] && break; sleep 0.1; done
    logger_alive && log "[BG] background logger started (pid $(cat "$STATE/logger.pid")); stops at reboot or with --stop-logger" \
                 || warn "Background logger could not start (non-fatal)." "Không khởi động được tiến trình log nền (không nghiêm trọng)."
}
stop_logger() {
    if logger_alive; then kill -TERM -- "-$(cat "$STATE/logger.pid")" 2>/dev/null; rm -f "$STATE/logger.pid"; info "Background logger stopped." "Đã dừng tiến trình log nền."
    else info "Background logger is not running." "Tiến trình log nền không chạy."; fi
}

# ------------------------------- AI patch ledger (travels inside the script) ---
PATCH_LEDGER=(
"ISSUE-001 Brave UI rendered in a heart-shaped font | cause: RixLoveFool.ttf also names itself 'Arial' (ArialMT), so fontconfig answered every 'Arial' request with it | FIX v2: spoof detection + behavioural canary + --diagnose --fix"
"ISSUE-002 Blacklist by file name only; already-installed copies were never removed | FIX v2: audit and isolate fonts that are already installed (--diagnose --fix)"
"ISSUE-003 'Isolated' folder ~/.fonts_design was registered in fontconfig, so it was not isolated | FIX v2: folder is not scanned; use with-design-fonts to expose it to one app"
"ISSUE-004 fonts.conf used mode=assign for sans-serif/serif/monospace and broke the default fallback chain | FIX v2: prepend-only alias file in conf.d; old file backed up (.v1.bak)"
"ISSUE-005 pkill -9 on brave/chrome/onlyoffice also killed unrelated apps (Discord, Electron) | FIX v2: no process killing; ask the user to restart the browser"
"ISSUE-006 sed edits of Brave 'Preferences' could leave invalid JSON | FIX v2: python json with backup, only on request, only when Brave is closed"
"ISSUE-007 rm -rf of OnlyOffice data/fonts could delete the user's own fonts | FIX v2: removed"
"ISSUE-008 Password typed in a dialog and piped to sudo -S | FIX v2: pkexec (polkit) or sudo in a terminal"
"ISSUE-009 Hard-coded /home/\$USER paths | FIX v2/v3: \$HOME and XDG directories of the CURRENT user"
"ISSUE-010 Empty FONTCONFIG_FILE made the hijack check see no fonts (false 'baseline missing') | FIX v2.1: only export the variable when set"
"ISSUE-011 AI mis-identified the culprit as MTD Quimbly from a small screenshot | FIX: verified at high zoom; rule: confirm by behaviour (fc-match), not by eye"
"ISSUE-012 v2 isolated 439 decorative/VNI fonts that customers use in documents | FIX v3: only PROVEN hazards are isolated (spoofing, hijacking, broken); --strict restores the old policy"
"ISSUE-013 Progress window auto-closed at 100% and the only result was a 7 s bubble, so users saw the GUI vanish with no success message | FIX v3.1: persistent result dialog (OK button) + bubble"
"ISSUE-014 Background logger recorded unrelated system errors (e.g. microphone service every 30 s) and echoed the script's own output | FIX v3.1: font/crash-only filter, own output excluded, repeated lines rate-limited"
"ISSUE-015 Counter showed '-1 installed' when only an old harmful font was cleaned up | FIX v3.1: separate 'cleaned up' counter, counters never negative"
"ISSUE-016 Gaming module (Steam/Wine/sysctl/anti-cheat notes) was added although this is a font-only script; games are handled by a separate script | FIX v3.1: removed completely"
"ISSUE-017 Script saved in ~/Downloads does nothing on double-click (browser downloads have no executable bit; project folder on an NTFS/exFAT partition is mounted executable) | FIX v3.2: run once with 'bash install_fonts_universal.sh' and the script chmods itself; header explains it"
"v3 NEW bilingual EN/VI UI, single replaceable notification, progress window, error count, background logger (no autostart), --uninstall, --clean"
)
write_header() {
    : > "$LOG_FILE"
    {
        echo "=============================================================="
        echo " FONT INSTALLER REPORT v$VERSION / BÁO CÁO TRÌNH CÀI FONT"
        echo " $(date -Is)   mode=$MODE strict=$STRICT dry-run=$DRY"
        echo "=============================================================="
        echo "[ENV] distro=$DISTRO_NAME id=$DISTRO_ID like=$DISTRO_LIKE biglinux=$IS_BIGLINUX immutable=$IMMUTABLE"
        echo "[ENV] desktop=$DESKTOP session=$SESSION kernel=$(uname -r) user=$(id -un) home=$HOME"
        echo "[ENV] tools: pkexec=$(have pkexec && echo y || echo n) zenity=$(have zenity && echo y || echo n) notify-send=$(have notify-send && echo y || echo n) python3=$(have python3 && echo y || echo n) fc-match=$(fc-match --version 2>&1 | head -n1)"
        echo "--------------------- AI PATCH LEDGER (past -> present) ---------------------"
        printf '%s\n' "${PATCH_LEDGER[@]}"
        echo "-----------------------------------------------------------------------------"
    } >> "$LOG_FILE"
}

for t in fc-scan fc-match fc-list fc-cache; do
    have "$t" || { echo "Missing '$t' - install the fontconfig package. / Thiếu '$t' - hãy cài gói fontconfig." >&2; exit 1; }
done
write_header
start_logger

# ------------------------------ extraction -----------------------------------
SEVENZ=""
find_7z() { for c in 7z 7zz 7za; do have "$c" && { SEVENZ="$c"; return 0; }; done; return 1; }
ensure_7z() { find_7z && return 0; confirm "7z is missing. Install it now?" "Thiếu 7z. Cài ngay?" && pkg_install 7z && find_7z; }
extract_archive() {   # $1 archive, $2 destination
    local a="$1" out="$2" mime rc; mkdir -p "$out"
    mime="$(file --mime-type -b -- "$a" 2>/dev/null)"
    case "$mime" in
        application/zip)
            if have unzip; then unzip -q -o -- "$a" -d "$out" >> "$LOG_FILE" 2>&1; rc=$?; [ "$rc" -le 1 ] && return 0; fi
            ensure_7z && "$SEVENZ" x -y -o"$out" -- "$a" >/dev/null ;;
        application/x-7z-compressed) ensure_7z && "$SEVENZ" x -y -o"$out" -- "$a" >/dev/null ;;
        application/vnd.rar|application/x-rar)
            if have unrar; then unrar x -o+ -idq -- "$a" "$out/"; else ensure_7z && "$SEVENZ" x -y -o"$out" -- "$a" >/dev/null; fi ;;
        application/x-tar|application/gzip|application/x-gzip|application/x-xz|application/x-bzip2) tar -xf "$a" -C "$out" ;;
        *) return 2 ;;
    esac
}

# ------------------------------ static audit ---------------------------------
write_auditor() {
cat > "$WORK/audit_font.py" << 'PYEOF'
#!/usr/bin/env python3
"""Static font audit (stdlib only). Usage: audit_font.py FILE [FILE...]
Prints one TSV line per file:  path  VERDICT  reasons  family  style  psname
VERDICT: OK | NOTE (cosmetic/legacy, safe to install) | ISOLATE (proven hazard) | REJECT (broken)
"""
import re
import struct
import sys

DECOR_WORDS = re.compile(
    r"(script|brush|handwrit|calligra|thuphap|graffiti|ornament|dingbat|swash|stencil|"
    r"cartoon|heart|love|chops|wedgie|whimsy|youngblood|zoink|doodle|tcvn|"
    r"(?<![a-z])s?vn|(?<![a-z])tmc)",
    re.I,
)


def u16(b, o): return struct.unpack_from(">H", b, o)[0]
def i16(b, o): return struct.unpack_from(">h", b, o)[0]
def u32(b, o): return struct.unpack_from(">I", b, o)[0]


def tables(b):
    base = 0
    if b[:4] in (b"ttcf", b"OTTO", b"\x00\x01\x00\x00", b"true"):
        if b[:4] == b"ttcf":
            base = u32(b, 12)
    else:
        raise ValueError("not an sfnt font")
    n = u16(b, base + 4)
    out = {}
    for i in range(n):
        o = base + 12 + 16 * i
        tag = b[o:o + 4].decode("latin1")
        out[tag] = (u32(b, o + 8), u32(b, o + 12))
    return out


def get_name(b, t):
    if "name" not in t:
        return "", "", ""
    off, _ = t["name"]
    count, strofs = u16(b, off + 2), u16(b, off + 4)
    found = {}
    for i in range(count):
        r = off + 6 + 12 * i
        pid, eid, lid, nid, ln, so = (u16(b, r + k) for k in range(0, 12, 2))
        raw = b[off + strofs + so: off + strofs + so + ln]
        try:
            s = raw.decode("utf-16-be") if pid in (0, 3) else raw.decode("mac_roman")
        except Exception:
            continue
        pri = 2 if (pid == 3 and lid == 0x409) else 1 if pid == 1 else 0
        if nid not in found or pri > found[nid][0]:
            found[nid] = (pri, s)
    g = lambda n: found.get(n, (0, ""))[1]
    return g(16) or g(1), g(17) or g(2), g(6)


PROTECTED = {
    "arial", "arialmt", "helvetica", "helveticaneue", "timesnewroman", "timesnewromanps", "times", "couriernew",
    "courier", "verdana", "tahoma", "segoeui", "calibri", "cambria", "georgia", "trebuchetms", "roboto",
    "notosans", "notoserif", "notosansmono", "dejavusans", "dejavuserif", "liberationsans", "liberationserif",
    "ubuntu", "cantarell", "inter", "sansserif", "serif", "monospace", "systemui", "lato", "montserrat",
    "opensans", "sourcesanspro", "firasans", "oswald", "comicsansms", "impact", "consolas", "lucidagrande",
    "lucidaconsole", "palatinolinotype", "garamond", "candara", "corbel", "constantia", "segoeuisymbol",
    "sfprodisplay", "sfprotext", "blinkmacsystemfont", "applesystem", "noto", "notosanscjk", "dejavusansmono",
    "liberationmono", "freesans", "freeserif", "freemono", "nimbussans", "nimbusroman", "tahomabold", "arialblack",
}


def norm(s):
    return re.sub(r"[\s_,\-]", "", s.lower())


def all_family_names(b, t):
    """Every family-ish name record (IDs 1, 16, 21) on every platform/language.
    fontconfig indexes ALL of them, so a font can pose as another family."""
    out = set()
    if "name" not in t:
        return out
    off, _ = t["name"]
    count, strofs = u16(b, off + 2), u16(b, off + 4)
    for i in range(count):
        r = off + 6 + 12 * i
        pid, eid, lid, nid, ln, so = (u16(b, r + k) for k in range(0, 12, 2))
        if nid not in (1, 16, 21):
            continue
        raw = b[off + strofs + so: off + strofs + so + ln]
        try:
            out.add((raw.decode("utf-16-be") if pid in (0, 3) else raw.decode("mac_roman")).strip())
        except Exception:
            pass
    return out


def cmap_info(b, t):
    """Return (set_of_codepoints, is_symbol_only)."""
    if "cmap" not in t:
        return set(), False
    off, _ = t["cmap"]
    n = u16(b, off + 2)
    cps, has_unicode, has_symbol, has_unicode_alt = set(), False, False, False
    for i in range(n):
        pid, eid, so = u16(b, off + 4 + 8 * i), u16(b, off + 6 + 8 * i), u32(b, off + 8 + 8 * i)
        if pid == 3 and eid == 0:
            has_symbol = True
        elif pid == 3 and eid in (1, 10):
            has_unicode = True
        elif pid == 0:
            has_unicode_alt = True
        else:
            continue
        s = off + so
        fmt = u16(b, s)
        try:
            if fmt == 4:
                segx2 = u16(b, s + 6)
                seg = segx2 // 2
                ends = s + 14
                starts = ends + segx2 + 2
                for k in range(seg):
                    e, st = u16(b, ends + 2 * k), u16(b, starts + 2 * k)
                    if st <= e and e - st < 0x10000:
                        cps.update(range(st, e + 1))
            elif fmt == 12:
                ng = u32(b, s + 12)
                for k in range(min(ng, 20000)):
                    st, e = u32(b, s + 16 + 12 * k), u32(b, s + 20 + 12 * k)
                    if e - st < 0x20000:
                        cps.update(range(st, e + 1))
            elif fmt == 6:
                first, cnt = u16(b, s + 6), u16(b, s + 8)
                cps.update(range(first, first + cnt))
            elif fmt == 0:
                cps.update(range(256))
        except struct.error:
            pass
    if has_symbol and not has_unicode:
        # symbol cmaps live in F000-F0FF; fold down to the low range
        cps = {c - 0xF000 if 0xF000 <= c <= 0xF0FF else c for c in cps}
        return cps, True
    return cps, False


def audit(path):
    b = open(path, "rb").read()
    t = tables(b)
    for need in ("cmap", "head", "name"):
        if need not in t:
            return "REJECT", f"missing_{need}", "", "", ""
    fam, style, ps = get_name(b, t)
    cps, symbol = cmap_info(b, t)
    hard, soft = [], []
    own = {norm(fam)} | {norm(x) for x in (get_name(b, t)[0],)}
    posing = sorted({x for x in all_family_names(b, t) if norm(x) in PROTECTED and norm(x) not in own})
    if posing:
        hard.append("spoofs_system_family(" + "/".join(posing) + ")")
    else:
        fams = {norm(x) for x in all_family_names(b, t) if norm(x)}
        p = norm(fam)
        odd = [x for x in fams if p and not (x in p or p in x)]
        if odd:
            soft.append("alias_family_conflict")

    if not cps:
        return "REJECT", "empty_cmap", fam, style, ps
    if symbol:
        soft.append("legacy_symbol_encoding(VNI/VN)")
    need = set(range(0x41, 0x5B)) | set(range(0x61, 0x7B)) | set(range(0x30, 0x3A)) | {0x20}
    missing = len(need - cps)
    if missing and not symbol:
        soft.append(f"incomplete_latin(-{missing})")

    if "OS/2" in t:
        o = t["OS/2"][0]
        panose = b[o + 32] if o + 33 <= len(b) else 0
        if panose in (3, 4, 5):
            soft.append({3: "panose_handwritten", 4: "panose_decorative", 5: "panose_symbol"}[panose])
    if "hhea" in t:
        h = t["hhea"][0]
        upem = u16(b, t["head"][0] + 18) or 1000
        line = (i16(b, h + 4) - i16(b, h + 6) + i16(b, h + 8)) / upem
        if line > 2.2 or line < 0.85:
            soft.append(f"abnormal_line_height({line:.2f}em)")

    if DECOR_WORDS.search(fam + " " + path.rsplit("/", 1)[-1]):
        soft.append("decorative_or_legacy_name")
    if len(b) > 8_000_000:
        soft.append(f"huge_file({len(b)//1_000_000}MB)")

    if hard:
        return "ISOLATE", ",".join(hard + soft), fam, style, ps
    return ("NOTE" if soft else "OK"), ",".join(soft), fam, style, ps


def main():
    for p in sys.argv[1:]:
        try:
            v, r, fam, sty, ps = audit(p)
        except Exception as e:  # corrupt / truncated file
            v, r, fam, sty, ps = "REJECT", f"unreadable({type(e).__name__})", "", "", ""
        clean = lambda s: s.replace("\t", " ").replace("\n", " ")
        print("\t".join([p, v, r or "-", clean(fam) or "-", clean(sty) or "-", clean(ps) or "-"]))


if __name__ == "__main__":
    main()
PYEOF
}
# audit_files FILE... -> $WORK/audit.tsv (path, OK|NOTE|ISOLATE|REJECT, reasons, family, style, psname)
audit_files() {
    : > "$WORK/audit.tsv"; [ "$#" -eq 0 ] && return 0
    if have python3; then
        write_auditor
        printf '%s\0' "$@" | xargs -0 python3 "$WORK/audit_font.py" >> "$WORK/audit.tsv" 2>> "$LOG_FILE"
    else
        warn "python3 not found: structural audit skipped, behavioural check still runs." "Không có python3: bỏ qua kiểm tra cấu trúc, vẫn kiểm tra hành vi."
        printf '%s\0' "$@" | xargs -0 fc-scan --format '%{file}\tOK\t-\t%{family[0]}\t%{style[0]}\t%{postscriptname}\n' >> "$WORK/audit.tsv" 2>> "$LOG_FILE"
    fi
    printf '%s\0' "$@" | xargs -0 fc-scan --format '%{file}\n' 2>/dev/null | sort -u > "$WORK/readable.txt"
    awk -F'\t' 'NR==FNR{ok[$0]=1; next} { if(!($1 in ok) && $2!="REJECT"){ $2="REJECT"; $3="freetype_cannot_open" } print $1"\t"$2"\t"$3"\t"$4"\t"$5"\t"$6 }' \
        "$WORK/readable.txt" "$WORK/audit.tsv" > "$WORK/audit2.tsv" && mv "$WORK/audit2.tsv" "$WORK/audit.tsv"
}

# ------------------------------ behavioural canary ----------------------------
# Simulates how browsers ask fontconfig. A font that outranks the system fonts for a name nobody asked it for
# would hijack the interface. / Mô phỏng cách trình duyệt hỏi fontconfig; font chiếm chỗ font hệ thống bị cách ly.
CANARY_QUERIES=(
    "sans-serif" "serif" "monospace" "system-ui"
    "Arial" "Helvetica" "Times New Roman" "Courier New" "Segoe UI" "Roboto" "Noto Sans" "Inter" "Verdana" "Tahoma" "Calibri" "Georgia"
    "sans-serif:lang=vi" "serif:lang=vi" "monospace:lang=vi" "Arial:lang=vi"
    "sans-serif:charset=1ea1" "sans-serif:charset=1ef9" "sans-serif:charset=20ab"
    "sans-serif:charset=2022" "sans-serif:charset=2713" "sans-serif:charset=a9"
)
BASELINE_BROKEN=0
HIJACK_FILE="$(mktemp -u)"
find_hijackers() {   # CONFIG(or empty) ERE_OF_UNTRUSTED_PATHS -> HIJACK_FILE (path \t query)
    local cfg="$1" re="$2" q fam file ffam trusted depth
    : > "$HIJACK_FILE"; BASELINE_BROKEN=0
    declare -A seen=()
    local envp=(env); [ -n "$cfg" ] && envp=(env "FONTCONFIG_FILE=$cfg")
    for q in "${CANARY_QUERIES[@]}"; do
        fam="${q%%:*}"; trusted=0; depth=0
        while IFS=$'\t' read -r file ffam; do
            [ -z "$file" ] && continue
            if [[ "$file" =~ $re ]]; then
                [ "$(norm "$ffam")" = "$(norm "$fam")" ] && continue     # explicitly requested family: legitimate
                depth=$((depth + 1))
                [ -z "${seen[$file]+x}" ] && { seen[$file]=1; printf '%s\t%s\n' "$file" "$q" >> "$HIJACK_FILE"; }
            else trusted=1; break; fi
        done < <("${envp[@]}" fc-match -s -a --format '%{file}\t%{family[0]}\n' "$q" 2>/dev/null)
        if [ "$trusted" -eq 0 ] || [ "$depth" -gt 25 ]; then BASELINE_BROKEN=1; fi
    done
}
esc_re() { printf '%s' "$1" | sed 's/[.[\*^$()+?{}|]/\\&/g'; }
user_roots_re() { local r="" p; for p in "${USER_FONT_ROOTS[@]}"; do r="$r|$(esc_re "$p")"; done; printf '^(%s)/' "${r#|}"; }

show_live_resolution() {
    local q out
    info "Fonts that answer generic requests now:" "Font đang trả lời các tên chung:"
    for q in "sans-serif" "serif" "monospace" "system-ui" "Arial" "Times New Roman" "sans-serif:lang=vi"; do
        out="$(fc-match --format '%{family[0]} (%{file})' "$q" 2>/dev/null)"
        printf '  %-22s -> %s\n' "$q" "$out"; log "  canary $q -> $out"
    done
}

# ------------------------------ isolation / design wrapper --------------------
isolate_file() {   # move an installed file to the isolated folder / chuyển file đã cài vào thư mục cách ly
    local f="$1" why="$2" base dest; base="$(basename "$f")"; dest="$ISOLATED_DIR/$base"
    [ -e "$dest" ] && dest="$ISOLATED_DIR/${base%.*}.$(sha1sum "$f" | cut -c1-6).${base##*.}"
    mkdir -p "$ISOLATED_DIR"; mv -- "$f" "$dest" || { err "Cannot isolate $base" "Không thể cách ly $base"; return 1; }
    printf '%s\t%s\t%s\n' "$(date -Is)" "$base" "$why" >> "$ISOLATED_DIR/manifest.tsv"
}
setup_design_wrapper() {
    mkdir -p "$(dirname "$DESIGN_CONF")" "$(dirname "$WRAPPER")" "$XDG_CACHE/fontconfig-design"
    cat > "$DESIGN_CONF" << XML
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<!-- Created by install_fonts_universal.sh - used only through 'with-design-fonts' / chỉ dùng qua 'with-design-fonts' -->
<fontconfig>
    <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
    <dir>$ISOLATED_DIR</dir>
    <cachedir>$XDG_CACHE/fontconfig-design</cachedir>
</fontconfig>
XML
    cat > "$WRAPPER" << SH
#!/usr/bin/env bash
# Run one app with the isolated fonts / Chạy một ứng dụng với font cách ly
[ \$# -eq 0 ] && { echo "Usage: with-design-fonts <command> [args...]"; exit 1; }
fc-cache -f "$ISOLATED_DIR" >/dev/null 2>&1
FONTCONFIG_FILE="$DESIGN_CONF" exec "\$@"
SH
    chmod +x "$WRAPPER"
}
write_managed_conf() {
    mkdir -p "$(dirname "$MANAGED_CONF")"
    cat > "$MANAGED_CONF" << 'XML'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<!-- install_fonts_universal.sh v3: ADDS preferences only; never replaces the default lists. -->
<fontconfig>
    <alias><family>sans-serif</family><prefer><family>Noto Sans</family><family>DejaVu Sans</family><family>Liberation Sans</family></prefer></alias>
    <alias><family>serif</family><prefer><family>Noto Serif</family><family>DejaVu Serif</family><family>Liberation Serif</family></prefer></alias>
    <alias><family>monospace</family><prefer><family>Noto Sans Mono</family><family>DejaVu Sans Mono</family><family>Liberation Mono</family></prefer></alias>
</fontconfig>
XML
}
migrate_v1() {   # clean traces of the old script / dọn dấu vết của script cũ
    local c="$XDG_CONF/fontconfig/fonts.conf"
    if [ -f "$c" ] && grep -q 'fonts_design' "$c" && grep -q 'mode="assign"' "$c"; then
        cp -- "$c" "$c.v1.bak" && rm -f -- "$c"
        info "Old fonts.conf removed (backup: $c.v1.bak)." "Đã gỡ fonts.conf cũ (sao lưu: $c.v1.bak)."
    fi
    if [ -d "$HOME/.fonts_design" ]; then
        local f n=0
        while IFS= read -r -d '' f; do isolate_file "$f" "old_design_dir_was_globally_registered"; n=$((n + 1)); done < <(find "$HOME/.fonts_design" -type f -print0)
        rmdir "$HOME/.fonts_design" 2>/dev/null
        [ "$n" -gt 0 ] && info "Moved $n fonts out of ~/.fonts_design." "Đã chuyển $n font khỏi ~/.fonts_design."
    fi
}

# ------------------------------ Brave ----------------------------------------
BRAVE_PREF="$XDG_CONF/BraveSoftware/Brave-Browser/Default/Preferences"
brave_report() {
    [ -f "$BRAVE_PREF" ] && have python3 || return 0
    python3 - "$BRAVE_PREF" << 'PY'
import json, sys
try: d = json.load(open(sys.argv[1]))
except Exception as e: print(f"  [!] Cannot read Brave Preferences / Không đọc được Preferences: {e}"); sys.exit(0)
f = d.get("webkit", {}).get("webprefs", {}).get("fonts")
print("  Brave custom fonts / Font tuỳ chỉnh của Brave:", "none (default) / không có" if not f else "")
if f:
    for k, v in f.items(): print(f"    {k}: {v}")
    print("  -> run --fix-brave-prefs / chạy --fix-brave-prefs")
PY
}
brave_fix() {
    [ -f "$BRAVE_PREF" ] || { info "Brave Preferences not found." "Không tìm thấy Preferences của Brave."; return 1; }
    have python3 || { err "python3 is required." "Cần python3."; return 1; }
    if pgrep -x brave >/dev/null 2>&1; then warn "Close Brave first (the script no longer kills processes)." "Hãy đóng Brave trước (script không còn tự tắt tiến trình)."; return 1; fi
    cp -- "$BRAVE_PREF" "$BRAVE_PREF.bak.$(date +%s)"
    python3 - "$BRAVE_PREF" << 'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
removed = d.get("webkit", {}).get("webprefs", {}).pop("fonts", None)
json.dump(d, open(p, "w"), separators=(",", ":"))
print("Custom font settings removed / Đã xoá cấu hình font:" if removed else "No custom font settings / Không có cấu hình font.", removed or "")
PY
}

# ------------------------------ clean / uninstall ------------------------------
do_clean() {
    local n=0
    while IFS= read -r d; do rm -rf "$d"; n=$((n + 1)); done < <(find "${TMPDIR:-/tmp}" -maxdepth 1 \( -name 'font_installer_*' -o -name 'font_doctor_*' \) -mmin +30 2>/dev/null)
    [ -f "$STATE/logger.pid" ] && ! logger_alive && rm -f "$STATE/logger.pid"
    # keep only the newest Brave Preferences backup and drop v1 backups older than 30 days
    ls -1t "$BRAVE_PREF".bak.* 2>/dev/null | tail -n +2 | while IFS= read -r f; do rm -f "$f"; done
    find "$XDG_CONF/fontconfig" -maxdepth 1 -name '*.v1.bak' -mtime +30 -delete 2>/dev/null
    info "Cleanup finished ($n stale temp folders removed)." "Dọn dẹp xong (đã xoá $n thư mục tạm cũ)."
}
do_uninstall() {
    info "Uninstall: removing what this script added." "Gỡ cài đặt: xoá những gì script đã thêm."
    stop_logger
    local nf=0; [ -d "$FONT_DIR" ] && nf="$(find "$FONT_DIR" -type f | wc -l)"
    if [ -d "$FONT_DIR" ] && confirm "Remove $nf fonts installed by this script ($FONT_DIR)?" "Xoá $nf font đã cài bởi script ($FONT_DIR)?"; then
        [ "$DRY" -eq 0 ] && rm -rf -- "$FONT_DIR"; info "Installed fonts removed." "Đã xoá font đã cài."
    fi
    if [ -d "$ISOLATED_DIR" ] && confirm "Also delete the isolated fonts folder ($ISOLATED_DIR)?" "Xoá luôn thư mục font cách ly ($ISOLATED_DIR)?"; then
        [ "$DRY" -eq 0 ] && rm -rf -- "$ISOLATED_DIR"
    fi
    if [ "$DRY" -eq 0 ]; then
        rm -f -- "$MANAGED_CONF" "$DESIGN_CONF" "$WRAPPER"; rm -rf -- "$XDG_CACHE/fontconfig-design"
        fc-cache -f >/dev/null 2>&1
    fi
    do_clean
    notify -f done "Uninstall complete" "Đã gỡ cài đặt xong"
    show_result info "Uninstall complete." "Đã gỡ cài đặt xong." "Log: $LOG_FILE"
}

# ============================= MODES ==========================================
case "$MODE" in
    brave)       brave_fix; exit $? ;;
    stop-logger) stop_logger; exit 0 ;;
    clean)       do_clean; exit 0 ;;
    uninstall)   WORK="$(mktemp -d "${TMPDIR:-/tmp}/font_installer_XXXXXX")"; do_uninstall; exit 0 ;;
esac

if [ "$MODE" = "diagnose" ]; then
    WORK="$(mktemp -d "${TMPDIR:-/tmp}/font_doctor_XXXXXX")"
    info "Font doctor" "Chẩn đoán font"
    show_live_resolution
    mapfile -d '' -t INSTALLED < <(find "${USER_FONT_ROOTS[@]}" -type f \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.ttc' -o -iname '*.otc' \) -print0 2>/dev/null)
    info "User-installed fonts: ${#INSTALLED[@]}" "Font người dùng đã cài: ${#INSTALLED[@]}"
    [ -f "$XDG_CONF/fontconfig/fonts.conf" ] && grep -q 'fonts_design' "$XDG_CONF/fontconfig/fonts.conf" \
        && warn "Old fonts.conf registers ~/.fonts_design globally and overrides sans-serif/serif/monospace." "fonts.conf cũ đăng ký ~/.fonts_design toàn hệ thống và ghi đè sans-serif/serif/monospace."
    find_hijackers "${FONTCONFIG_FILE:-}" "$(user_roots_re)"
    nh=$(wc -l < "$HIJACK_FILE")
    info "Fonts hijacking the interface: $nh" "Font chiếm quyền giao diện: $nh"
    awk -F'\t' '{print "  " $1 "  <-  asked for: " $2}' "$HIJACK_FILE" | head -n 20
    [ "$BASELINE_BROKEN" -eq 1 ] && warn "Baseline fonts (Noto/DejaVu/Liberation) are missing or outranked: likely root cause." "Thiếu/bị lấn át bộ font nền (Noto/DejaVu/Liberation): nhiều khả năng là nguyên nhân gốc."
    if [ "${#INSTALLED[@]}" -gt 0 ]; then
        audit_files "${INSTALLED[@]}"
        info "Structural audit: $(cut -f2 "$WORK/audit.tsv" | sort | uniq -c | tr '\n' ' ')" "Kiểm tra cấu trúc: (OK/NOTE/ISOLATE/REJECT)"
    fi
    info "Brave:" "Brave:"; brave_report
    if [ "$FIX" -eq 1 ]; then
        if [ "$BASELINE_BROKEN" -eq 1 ] && ! fc-list : family | grep -qiE '^(noto sans|dejavu sans|liberation sans)'; then
            confirm "Install baseline fonts (Noto/DejaVu/Liberation)?" "Cài bộ font nền (Noto/DejaVu/Liberation)?" && pkg_install baseline-fonts
        fi
        declare -A MOVE=()
        while IFS=$'\t' read -r f q; do MOVE["$f"]="hijacks_generic_fallback($q)"; done < "$HIJACK_FILE"
        while IFS=$'\t' read -r f v r _; do
            { [ "$v" = "ISOLATE" ] || { [ "$STRICT" -eq 1 ] && [ "$v" = "NOTE" ]; }; } && [ -z "${MOVE[$f]+x}" ] && MOVE["$f"]="$r"
        done < "$WORK/audit.tsv"
        if [ "${#MOVE[@]}" -eq 0 ]; then info "Nothing to fix." "Không có gì cần sửa."
        elif confirm "Isolate ${#MOVE[@]} harmful font(s)? Reversible (folder: $ISOLATED_DIR)." "Cách ly ${#MOVE[@]} font gây hại? Có thể hoàn tác (thư mục: $ISOLATED_DIR)."; then
            if [ "$DRY" -eq 0 ]; then
                for f in "${!MOVE[@]}"; do [ -f "$f" ] && { isolate_file "$f" "${MOVE[$f]}"; log "[ISOLATED] $(basename "$f") <- ${MOVE[$f]}"; }; done
                migrate_v1; write_managed_conf; setup_design_wrapper; fc-cache -f >/dev/null 2>&1
                info "Isolated ${#MOVE[@]} font(s). Please restart your browser." "Đã cách ly ${#MOVE[@]} font. Hãy khởi động lại trình duyệt."
                show_live_resolution
            else info "[dry-run] no changes made." "[chạy thử] không thay đổi gì."; fi
        fi
    else info "Re-run with --fix to repair." "Chạy lại với --fix để sửa."; fi
    notify -f done "Diagnosis finished: $ERR_COUNT error(s), $WARN_COUNT warning(s)" "Chẩn đoán xong: $ERR_COUNT lỗi, $WARN_COUNT cảnh báo"
    show_result info "Diagnosis finished: $ERR_COUNT error(s), $WARN_COUNT warning(s)." "Chẩn đoán xong: $ERR_COUNT lỗi, $WARN_COUNT cảnh báo." "Log: $LOG_FILE"
    info "Log: $LOG_FILE" "Nhật ký: $LOG_FILE"
    exit 0
fi

# ============================= INSTALL ========================================
WORK="$(mktemp -d "${TMPDIR:-/tmp}/font_installer_XXXXXX")"

if [ -z "$INPUT" ] && gui; then
    kind="$(zenity --list --radiolist --title="Font Installer / Trình cài font" --text="Choose the source type\nChọn loại nguồn" \
            --column="" --column="Type / Loại" TRUE "Archive file / File nén" FALSE "Folder / Thư mục" 2>/dev/null)" || exit 1
    if [[ "$kind" == Folder* ]]; then INPUT="$(zenity --file-selection --directory --title="Choose the font folder / Chọn thư mục font" 2>/dev/null)"
    else INPUT="$(zenity --file-selection --title="Choose the font archive / Chọn file nén font" 2>/dev/null)"; fi
fi
[ -n "$INPUT" ] && [ -e "$INPUT" ] || { echo "A valid path is required (see --help). / Cần đường dẫn hợp lệ (xem --help)." >&2; exit 1; }

progress_start "Installing fonts" "Đang cài font"
notify start "Font installation started - please wait" "Bắt đầu cài font - vui lòng chờ"
progress 3 "Reading source" "Đọc nguồn"
SRC="$WORK/src"; mkdir -p "$SRC"
if [ -d "$INPUT" ]; then cp -r -- "$INPUT"/. "$SRC"/; else cp -- "$INPUT" "$SRC"/; fi

progress 8 "Extracting archives" "Giải nén"
for _pass in 1 2 3; do
    found=0
    while IFS= read -r -d '' f; do
        case "${f,,}" in *.ttf|*.otf|*.ttc|*.otc) continue ;; esac
        case "$(file --mime-type -b -- "$f" 2>/dev/null)" in
            application/zip|application/x-7z-compressed|application/vnd.rar|application/x-rar|application/x-tar|application/gzip|application/x-gzip|application/x-xz|application/x-bzip2)
                if extract_archive "$f" "$f.__x"; then rm -f -- "$f"; found=1
                else err "Cannot extract: $(basename "$f")" "Không giải nén được: $(basename "$f")"; fi ;;
        esac
    done < <(find "$SRC" -type f -print0)
    [ "$found" -eq 0 ] && break
done
mapfile -d '' -t CANDS < <(find "$SRC" -type f \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.ttc' -o -iname '*.otc' \) -print0)
if [ "${#CANDS[@]}" -eq 0 ]; then
    progress_end; err "No font files found." "Không tìm thấy font nào."
    notify -f done "No fonts found in the selected source" "Không tìm thấy font trong nguồn đã chọn"
    show_result error "No fonts found in the selected source." "Không tìm thấy font trong nguồn đã chọn."; exit 1
fi
info "Found ${#CANDS[@]} font file(s)." "Tìm thấy ${#CANDS[@]} file font."

progress 15 "Checking font files (structure)" "Kiểm tra cấu trúc font"
audit_files "${CANDS[@]}"
fc-list --format '%{postscriptname}\n' 2>/dev/null | sort -u > "$WORK/installed_ps.txt"
declare -A VERDICT=() WHY=() SEEN_HASH=()
n_dup=0
# content hashes of fonts we already installed/isolated -> re-running never creates duplicates / chạy lại không tạo bản trùng
: > "$WORK/installed_hashes.txt"
find "$FONT_DIR" "$ISOLATED_DIR" -type f \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.ttc' -o -iname '*.otc' \) -print0 2>/dev/null \
    | xargs -0 -r sha1sum 2>/dev/null | cut -c1-40 | sort -u > "$WORK/installed_hashes.txt"
while IFS=$'\t' read -r path verdict reasons fam sty ps; do
    [ "$ps" = "-" ] && ps=""
    h="$(sha1sum -- "$path" | cut -c1-40)"
    if [ -n "${SEEN_HASH[$h]+x}" ] || grep -Fxq "$h" "$WORK/installed_hashes.txt"; then n_dup=$((n_dup + 1)); continue; fi; SEEN_HASH[$h]=1
    if [ -n "$ps" ] && grep -Fxq -- "$ps" "$WORK/installed_ps.txt"; then
        n_dup=$((n_dup + 1)); log "[SKIP already installed] $(basename "$path") ($ps)"; continue
    fi
    [ "$STRICT" -eq 1 ] && [ "$verdict" = "NOTE" ] && verdict="ISOLATE"
    VERDICT["$path"]="$verdict"; WHY["$path"]="$reasons"
done < "$WORK/audit.tsv"

progress 30 "Safety test before installing (simulating your browser)" "Kiểm tra an toàn trước khi cài (mô phỏng trình duyệt)"
PRE="$WORK/preflight"; mkdir -p "$PRE/fonts" "$PRE/cache"
declare -A STAGED=()
for p in "${!VERDICT[@]}"; do
    case "${VERDICT[$p]}" in OK|NOTE) ;; *) continue ;; esac
    d="$PRE/fonts/$(sha1sum -- "$p" | cut -c1-8)_$(basename "$p")"
    ln -s -- "$p" "$d" 2>/dev/null || cp -- "$p" "$d"; STAGED["$d"]="$p"
done
cat > "$PRE/fonts.conf" << XML
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
    <include ignore_missing="yes">$BASE_FC</include>
    <dir>$PRE/fonts</dir>
    <cachedir>$PRE/cache</cachedir>
</fontconfig>
XML
pre_re="^$(esc_re "$PRE/fonts")/"
baseline_offered=0
for round in 1 2 3 4 5; do
    progress $((30 + round * 4)) "Safety test, round $round" "Kiểm tra an toàn, vòng $round"
    FONTCONFIG_FILE="$PRE/fonts.conf" fc-cache -f >/dev/null 2>&1
    find_hijackers "$PRE/fonts.conf" "$pre_re"
    if [ "$BASELINE_BROKEN" -eq 1 ] && [ "$baseline_offered" -eq 0 ]; then
        baseline_offered=1
        warn "Baseline fonts are missing: unknown fonts could take over the interface." "Thiếu bộ font nền: font lạ có thể chiếm giao diện."
        if confirm "Install baseline fonts (Noto, DejaVu, Liberation) to fix the root cause?" "Cài bộ font nền (Noto, DejaVu, Liberation) để xử lý tận gốc?"; then
            pkg_install baseline-fonts && { fc-cache -f >/dev/null 2>&1; continue; }
        fi
    fi
    [ -s "$HIJACK_FILE" ] || break
    [ "$BASELINE_BROKEN" -eq 1 ] && break
    while IFS=$'\t' read -r hp q; do
        orig="${STAGED[$hp]:-}"; [ -n "$orig" ] || continue
        VERDICT["$orig"]="ISOLATE"; WHY["$orig"]="hijacks_generic_fallback($q)"; rm -f -- "$hp"
    done < "$HIJACK_FILE"
done
if [ "$BASELINE_BROKEN" -eq 1 ]; then
    warn "Cannot guarantee safety without baseline fonts: SAFE MODE, nothing is installed globally." "Không thể đảm bảo an toàn khi thiếu font nền: CHẾ ĐỘ AN TOÀN, không cài font nào toàn hệ thống."
    for p in "${!VERDICT[@]}"; do case "${VERDICT[$p]}" in OK|NOTE) VERDICT["$p"]="ISOLATE"; WHY["$p"]="no_safe_baseline_fonts" ;; esac; done
fi

n_std=0; n_iso=0; n_rej=0; n_cleaned=0; n_total=${#VERDICT[@]}; i=0
[ "$DRY" -eq 0 ] && mkdir -p "$FONT_DIR" "$ISOLATED_DIR"
for p in "${!VERDICT[@]}"; do
    i=$((i + 1)); [ $((i % 40)) -eq 0 ] && progress $((55 + i * 30 / (n_total + 1))) "Installing fonts ($i/$n_total)" "Đang cài font ($i/$n_total)"
    base="$(basename "$p")"
    case "${VERDICT[$p]}" in
        OK|NOTE)
            if [ "$DRY" -eq 0 ]; then
                dest="$FONT_DIR/$base"; [ -e "$dest" ] && dest="$FONT_DIR/${base%.*}.$(sha1sum "$p" | cut -c1-6).${base##*.}"
                cp -- "$p" "$dest" || { err "Copy failed: $base" "Chép thất bại: $base"; continue; }
            fi
            log "[INSTALLED] $base ${WHY[$p]:+(note: ${WHY[$p]})}"; n_std=$((n_std + 1)) ;;
        ISOLATE)
            if [ "$DRY" -eq 0 ]; then
                dest="$ISOLATED_DIR/$base"; [ -e "$dest" ] && dest="$ISOLATED_DIR/${base%.*}.$(sha1sum "$p" | cut -c1-6).${base##*.}"
                cp -- "$p" "$dest" && printf '%s\t%s\t%s\n' "$(date -Is)" "$base" "${WHY[$p]}" >> "$ISOLATED_DIR/manifest.tsv"
            fi
            log "[ISOLATED] $base <- ${WHY[$p]}"; n_iso=$((n_iso + 1)) ;;
        REJECT) log "[REJECTED broken] $base <- ${WHY[$p]}"; n_rej=$((n_rej + 1)) ;;
    esac
done

progress 90 "Finalizing (font cache, safety re-check)" "Hoàn tất (cache font, kiểm tra lại)"
if [ "$DRY" -eq 0 ]; then
    migrate_v1; write_managed_conf; setup_design_wrapper
    fc-cache -f "$FONT_DIR" >> "$LOG_FILE" 2>&1 || err "fc-cache failed" "fc-cache thất bại"
    find_hijackers "${FONTCONFIG_FILE:-}" "$(user_roots_re)"
    if [ "$BASELINE_BROKEN" -eq 0 ] && [ -s "$HIJACK_FILE" ]; then
        while IFS=$'\t' read -r hp q; do
            [ -f "$hp" ] && { isolate_file "$hp" "hijacks_generic_fallback($q)"; log "[ISOLATED after install] $(basename "$hp") <- $q"; n_cleaned=$((n_cleaned + 1)); }
        done < "$HIJACK_FILE"
        fc-cache -f >/dev/null 2>&1
    fi
    show_live_resolution
fi
do_clean >/dev/null
progress 100 "Done" "Xong"; progress_end

info "Installed: $n_std | Isolated: $n_iso | Cleaned up: $n_cleaned | Broken: $n_rej | Already present: $n_dup | Errors: $ERR_COUNT" \
     "Đã cài: $n_std | Cách ly: $n_iso | Dọn từ lần cài cũ: $n_cleaned | Hỏng: $n_rej | Đã có: $n_dup | Lỗi: $ERR_COUNT"
err_txt=""
if [ "$ERR_COUNT" -gt 0 ]; then
    printf '  - %s\n' "${ERR_LIST[@]}"; printf '  - %s\n' "${ERR_LIST[@]}" >> "$LOG_FILE"
    err_txt="$(printf -- '- %s\n' "${ERR_LIST[@]:0:8}")"
fi
[ "$n_iso" -gt 0 ] && info "Isolated fonts stay usable per app: with-design-fonts <app>" "Font cách ly vẫn dùng được cho từng ứng dụng: with-design-fonts <ứng dụng>"
info "Log (overwritten on every run): $LOG_FILE" "Nhật ký (ghi đè mỗi lần chạy): $LOG_FILE"

if [ "$ERR_COUNT" -gt 0 ]; then
    kind=warning; head_en="Finished with $ERR_COUNT error(s)."; head_vi="Hoàn tất nhưng có $ERR_COUNT lỗi."
elif [ "$n_std" -eq 0 ] && [ "$n_cleaned" -eq 0 ] && [ "$n_dup" -gt 0 ]; then
    kind=info; head_en="Nothing new to install: $n_dup font(s) are already present."; head_vi="Không có gì mới để cài: $n_dup font đã có sẵn."
else
    kind=info; head_en="Fonts installed successfully."; head_vi="Cài font thành công."
fi
body="Installed / Đã cài: $n_std
Isolated (unsafe) / Cách ly (không an toàn): $n_iso
Cleaned from earlier installs / Dọn từ lần cài cũ: $n_cleaned
Already present / Đã có sẵn: $n_dup
Broken files / File hỏng: $n_rej
Errors / Lỗi: $ERR_COUNT${err_txt:+
$err_txt}

Restart your browser and office apps to apply.
Hãy khởi động lại trình duyệt và ứng dụng văn phòng để áp dụng.
Log: $LOG_FILE"
log "[RESULT] $head_en | $head_vi"
notify -f done "$head_en" "$head_vi"
show_result "$kind" "$head_en" "$head_vi" "$body"
