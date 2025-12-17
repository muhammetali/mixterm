import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/server_provider.dart';
import '../utils/theme.dart';
import 'server_tile.dart';

class ServerList extends StatelessWidget {
  final VoidCallback onAddServer;

  const ServerList({super.key, required this.onAddServer});

  @override
  Widget build(BuildContext context) {
    return Consumer<ServerProvider>(
      builder: (context, serverProvider, _) {
        if (serverProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (serverProvider.servers.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          children: [
            _buildSearchAndAdd(context),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: serverProvider.servers.length,
                itemBuilder: (context, index) {
                  return ServerTile(
                    server: serverProvider.servers[index],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchAndAdd(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search servers...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: ElevatedButton.icon(
              onPressed: onAddServer,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dns_outlined,
            size: 48,
            color: AppTheme.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No servers yet',
            style: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: onAddServer,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Server'),
          ),
        ],
      ),
    );
  }
}
