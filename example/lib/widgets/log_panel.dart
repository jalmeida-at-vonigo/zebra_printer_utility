import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Log entry data model
class LogEntry {
  final DateTime timestamp;
  final String level;
  final String message;
  final String? details;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.details,
  });

  Color get levelColor {
    switch (level.toLowerCase()) {
      case 'error':
      case 'exception':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      case 'success':
        return Colors.green;
      case 'debug':
      case 'trace':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  IconData get levelIcon {
    switch (level.toLowerCase()) {
      case 'error':
      case 'exception':
        return Icons.error;
      case 'warning':
        return Icons.warning;
      case 'info':
        return Icons.info;
      case 'success':
        return Icons.check_circle;
      case 'debug':
      case 'trace':
        return Icons.bug_report;
      default:
        return Icons.note;
    }
  }
}

/// A clean, reusable log panel widget for displaying operation logs
class LogPanel extends StatefulWidget {
  final List<LogEntry> logs;
  final VoidCallback? onClear;
  final double? maxHeight;

  const LogPanel({
    super.key,
    required this.logs,
    this.onClear,
    this.maxHeight,
  });

  @override
  State<LogPanel> createState() => _LogPanelState();
}

class _LogPanelState extends State<LogPanel> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void didUpdateWidget(LogPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.logs.length > oldWidget.logs.length && _autoScroll) {
      // New log added, scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _copyLogs() async {
    final logsText = widget.logs.map((log) {
      final time = '${log.timestamp.hour.toString().padLeft(2, '0')}:'
          '${log.timestamp.minute.toString().padLeft(2, '0')}:'
          '${log.timestamp.second.toString().padLeft(2, '0')}';
      return '[$time] [${log.level.toUpperCase()}] ${log.message}${log.details != null ? '\n  Details: ${log.details}' : ''}';
    }).join('\n');
    
    await Clipboard.setData(ClipboardData(text: logsText));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logs copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.terminal,
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Operation Log',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const Spacer(),
                // Auto-scroll toggle
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _autoScroll = !_autoScroll;
                    });
                  },
                  icon: Icon(
                    _autoScroll ? Icons.vertical_align_bottom : Icons.pan_tool,
                    size: 16,
                  ),
                  label: Text(_autoScroll ? 'Auto' : 'Manual'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                ),
                // Copy button
                IconButton(
                  onPressed: widget.logs.isEmpty ? null : _copyLogs,
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copy logs',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
                // Clear button
                if (widget.onClear != null)
                  IconButton(
                    onPressed: widget.logs.isEmpty ? null : widget.onClear,
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: 'Clear logs',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          // Log content
          Expanded(
            child: widget.logs.isEmpty
                ? Center(
                    child: Text(
                      'No logs yet',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: widget.logs.length,
                    itemBuilder: (context, index) {
                      final log = widget.logs[index];
                      return _buildLogEntry(log);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(LogEntry log) {
    final time = '${log.timestamp.hour.toString().padLeft(2, '0')}:'
        '${log.timestamp.minute.toString().padLeft(2, '0')}:'
        '${log.timestamp.second.toString().padLeft(2, '0')}';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: log.levelColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: log.levelColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time
          Text(
            time,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 8),
          // Level icon
          Icon(
            log.levelIcon,
            size: 16,
            color: log.levelColor,
          ),
          const SizedBox(width: 4),
          // Message
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.message,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[800],
                  ),
                ),
                if (log.details != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    log.details!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
} 