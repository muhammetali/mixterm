# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MixTerm is a professional SSH/SFTP client built with Flutter for Linux and macOS. It provides multi-tab terminal sessions, visual SFTP file browser, AES-256 encrypted credential storage, and Google Drive cloud sync.

## Build & Run Commands

```bash
# Install dependencies
flutter pub get

# Run in development
flutter run -d linux    # Linux
flutter run -d macos    # macOS

# Release build
flutter build linux --release
flutter build macos --release

# Install (Linux only)
./scripts/install_linux.sh
```

## Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/models/server_test.dart

# Run tests matching name
flutter test --name "Server Model"

# Coverage report
flutter test --coverage
```

## Code Quality

```bash
# Analyze for issues
flutter analyze

# Format code
dart format .
```

## Architecture

### State Management Pattern
Provider pattern with ChangeNotifier. Data flow: Widget → Provider → Service → External API

### Provider Initialization Order (main.dart)
1. StorageService - Encrypted credential storage
2. AuthService - Google OAuth
3. SettingsProvider - User preferences
4. ServerProvider - Server list & cloud sync
5. ConnectionProvider - Active SSH/SFTP connections
6. TabProvider - Tab lifecycle & terminal instances
7. TransferProvider - File transfer progress

### Directory Structure
- `lib/models/` - Data classes with `toJson()`/`fromJson()` (Server, TabSession, Settings)
- `lib/providers/` - State management (ChangeNotifier classes)
- `lib/services/` - Business logic (SshService, SftpService, StorageService, SyncService, AuthService, CryptoService)
- `lib/screens/` - Full-page screens (HomeScreen, LoginScreen, SettingsScreen)
- `lib/widgets/` - Reusable UI components
- `lib/utils/` - Theme, constants, terminal color schemes
- `test/` - Mirrors lib/ structure

### Key Dependencies
- `dartssh2` - SSH/SFTP protocol
- `xterm` - Terminal emulator widget
- `provider` - State management
- `encrypt` + `pointycastle` - AES-256 encryption
- `googleapis` + `googleapis_auth` - Google Drive sync

### Storage Locations
- Linux: `~/.local/share/mixterm/`
- macOS: `~/Library/Application Support/mixterm/`

## Key Technical Details

### Terminal Configuration
- xterm-compatible with 256 color support
- Default scrollback: 10,000 lines
- Default font: JetBrainsMono (bundled in assets/fonts/)
- Mouse support enabled

### Encryption
- AES-256 via `encrypt` package
- Master password derives encryption keys
- All credentials (passwords, SSH keys, passphrases) encrypted at rest

### TabProvider Terminal Management
Stores terminal instances in maps keyed by tab ID:
- `Map<String, Terminal> terminals`
- `Map<String, TerminalController> terminalControllers`

### Server Model Key Fields
```dart
id, name, host, port, username, password?, privateKey?, passphrase?, authType (password|key), group?
```

### TabSession Model
```dart
id, serverId?, type (ssh|sftp), title, currentPath, isConnected
```
