import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mixterm/models/server.dart';
import 'package:mixterm/providers/server_provider.dart';
import 'package:mixterm/services/storage_service.dart';
import 'package:mixterm/services/sync_service.dart';

class MockStorageService extends Mock implements StorageService {}
class MockSyncService extends Mock implements SyncService {}

void main() {
  late MockStorageService mockStorageService;
  late MockSyncService mockSyncService;
  late ServerProvider provider;

  setUpAll(() {
    registerFallbackValue(<Server>[]);
  });

  setUp(() {
    mockStorageService = MockStorageService();
    mockSyncService = MockSyncService();
    when(() => mockStorageService.saveServers(any(), createBackup: any(named: 'createBackup')))
        .thenAnswer((_) async => true);

    provider = ServerProvider(mockStorageService, mockSyncService);
  });

  Server server(String id, {String? group}) => Server(
        id: id,
        name: id,
        host: 'host-$id',
        username: 'user',
        group: group,
      );

  group('groups', () {
    test('is empty when no server has a group set', () async {
      await provider.addServer(server('s1'));
      await provider.addServer(server('s2', group: ''));

      expect(provider.groups, isEmpty);
    });

    test('lists each distinct group exactly once, sorted alphabetically', () async {
      await provider.addServer(server('s1', group: 'Staging'));
      await provider.addServer(server('s2', group: 'Production'));
      await provider.addServer(server('s3', group: 'Staging'));

      expect(provider.groups, ['Production', 'Staging']);
    });

    test('ignores servers with a null or empty group', () async {
      await provider.addServer(server('s1', group: 'Team A'));
      await provider.addServer(server('s2'));
      await provider.addServer(server('s3', group: ''));

      expect(provider.groups, ['Team A']);
    });
  });

  group('getServersByGroup', () {
    test('null returns servers with no group (null or empty)', () async {
      final ungrouped1 = server('s1');
      final ungrouped2 = server('s2', group: '');
      final grouped = server('s3', group: 'Team A');
      await provider.addServer(ungrouped1);
      await provider.addServer(ungrouped2);
      await provider.addServer(grouped);

      final result = provider.getServersByGroup(null);

      expect(result, containsAll([ungrouped1, ungrouped2]));
      expect(result, isNot(contains(grouped)));
    });

    test('a group name returns only servers in that exact group', () async {
      final teamA = server('s1', group: 'Team A');
      final teamB = server('s2', group: 'Team B');
      await provider.addServer(teamA);
      await provider.addServer(teamB);

      expect(provider.getServersByGroup('Team A'), [teamA]);
      expect(provider.getServersByGroup('Team B'), [teamB]);
    });

    test('an unknown group name returns an empty list', () async {
      await provider.addServer(server('s1', group: 'Team A'));

      expect(provider.getServersByGroup('No Such Group'), isEmpty);
    });
  });
}
