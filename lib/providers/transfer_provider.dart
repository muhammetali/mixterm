import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

enum TransferType { upload, download }
enum TransferStatus { pending, inProgress, completed, failed, cancelled }

class TransferTask {
  final String id;
  final String filename;
  final TransferType type;
  final int totalBytes;
  int transferredBytes;
  TransferStatus status;
  final String? error;
  final DateTime startTime;
  DateTime? endTime;

  TransferTask({
    required this.id,
    required this.filename,
    required this.type,
    this.totalBytes = 0,
    this.transferredBytes = 0,
    this.status = TransferStatus.pending,
    this.error,
    DateTime? startTime,
  }) : startTime = startTime ?? DateTime.now();

  double get progress => totalBytes > 0 ? transferredBytes / totalBytes : 0.0;
  
  TransferTask copyWith({
    int? transferredBytes,
    TransferStatus? status,
    String? error,
    DateTime? endTime,
  }) {
    return TransferTask(
      id: id,
      filename: filename,
      type: type,
      totalBytes: totalBytes,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      status: status ?? this.status,
      error: error ?? this.error,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}

class TransferProvider extends ChangeNotifier {
    final List<TransferTask> _tasks = [];
    final _uuid = const Uuid();
    // Map to hold cancellation callbacks for active tasks
    final Map<String, VoidCallback> _cancelCallbacks = {};
  
    List<TransferTask> get tasks => List.unmodifiable(_tasks);
  
    // ... existing getters
  
    String startTransfer(String filename, TransferType type, {int totalBytes = 0, VoidCallback? onCancel}) {
      final task = TransferTask(
        id: _uuid.v4(),
        filename: filename,
        type: type,
        totalBytes: totalBytes,
        status: TransferStatus.inProgress,
      );
      _tasks.insert(0, task);
      if (onCancel != null) {
        _cancelCallbacks[task.id] = onCancel;
      }
      notifyListeners();
      return task.id;
    }
  
    void cancelTransfer(String taskId) {
      if (_cancelCallbacks.containsKey(taskId)) {
        _cancelCallbacks[taskId]?.call();
        _cancelCallbacks.remove(taskId);
      }
      
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        _tasks[index] = _tasks[index].copyWith(
          status: TransferStatus.failed, // Or create a dedicated 'cancelled' status
          error: 'Cancelled by user',
          endTime: DateTime.now(),
        );
        notifyListeners();
        
        // Remove from list after a delay (optional, consistent with completeTransfer)
         Future.delayed(const Duration(seconds: 2), () {
          removeTask(taskId);
        });
      }
    }
  void updateProgress(String taskId, int transferred, int total) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      // Only update if changed significantly to reduce rebuilds
      // Or simply update
      _tasks[index] = _tasks[index].copyWith(
        transferredBytes: transferred,
      );
      // We don't update totalBytes here as it's usually fixed, but could be added if needed
      notifyListeners();
    }
  }

  void completeTransfer(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(
        status: TransferStatus.completed,
        transferredBytes: _tasks[index].totalBytes, // Ensure 100%
        endTime: DateTime.now(),
      );
      notifyListeners();
      
      // Auto-remove completed tasks after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        removeTask(taskId);
      });
    }
  }

  void failTransfer(String taskId, String error) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(
        status: TransferStatus.failed,
        error: error,
        endTime: DateTime.now(),
      );
      notifyListeners();
    }
  }

  void removeTask(String taskId) {
    _tasks.removeWhere((t) => t.id == taskId);
    notifyListeners();
  }
  
  void clearCompleted() {
    _tasks.removeWhere((t) => t.status == TransferStatus.completed);
    notifyListeners();
  }
}
