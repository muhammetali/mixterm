import 'package:flutter_test/flutter_test.dart';
import 'package:mixterm/models/server.dart';

void main() {
  group('Server Model', () {
    group('Constructor', () {
      test('creates server with required fields', () {
        final server = Server(
          name: 'Test Server',
          host: '192.168.1.1',
          username: 'root',
        );

        expect(server.name, 'Test Server');
        expect(server.host, '192.168.1.1');
        expect(server.username, 'root');
        expect(server.port, 22); // default
        expect(server.authType, AuthType.password); // default
        expect(server.id, isNotEmpty);
      });

      test('creates server with custom port', () {
        final server = Server(
          name: 'Custom Port Server',
          host: 'example.com',
          username: 'admin',
          port: 2222,
        );

        expect(server.port, 2222);
      });

      test('creates server with password auth', () {
        final server = Server(
          name: 'Password Server',
          host: 'example.com',
          username: 'user',
          password: 'secret123',
          authType: AuthType.password,
        );

        expect(server.password, 'secret123');
        expect(server.authType, AuthType.password);
      });

      test('creates server with key auth', () {
        final server = Server(
          name: 'Key Server',
          host: 'example.com',
          username: 'user',
          privateKey: '-----BEGIN RSA PRIVATE KEY-----\n...',
          passphrase: 'keypass',
          authType: AuthType.key,
        );

        expect(server.privateKey, isNotNull);
        expect(server.passphrase, 'keypass');
        expect(server.authType, AuthType.key);
      });

      test('creates server with group', () {
        final server = Server(
          name: 'Grouped Server',
          host: 'example.com',
          username: 'user',
          group: 'Production',
        );

        expect(server.group, 'Production');
      });

      test('generates unique IDs', () {
        final server1 = Server(
          name: 'Server 1',
          host: 'host1.com',
          username: 'user1',
        );
        final server2 = Server(
          name: 'Server 2',
          host: 'host2.com',
          username: 'user2',
        );

        expect(server1.id, isNot(server2.id));
      });

      test('uses provided ID if given', () {
        final server = Server(
          id: 'custom-id-123',
          name: 'Custom ID Server',
          host: 'example.com',
          username: 'user',
        );

        expect(server.id, 'custom-id-123');
      });

      test('sets timestamps automatically', () {
        final before = DateTime.now();
        final server = Server(
          name: 'Timestamped Server',
          host: 'example.com',
          username: 'user',
        );
        final after = DateTime.now();

        expect(server.createdAt.isAfter(before.subtract(const Duration(seconds: 1))), true);
        expect(server.createdAt.isBefore(after.add(const Duration(seconds: 1))), true);
      });
    });

    group('copyWith', () {
      late Server originalServer;

      setUp(() {
        originalServer = Server(
          id: 'test-id',
          name: 'Original',
          host: 'original.com',
          port: 22,
          username: 'original-user',
          password: 'original-pass',
          authType: AuthType.password,
          group: 'Original Group',
        );
      });

      test('copies with new name', () {
        final copied = originalServer.copyWith(name: 'New Name');

        expect(copied.name, 'New Name');
        expect(copied.id, originalServer.id);
        expect(copied.host, originalServer.host);
      });

      test('copies with new host', () {
        final copied = originalServer.copyWith(host: 'new.com');

        expect(copied.host, 'new.com');
        expect(copied.name, originalServer.name);
      });

      test('copies with new port', () {
        final copied = originalServer.copyWith(port: 2222);

        expect(copied.port, 2222);
      });

      test('copies with new auth type', () {
        final copied = originalServer.copyWith(
          authType: AuthType.key,
          privateKey: '-----BEGIN KEY-----',
        );

        expect(copied.authType, AuthType.key);
        expect(copied.privateKey, '-----BEGIN KEY-----');
      });

      test('preserves id on copy', () {
        final copied = originalServer.copyWith(name: 'Different');

        expect(copied.id, originalServer.id);
      });

      test('updates updatedAt on copy', () {
        final copied = originalServer.copyWith(name: 'Updated');

        expect(copied.updatedAt.isAfter(originalServer.createdAt) ||
               copied.updatedAt.isAtSameMomentAs(originalServer.createdAt), true);
      });
    });

    group('JSON Serialization', () {
      test('toJson includes all fields', () {
        final server = Server(
          id: 'json-test-id',
          name: 'JSON Server',
          host: 'json.example.com',
          port: 2222,
          username: 'jsonuser',
          password: 'jsonpass',
          authType: AuthType.password,
          group: 'JSON Group',
        );

        final json = server.toJson();

        expect(json['id'], 'json-test-id');
        expect(json['name'], 'JSON Server');
        expect(json['host'], 'json.example.com');
        expect(json['port'], 2222);
        expect(json['username'], 'jsonuser');
        expect(json['password'], 'jsonpass');
        expect(json['authType'], 'password');
        expect(json['group'], 'JSON Group');
        expect(json['createdAt'], isNotNull);
        expect(json['updatedAt'], isNotNull);
      });

      test('toJson handles null fields', () {
        final server = Server(
          name: 'Minimal',
          host: 'example.com',
          username: 'user',
        );

        final json = server.toJson();

        expect(json['password'], isNull);
        expect(json['privateKey'], isNull);
        expect(json['passphrase'], isNull);
        expect(json['group'], isNull);
      });

      test('fromJson restores server correctly', () {
        final original = Server(
          id: 'restore-test',
          name: 'Restore Server',
          host: 'restore.com',
          port: 3333,
          username: 'restoreuser',
          password: 'restorepass',
          authType: AuthType.password,
          group: 'Restore Group',
        );

        final json = original.toJson();
        final restored = Server.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.host, original.host);
        expect(restored.port, original.port);
        expect(restored.username, original.username);
        expect(restored.password, original.password);
        expect(restored.authType, original.authType);
        expect(restored.group, original.group);
      });

      test('fromJson handles key auth', () {
        final json = {
          'id': 'key-server',
          'name': 'Key Auth Server',
          'host': 'key.example.com',
          'port': 22,
          'username': 'keyuser',
          'privateKey': '-----BEGIN KEY-----',
          'passphrase': 'keypass',
          'authType': 'key',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        };

        final server = Server.fromJson(json);

        expect(server.authType, AuthType.key);
        expect(server.privateKey, '-----BEGIN KEY-----');
        expect(server.passphrase, 'keypass');
      });

      test('fromJson uses default port when missing', () {
        final json = {
          'id': 'default-port',
          'name': 'Default Port Server',
          'host': 'example.com',
          'username': 'user',
          'authType': 'password',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        };

        final server = Server.fromJson(json);

        expect(server.port, 22);
      });

      test('fromJson handles unknown authType gracefully', () {
        final json = {
          'id': 'unknown-auth',
          'name': 'Unknown Auth Server',
          'host': 'example.com',
          'username': 'user',
          'authType': 'unknownType',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        };

        final server = Server.fromJson(json);

        expect(server.authType, AuthType.password); // default fallback
      });
    });

    group('toString', () {
      test('returns readable format', () {
        final server = Server(
          name: 'My Server',
          host: 'myserver.com',
          port: 22,
          username: 'user',
        );

        expect(server.toString(), 'Server(My Server, myserver.com:22)');
      });
    });

    group('AuthType Enum', () {
      test('has password and key values', () {
        expect(AuthType.values, contains(AuthType.password));
        expect(AuthType.values, contains(AuthType.key));
        expect(AuthType.values.length, 2);
      });
    });
  });
}
