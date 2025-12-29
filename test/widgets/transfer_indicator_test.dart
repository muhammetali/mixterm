import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mixterm/providers/transfer_provider.dart';
import 'package:mixterm/widgets/transfer_indicator.dart';

void main() {
  group('TransferIndicator Widget Tests', () {
    testWidgets('Shows nothing when task list is empty', (WidgetTester tester) async {
      final provider = TransferProvider();
      
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TransferProvider>.value(
            value: provider,
            child: const Scaffold(body: TransferIndicator()),
          ),
        ),
      );

      // Should be invisible (SizedBox.shrink)
      // Check for absence of the specific container content
      expect(find.text('Active Transfers'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Shows summary when transfer starts', (WidgetTester tester) async {
      final provider = TransferProvider();
      provider.startTransfer('test.txt', TransferType.upload);
      
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TransferProvider>.value(
            value: provider,
            child: const Scaffold(body: TransferIndicator()),
          ),
        ),
      );

      // We expect one Material widget from Scaffold, and maybe one from our widget.
      // Better to check for specific content.
      expect(find.text('1 Active Transfers'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Expands to show details and progress', (WidgetTester tester) async {
      final provider = TransferProvider();
      // Start a task with known progress
      final id = provider.startTransfer('important_file.zip', TransferType.download, totalBytes: 100);
      provider.updateProgress(id, 50, 100);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TransferProvider>.value(
            value: provider,
            child: const Scaffold(body: TransferIndicator()),
          ),
        ),
      );

      // Initial state: Collapsed, file name not visible
      expect(find.text('important_file.zip'), findsNothing);

      // Act: Tap to expand
      await tester.tap(find.text('1 Active Transfers'));
      
      // Advance frames manually to avoid timeout from CircularProgressIndicator
      await tester.pump(); 
      await tester.pump(const Duration(milliseconds: 300));

      // Assert: Details visible
      expect(find.text('important_file.zip'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget); // Cancel button
    });

    testWidgets('Shows completed state correctly', (WidgetTester tester) async {
      final provider = TransferProvider();
      final id = provider.startTransfer('done.txt', TransferType.upload);
      provider.completeTransfer(id);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TransferProvider>.value(
            value: provider,
            child: const Scaffold(body: TransferIndicator()),
          ),
        ),
      );

      expect(find.text('Transfers Completed'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Advance time to allow the auto-remove timer (5s) to complete
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
