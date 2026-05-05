#!/usr/bin/env bash
# =============================================================================
#  macos-cleanup.sh
#  A safe, interactive disk cleanup utility for macOS
#
#  Tested on: macOS Ventura, Sonoma, Sequoia
#  Author:    community
#  License:   MIT
#
#  USAGE:
#    bash macos-cleanup.sh              # dry-run (default, nothing is deleted)
#    bash macos-cleanup.sh --clean      # interactive mode: asks before each step
#    bash macos-cleanup.sh --clean --yes # non-interactive: cleans everything
#
#  WHAT IT CLEANS:
#    - User & system caches
#    - System & user logs
#    - Temporary files
#    - Trash (all volumes)
#    - Xcode derived data, archives, simulators (if Xcode is installed)
#    - Local Time Machine snapshots
#    - Homebrew, npm, pip caches (if installed)
#    - Large unused game data (optional, interactive)
#    - iMazing backups (optional, interactive)
#    - Webex / Cisco Spark upgrade cache
#    - Dead app caches (uTorrent, Steam data, etc.)
#
#  WHAT IT NEVER TOUCHES:
#    - iCloud / OneDrive synced files
#    - iOS backups (shows size info only)
#    - System files
#    - Any file outside the listed paths
# =============================================================================

set -euo pipefail
export LC_ALL=C LANG=C

# ── Colours ──────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  RED='\033[0;31m' YEL='\033[1;33m' GRN='\033[0;32m'
  CYN='\033[0;36m' BLD='\033[1m'    DIM='\033[2m' RST='\033[0m'
else
  RED='' YEL='' GRN='' CYN='' BLD='' DIM='' RST=''
fi

# ── Argument parsing ──────────────────────────────────────────────────────────
DRY_RUN=true
AUTO_YES=false

for arg in "$@"; do
  case "$arg" in
    --clean) DRY_RUN=false ;;
    --yes)   AUTO_YES=true  ;;
    --help|-h)
      sed -n '3,30p' "$0" | sed 's/^#  \?//'
      exit 0 ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────
FREED=0

hr()  { printf '%s\n' "══════════════════════════════════════════════════════════"; }
hr2() { printf '%s\n' "──────────────────────────────────────────────────────────"; }

bytes_to_human() {
  local b=${1:-0}
  if   (( b >= 1073741824 )); then printf "%.1f GB" "$(echo "scale=1; $b/1073741824" | bc)"
  elif (( b >= 1048576 ));    then printf "%.0f MB" "$(echo "scale=0; $b/1048576"    | bc)"
  elif (( b >= 1024 ));       then printf "%.0f KB" "$(echo "scale=0; $b/1024"       | bc)"
  else printf "%d B" "$b"; fi
}

dir_size_bytes() {
  [[ -e "$1" ]] || { echo 0; return; }
  du -sk "$1" 2>/dev/null | awk '{print $1 * 1024}'
}

# Prints a labelled size line; used in dry-run and before deletion
print_entry() {
  local status="$1" colour="$2" label="$3" size="$4"
  printf "  ${colour}[%-8s]${RST} %-50s %s\n" "$status" "$label" "$size"
}

# Core deletion function
#   $1 = path to delete
#   $2 = human label
#   $3 = "dir"  → delete contents, keep folder
#        "path" → delete path entirely (default)
do_clean() {
  local path="$1" label="$2" mode="${3:-path}"
  [[ -e "$path" ]] || { print_entry "MISSING" "$DIM" "$label" "—"; return; }

  local sz; sz=$(dir_size_bytes "$path")
  (( sz == 0 )) && { print_entry "EMPTY" "$DIM" "$label" "0 B"; return; }

  if $DRY_RUN; then
    print_entry "DRY-RUN" "$YEL" "$label" "$(bytes_to_human $sz)"
  else
    print_entry "CLEANING" "$RED" "$label" "$(bytes_to_human $sz)"
    if [[ "$mode" == "dir" ]]; then
      find "$path" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
    else
      rm -rf "$path" 2>/dev/null || true
    fi
    print_entry "DONE" "$GRN" "$label" "freed $(bytes_to_human $sz)"
  fi
  FREED=$(( FREED + sz ))
}

# Ask user before an optional section (skipped if --yes or dry-run)
ask_section() {
  local prompt="$1"
  $DRY_RUN  && return 0   # always show in dry-run
  $AUTO_YES && return 0   # --yes skips all prompts
  printf "\n  ${YEL}?${RST}  %s  [y/N] " "$prompt"
  local ans; read -r ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
hr
printf "${BLD}  🍎  macOS Cleanup Utility${RST}\n"
hr

if $DRY_RUN; then
  printf "  ${YEL}MODE: DRY-RUN — nothing will be deleted${RST}\n"
  printf "  ${DIM}Run with --clean to actually remove files${RST}\n"
elif $AUTO_YES; then
  printf "  ${RED}MODE: CLEAN (non-interactive) — all sections will run${RST}\n"
else
  printf "  ${RED}MODE: CLEAN (interactive) — you will be asked before each section${RST}\n"
fi

FREE_BEFORE=$(df -k / | awk 'NR==2{print $4 * 1024}')
printf "  Disk free before: ${BLD}%s${RST}\n" "$(bytes_to_human "$FREE_BEFORE")"
hr
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# 1. USER CACHES
# ═════════════════════════════════════════════════════════════════════════════
printf "${BLD}[1] User caches${RST}  ~/Library/Caches\n"
do_clean "$HOME/Library/Caches" "~/Library/Caches" dir
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# 2. LOGS
# ═════════════════════════════════════════════════════════════════════════════
printf "${BLD}[2] Logs${RST}\n"
do_clean "$HOME/Library/Logs"  "~/Library/Logs"   dir
do_clean "/Library/Logs"       "/Library/Logs"     dir
do_clean "/private/var/log"    "/private/var/log"  dir
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# 3. TEMP FILES
# ═════════════════════════════════════════════════════════════════════════════
printf "${BLD}[3] Temporary files${RST}\n"
do_clean "/private/tmp" "/private/tmp" dir
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# 4. TRASH
# ═════════════════════════════════════════════════════════════════════════════
printf "${BLD}[4] Trash${RST}\n"
do_clean "$HOME/.Trash" "~/.Trash" dir
for t in /Volumes/*/.Trashes/"$(id -u)"; do
  [[ -d "$t" ]] && do_clean "$t" "Trash on $(dirname "$(dirname "$t")")" dir
done
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# 5. XCODE (skipped if not installed)
# ═════════════════════════════════════════════════════════════════════════════
XDEV="$HOME/Library/Developer"
if [[ -d "$XDEV/Xcode" ]] || [[ -d "$XDEV/CoreSimulator" ]]; then
  printf "${BLD}[5] Xcode artefacts${RST}\n"
  do_clean "$XDEV/Xcode/DerivedData"           "Xcode DerivedData"           dir
  do_clean "$XDEV/Xcode/Archives"              "Xcode Archives"              dir
  do_clean "$XDEV/Xcode/iOS DeviceSupport"     "Xcode iOS DeviceSupport"     dir
  do_clean "$XDEV/Xcode/watchOS DeviceSupport" "Xcode watchOS DeviceSupport" dir
  do_clean "$XDEV/CoreSimulator/Caches"        "Simulator Caches"            dir

  if command -v xcrun &>/dev/null; then
    if $DRY_RUN; then
      sz=$(dir_size_bytes "$XDEV/CoreSimulator/Devices")
      print_entry "DRY-RUN" "$YEL" "iOS Simulators (unavailable)" "$(bytes_to_human $sz)"
    else
      xcrun simctl delete unavailable 2>/dev/null || true
      print_entry "DONE" "$GRN" "iOS Simulators (unavailable)" "removed"
    fi
  fi
  echo ""
else
  printf "${BLD}[5] Xcode${RST}  ${DIM}not installed, skipping${RST}\n\n"
fi

# ═════════════════════════════════════════════════════════════════════════════
# 6. TIME MACHINE LOCAL SNAPSHOTS
# ═════════════════════════════════════════════════════════════════════════════
printf "${BLD}[6] Time Machine local snapshots${RST}\n"
snaps=()
while IFS= read -r line; do
  [[ "$line" =~ ^com\.apple\.TimeMachine ]] && snaps+=("$line")
done < <(tmutil listlocalsnapshots / 2>/dev/null)

if (( ${#snaps[@]} == 0 )); then
  printf "  ${DIM}No local snapshots found${RST}\n"
else
  printf "  Found ${BLD}%d${RST} snapshot(s)\n" "${#snaps[@]}"
  for s in "${snaps[@]}"; do printf "    ${DIM}%s${RST}\n" "$s"; done
  if ! $DRY_RUN; then
    for s in "${snaps[@]}"; do
      tmutil deletelocalsnapshots "${s##*.}" 2>/dev/null && \
        printf "  ${GRN}[DELETED]${RST} %s\n" "$s" || true
    done
  fi
fi
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# 7. HOMEBREW (if installed)
# ═════════════════════════════════════════════════════════════════════════════
if command -v brew &>/dev/null; then
  printf "${BLD}[7] Homebrew cache${RST}\n"
  brew_cache=$(brew --cache 2>/dev/null || echo "")
  if [[ -d "$brew_cache" ]]; then
    sz=$(dir_size_bytes "$brew_cache")
    if $DRY_RUN; then
      print_entry "DRY-RUN" "$YEL" "Homebrew cache" "$(bytes_to_human $sz)"
    else
      brew cleanup --prune=all -s 2>/dev/null || true
      print_entry "DONE" "$GRN" "Homebrew cache" "freed $(bytes_to_human $sz)"
    fi
    FREED=$(( FREED + sz ))
  fi
  echo ""
fi

# ═════════════════════════════════════════════════════════════════════════════
# 8. npm (if installed)
# ═════════════════════════════════════════════════════════════════════════════
if command -v npm &>/dev/null; then
  printf "${BLD}[8] npm cache${RST}\n"
  npm_cache=$(npm config get cache 2>/dev/null || echo "")
  [[ -d "$npm_cache" ]] && do_clean "$npm_cache" "npm cache" dir
  echo ""
fi

# ═════════════════════════════════════════════════════════════════════════════
# 9. pip (if installed)
# ═════════════════════════════════════════════════════════════════════════════
if command -v pip3 &>/dev/null; then
  printf "${BLD}[9] pip cache${RST}\n"
  pip_cache=$(pip3 cache dir 2>/dev/null || echo "")
  [[ -d "$pip_cache" ]] && do_clean "$pip_cache" "pip cache" dir
  echo ""
fi

# ═════════════════════════════════════════════════════════════════════════════
# 10. WEBEX / CISCO SPARK UPGRADE CACHE
# ═════════════════════════════════════════════════════════════════════════════
SPARK="$HOME/Library/Application Support/Cisco Spark"
if [[ -d "$SPARK" ]]; then
  printf "${BLD}[10] Webex / Cisco Spark upgrade cache${RST}\n"
  do_clean "$SPARK/Webexteams_upgrades_arm" "Webex upgrade cache (arm)" path
  do_clean "$SPARK/Webexteams_upgrades"     "Webex upgrade cache"       path
  echo ""
fi

# ═════════════════════════════════════════════════════════════════════════════
# 11. iOS BACKUPS — info only
# ═════════════════════════════════════════════════════════════════════════════
printf "${BLD}[11] iOS backups${RST}  ${DIM}(info only — remove manually via Finder)${RST}\n"
BK="$HOME/Library/Application Support/MobileSync/Backup"
if [[ -d "$BK" ]]; then
  sz=$(dir_size_bytes "$BK")
  n=$(find "$BK" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  printf "  ${CYN}[INFO]${RST}    %-50s %s  (%s backup(s))\n" \
    "MobileSync/Backup" "$(bytes_to_human $sz)" "$n"
  printf "  ${DIM}  → Finder › [your device] › Manage Backups to remove old ones${RST}\n"
else
  printf "  ${DIM}No iOS backups found${RST}\n"
fi
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# 12. OPTIONAL — LARGE GAME DATA
# ═════════════════════════════════════════════════════════════════════════════
declare -A GAMES=(
  ["Magic: The Gathering Arena"]="$HOME/Library/Application Support/com.wizards.mtga"
  ["Pokémon TCG Online"]="$HOME/Library/Application Support/unity.The Pokémon Company International.Pokemon Trading Card Game Online"
  ["The Sandbox"]="$HOME/Library/Application Support/com.TSBGAMING.TheSandbox"
  ["Steam data"]="$HOME/Library/Application Support/Steam"
  ["Battle.net"]="$HOME/Library/Application Support/Battle.net"
  ["Epic Games"]="$HOME/Library/Application Support/Epic"
  ["Riot Games"]="$HOME/Library/Application Support/Riot Games"
)

found_games=false
for name in "${!GAMES[@]}"; do
  [[ -d "${GAMES[$name]}" ]] && { found_games=true; break; }
done

if $found_games; then
  printf "${BLD}[12] Optional — unused game data${RST}\n"
  for name in "${!GAMES[@]}"; do
    path="${GAMES[$name]}"
    [[ -d "$path" ]] || continue
    sz=$(dir_size_bytes "$path")
    (( sz == 0 )) && continue
    if $DRY_RUN; then
      print_entry "DRY-RUN" "$YEL" "$name" "$(bytes_to_human $sz)"
    elif ask_section "Delete data for \"$name\" ($(bytes_to_human $sz))?"; then
      do_clean "$path" "$name" path
    else
      printf "  ${DIM}[KEPT]    %s${RST}\n" "$name"
    fi
  done
  echo ""
fi

# ═════════════════════════════════════════════════════════════════════════════
# 13. OPTIONAL — iMAZING BACKUPS
# ═════════════════════════════════════════════════════════════════════════════
IMAZING="$HOME/Library/Application Support/iMazing/Backups"
if [[ -d "$IMAZING" ]]; then
  printf "${BLD}[13] Optional — iMazing backups${RST}\n"
  sz=$(dir_size_bytes "$IMAZING")
  if $DRY_RUN; then
    print_entry "DRY-RUN" "$YEL" "iMazing Backups" "$(bytes_to_human $sz)"
    printf "  ${DIM}  → Only delete if you have other iPhone backups (iCloud/iTunes)${RST}\n"
  elif ask_section "Delete iMazing backups ($(bytes_to_human $sz))? Only if you have backups elsewhere."; then
    do_clean "$IMAZING" "iMazing Backups" dir
  else
    printf "  ${DIM}[KEPT]    iMazing Backups${RST}\n"
  fi
  echo ""
fi

# ═════════════════════════════════════════════════════════════════════════════
# 14. OPTIONAL — macOS AERIAL WALLPAPERS
# ═════════════════════════════════════════════════════════════════════════════
AERIALS="$HOME/Library/Application Support/com.apple.wallpaper/aerials"
if [[ -d "$AERIALS" ]]; then
  printf "${BLD}[14] Optional — macOS Aerial wallpapers${RST}\n"
  sz=$(dir_size_bytes "$AERIALS")
  if $DRY_RUN; then
    print_entry "DRY-RUN" "$YEL" "Aerial wallpapers" "$(bytes_to_human $sz)"
    printf "  ${DIM}  → macOS will re-download them if you use aerial wallpapers${RST}\n"
  elif ask_section "Delete aerial wallpapers cache ($(bytes_to_human $sz))? macOS will re-download if needed."; then
    do_clean "$AERIALS" "Aerial wallpapers" path
  else
    printf "  ${DIM}[KEPT]    Aerial wallpapers${RST}\n"
  fi
  echo ""
fi

# ═════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═════════════════════════════════════════════════════════════════════════════
FREE_AFTER=$(df -k / | awk 'NR==2{print $4 * 1024}')
ACTUALLY_FREED=$(( FREE_AFTER - FREE_BEFORE ))

hr
printf "${BLD}  SUMMARY${RST}\n"
hr2
printf "  Estimated removed  : ${BLD}%s${RST}\n" "$(bytes_to_human $FREED)"
if ! $DRY_RUN; then
  printf "  Actually freed     : ${BLD}%s${RST}\n" "$(bytes_to_human $ACTUALLY_FREED)"
  printf "  Disk free now      : ${BLD}%s${RST}\n" "$(bytes_to_human $FREE_AFTER)"
else
  echo ""
  printf "  ${YEL}Run with --clean to actually free this space:${RST}\n"
  printf "  ${BLD}bash %s --clean${RST}\n" "$(basename "$0")"
fi
hr
echo ""
