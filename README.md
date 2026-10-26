# 💻 Terminas — Native macOS SSH Client, SFTP & Terminal

<p align="center">
  <img src="Resources/AppIcon.png" alt="Terminas App Icon" width="128" height="128" style="border-radius: 24px; box-shadow: 0 10px 25px rgba(0,0,0,0.2);" />
</p>

<p align="center">
  <b>A blazing-fast, secure, and native macOS SSH client, terminal emulator, SFTP file manager, and system configuration vault.</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2013%2B-blue?logo=apple" alt="macOS 13+" />
  <img src="https://img.shields.io/badge/Architecture-Apple%20Silicon%20%7C%20Intel-success" alt="Universal" />
  <img src="https://img.shields.io/badge/Language-Swift%205.9%2B-orange?logo=swift" alt="Swift 5.9+" />
  <img src="https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-purple" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/Security-Apple%20Keychain%20%7C%20AES--256-red" alt="Security" />
  <img src="https://img.shields.io/badge/Size-~5.4%20MB-informational" alt="Size" />
  <a href="#-support--donate"><img src="https://img.shields.io/badge/Support-Donate%20(VietQR)-success?logo=applepay&logoColor=white" alt="Donate" /></a>
</p>

---

## 📖 Overview

**Terminas** is a modern SSH workspace and terminal manager engineered specifically for macOS. Inspired by tools like **Termius**, **iTerm2**, and **Transmit**, Terminas is built from the ground up using **pure Swift and SwiftUI**, delivering fluid 120Hz ProMotion responsiveness, deep Apple Silicon hardware acceleration, and seamless system integration (Touch ID, Secure Enclave Keychain, native Finder drag-and-drop).

Whether you are managing fleets of cloud VPS instances, home lab clusters, database tunnels, local development shells, or shell environment files (`.zshrc`), Terminas provides an all-in-one unified workspace.

---

## ✨ Key Features

### 1. 🗂️ Workspaces Isolation & Production Safety Guard
- **Project Context Isolation**: Organize servers, reusable snippets, and SSH tunnels into dedicated workspaces (`All Workspaces`, `Production`, `Staging`, `Personal`, `HomeLab`). Selecting a workspace instantly filters your view to only what matters.
- **Production Safety Reminder (`[🚨 PROD]`)**:
  - Mark mission-critical environments as **Production**.
  - Terminals connected to production hosts display a prominent red **`[🚨 PROD]`** safety banner in the status bar to guard against accidental destructive commands (`rm -rf`, `drop table`, `systemctl restart`).

### 2. 🪟 Split Panes (Split Terminal up to 4 Panes in 1 Tab)
- **Vertical Split (`⌘ + D`)**: Split your active terminal vertically side-by-side to compare configurations or run test commands next to your code.
- **Horizontal Split (`⌘ + ⇧ + D`)**: Stack panes horizontally (e.g., monitor `tail -f access.log` on top while executing commands below).
- **Flexible Grid**: Supports up to 4 concurrent panes in a single tab with individual focus highlights, titles, and independent pane closing (`✕`).

### 3. 📡 Broadcast Input / Multi-Exec (Simultaneous Command Mirroring)
- **Real-Time Keystroke Mirroring**: Turn on **Broadcast Mode** to send every keystroke and key combination typed in your active pane simultaneously to all other panes in the tab.
- **Quick Broadcast Prompt Bar**: Dedicated command input bar to broadcast one-liner administration scripts across servers in one click.

### 4. 🔀 Proxy Jump / Bastion Host Chain GUI
- **Enterprise Network Gateway**: Easily route SSH and SFTP connections through a Bastion / Jump Server into private subnets (AWS VPC, GCP, On-Premises) without manually writing complex `ProxyCommand` strings.
- **Automatic `-J` Handling**: Terminas automatically manages OpenSSH ProxyJump arguments and displays a `Bastion` tag on routed host cards.

### 5. 📁 SFTP File Browser & Finder Drag-and-Drop
- **Direct Drag & Drop from Finder**: Drag files or entire folders straight from your macOS Desktop or Finder into the SFTP table to initiate an instant background upload.
- **Active Transfer Banner**: Real-time progress feedback showing upload and download states.
- **Smart Breadcrumb Path Bar**: Interactive folder segments, quick navigation to Parent (`↑`), and Home (`⌂`).
- **Instant In-App Preview**: Double-click text, log, and configuration files (`nginx.conf`, `.env`, `.py`, `.json`, `.yml`, etc.) to inspect their content with line numbering and syntax formatting without downloading them to disk.
- Create new directories (`mkdir`) and delete remote files safely.

### 6. ⌘ Command Palette (`⌘ + K`)
- **Spotlight & Raycast-Style Modal**: Hit `⌘ + K` anywhere in the app to open an instant keyboard-driven search palette.
- **Quick Actions**: Search and connect to servers, run snippets into the active terminal, switch workspaces, toggle broadcast mode, split panes, or lock the application without touching the mouse.

### 7. 🩺 Live Host Health Check & Ping Latency Indicator
- **Non-blocking TCP Probes**: Probes SSH ports in the background via Apple's native `Network.framework`.
- **Latency & Status Dots**: Displays live indicators next to host cards:
  - 🟢 Green: Online with latency counter (e.g. `24ms`).
  - 🟠 Orange: Reachable with higher latency (>100ms).
  - 🔴 Red: Unreachable or port closed.
  - Dedicated **"Ping All"** button in the host list toolbar.

### 8. 📊 Real-Time Server Metrics & Stats Bar
- Displays a clean real-time status bar directly above active SSH terminal sessions:
  - 🕒 **Server Clock**: Current server date, time, and timezone.
  - ⚡️ **CPU Utilization**: Live CPU load percentage with progressive color indicators (green, orange, red).
  - 🧠 **Memory (RAM)**: Memory usage ratio (`Used / Total`) and percentage.
  - 💾 **Disk Usage**: Root filesystem (`/`) consumption and total available storage.
  - ⏱️ **System Uptime**: Live continuous server uptime counter.

### 9. 🔄 Auto-Reconnect & Connection Recovery
- **Dropped Connection Resilience**: Detects dropped SSH sockets instantly when closing the laptop lid, waking from sleep, or switching Wi-Fi networks.
- **Center-Viewport Recovery**: When a session disconnects, an intuitive **"Reconnect"** banner appears right in the middle of the terminal view, enabling instant one-click reconnection without losing your tab layout.

### 10. 🔀 SSH Tunnels / Port Forwarding GUI
- Manage encrypted port forwarding effortlessly with intuitive visual toggles:
  - **Local Port Forwarding (`-L`)**: Access remote private databases (MySQL, PostgreSQL, Redis, MongoDB) securely on `localhost:port`.
  - **Remote Port Forwarding (`-R`)**: Expose local webhooks and dev services to remote servers (similar to ngrok).
  - **Dynamic SOCKS5 Proxy (`-D`)**: Route browser and app traffic through an encrypted VPS tunnel.

### 11. 🛠️ Local Device Management (SSH Keys, Config, Shell)
- **SSH Key Manager**:
  - Scan and view all private and public keys stored in `~/.ssh`.
  - Generate modern **ED25519** and **RSA (4096-bit)** key pairs with custom filenames and comments.
  - **1-Click Copy for GitHub & GitLab**: Copy public keys directly to your clipboard in OpenSSH format ready for GitHub, GitLab, and remote `~/.ssh/authorized_keys`.
- **SSH Config Manager (`~/.ssh/config`)**:
  - Structured visual GUI + raw file editor for your OpenSSH client configuration.
  - Manage host aliases, `ProxyJump` jump hosts, identity key files, and custom ports.
  - **1-Click Import**: Import existing hosts from `~/.ssh/config` into Terminas workspaces with a single click.
- **Shell Configuration Editor (`.zshrc`, `.bashrc`, `.zprofile`)**:
  - **Oh My Zsh Plugins**: Dedicated **Plugins** manager displaying multiline `plugins=(...)` arrays cleanly with search, 1-click removal, and quick recommendations (`git`, `docker`, `zsh-autosuggestions`, `kubectl`, etc.).
  - **Environment Variables**: Add, modify, and delete `export KEY="VALUE"` variables safely.
  - **Aliases & PATH**: Manage command shortcuts and `$PATH` directories with visual disk validation.
  - **Automated Syntax Testing**: Executes `zsh -n` verification before saving to ensure zero broken shell startup scripts. Automatic `.bak` backup generation.

### 12. 🔒 Enterprise-Grade Security & Vault
- **Biometric App Lock (`Touch ID / Apple Watch`)**:
  - Integrated with Apple's **`LocalAuthentication`** framework.
  - Automatically locks the app upon startup or after inactivity. Unlock quickly with **Touch ID**, **Apple Watch**, or your **macOS user login password**.
  - Instant lock keyboard shortcut: `⌘ + L`.
- **Zero Plain-Text Credentials**:
  - 🔐 **SSH & Root Passwords**: Stored in **Apple Keychain Services** backed by the hardware **Secure Enclave**.
  - 🛡️ **AES-256-GCM Storage Encryption (Apple CryptoKit)**: Host details, snippets, tunnels, and workspaces are serialized and encrypted with an isolated 256-bit master key before touching disk (`~/Library/Application Support/Terminas/`).
- **Automatic User Escalation (`su` / `sudo`)**:
  - For hardened servers disabling direct `root` SSH logins, Terminas connects with standard user credentials and automatically runs `su -` or `sudo -i`, injecting root credentials securely from macOS Keychain.

---

## ⌨️ Essential Keyboard Shortcuts

| Shortcut | Action | Scope |
| :--- | :--- | :--- |
| `⌘ + K` | **Open Command Palette** (Search servers, snippets, tools) | Global |
| `⌘ + T` | Open new Local Terminal tab | Global |
| `⌘ + W` | Close active Terminal tab | Terminal |
| `⌘ + D` | **Split Pane Vertically** (side-by-side) | Terminal |
| `⌘ + ⇧ + D` | **Split Pane Horizontally** (top-bottom) | Terminal |
| `⌘ + ⌥ + B` | **Toggle Broadcast Mode** (mirror input to all panes) | Terminal |
| `⌘ + ⇧ + R` | **Reconnect Active Session** | Terminal |
| `⌘ + 1` … `⌘ + 9` | Switch directly to Tab 1 through 9 | Terminal |
| `⌘ + F` | Focus search bar (Hosts, Snippets, Keys) | List Views |
| `⌘ + S` | Save changes (Shell config, SSH config) | Editors |
| `⌘ + L` | Instantly lock application with Touch ID / Password | Global |
| `⌘ + ⇧ + H` | Jump to **Hosts** | Navigation |
| `⌘ + ⇧ + T` | Jump to **Terminal Sessions** | Navigation |
| `⌘ + ⇧ + S` | Jump to **SFTP Browser** | Navigation |

---

## 🚀 Installation & Getting Started

### Method 1: DMG Installer (Recommended)
1. Download [**`Terminas.dmg`**](https://github.com/ngocmanhht/terminas/releases/latest) (~5.5 MB) from Releases or use the bundled disk image.
2. Drag the **Terminas** icon into your **Applications** folder.
3. Launch **Terminas** from Spotlight (`⌘ + Space`) or Launchpad.

### Method 2: Launch Directly
```bash
open Terminas.app
```

### Method 3: Build from Source
Ensure you have Xcode 15+ and Swift 5.9+ installed on macOS Sonoma or Sequoia:

```bash
# 1. Clone or navigate to the repository
cd /path/to/terminas

# 2. Build the production app bundle
./build-app.sh

# 3. (Optional) Generate the professional DMG installer
./create-dmg.sh

# 4. Run the newly compiled application
open Terminas.app
```

---

## 🏗️ Project Architecture & File Structure

```
terminas/
├── Terminas.app/                        # Standalone compiled macOS Application
├── Terminas.dmg                        # Professional disk image installer
├── build-app.sh                        # SPM build & bundle packaging script
├── create-dmg.sh                       # DMG creation script with drag-to-Applications
├── Package.swift                       # Swift Package Manager manifest
├── Resources/
│   ├── AppIcon.png                     # Application Icon (1024x1024)
│   ├── AppIcon.icns                    # Multi-resolution macOS ICNS asset
│   └── Info.plist                      # Application metadata & entitlements
└── Sources/Terminas/
    ├── App/
    │   └── TerminasApp.swift           # Main entry point (@main, WindowGroup, Commands)
    ├── Models/
    │   ├── HostItem.swift              # SSH Host data model with Bastion jumpHostId
    │   ├── ServerMetrics.swift         # Real-time CPU, RAM, Disk & Uptime telemetry
    │   ├── RemoteFileItem.swift        # SFTP remote file & directory attributes
    │   ├── TunnelItem.swift            # Port Forwarding model (-L, -R, -D)
    │   ├── SSHKeyItem.swift            # SSH key pair metadata & OpenSSH formatting
    │   ├── SSHConfigEntry.swift        # ~/.ssh/config parsed entity model
    │   ├── ZshConfigModels.swift       # Shell environment, plugins, and alias models
    │   ├── SnippetItem.swift           # Reusable command snippet model
    │   ├── WorkspaceItem.swift         # Project workspace model & PROD safety flag
    │   ├── SessionTab.swift            # Active tab lifecycle, broadcast & split coordination
    │   ├── TerminalPane.swift          # Individual split pane process & metrics lifecycle
    │   ├── SessionStatus.swift         # Connecting, connected, terminated state model
    │   └── TerminalTheme.swift         # ANSI color palette & theme presets
    ├── Services/
    │   ├── HostStore.swift             # Encrypted host persistence & filtering
    │   ├── HostHealthChecker.swift     # Background TCP probe & live latency engine
    │   ├── SFTPService.swift           # SFTP/SCP remote operations, drop upload & transfers
    │   ├── ServerMonitorService.swift  # Remote telemetry polling engine with Bastion jump
    │   ├── TunnelManager.swift         # Background SSH port forwarding process lifecycle
    │   ├── SSHKeyManager.swift         # ~/.ssh key scanner & ED25519/RSA generator
    │   ├── SSHConfigFileManager.swift  # ~/.ssh/config file manager & entry editor
    │   ├── SSHConfigParser.swift       # OpenSSH config syntax parser & serializer
    │   ├── ZshConfigFileManager.swift  # Shell configuration manager & zsh -n syntax checker
    │   ├── SecurityManager.swift       # Biometric Touch ID & App Lock controller
    │   ├── KeychainService.swift       # Apple Keychain Services wrapper
    │   ├── CryptoService.swift         # AES-256-GCM CryptoKit vault encryption
    │   ├── BackupService.swift         # Encrypted workspace backup import/export
    │   ├── SnippetStore.swift          # Snippet persistence & tag categorization
    │   ├── TerminalSessionManager.swift# Multi-tab & split coordinator
    │   └── AppNavigationManager.swift  # Centralized app routing & command palette state
    ├── Terminal/
    │   ├── TerminalViewRepresentable.swift # SwiftTerm AppKit/SwiftUI bridging adapter
    │   └── TerminalThemeApplicator.swift   # Dynamic ANSI color scheme injection
    └── Views/
        ├── MainContentView.swift       # Root NavigationSplitView & titlebar layout
        ├── CommandPaletteView.swift    # Spotlight/Raycast-style floating command palette
        ├── HostListView.swift          # Host cards, health probes, and workspace switcher
        ├── HostRowView.swift           # Host card with live latency dot & Bastion badge
        ├── HostEditSheet.swift         # Server creation/editing sheet with Bastion picker
        ├── QuickConnectSheet.swift     # Fast user@host:port connection dialog
        ├── ImportSSHConfigSheet.swift  # ~/.ssh/config batch importer
        ├── TerminalTabsView.swift      # Tab bar, split actions, broadcast toggle & panes
        ├── PanesContainerView.swift    # 1-to-4 split panes layout (vertical & horizontal)
        ├── ServerStatsBarView.swift    # Live CPU, RAM, Disk & Uptime metrics header
        ├── SFTPBrowserView.swift       # Dual-pane remote file browser with Finder drag-drop
        ├── TunnelListView.swift        # Port forwarding dashboard & tunnel creator
        ├── SSHKeysView.swift           # SSH key manager, generator & public key copier
        ├── GenerateSSHKeySheet.swift   # Key generation dialog (ED25519 / RSA)
        ├── SSHConfigEditorView.swift   # ~/.ssh/config visual & raw editor
        ├── ZshConfigView.swift         # Shell config editor (Env, Plugins, Aliases, PATH)
        ├── SnippetsView.swift          # Command snippets vault
        ├── SettingsView.swift          # Themes, typography, default ports & backup
        ├── WorkspacePickerButton.swift # Workspace selector & production indicator
        └── AppLockOverlayView.swift    # Touch ID / Password lock screen overlay
```

---

## 🔒 Security & Privacy Architecture

- **No Remote Telemetry**: Terminas makes **zero network requests** to external third parties. All connections are made directly to the SSH servers you specify.
- **Hardware Isolation**: Passwords and private credentials never touch plain text files. They are routed into Apple's **Secure Enclave** via the macOS Keychain.
- **Encrypted Local Database**: The local data store at `~/Library/Application Support/Terminas/` is encrypted with **AES-256-GCM**. Even if database files are backed up or copied, they cannot be decrypted without the host Mac's Keychain master key.

---

## ☕️ Support & Donate

Nếu bạn thấy **Terminas** hữu ích cho công việc hàng ngày, hãy ủng hộ tác giả một ly cà phê để tiếp thêm động lực phát triển thêm nhiều tính năng mới nhé! ☕️🚀

<p align="center">
  <img src="Resources/donate_vietqr.png" alt="Donate qua VietQR - VPBank" width="300" style="border-radius: 16px; box-shadow: 0 8px 24px rgba(0,0,0,0.15);" />
</p>

<p align="center">
  🏦 <b>Ngân hàng:</b> VPBank (Ngân hàng TMCP Việt Nam Thịnh Vượng)<br>
  💳 <b>Số tài khoản:</b> <code>0853462608</code><br>
  👤 <b>Chủ tài khoản:</b> <b>DOAN ANH NGOC</b><br>
  📝 <b>Nội dung:</b> <code>Donate Terminas</code>
</p>

- ⭐ **Star repository** nếu bạn yêu thích Terminas!
- 🐛 **Báo lỗi hoặc đề xuất tính năng mới?** Hãy mở Issue hoặc đóng góp Pull Request.
- 📢 **Chia sẻ Terminas** tới bạn bè và đồng nghiệp cần một SSH & SFTP client thuần native, siêu tốc trên macOS.

---

## 📄 License

Terminas is crafted with care for developers, sysadmins, and DevOps engineers. Distributed under the **MIT License**.
