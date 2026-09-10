import 'package:assignment_tracker/models/models.dart';
import 'package:assignment_tracker/services/calendar_service.dart';
import 'package:assignment_tracker/services/notification_service.dart';
import 'package:assignment_tracker/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

/// Screen for creating and editing assignments
class AssignmentDetailScreen extends StatefulWidget {
  final StorageService storageService;
  final CalendarService calendarService;
  final NotificationService notificationService;
  final Assignment? assignment;

  const AssignmentDetailScreen({
    super.key,
    required this.storageService,
    required this.calendarService,
    required this.notificationService,
    this.assignment,
  });

  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late String _selectedCourseId;
  late String _selectedCourseName;
  late DateTime? _selectedDueDate;
  late AssignmentStatus _selectedStatus;
  late List<Course> _courses;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.assignment?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.assignment?.description ?? '',
    );
    _selectedDueDate = widget.assignment?.dueDate;
    _selectedStatus = widget.assignment?.status ?? AssignmentStatus.notStarted;
    _selectedCourseId = widget.assignment?.courseId ?? '';
    _selectedCourseName = widget.assignment?.courseName ?? '';

    _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      final courses = await widget.storageService.getCourses();
      setState(() {
        _courses = courses;
        if (_courses.isNotEmpty && _selectedCourseId.isEmpty) {
          _selectedCourseId = _courses.first.id;
          _selectedCourseName = _courses.first.name;
        }
      });
    } catch (e) {
      // Error loading courses
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2099),
    );

    if (picked != null) {
      setState(() => _selectedDueDate = picked);
    }
  }

  Future<void> _saveAssignment() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an assignment title')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final assignment = widget.assignment ??
          Assignment(
            id: const Uuid().v4(),
            courseId: _selectedCourseId,
            courseName: _selectedCourseName,
            title: _titleController.text,
            description: _descriptionController.text,
          );

      final updatedAssignment = assignment.copyWith(
        title: _titleController.text,
        description: _descriptionController.text,
        dueDate: _selectedDueDate,
        status: _selectedStatus,
        courseId: _selectedCourseId,
        courseName: _selectedCourseName,
      );

      // Save to storage
      await widget.storageService.saveAssignment(updatedAssignment);

      // (Re)schedule 5/3/2/1-day reminders (or clear them if done / no date).
      await widget.notificationService.scheduleForAssignment(updatedAssignment);

      // Sync to calendar. A calendar failure must not block saving, so it is
      // handled separately and only surfaces as a warning.
      String? calendarWarning;
      try {
        final eventId = await widget.calendarService
            .syncAssignmentToCalendar(updatedAssignment);

        final synced = updatedAssignment.copyWith(
          calendarEventId: eventId,
          hasCalendarEvent: eventId != null,
        );
        await widget.storageService.saveAssignment(synced);

        if (_selectedDueDate != null &&
            _selectedStatus != AssignmentStatus.done &&
            eventId == null) {
          calendarWarning =
              'Saved, but could not add it to your calendar. Check the '
              'calendar permission and the Calendar Email in Settings.';
        }
      } catch (e) {
        debugPrint('Calendar sync failed: $e');
        calendarWarning = 'Saved, but calendar sync failed.';
      }

      if (mounted) {
        if (calendarWarning != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(calendarWarning)),
          );
        }
        Navigator.pop(context, updatedAssignment);
      }
    } catch (e) {
      debugPrint('Error saving assignment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving assignment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.assignment == null ? 'Add Assignment' : 'Edit Assignment'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Course dropdown
                  Text(
                    'Course',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue:
                        _selectedCourseId.isNotEmpty ? _selectedCourseId : null,
                    items: _courses
                        .map((course) => DropdownMenuItem(
                              value: course.id,
                              child: Text(course.name),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        final course =
                            _courses.firstWhere((c) => c.id == value);
                        setState(() {
                          _selectedCourseId = value;
                          _selectedCourseName = course.name;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Select a course',
                      prefixIcon: const Icon(Icons.school),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title field
                  Text(
                    'Assignment Title',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'e.g., Read pages 227-307',
                      prefixIcon: const Icon(Icons.assignment),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Description field
                  Text(
                    'Description',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Add any additional details...',
                      prefixIcon: const Icon(Icons.description),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Due date picker
                  Text(
                    'Due Date',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _selectDueDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          if (_selectedDueDate != null)
                            Text(
                              DateFormat('MMM dd, yyyy')
                                  .format(_selectedDueDate!),
                              style: theme.textTheme.bodyLarge,
                            )
                          else
                            Text(
                              'Select a due date',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          const Spacer(),
                          if (_selectedDueDate != null)
                            TextButton(
                              onPressed: () {
                                setState(() => _selectedDueDate = null);
                              },
                              child: const Text('Clear'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Status dropdown
                  Text(
                    'Status',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<AssignmentStatus>(
                    initialValue: _selectedStatus,
                    items: AssignmentStatus.values
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Row(
                                children: [
                                  Icon(status.icon),
                                  const SizedBox(width: 8),
                                  Text(status.displayName),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedStatus = value);
                      }
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Save button
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveAssignment,
                    icon: _isSaving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                theme.colorScheme.onPrimary,
                              ),
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Saving...' : 'Save Assignment'),
                  ),
                ],
              ),
            ),
    );
  }
}
