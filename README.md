# 🧹 mac-janitor

> Stop hoarding GBs you didn't know you had. **mac-janitor** is a safe, interactive bash script that hunts down caches, logs, Xcode junk, Time Machine snapshots and forgotten game data on macOS. Dry-run by default — nothing is deleted until you say so.

![macOS](https://img.shields.io/badge/macOS-Ventura%20%7C%20Sonoma%20%7C%20Sequoia-blue)
![Shell](https://img.shields.io/badge/shell-bash-green)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

---

## ✨ Features

- **Dry-run by default** — shows what would be deleted without touching anything
- **Interactive mode** — asks before removing optional sections (game data, backups, wallpapers)
- **Non-interactive mode** — fully automated, great for scripts and scheduled tasks
- **Spotlight-powered large file scan** — instantly finds files over 500 MB using macOS's own index
- **No dependencies** — pure bash, works on any Mac out of the box
- **Safe by design** — never touches iCloud, OneDrive, iOS backups or system files

---

## 🚀 Usage

```bash
# 1. Clone the repo
git clone https://gitlab.com/yourname/mac-janitor.git
cd mac-janitor

# 2. Make the script executable
chmod +x macos-cleanup.sh

# 3. Preview what would be cleaned (safe, nothing is deleted)
bash macos-cleanup.sh

# 4. Clean interactively (asks before optional sections)
bash macos-cleanup.sh --clean

# 5. Clean everything automatically (no prompts)
bash macos-cleanup.sh --clean --yes
```

---

## 🗑️ What it cleans

| Section | Description |
|---------|-------------|
| User caches | `~/Library/Caches` |
| System & user logs | `~/Library/Logs`, `/Library/Logs`, `/private/var/log` |
| Temporary files | `/private/tmp` |
| Trash | User trash + all mounted volumes |
| Xcode artefacts | DerivedData, Archives, iOS/watchOS DeviceSupport, Simulators |
| Time Machine snapshots | Local snapshots stored on disk |
| Homebrew cache | `brew cleanup --prune=all` |
| npm cache | `npm cache clean` |
| pip cache | `pip3 cache purge` |
| Webex / Cisco Spark | Leftover upgrade packages |
| Game data *(optional)* | MTG Arena, Pokémon TCG, The Sandbox, Steam, Battle.net, Epic, Riot |
| iMazing backups *(optional)* | iPhone/iPad backups made with iMazing |
| Aerial wallpapers *(optional)* | macOS aerial wallpaper cache (re-downloaded on demand) |

---

## 🛡️ What it never touches

- iCloud Drive and OneDrive synced files
- iOS / iTunes backups (shows size info only — remove manually via Finder)
- macOS system files
- Any path not explicitly listed in the script

---

## 🔍 mac-find-space — find your hidden space hogs

Before cleaning, run the companion diagnostic tool to see exactly where your gigabytes went:

```bash
bash mac-find-space.sh
```

**What it reports (read-only, nothing is deleted):**

| Section | What it shows |
|---------|---------------|
| Disk overview | Total / used / free space |
| Largest folders | Top folders by area: home, library, downloads, apps... |
| Files > 500 MB | Instant results via Spotlight — no slow full-disk scan |
| Time Machine snapshots | Local snapshots with delete instructions |
| iOS backups | Size and count with removal guidance |
| Virtual machines | UTM, VMware, Parallels, VirtualBox disk images |

The recommended workflow is: **scan first, then clean.**

```bash
bash mac-find-space.sh       # 1. find out what's eating your disk
bash macos-cleanup.sh --clean  # 2. clean it up safely
```

---

## ✅ Requirements

- macOS Ventura, Sonoma, or Sequoia
- bash (pre-installed on all Macs)
- `bc` (pre-installed on all Macs)
- Optional: Xcode CLI tools (for simulator cleanup), Homebrew, npm, pip

---

## 🤝 Contributing

Contributions are welcome! If you know of other safe locations to clean, or want to add support for more tools and games, feel free to open an issue or a merge request.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/add-docker-cleanup`)
3. Commit your changes
4. Open a Merge Request

---

## 📄 License

MIT — see [LICENSE](LICENSE) for details.
