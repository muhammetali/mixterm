import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transfer_provider.dart';
import '../utils/theme.dart';

class TransferIndicator extends StatefulWidget {
  const TransferIndicator({super.key});

  @override
  State<TransferIndicator> createState() => _TransferIndicatorState();
}

class _TransferIndicatorState extends State<TransferIndicator> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<TransferProvider>(
      builder: (context, provider, _) {
        final tasks = provider.tasks;
        if (tasks.isEmpty) return const SizedBox.shrink();

        final activeCount = provider.activeTasks.length;
        
        return Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              color: AppTheme.cardColor,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 300,
                height: _expanded ? 300 : 48,
                constraints: BoxConstraints(
                  maxHeight: _expanded ? 400 : 48,
                  minHeight: 48,
                ),
                child: Column(
                  mainAxisSize: _expanded ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    // Header
                    InkWell(
                      onTap: () => setState(() => _expanded = !_expanded),
                      borderRadius: BorderRadius.vertical(
                        top: const Radius.circular(8),
                        bottom: Radius.circular(_expanded ? 0 : 8),
                      ),
                      child: SizedBox(
                        height: 48, // Fixed height for header to prevent overflow
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              if (activeCount > 0)
                                SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                                )
                              else
                                const Icon(Icons.check_circle, size: 16, color: AppTheme.successColor),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  activeCount > 0 ? '$activeCount Active Transfers' : 'Transfers Completed',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Spacer(),
                               if (!_expanded && activeCount == 0)
                                 IconButton(
                                   icon: const Icon(Icons.close, size: 16),
                                   padding: EdgeInsets.zero,
                                   constraints: const BoxConstraints(),
                                   onPressed: provider.clearCompleted,
                                 )
                               else
                                 Icon(_expanded ? Icons.expand_more : Icons.expand_less),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_expanded)
                      Expanded(
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: tasks.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                task.type == TransferType.upload ? Icons.upload : Icons.download,
                                size: 16,
                                color: _getStatusColor(task.status),
                              ),
                              title: Text(task.filename, overflow: TextOverflow.ellipsis),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (task.status == TransferStatus.inProgress)
                                    LinearProgressIndicator(value: task.progress, backgroundColor: AppTheme.borderColor),
                                  Text(
                                    task.status == TransferStatus.failed 
                                        ? task.error ?? 'Failed' 
                                        : _getStatusText(task),
                                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                              trailing: task.status == TransferStatus.inProgress || task.status == TransferStatus.pending
                                  ? IconButton(
                                      icon: const Icon(Icons.cancel, size: 14, color: AppTheme.errorColor),
                                      onPressed: () => provider.cancelTransfer(task.id),
                                      tooltip: 'Cancel Transfer',
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.close, size: 14),
                                      onPressed: () => provider.removeTask(task.id),
                                    ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(TransferStatus status) {
    switch (status) {
      case TransferStatus.inProgress: return AppTheme.primaryColor;
      case TransferStatus.completed: return AppTheme.successColor;
      case TransferStatus.failed: return AppTheme.errorColor;
      default: return AppTheme.textSecondary;
    }
  }

  String _getStatusText(TransferTask task) {
    if (task.status == TransferStatus.completed) return 'Completed';
    if (task.status == TransferStatus.inProgress) {
      final percentage = (task.progress * 100).toStringAsFixed(0);
      return '$percentage%';
    }
    return task.status.name;
  }
}
