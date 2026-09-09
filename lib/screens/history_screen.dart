import 'package:assignment_tracker/models/models.dart';
import 'package:assignment_tracker/services/storage_service.dart';
import 'package:assignment_tracker/widgets/assignment_card.dart';
import 'package:flutter/material.dart';

/// Screen displaying completed assignments
class HistoryScreen extends StatefulWidget {
  final StorageService storageService;

  const HistoryScreen({
    super.key,
    required this.storageService,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late List<Assignment> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await widget.storageService.getHistoryAssignments();
      history.sort((a, b) => (b.completedAt ?? DateTime(2000))
          .compareTo(a.completedAt ?? DateTime(2000)));

      setState(() {
        _history = history;
      });
    } catch (e) {
      // Error loading history
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteFromHistory(Assignment assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Assignment'),
        content: Text('Permanently delete "${assignment.title}" from history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.storageService.removeFromHistory(assignment.id);
      await _loadHistory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assignment removed from history')),
        );
      }
    }
  }

  Future<void> _restoreAssignment(Assignment assignment) async {
    try {
      final restoredAssignment = assignment.copyWith(
        status: AssignmentStatus.notStarted,
        completedAt: null,
      );

      await widget.storageService.saveAssignment(restoredAssignment);
      await widget.storageService.removeFromHistory(assignment.id);
      await _loadHistory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assignment restored')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error restoring assignment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No completed assignments',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your completed assignments will appear here',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade500,
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final assignment = _history[index];
                    return HistoryCard(
                      assignment: assignment,
                      onDelete: () => _deleteFromHistory(assignment),
                      onRestore: () => _restoreAssignment(assignment),
                    );
                  },
                ),
    );
  }
}
