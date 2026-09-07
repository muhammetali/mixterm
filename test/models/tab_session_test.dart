import 'package:flutter_test/flutter_test.dart';
import 'package:mixterm/models/tab_session.dart';

void main() {
  group('TabSession Model', () {
    group('Constructor', () {
      test('creates SSH tab with default title', () {
        final tab = TabSession(
          serverId: 'server-1',
          type: TabType.ssh,
        );

        expect(tab.type, TabType.ssh);
        expect(tab.title, 'SSH Terminal');
        expect(tab.serverId, 'server-1');
        expect(tab.id, isNotEmpty);
      });

      test('creates SFTP tab with default title', () {
        final tab = TabSession(
          serverId: 'server-1',
          type: TabType.sftp,
        );

        expect(tab.type, TabType.sftp);
        expect(tab.title, 'SFTP Browser');
      });

      test('accepts custom title', () {
        final tab = TabSession(
          serverId: 'server-1',
          type: TabType.ssh,
          title: 'Production Server - SSH',
        );

        expect(tab.title, 'Production Server - SSH');
      });

      test('generates unique IDs', () {
        final tab1 = TabSession(type: TabType.ssh, serverId: 'server-1');
        final tab2 = TabSession(type: TabType.ssh, serverId: 'server-2');

        expect(tab1.id, isNot(tab2.id));
      });

      test('uses provided ID if given', () {
        final tab = TabSession(
          id: 'custom-tab-id',
          type: TabType.ssh,
          serverId: 'server-1',
        );

        expect(tab.id, 'custom-tab-id');
      });

      test('sets default currentPath to /', () {
        final tab = TabSession(type: TabType.sftp, serverId: 'server-1');

        expect(tab.currentPath, '/');
      });

      test('accepts custom currentPath', () {
        final tab = TabSession(
          type: TabType.sftp,
          serverId: 'server-1',
          currentPath: '/home/user',
        );

        expect(tab.currentPath, '/home/user');
      });

      test('sets isConnected to false by default', () {
        final tab = TabSession(
          serverId: 'server-1',
          type: TabType.ssh,
        );

        expect(tab.isConnected, false);
      });

      test('sets createdAt automatically', () {
        final before = DateTime.now();
        final tab = TabSession(type: TabType.ssh, serverId: 'server-1');
        final after = DateTime.now();

        expect(tab.createdAt.isAfter(before.subtract(const Duration(seconds: 1))), true);
        expect(tab.createdAt.isBefore(after.add(const Duration(seconds: 1))), true);
      });
    });

    group('copyWith', () {
      late TabSession originalTab;

      setUp(() {
        originalTab = TabSession(
          id: 'test-tab',
          serverId: 'test-server',
          type: TabType.ssh,
          title: 'Original Title',
          currentPath: '/original',
          isConnected: false,
        );
      });

      test('copies with new title', () {
        final copied = originalTab.copyWith(title: 'New Title');

        expect(copied.title, 'New Title');
        expect(copied.id, originalTab.id);
        expect(copied.type, originalTab.type);
      });

      test('copies with new currentPath', () {
        final copied = originalTab.copyWith(currentPath: '/new/path');

        expect(copied.currentPath, '/new/path');
        expect(copied.title, originalTab.title);
      });

      test('copies with new isConnected', () {
        final copied = originalTab.copyWith(isConnected: true);

        expect(copied.isConnected, true);
        expect(copied.id, originalTab.id);
      });

      test('preserves id, serverId, and type', () {
        final copied = originalTab.copyWith(
          title: 'Changed',
          currentPath: '/changed',
          isConnected: true,
        );

        expect(copied.id, originalTab.id);
        expect(copied.serverId, originalTab.serverId);
        expect(copied.type, originalTab.type);
      });

      test('handles partial updates', () {
        final copied = originalTab.copyWith(isConnected: true);

        expect(copied.isConnected, true);
        expect(copied.title, originalTab.title);
        expect(copied.currentPath, originalTab.currentPath);
      });
    });

    group('JSON Serialization', () {
      test('toJson includes all fields', () {
        final tab = TabSession(
          id: 'json-tab-id',
          serverId: 'json-server-id',
          type: TabType.sftp,
          title: 'JSON Tab',
          currentPath: '/var/www',
        );

        final json = tab.toJson();

        expect(json['id'], 'json-tab-id');
        expect(json['serverId'], 'json-server-id');
        // The persisted wire format for `type` is the enum's *index*, so
        // TabType's declaration order is part of the saved-data contract:
        // reordering or inserting a value silently reinterprets every tab
        // already on disk (an ssh tab reopens as sftp). Pinned to the
        // literals on purpose — comparing to `TabType.sftp.index` would
        // move along with the enum and never catch that.
        expect(json['type'], 1);
        expect(TabType.ssh.index, 0);
        expect(TabType.sftp.index, 1);
        expect(json['title'], 'JSON Tab');
        expect(json['currentPath'], '/var/www');
        expect(json['createdAt'], isNotNull);
      });

      test('toJson handles null serverId', () {
        final tab = TabSession(type: TabType.ssh);

        final json = tab.toJson();

        expect(json['serverId'], isNull);
      });

      test('fromJson restores tab correctly', () {
        final original = TabSession(
          id: 'restore-tab',
          serverId: 'restore-server',
          type: TabType.ssh,
          title: 'Restore Tab',
          currentPath: '/home',
        );

        final json = original.toJson();
        final restored = TabSession.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.serverId, original.serverId);
        expect(restored.type, original.type);
        expect(restored.title, original.title);
        expect(restored.currentPath, original.currentPath);
      });

      test('fromJson handles SSH type', () {
        final json = {
          'id': 'ssh-tab',
          'serverId': 'server',
          'type': 0, // TabType.ssh.index
          'title': 'SSH Tab',
          'currentPath': '/',
        };

        final tab = TabSession.fromJson(json);

        expect(tab.type, TabType.ssh);
      });

      test('fromJson handles SFTP type', () {
        final json = {
          'id': 'sftp-tab',
          'serverId': 'server',
          'type': 1, // TabType.sftp.index
          'title': 'SFTP Tab',
          'currentPath': '/',
        };

        final tab = TabSession.fromJson(json);

        expect(tab.type, TabType.sftp);
      });

      test('fromJson uses default currentPath when null', () {
        final json = {
          'id': 'default-path-tab',
          'type': 0,
          'title': 'Tab',
        };

        final tab = TabSession.fromJson(json);

        expect(tab.currentPath, '/');
      });
    });

  });
}
