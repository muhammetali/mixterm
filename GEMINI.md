# MixTerm

## Project Overview

MixTerm is a professional SSH and SFTP client built with Flutter, designed to provide a native desktop experience on **Linux** and **macOS**. It mimics the functionality of tools like Termius, featuring a modern dark UI, multi-tab support, and secure credential management.

### Key Features
*   **SSH Terminal:** Full-featured xterm-compatible terminal with multi-tab support.
*   **SFTP Browser:** Visual file manager for remote servers with drag-and-drop upload support.
*   **Secure Storage:** All credentials are encrypted at rest using AES-256 (via `encrypt` package).
*   **Cloud Sync:** Sync server configurations across devices using Google Drive (via `googleapis`).
*   **Organization:** Group servers for easy management.

### Tech Stack
*   **Framework:** Flutter (Dart)
*   **State Management:** `provider`
*   **SSH/SFTP:** `dartssh2`
*   **Terminal:** `xterm`
*   **Encryption:** `encrypt`, `pointycastle`
*   **Auth/Sync:** `googleapis`, `googleapis_auth`

## Building and Running

### Prerequisites
*   **Flutter SDK:** Version 3.x or higher
*   **Linux:** GTK 3.0 development libraries (`libgtk-3-dev`)
*   **macOS:** Xcode command line tools

### Setup
1.  **Get dependencies:**
    ```bash
    flutter pub get
    ```

### Running in Development
To run the app in debug mode:

*   **Linux:**
    ```bash
    flutter run -d linux
    ```
*   **macOS:**
    ```bash
    flutter run -d macos
    ```

### Building for Release
*   **Linux:**
    ```bash
    flutter build linux --release
    ```
*   **macOS:**
    ```bash
    flutter build macos --release
    ```

### Installation (Linux)
A helper script is available to build and install the app to `~/.local/share/applications`:
```bash
./scripts/install_linux.sh
```

## Development Conventions

### Project Structure
The project follows a feature-layer separation pattern:

*   `lib/models/`: Data classes (e.g., `Server`, `TabSession`).
*   `lib/providers/`: State management using `ChangeNotifier` (e.g., `ServerProvider`, `ConnectionProvider`).
*   `lib/services/`: Core business logic and external integrations (e.g., `SshService`, `SftpService`, `StorageService`).
*   `lib/screens/`: Full-page application screens.
*   `lib/widgets/`: Reusable UI components.
*   `test/`: Unit and integration tests mirroring the `lib/` structure.

### State Management
*   The app uses **Provider** for dependency injection and state management.
*   Global state is initialized in `main.dart` via `MultiProvider`.
*   **Data Flow:** UI Widgets &rarr; Providers &rarr; Services &rarr; External APIs.

### Code Style
*   Follows standard Dart guidelines.
*   Linting is enforced via `flutter_lints` (defined in `analysis_options.yaml`).
*   **Formatting:** Run `dart format .` before committing.
*   **Analysis:** Run `flutter analyze` to check for issues.

### Testing
*   **Unit Tests:** Run `flutter test` to execute unit tests.
*   **Coverage:** Use `flutter test --coverage` to generate reports.
*   Tests are located in the `test/` directory and should mirror the structure of the source code.

### Configuration
*   **Constants:** App-wide constants are stored in `lib/utils/constants.dart`.
*   **Fonts:** The app uses `JetBrainsMono` as the bundled font for the terminal.
