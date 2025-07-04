import 'package:flutter/material.dart';
import 'package:zebrautil/internal/operation_manager.dart';

/// Compact log widget for displaying operation logs on any screen
class LogWidget extends StatefulWidget {
  final List<OperationLogEntry> logs;
  final VoidCallback? onClearLogs;
  final double height;
  final bool showDetails;

  const LogWidget({
    super.key,
    required this.logs,
    this.onClearLogs,
    this.height = 200,
    this.showDetails = false,
  });

  @override
  State<LogWidget> createState() => _LogWidgetState();
}

class _LogWidgetState extends State<LogWidget> {
  final ScrollController _scrollController = ScrollController();
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _showDetails = widget.showDetails;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: widget.height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.list_alt, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Logs (${widget.logs.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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
                      const Text('Details', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      if (widget.onClearLogs != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: widget.onClearLogs,
                          tooltip: 'Clear logs',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
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
                        'No logs yet',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(4),
                      itemCount: widget.logs.length,
                      itemBuilder: (context, index) {
                        final log = widget.logs[widget.logs.length - 1 - index];
                        return _buildCompactLogEntry(log);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactLogEntry(OperationLogEntry log) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 1),
      child: ExpansionTile(
        dense: true,
        leading: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: log.statusColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              log.statusIcon,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                log.method,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: log.statusColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                log.status.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
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
              _formatTimestamp(log.timestamp),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            if (log.duration != null)
              Text(
                '${log.duration!.inMilliseconds}ms',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
          ],
        ),
        children: _showDetails ? [_buildLogDetails(log)] : [],
      ),
    );
  }

  Widget _buildLogDetails(OperationLogEntry log) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (log.arguments != null && log.arguments!.isNotEmpty) ...[
            const Text(
              'Arguments:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                log.arguments.toString(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
              ),
            ),
            const SizedBox(height: 4),
          ],
          
          if (log.result != null) ...[
            const Text(
              'Result:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                log.result.toString(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
              ),
            ),
            const SizedBox(height: 4),
          ],
          
          if (log.error != null) ...[
            const Text(
              'Error:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                log.error!,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.red),
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

/// Simple log entry for basic logging
class SimpleLogEntry {
  final String message;
  final String level;
  final DateTime timestamp;

  const SimpleLogEntry({
    required this.message,
    required this.level,
    required this.timestamp,
  });
}

/// Simple log widget for basic logging
class SimpleLogWidget extends StatefulWidget {
  final List<SimpleLogEntry> logs;
  final VoidCallback? onClearLogs;
  final double height;

  const SimpleLogWidget({
    super.key,
    required this.logs,
    this.onClearLogs,
    this.height = 150,
  });

  @override
  State<SimpleLogWidget> createState() => _SimpleLogWidgetState();
}

class _SimpleLogWidgetState extends State<SimpleLogWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: widget.height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.list_alt, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Logs (${widget.logs.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  if (widget.onClearLogs != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: widget.onClearLogs,
                      tooltip: 'Clear logs',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
            
            // Log entries
            Expanded(
              child: widget.logs.isEmpty
                  ? const Center(
                      child: Text(
                        'No logs yet',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(4),
                      itemCount: widget.logs.length,
                      itemBuilder: (context, index) {
                        final log = widget.logs[widget.logs.length - 1 - index];
                        return _buildSimpleLogEntry(log);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleLogEntry(SimpleLogEntry log) {
    Color statusColor;
    IconData statusIcon;
    
    switch (log.level.toUpperCase()) {
      case 'SUCCESS':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'ERROR':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case 'WARNING':
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        break;
      case 'INFO':
      default:
        statusColor = Colors.blue;
        statusIcon = Icons.info;
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 1),
      child: ListTile(
        dense: true,
        leading: Icon(statusIcon, color: statusColor, size: 16),
        title: Text(
          log.message,
          style: const TextStyle(fontSize: 12),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _formatTimestamp(log.timestamp),
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            log.level.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
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