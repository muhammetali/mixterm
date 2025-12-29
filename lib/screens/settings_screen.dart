import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/auth_service.dart';
import '../utils/terminal_themes.dart';
import '../utils/theme.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSection(
                'Terminal',
                [
                  _buildSwitchTile(
                    'Copy on select',
                    'Automatically copy selected text to clipboard',
                    settings.copyOnSelect,
                    (value) => settings.setCopyOnSelect(value),
                  ),
                  _buildSwitchTile(
                    'Paste on right-click',
                    'Paste clipboard content when right-clicking',
                    settings.pasteOnRightClick,
                    (value) => settings.setPasteOnRightClick(value),
                  ),
                  _buildSwitchTile(
                    'Show scrollbar',
                    'Display scrollbar in terminal',
                    settings.showScrollbar,
                    (value) => settings.setShowScrollbar(value),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                'Appearance',
                [
                  _buildDropdownTile<String>(
                    'Font family',
                    settings.fontFamily,
                    AppConstants.fontFamilies,
                    (value) => settings.setFontFamily(value!),
                  ),
                  _buildDropdownTile<String>(
                    'Terminal theme',
                    settings.terminalTheme,
                    TerminalThemes.themes.map((t) => t.name).toList(),
                    (value) => settings.setTerminalTheme(value!),
                  ),
                  _buildSliderTile(
                    'Font size',
                    settings.fontSize,
                    AppConstants.minFontSize.toDouble(),
                    AppConstants.maxFontSize.toDouble(),
                    (value) => settings.setFontSize(value.round()),
                  ),
                  _buildSliderTile(
                    'Terminal opacity',
                    (settings.terminalOpacity * 100).round(),
                    50,
                    100,
                    (value) => settings.setTerminalOpacity(value / 100),
                  ),
                  _buildSliderTile(
                    'Scrollback lines',
                    settings.scrollbackLines,
                    AppConstants.minScrollbackLines.toDouble(),
                    AppConstants.maxScrollbackLines.toDouble(),
                    (value) => settings.setScrollbackLines(value.round()),
                    divisions: 99,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                'Account',
                [
                  Consumer<AuthService>(
                    builder: (context, auth, _) {
                      if (auth.isSignedIn) {
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: auth.userPhoto != null
                                ? NetworkImage(auth.userPhoto!)
                                : null,
                            child: auth.userPhoto == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(auth.userName ?? 'Unknown'),
                          subtitle: Text(auth.userEmail ?? ''),
                          trailing: TextButton(
                            onPressed: () async {
                              await auth.signOut();
                            },
                            child: const Text('Sign out'),
                          ),
                        );
                      }
                      return ListTile(
                        leading: const Icon(Icons.cloud_off),
                        title: const Text('Not signed in'),
                        subtitle:
                            const Text('Sign in to sync servers across devices'),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            await auth.signIn();
                          },
                          child: const Text('Sign in'),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                'About',
                [
                  ListTile(
                    title: const Text('Version'),
                    subtitle: Text(AppConstants.appVersion),
                  ),
                  const ListTile(
                    title: Text('MixTerm'),
                    subtitle: Text('SSH/SFTP client for Linux and macOS'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        Card(
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.primaryColor,
    );
  }

  Widget _buildSliderTile(
    String title,
    num value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    int? divisions,
  }) {
    return ListTile(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text(
            value.toString(),
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      subtitle: Slider(
        value: value.toDouble().clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
        activeColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildDropdownTile<T>(
    String title,
    T value,
    List<T> items,
    ValueChanged<T?> onChanged,
  ) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<T>(
        value: value,
        items: items.map((item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(item.toString()),
          );
        }).toList(),
        onChanged: onChanged,
        underline: const SizedBox(),
        dropdownColor: AppTheme.surfaceColor,
        style: const TextStyle(color: AppTheme.primaryColor),
      ),
    );
  }
}
