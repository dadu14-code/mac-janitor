#!/usr/bin/env bash
# =============================================================================
#  mac-find-space.sh
#  Read-only diagnostic tool — shows where your disk space went on macOS
#
#  Tested on: macOS Ventura, Sonoma, Sequoia
#  License:   MIT
#
#  USAGE:
#    bash mac-find-space.sh
#
#  Nothing is deleted. This script only reads and reports.
# =============================================================================

set -euo pipefail
export LC_ALL=C LANG=C

# ── Colours ───────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  RED='\033[0;31m' YEL='\033[1;33m' GRN='\033[0;32m'
  CYN='\033[0;36m' BLD='\033[1m'    DIM='\033[2m' RST='\033[0m'
else
  RED='' YEL='' GRN='' CYN='' BLD='' DIM='' RST=''
fi

hr()  { printf '%s\n' "══════════════════════════════════════════════════════════"; }
hr2() { printf '%s\n' "──────────────────────────────────────────────────────────"; }

scan_dir() {
  local label="$1" path="$2" depth="${3:-2}"
  [[ -d "$path" ]] || return
  printf "\n  ${CYN}▸ %s${RST}\n" "$label"
  du -hd "$depth" "$path" 2>/dev/null \
    | sort -rh | head -12 \
    | awk '{printf "    %-10s %s\n", $1, $2}'
}

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
hr
printf "${BLD}  🔍  mac-find-space — disk usage diagnostics${RST}\n"
hr
printf "  ${DIM}Read-only. Nothing will be modified or deleted.${RST}\n"
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# 1. DISK OVERVIEW
# ═════════════════════════════════════════════════════════════════════════════
printf "${BLD}[1] Disk overview${RST}\n"
df -h / | awk 'NR==2 {
  printf "  Total: %s   Used: %s   Free: %s   (%s full)\n", $2, $3, $4, $5
}'
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# 2. LARGEST FOLDERS BY AREA
# ═════════════════════════════════════════════════════════════════════════════
printf "${BLD}[2] Largest folders by area${RST}\n"

scan_dir "Home (~)"                    "$HOME"                                2
scan_dir "Library"                     "$HOME/Library"                        2
scan_dir "Downloads"                   "$HOME/Downloads"                      1
scan_dir "Documents"                   "$HOME/Documents"                      2
scan_dir "Desktop"                     "$HOME/Desktop"                        1
scan_dir "Movies"                      "$HOME/Movies"                         2
scan_dir "iCloud (local)"              "$HOME/Library/Mobile Documents"       2
scan_dir "Application Support"         "$HOME/Library/Application Support"    2
scan_dir "Group Containers"            "$HOME/Library/Group Containers"       1
scan_dir "Applications"                "/Applications"                        1
scan_dir "System Data (/private/var)"  "/private/var"                        2
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# 3. FILES LARGER THAN 500 MB (via Spotlight — instant)
# ═════════════════════════════════════════════════════════════════════════════
printf "${BLD}[3] Files larger than 500 MB${RST}  ${DIM}(via Spotlight index — instant)${RST}\n"

mdfind "kMDItemFSSize > 524288000" 2>/dev/null \
  | grep -v "^/System/Volumes/VM" \
  | grep -v "^/private/var/vm" \
  | while IFS= read -r f; do
      [[ -f "$f" ]] || continue
      sz=$(stat -f%z "$f" 2>/dev/null) || continue
      [[ -z "$sz" ]] && continue
      printf "%015d %s\n" "$sz" "$f"
    done \
  | sort -rn \
  | head -30 \
  | awk '{
      bytes = $1
      sub(/^[^ ]+ /, "", $0); path = $0
      if      (bytes >= 1073741824) size = sprintf("%.1f GB", bytes/1073741824)
      else if (bytes >= 1048576)    size = sprintf("%.0f MB", bytes/1048576)
      else                          size = sprintf("%.0f KB", bytes/1024)
      printf "  %-10s %s\n", size, path
    }'
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# 4. TIME MACHINE LOCAL SNAPSHOTS
# ═════════════════════════════════════════════════════════════════════════════
printf "${BLD}[4] Time Machine local snapshots${RST}\n"
snaps=()
while IFS= read -r line; do
  [[ "$line" =~ ^com\.apple\.TimeMachine ]] && snaps+=("$line")
done < <(tmutil listlocalsnapshots / 2>/dev/null)

if (( ${#snaps[@]} == 0 )); then
  printf "  ${DIM}No local snapshots found${RST}\n"
else
  printf "  ${RED}Found %d snapshot(s) — these can take up tens of GB!${RST}\n" "${#snaps[@]}"
  printf "    ${DIM}%s${RST}\n" "${snaps[@]}"
  printf "\n  To delete them all:\n"
  printf "  ${YEL}tmutil listlocalsnapshots / | grep '^com\.' | while read s; do tmutil deletelocalsnapshots \"\${s##*.}\"; done${RST}\n"
fi
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# 5. iOS BACKUPS
# ═════════════════════════════════════════════════════════════════════════════
printf "${BLD}[5] iOS backups${RST}\n"
BK="$HOME/Library/Application Support/MobileSync/Backup"
if [[ -d "$BK" ]]; then
  sz=$(du -sh "$BK" 2>/dev/null | cut -f1)
  n=$(find "$BK" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  printf "  ${RED}%-8s${RST} %s backup(s)\n" "$sz" "$n"
  printf "  ${DIM}  → Remove old ones via Finder › [your device] › Manage Backups${RST}\n"
else
  printf "  ${DIM}No iOS backups found${RST}\n"
fi
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# 6. VIRTUAL MACHINES
# ═════════════════════════════════════════════════════════════════════════════
printf "${BLD}[6] Virtual machines${RST}\n"
found_vm=false
for ext in vmwarevm utm parallels vbox vmdk; do
  while IFS= read -r f; do
    [[ -e "$f" ]] || continue
    sz=$(du -sh "$f" 2>/dev/null | cut -f1)
    printf "  ${RED}%-8s${RST} %s\n" "$sz" "$f"
    found_vm=true
  done < <(mdfind "kMDItemFSName == '*.${ext}'" 2>/dev/null | head -5)
done
$found_vm || printf "  ${DIM}No virtual machines found${RST}\n"
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# FOOTER
# ═════════════════════════════════════════════════════════════════════════════
hr
printf "${BLD}  Next step:${RST} run ${BLD}macos-cleanup.sh --clean${RST} to reclaim space safely.\n"
hr
echo ""
