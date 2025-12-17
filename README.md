# MixTerm

Professional SSH/SFTP client built with Flutter for Linux and macOS.

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)
![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS-lightgrey.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Screenshots](#screenshots)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [User Guide](#user-guide)
- [Architecture](#architecture)
- [Configuration](#configuration)
- [Development](#development)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

MixTerm is a modern, feature-rich SSH and SFTP client designed for developers and system administrators. Built with Flutter, it provides a native desktop experience on Linux and macOS with a beautiful dark theme and intuitive interface.

### Key Highlights

- **Multi-tab Support**: Open multiple SSH/SFTP sessions simultaneously
- **Split Pane View**: Work with two sessions side-by-side
- **Secure Storage**: All credentials encrypted with AES-256
- **Cloud Sync**: Sync server configurations via Google Drive
- **Drag & Drop**: Upload files by dragging from desktop

---

## Features

### Connection Management

| Feature | Description |
|---------|-------------|
| SSH Terminal | Full-featured terminal emulator with xterm compatibility |
| SFTP Browser | Visual file browser for remote servers |
| Password Auth | Traditional username/password authentication |
| Key Auth | SSH key-based authentication with passphrase support |
| Server Groups | Organize servers into logical groups |

### Tab System

| Feature | Description |
|---------|-------------|
| Multiple Tabs | Open unlimited SSH/SFTP sessions |
| Tab Persistence | Sessions remain open until explicitly closed |
| Tab Reordering | Drag tabs to reorder them |
| Quick Close | Middle-click or X button to close tabs |
| Connection Status | Visual indicators for connected/disconnected state |

### Split Pane

| Feature | Description |
|---------|-------------|
| Vertical Split | Divide workspace into two panes |
| Resizable Divider | Drag to adjust pane sizes |
| Independent Panes | Each pane shows different tab content |
| Double-click Reset | Double-click divider to reset 50/50 split |

### SFTP Features

| Feature | Description |
|---------|-------------|
| File Navigation | Browse remote directories with breadcrumb path |
| Upload Files | Drag & drop from desktop or use upload dialog |
| Download Files | Right-click context menu to download |
| Create Directory | Create new folders on remote server |
| Rename Items | Rename files and directories |
| Delete Items | Delete with confirmation dialog |
| File Icons | Visual icons based on file type |

### Local File Browser

| Feature | Description |
|---------|-------------|
| Browse Local | Navigate local filesystem |
| Drag to Upload | Drag local files to SFTP browser |
| Path Navigation | Breadcrumb-style path bar |
| File Selection | Select files for batch operations |

### Security

| Feature | Description |
|---------|-------------|
| Master Password | Protect app with master password |
| AES-256 Encryption | All credentials encrypted at rest |
| Secure Storage | Platform-native secure storage |
| No Plain Text | Passwords never stored in plain text |

### Cloud Sync

| Feature | Description |
|---------|-------------|
| Google Drive | Sync server configs to Google Drive |
| Encrypted Backup | All synced data is encrypted |
| Multi-device | Access servers from multiple computers |

---

## Screenshots

```
+---------------------------------------------------------------------+
| [Server List]  |  [Tab1: SSH] [Tab2: SFTP] [Tab3: Local] [+]        |
|                |-----------------------------------------------------|
|  Production    |                                                     |
|  * Web Server  |  user@server:~$                                    |
|  * Database    |  $ ls -la                                          |
|                |  total 48                                           |
|  Development   |  drwxr-xr-x  5 user user 4096 Dec 17 10:00 .       |
|  * Dev Server  |  drwxr-xr-x  3 root root 4096 Dec 15 08:00 ..      |
|  * Staging     |  -rw-r--r--  1 user user  220 Dec 15 08:00 .bash   |
|                |                                                     |
| [+ Add Server] |-----------------------------------------------------|
| [Settings]     |  * Connected                                        |
+---------------------------------------------------------------------+
```

---

## Installation

### Prerequisites

- Flutter SDK 3.x or higher
- Linux: GTK 3.0 development libraries
- macOS: Xcode command line tools

### Build from Source

```bash
# Clone repository
git clone https://github.com/muhammetali/mixterm.git
cd mixterm

# Install dependencies
flutter pub get

# Build for Linux
flutter build linux --release

# Build for macOS
flutter build macos --release
```

### Run in Development

```bash
flutter run -d linux
# or
flutter run -d macos
```

---

## Quick Start

### 1. First Launch

On first launch, you'll be prompted to create a master password. This password encrypts all your stored credentials.

### 2. Add a Server

1. Click **"+ Add Server"** in the sidebar
2. Enter server details:
   - **Name**: Display name for the server
   - **Host**: IP address or hostname
   - **Port**: SSH port (default: 22)
   - **Username**: SSH username
3. Choose authentication method:
   - **Password**: Enter password
   - **SSH Key**: Paste private key and optional passphrase
4. Optionally assign to a **Group**
5. Click **Save**

### 3. Connect

1. Click on a server in the list
2. Choose connection type:
   - **SSH Terminal**: Opens terminal session
   - **SFTP Browser**: Opens file browser
3. A new tab opens with your session

### 4. Split View

1. Open at least 2 tabs
2. Click the split icon in the tab bar
3. Drag the divider to resize panes

---

## User Guide

### Managing Servers

#### Add Server
```
Sidebar -> "+ Add Server" -> Fill form -> Save
```

#### Edit Server
```
Right-click server -> Edit -> Modify details -> Save
```

#### Duplicate Server
```
Right-click server -> Duplicate
```

#### Delete Server
```
Right-click server -> Delete -> Confirm
```

### SSH Terminal

#### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+Shift+C` | Copy selected text |
| `Ctrl+Shift+V` | Paste from clipboard |
| Right-click | Paste (if enabled in settings) |

#### Terminal Features

- Full xterm compatibility
- 256 color support
- Mouse support
- Scrollback buffer (10,000 lines)
- Custom font and size

### SFTP Browser

#### Navigation

- **Click folder**: Enter directory
- **Click breadcrumb**: Jump to path
- **Up arrow**: Go to parent directory
- **Home button**: Go to home directory
- **Refresh**: Reload current directory

#### File Operations

| Action | How To |
|--------|--------|
| Upload | Drag files onto browser or click Upload |
| Download | Right-click -> Download |
| Rename | Right-click -> Rename |
| Delete | Right-click -> Delete |
| New Folder | Click folder+ icon |

#### Drag & Drop

1. Drag files from your desktop
2. Drop onto SFTP browser
3. Files upload to current directory
4. Progress shown in snackbar

### Tab Management

#### Opening Tabs

- Click server -> Choose SSH or SFTP
- Each connection opens in new tab
- Click "Local Files" for local browser

#### Closing Tabs

- Click X on tab
- Middle-click tab
- Disconnect from toolbar

#### Reordering Tabs

- Drag tab to new position
- Release to drop

### Split Pane

#### Enable Split View

1. Have at least 2 tabs open
2. Click split icon (vertical lines)
3. View divides into two panes

#### Using Split View

- Left pane shows one tab
- Right pane shows another tab
- Click tabs to change pane content
- Drag divider to resize

#### Disable Split View

- Click split icon again
- Or close tabs until only 1 remains

### Settings

Access via gear icon in sidebar.

#### Appearance

| Setting | Description |
|---------|-------------|
| Theme | Dark theme (default) |
| Font Size | Terminal font size (8-24) |
| Font Family | Monospace font selection |
| Opacity | Terminal background opacity |

#### Behavior

| Setting | Description |
|---------|-------------|
| Paste on Right-click | Enable right-click paste |
| Confirm on Close | Confirm before closing connected tabs |

#### Security

| Setting | Description |
|---------|-------------|
| Change Password | Update master password |
| Auto-lock | Lock app after inactivity |

### Cloud Sync

#### Setup

1. Click cloud icon in sidebar
2. Sign in with Google account
3. Authorize MixTerm access

#### Sync

- Click cloud icon to sync
- Uploads encrypted server configs
- Downloads configs from other devices

---

## Architecture

### Project Structure

```
lib/
|-- main.dart                 # App entry point
|-- app.dart                  # MaterialApp configuration
|
|-- models/                   # Data models
|   |-- server.dart          # Server configuration model
|   +-- tab_session.dart     # Tab/session model
|
|-- providers/               # State management
|   |-- server_provider.dart     # Server list management
|   |-- connection_provider.dart # SSH/SFTP connections
|   |-- tab_provider.dart        # Tab state management
|   +-- settings_provider.dart   # App settings
|
|-- services/                # Business logic
|   |-- ssh_service.dart     # SSH connection handling
|   |-- sftp_service.dart    # SFTP operations
|   |-- storage_service.dart # Encrypted storage
|   |-- auth_service.dart    # Google OAuth
|   +-- sync_service.dart    # Cloud sync
|
|-- screens/                 # Full-page screens
|   |-- home_screen.dart     # Main app screen
|   |-- login_screen.dart    # Master password screen
|   +-- settings_screen.dart # Settings page
|
|-- widgets/                 # Reusable widgets
|   |-- server_list.dart         # Server sidebar
|   |-- server_tile.dart         # Server list item
|   |-- terminal_view.dart       # Terminal widget
|   |-- sftp_browser.dart        # SFTP file browser
|   |-- local_file_browser.dart  # Local file browser
|   |-- session_tab_bar.dart     # Tab bar
|   |-- split_pane.dart          # Split container
|   +-- dialogs/                 # Dialog widgets
|       |-- add_server_dialog.dart
|       +-- master_password_dialog.dart
|
+-- utils/                   # Utilities
    +-- theme.dart           # App theming
```

### State Management

MixTerm uses **Provider** for state management.

```
+----------------------------------------------------------+
|                    MultiProvider                          |
|  +----------------------------------------------------+  |
|  | StorageService (encrypted storage)                 |  |
|  | AuthService (Google OAuth)                         |  |
|  | SettingsProvider (app settings)                    |  |
|  | ServerProvider (server list)                       |  |
|  | ConnectionProvider (SSH/SFTP connections)          |  |
|  | TabProvider (tab management)                       |  |
|  +----------------------------------------------------+  |
+----------------------------------------------------------+
```

### Data Flow

```
User Action
    |
    v
Widget (UI)
    |
    v
Provider (State)
    |
    v
Service (Business Logic)
    |
    v
External (SSH/SFTP/Storage)
```

### Key Classes

#### Server Model
```dart
class Server {
  String id;          // Unique identifier
  String name;        // Display name
  String host;        // IP/hostname
  int port;           // SSH port
  String username;    // SSH user
  String? password;   // Optional password
  String? privateKey; // Optional SSH key
  AuthType authType;  // password or key
  String? group;      // Optional group name
}
```

#### TabSession Model
```dart
class TabSession {
  String id;          // Unique identifier
  String? serverId;   // Associated server
  TabType type;       // ssh, sftp, or local
  String title;       // Tab title
  String currentPath; // Current directory
  bool isConnected;   // Connection status
}
```

#### TabProvider
```dart
class TabProvider {
  List<TabSession> tabs;      // All open tabs
  String? activeTabId;        // Currently active tab
  bool isSplitView;           // Split mode enabled
  String? leftPaneTabId;      // Left pane content
  String? rightPaneTabId;     // Right pane content

  // Terminal instances stored by tab ID
  Map<String, Terminal> terminals;
}
```

---

## Configuration

### Server Configuration

Servers are stored encrypted in:
- Linux: `~/.local/share/mixterm/`
- macOS: `~/Library/Application Support/mixterm/`

### Settings File

Settings stored in same location as `settings.json`:

```json
{
  "fontSize": 14,
  "fontFamily": "JetBrains Mono",
  "terminalOpacity": 1.0,
  "pasteOnRightClick": true,
  "themeMode": "dark"
}
```

### Environment Variables

| Variable | Description |
|----------|-------------|
| `HOME` | User home directory |
| `XDG_DATA_HOME` | Data directory (Linux) |

---

## Development

### Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.0.0          # State management
  dartssh2: ^2.9.0          # SSH/SFTP
  xterm: ^3.6.0             # Terminal emulator
  uuid: ^4.2.0              # Unique IDs
  encrypt: ^5.0.1           # AES encryption
  shared_preferences: ^2.2.0 # Settings storage
  file_picker: ^8.0.0       # File selection
  path_provider: ^2.1.0     # Path utilities
  desktop_drop: ^0.4.4      # Drag & drop
  googleapis: ^13.0.0       # Google APIs
  googleapis_auth: ^1.5.0   # Google OAuth
  intl: ^0.19.0             # Internationalization
```

### Building

```bash
# Debug build
flutter run -d linux

# Release build
flutter build linux --release

# Analyze code
flutter analyze

# Run tests
flutter test
```

### Code Style

- Follow Dart style guide
- Use `flutter analyze` for linting
- Format with `dart format`

---

## Testing

### Test Structure

```
test/
|-- models/
|   |-- server_test.dart         # Server model tests
|   +-- tab_session_test.dart    # TabSession model tests
|-- providers/
|   +-- tab_provider_test.dart   # TabProvider tests
|-- widgets/                      # Widget tests
+-- integration/                  # Integration tests
```

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/models/server_test.dart

# Run with coverage
flutter test --coverage

# Run specific test group
flutter test --name "Server Model"
```

### Test Coverage

| Component | Tests | Coverage |
|-----------|-------|----------|
| Server Model | 27 | 100% |
| TabSession Model | 26 | 100% |
| TabProvider | 51 | 95% |
| **Total** | **104** | - |

---

## Troubleshooting

### Connection Issues

**Problem**: SSH connection fails

**Solutions**:
1. Verify server IP/hostname is correct
2. Check SSH port (default 22)
3. Verify username and password/key
4. Ensure server allows SSH connections

**Problem**: "Host key verification failed"

**Solution**: First connection to server requires accepting host key

### SFTP Issues

**Problem**: Cannot upload files

**Solutions**:
1. Check write permissions on remote directory
2. Verify disk space on server
3. Check file size limits

**Problem**: Files not showing

**Solution**: Click refresh button to reload directory

### App Issues

**Problem**: Forgot master password

**Solution**: Delete data directory and restart (loses all saved servers)

**Problem**: Google sync not working

**Solutions**:
1. Check internet connection
2. Re-authorize Google account
3. Check Google Drive storage quota

---

## Contributing

### How to Contribute

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

### Development Guidelines

- Write tests for new features
- Update documentation
- Follow existing code style
- Keep commits atomic and descriptive

### Reporting Issues

- Use GitHub Issues
- Include steps to reproduce
- Include system information
- Attach logs if available

---

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- [dartssh2](https://pub.dev/packages/dartssh2) - SSH/SFTP implementation
- [xterm](https://pub.dev/packages/xterm) - Terminal emulator
- [Flutter](https://flutter.dev) - UI framework

---

**MixTerm** - Professional SSH/SFTP Client

Made with Flutter
