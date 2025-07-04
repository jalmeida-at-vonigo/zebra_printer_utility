import 'package:flutter/material.dart';
import 'package:zebrautil/internal/operation_manager.dart';

/// Widget to display operation logs with colors and details
class OperationLogPanel extends StatefulWidget {
  final List<OperationLogEntry> logs;
  final VoidCallback? onClearLogs;

  const OperationLogPanel({
    super.key,
    required this.logs,
    this.onClearLogs,
  });

  @override
  State<OperationLogPanel> createState() => _OperationLogPanelState();
}

class _OperationLogPanelState extends State<OperationLogPanel> {
  final ScrollController _scrollController = ScrollController();
  bool _showDetails = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.list_alt, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Operation Log (${widget.logs.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Switch(
                      value: _showDetails,
                      onChanged: (value) {
                        setState(() {
                          _showDetails = value;
                        });
                      },
                    ),
                    const Text('Details'),
                    const SizedBox(width: 8),
                    if (widget.onClearLogs != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: widget.onClearLogs,
                        tooltip: 'Clear logs',
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          // Log entries
          Expanded(
            child: widget.logs.isEmpty
                ? const Center(
                    child: Text(
                      'No operations logged yet',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: widget.logs.length,
                    itemBuilder: (context, index) {
                      final log = widget.logs[widget.logs.length - 1 - index]; // Reverse order
                      return _buildLogEntry(log);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(OperationLogEntry log) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ExpansionTile(
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: log.statusColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              log.statusIcon,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                log.method,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: log.statusColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                log.status.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ID: ${log.operationId}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              _formatTimestamp(log.timestamp),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (log.duration != null)
              Text(
                'Duration: ${log.duration!.inMilliseconds}ms',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        children: _showDetails ? [_buildLogDetails(log)] : [],
      ),
    );
  }

  Widget _buildLogDetails(OperationLogEntry log) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (log.arguments != null && log.arguments!.isNotEmpty) ...[
            const Text(
              'Arguments:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                log.arguments.toString(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
          ],
          
          if (log.result != null) ...[
            const Text(
              'Result:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                log.result.toString(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
          ],
          
          if (log.error != null) ...[
            const Text(
              'Error:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                log.error!,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          
          if (log.channelName != null) ...[
            const Text(
              'Channel:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                log.channelName!,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
          ],
          
          if (log.stackTrace != null) ...[
            const Text(
              'Stack Trace:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                log.stackTrace.toString(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
} 