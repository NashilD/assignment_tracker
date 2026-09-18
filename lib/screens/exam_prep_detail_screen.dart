import 'package:assignment_tracker/models/models.dart';
import 'package:assignment_tracker/services/calendar_service.dart';
import 'package:assignment_tracker/services/notification_service.dart';
import 'package:assignment_tracker/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

/// Dedicated form for creating and editing exam-prep tasks: Test, Midterm
/// and Final Exam. Separate from [AssignmentDetailScreen] because these
/// share a Course/Date/Notes/Status shape but add a study-topics checklist
/// and use exam-prep wording (Study Status, Notes) instead of the
/// assignment wording.
class ExamPrepDetailScreen extends StatefulWidget {
  final StorageService storageService;
  final CalendarService calendarService;
  final NotificationService notificationService;
  final TaskType taskType;
  final Assignment? assignment;

  const ExamPrepDetailScreen({
    super.key,
    required this.storageService,
    required this.calendarService,
    required this.notificationService,
    required this.taskType,
    this.assignment,
  });

  @override
  State<ExamPrepDetailScreen> createState() => _ExamPrepDetailScreenState();
}

class _ExamPrepDetailScreenState extends State<ExamPrepDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late TextEditingController _topicInputController;
  late String _selectedCourseId;
  late String _selectedCourseName;
  late DateTime? _selectedDate;
  late AssignmentStatus _selectedStatus;
  late List<StudyTopic> _topics;
  late List<Course> _courses;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.assignment?.title ?? '',
    );
    _notesController = TextEditingController(
      text: widget.assignment?.description ?? '',
    );
    _topicInputController = TextEditingController();
    _selectedDate = widget.assignment?.dueDate;
    _selectedStatus = widget.assignment?.status ?? AssignmentStatus.notStarted;
    _selectedCourseId = widget.assignment?.courseId ?? '';
    _selectedCourseName = widget.assignment?.courseName ?? '';
    // Defensive copy so edits here don't mutate the original until saved.
    _topics =
        widget.assignment?.topics.map((t) => t.copyWith()).toList() ?? [];

    _loadCourses();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _topicInputController.dispose();
    super.dispose();
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

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2099),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _addTopic() {
    final text = _topicInputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _topics.add(StudyTopic(id: const Uuid().v4(), text: text));
      _topicInputController.clear();
    });
  }

  void _toggleTopic(StudyTopic topic) {
    setState(() => topic.isDone = !topic.isDone);
  }

  void _removeTopic(StudyTopic topic) {
    setState(() => _topics.removeWhere((t) => t.id == topic.id));
  }

  Future<void> _editTopic(StudyTopic topic) async {
    final controller = TextEditingController(text: topic.text);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Topic'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (result != null && result.isNotEmpty) {
      setState(() => topic.text = result);
    }
  }

  Future<void> _saveTask() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a name for this ${widget.taskType.displayName}',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final task = widget.assignment ??
          Assignment(
            id: const Uuid().v4(),
            courseId: _selectedCourseId,
            courseName: _selectedCourseName,
            title: _titleController.text,
            description: _notesController.text,
            taskType: widget.taskType,
          );

      final updatedTask = task.copyWith(
        title: _titleController.text,
        description: _notesController.text,
        dueDate: _selectedDate,
        status: _selectedStatus,
        courseId: _selectedCourseId,
        courseName: _selectedCourseName,
        taskType: widget.taskType,
        topics: _topics,
      );

      // Save to storage
      await widget.storageService.saveAssignment(updatedTask);

      // (Re)schedule 5/3/2/1-day reminders (or clear them if done / no date).
      await widget.notificationService.scheduleForAssignment(updatedTask);

      // Sync to calendar. A calendar failure must not block saving, so it is
      // handled separately and only surfaces as a warning.
      String? calendarWarning;
      try {
        final eventId = await widget.calendarService
            .syncAssignmentToCalendar(updatedTask);

        final synced = updatedTask.copyWith(
          calendarEventId: eventId,
          hasCalendarEvent: eventId != null,
        );
        await widget.storageService.saveAssignment(synced);

        if (_selectedDate != null &&
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
        Navigator.pop(context, updatedTask);
      }
    } catch (e) {
      debugPrint('Error saving ${widget.taskType.displayName}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeName = widget.taskType.displayName;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.assignment == null ? 'Add $typeName' : 'Edit $typeName'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Course dropdown
                  Text('Course', style: theme.textTheme.titleMedium),
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
                  Text('$typeName Name', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'e.g., Chapter 5 $typeName',
                      prefixIcon: Text(
                        widget.taskType.emoji,
                        style: const TextStyle(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Date picker
                  Text('Date', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          if (_selectedDate != null)
                            Text(
                              DateFormat('MMM dd, yyyy').format(_selectedDate!),
                              style: theme.textTheme.bodyLarge,
                            )
                          else
                            Text(
                              'Select a date',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          const Spacer(),
                          if (_selectedDate != null)
                            TextButton(
                              onPressed: () {
                                setState(() => _selectedDate = null);
                              },
                              child: const Text('Clear'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Topics to study
                  Text('Topics to Study', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _topicInputController,
                          decoration: InputDecoration(
                            hintText: 'Add a topic',
                            prefixIcon: const Icon(Icons.checklist),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onSubmitted: (_) => _addTopic(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _addTopic,
                        icon: const Icon(Icons.add),
                        tooltip: 'Add topic',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_topics.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No topics yet. Add what you need to study above.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    Card(
                      margin: EdgeInsets.zero,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final topic in _topics)
                            CheckboxListTile(
                              value: topic.isDone,
                              onChanged: (_) => _toggleTopic(topic),
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                              title: Text(
                                topic.text,
                                style: topic.isDone
                                    ? theme.textTheme.bodyMedium?.copyWith(
                                        decoration:
                                            TextDecoration.lineThrough,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      )
                                    : theme.textTheme.bodyMedium,
                              ),
                              secondary: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: 'Edit topic',
                                    onPressed: () => _editTopic(topic),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Remove topic',
                                    onPressed: () => _removeTopic(topic),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Notes field (optional)
                  Text('Notes', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Add any additional notes (optional)...',
                      prefixIcon: const Icon(Icons.notes),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Study status dropdown
                  Text('Study Status', style: theme.textTheme.titleMedium),
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
                                  Text(status.labelFor(widget.taskType)),
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
                    onPressed: _isSaving ? null : _saveTask,
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
                    label: Text(_isSaving ? 'Saving...' : 'Save $typeName'),
                  ),
                ],
              ),
            ),
    );
  }
}
