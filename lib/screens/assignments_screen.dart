import 'package:assignment_tracker/models/models.dart';
import 'package:assignment_tracker/screens/assignment_detail_screen.dart';
import 'package:assignment_tracker/screens/exam_prep_detail_screen.dart';
import 'package:assignment_tracker/services/calendar_service.dart';
import 'package:assignment_tracker/services/notification_service.dart';
import 'package:assignment_tracker/services/storage_service.dart';
import 'package:assignment_tracker/widgets/assignment_card.dart';
import 'package:flutter/material.dart';

/// Screen displaying active assignments
class AssignmentsScreen extends StatefulWidget {
  final StorageService storageService;
  final CalendarService calendarService;
  final NotificationService notificationService;

  const AssignmentsScreen({
    super.key,
    required this.storageService,
    required this.calendarService,
    required this.notificationService,
  });

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  late List<Assignment> _assignments = [];
  Map<String, Color> _courseColors = {};
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
      final courses = await widget.storageService.getCourses();
      // Filter out Done status assignments
      final active =
          assignments.where((a) => a.status != AssignmentStatus.done).toList();
      active.sort((a, b) =>
          (a.dueDate ?? DateTime(2099)).compareTo(b.dueDate ?? DateTime(2099)));

      setState(() {
        _assignments = active;
        _courseColors = {for (final c in courses) c.id: c.color};
      });
    } catch (e) {
      // Error loading assignments
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addAssignment() async {
    final taskType = await _pickTaskType();
    if (taskType == null || !mounted) return;

    final result = await Navigator.of(context).push<Assignment>(
      MaterialPageRoute(
        builder: (context) => taskType == TaskType.assignment
            ? AssignmentDetailScreen(
                storageService: widget.storageService,
                calendarService: widget.calendarService,
                notificationService: widget.notificationService,
              )
            : ExamPrepDetailScreen(
                storageService: widget.storageService,
                calendarService: widget.calendarService,
                notificationService: widget.notificationService,
                taskType: taskType,
              ),
      ),
    );

    if (result != null) {
      await _loadAssignments();
    }
  }

  /// Shows a modal bottom sheet letting the user choose which kind of task
  /// to create: Assignment, Test, Midterm or Final Exam.
  Future<TaskType?> _pickTaskType() {
    return showModalBottomSheet<TaskType>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'New Task',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            for (final taskType in TaskType.values)
              ListTile(
                leading: Text(
                  taskType.emoji,
                  style: const TextStyle(fontSize: 22),
                ),
                title: Text(taskType.displayName),
                onTap: () => Navigator.pop(context, taskType),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _editAssignment(Assignment assignment) async {
    final result = await Navigator.of(context).push<Assignment>(
      MaterialPageRoute(
        builder: (context) => assignment.taskType == TaskType.assignment
            ? AssignmentDetailScreen(
                storageService: widget.storageService,
                calendarService: widget.calendarService,
                notificationService: widget.notificationService,
                assignment: assignment,
              )
            : ExamPrepDetailScreen(
                storageService: widget.storageService,
                calendarService: widget.calendarService,
                notificationService: widget.notificationService,
                taskType: assignment.taskType,
                assignment: assignment,
              ),
      ),
    );

    if (result != null) {
      await _loadAssignments();
    }
  }

  Future<void> _changeStatus(
    Assignment assignment,
    AssignmentStatus status,
  ) async {
    if (status == assignment.status) return;

    final updated = assignment.copyWith(status: status);
    try {
      if (status == AssignmentStatus.done) {
        // Done assignments live in History and no longer need a calendar event
        // or reminders.
        if (assignment.calendarEventId != null) {
          await widget.calendarService
              .deleteEvent(assignment.calendarEventId!);
        }
        await widget.notificationService.cancelForAssignmentId(assignment.id);
        await widget.storageService.moveToHistory(updated);
      } else {
        await widget.storageService.saveAssignment(updated);
      }
      await _loadAssignments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == AssignmentStatus.done
                  ? '"${assignment.title}" moved to History'
                  : 'Status set to ${status.labelFor(assignment.taskType)}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update status')),
        );
      }
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
      await widget.notificationService.cancelForAssignmentId(assignment.id);

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
              ? const EmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'No tasks yet',
                  subtitle: 'Tap + to add an assignment, test, midterm or '
                      'final exam',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _assignments.length,
                  itemBuilder: (context, index) {
                    final assignment = _assignments[index];
                    return AssignmentCard(
                      assignment: assignment,
                      accentColor: _courseColors[assignment.courseId],
                      onEdit: () => _editAssignment(assignment),
                      onDelete: () => _deleteAssignment(assignment),
                      onStatusChanged: (status) =>
                          _changeStatus(assignment, status),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addAssignment,
        tooltip: 'New Task',
        child: const Icon(Icons.add),
      ),
    );
  }
}
