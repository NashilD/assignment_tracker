import 'package:assignment_tracker/models/models.dart';
import 'package:assignment_tracker/screens/assignment_detail_screen.dart';
import 'package:assignment_tracker/services/calendar_service.dart';
import 'package:assignment_tracker/services/storage_service.dart';
import 'package:assignment_tracker/widgets/assignment_card.dart';
import 'package:flutter/material.dart';

/// Screen displaying active assignments
class AssignmentsScreen extends StatefulWidget {
  final StorageService storageService;
  final CalendarService calendarService;

  const AssignmentsScreen({
    super.key,
    required this.storageService,
    required this.calendarService,
  });

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  late List<Assignment> _assignments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    setState(() => _isLoading = true);
    try {
      final assignments = await widget.storageService.getAssignments();
      // Filter out Done status assignments
      final active =
          assignments.where((a) => a.status != AssignmentStatus.done).toList();
      active.sort((a, b) =>
          (a.dueDate ?? DateTime(2099)).compareTo(b.dueDate ?? DateTime(2099)));

      setState(() {
        _assignments = active;
      });
    } catch (e) {
      // Error loading assignments
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addAssignment() async {
    final result = await Navigator.of(context).push<Assignment>(
      MaterialPageRoute(
        builder: (context) => AssignmentDetailScreen(
          storageService: widget.storageService,
          calendarService: widget.calendarService,
        ),
      ),
    );

    if (result != null) {
      await _loadAssignments();
    }
  }

  Future<void> _editAssignment(Assignment assignment) async {
    final result = await Navigator.of(context).push<Assignment>(
      MaterialPageRoute(
        builder: (context) => AssignmentDetailScreen(
          storageService: widget.storageService,
          calendarService: widget.calendarService,
          assignment: assignment,
        ),
      ),
    );

    if (result != null) {
      await _loadAssignments();
    }
  }

  Future<void> _deleteAssignment(Assignment assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Assignment'),
        content: Text('Delete "${assignment.title}"?'),
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
      // Delete calendar event if exists
      if (assignment.calendarEventId != null) {
        await widget.calendarService.deleteEvent(assignment.calendarEventId!);
      }

      await widget.storageService.deleteAssignment(assignment.id);
      await _loadAssignments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assignment deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignments'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assignments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No assignments yet',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add an assignment to get started',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade500,
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _assignments.length,
                  itemBuilder: (context, index) {
                    final assignment = _assignments[index];
                    return AssignmentCard(
                      assignment: assignment,
                      onEdit: () => _editAssignment(assignment),
                      onDelete: () => _deleteAssignment(assignment),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAssignment,
        icon: const Icon(Icons.add),
        label: const Text('Add Assignment'),
      ),
    );
  }
}
