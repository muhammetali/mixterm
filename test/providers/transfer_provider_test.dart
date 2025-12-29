import 'package:flutter_test/flutter_test.dart';
import 'package:mixterm/providers/transfer_provider.dart';

void main() {
  late TransferProvider provider;

  setUp(() {
    provider = TransferProvider();
  });

  group('TransferProvider Tests', () {
    test('startTransfer adds a task and returns ID', () {
      final id = provider.startTransfer('test.txt', TransferType.upload, totalBytes: 100);
      
      expect(provider.tasks.length, 1);
      expect(provider.tasks.first.id, id);
      expect(provider.tasks.first.status, TransferStatus.inProgress);
    });

    test('updateProgress updates transferred bytes', () {
      final id = provider.startTransfer('test.txt', TransferType.download, totalBytes: 100);
      
      provider.updateProgress(id, 50, 100);
      
      expect(provider.tasks.first.transferredBytes, 50);
      expect(provider.tasks.first.progress, 0.5);
    });

    test('completeTransfer marks task as completed', () {
      final id = provider.startTransfer('test.txt', TransferType.upload, totalBytes: 100);
      
      provider.completeTransfer(id);
      
      expect(provider.tasks.first.status, TransferStatus.completed);
      expect(provider.tasks.first.transferredBytes, 100);
      expect(provider.tasks.first.endTime, isNotNull);
    });

    test('failTransfer marks task as failed with error', () {
      final id = provider.startTransfer('test.txt', TransferType.upload);
      
      provider.failTransfer(id, 'Network error');
      
      expect(provider.tasks.first.status, TransferStatus.failed);
      expect(provider.tasks.first.error, 'Network error');
    });

    test('cancelTransfer triggers callback and updates status', () {
      bool isCancelled = false;
      final id = provider.startTransfer(
        'test.txt', 
        TransferType.download,
        onCancel: () => isCancelled = true,
      );

      provider.cancelTransfer(id);

      expect(isCancelled, true);
      expect(provider.tasks.first.status, TransferStatus.failed);
      expect(provider.tasks.first.error, 'Cancelled by user');
    });

    test('removeTask removes the task from list', () {
      final id = provider.startTransfer('test.txt', TransferType.upload);
      expect(provider.tasks.length, 1);

      provider.removeTask(id);
      expect(provider.tasks.length, 0);
    });

    test('clearCompleted removes only completed tasks', () {
      final id1 = provider.startTransfer('active.txt', TransferType.upload);
      final id2 = provider.startTransfer('completed.txt', TransferType.upload);
      
      provider.completeTransfer(id2);
      
      expect(provider.tasks.length, 2);
      
      provider.clearCompleted();
      
      expect(provider.tasks.length, 1);
      expect(provider.tasks.first.id, id1);
    });
  });
}
