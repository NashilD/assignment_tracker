import 'package:assignment_tracker/models/models.dart';
import 'package:assignment_tracker/services/calendar_service.dart';
import 'package:assignment_tracker/services/notification_service.dart';
import 'package:assignment_tracker/services/storage_service.dart';
import 'package:assignment_tracker/widgets/assignment_card.dart';
import 'package:flutter/material.dart';

/// Screen displaying completed assignments
class HistoryScreen extends StatefulWidget {
  final StorageService storageService;
  final CalendarService calendarService;
  final NotificationService notificationService;

  const HistoryScreen({
    super.key,
    required this.storageService,
    required this.calendarService,
    required this.notificationService,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late List<Assignment> _history = [];
  Map<String, Color> _courseColors = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      await widget.storageService.purgeExpiredHistory();
      final history = await widget.storageService.getHistoryAssignments();
      final courses = await widget.storageService.getCourses();
      history.sort((a, b) => (b.completedAt ?? DateTime(2000))
          .compareTo(a.completedAt ?? DateTime(2000)));

      setState(() {
        _history = history;
        _courseColors = {for (final c in courses) c.id: c.color};
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
      // Remove any lingering calendar event / reminders for this assignment.
      if (assignment.calendarEventId != null) {
        await widget.calendarService.deleteEvent(assignment.calendarEventId!);
      }
      await widget.notificationService.cancelForAssignmentId(assignment.id);
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
      // Rebuild explicitly: copyWith can't null out completedAt / the stale
      // calendar link, and the old event was deleted when it was completed.
      var restoredAssignment = Assignment(
        id: assignment.id,
        courseId: assignment.courseId,
        courseName: assignment.courseName,
        title: assignment.title,
        description: assignment.description,
        dueDate: assignment.dueDate,
        status: AssignmentStatus.notStarted,
        createdAt: assignment.createdAt,
        completedAt: null,
        hasCalendarEvent: false,
        calendarEventId: null,
        taskType: assignment.taskType,
        topics: assignment.topics.map((t) => t.copyWith()).toList(),
      );

      // Put it back on the calendar if it still has a due date.
      if (restoredAssignment.dueDate != null) {
        try {
          final eventId = await widget.calendarService
              .syncAssignmentToCalendar(restoredAssignment);
          if (eventId != null) {
            restoredAssignment = restoredAssignment.copyWith(
              calendarEventId: eventId,
              hasCalendarEvent: true,
            );
          }
        } catch (e) {
          debugPrint('Calendar re-sync on restore failed: $e');
        }
      }

      await widget.storageService.saveAssignment(restoredAssignment);
      // Bring back the 5/3/2/1-day reminders.
      await widget.notificationService
          .scheduleForAssignment(restoredAssignment);
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
              ? const EmptyState(
                  icon: Icons.history,
                  title: 'No completed assignments',
                  subtitle: 'Your completed assignments will appear here',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final assignment = _history[index];
                    return HistoryCard(
                      assignment: assignment,
                      accentColor: _courseColors[assignment.courseId],
                      onDelete: () => _deleteFromHistory(assignment),
                      onRestore: () => _restoreAssignment(assignment),
                    );
                  },
                ),
    );
  }
}
