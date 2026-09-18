import 'package:flutter/material.dart';

/// Represents a course in the system
class Course {
  final String id;
  String name;
  Color color;
  bool isCustom;

  Course({
    required this.id,
    required this.name,
    required this.color,
    this.isCustom = false,
  });

  Course copyWith({
    String? id,
    String? name,
    Color? color,
    bool? isCustom,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color.toARGB32(),
      'isCustom': isCustom,
    };
  }

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      color: Color(map['color'] ?? 0xFF2196F3),
      isCustom: map['isCustom'] ?? false,
    );
  }
}

/// Represents an assignment (or exam-prep task) in the system
class Assignment {
  final String id;
  String courseId;
  String courseName;
  String title;
  String description;
  DateTime? dueDate;
  AssignmentStatus status;
  DateTime createdAt;
  DateTime? completedAt;
  bool hasCalendarEvent;
  String? calendarEventId;
  TaskType taskType;
  List<StudyTopic> topics;

  Assignment({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.title,
    required this.description,
    this.dueDate,
    this.status = AssignmentStatus.notStarted,
    DateTime? createdAt,
    this.completedAt,
    this.hasCalendarEvent = false,
    this.calendarEventId,
    this.taskType = TaskType.assignment,
    List<StudyTopic>? topics,
  })  : createdAt = createdAt ?? DateTime.now(),
        topics = topics ?? [];

  /// Status label appropriate for this task's type (exam-prep tasks use
  /// "Not Studied / Studying / Done" instead of "Not Started / In Progress").
  String get statusLabel => status.labelFor(taskType);

  int get daysRemaining {
    if (dueDate == null) return -1;
    final now = DateTime.now();
    final difference = dueDate!.difference(now).inDays;
    return difference >= 0 ? difference + 1 : difference;
  }

  bool get isOverdue {
    if (dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!) && status != AssignmentStatus.done;
  }

  bool get isDueToday {
    if (dueDate == null) return false;
    final today = DateTime.now();
    return dueDate!.year == today.year &&
        dueDate!.month == today.month &&
        dueDate!.day == today.day;
  }

  Assignment copyWith({
    String? id,
    String? courseId,
    String? courseName,
    String? title,
    String? description,
    DateTime? dueDate,
    AssignmentStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
    bool? hasCalendarEvent,
    String? calendarEventId,
    TaskType? taskType,
    List<StudyTopic>? topics,
  }) {
    return Assignment(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      hasCalendarEvent: hasCalendarEvent ?? this.hasCalendarEvent,
      calendarEventId: calendarEventId ?? this.calendarEventId,
      taskType: taskType ?? this.taskType,
      topics: topics ?? this.topics,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseId': courseId,
      'courseName': courseName,
      'title': title,
      'description': description,
      'dueDate': dueDate?.toIso8601String(),
      'status': status.toString(),
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'hasCalendarEvent': hasCalendarEvent,
      'calendarEventId': calendarEventId,
      'taskType': taskType.toString(),
      'topics': topics.map((t) => t.toMap()).toList(),
    };
  }

  factory Assignment.fromMap(Map<String, dynamic> map) {
    return Assignment(
      id: map['id'] ?? '',
      courseId: map['courseId'] ?? '',
      courseName: map['courseName'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      status: _parseStatus(map['status']),
      createdAt:
          DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'])
          : null,
      hasCalendarEvent: map['hasCalendarEvent'] ?? false,
      calendarEventId: map['calendarEventId'],
      taskType: _parseTaskType(map['taskType']),
      topics: (map['topics'] as List<dynamic>?)
              ?.map((t) => StudyTopic.fromMap(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  static AssignmentStatus _parseStatus(String? status) {
    switch (status) {
      case 'AssignmentStatus.inProgress':
        return AssignmentStatus.inProgress;
      case 'AssignmentStatus.done':
        return AssignmentStatus.done;
      default:
        return AssignmentStatus.notStarted;
    }
  }

  static TaskType _parseTaskType(String? taskType) {
    switch (taskType) {
      case 'TaskType.test':
        return TaskType.test;
      case 'TaskType.midterm':
        return TaskType.midterm;
      case 'TaskType.finalExam':
        return TaskType.finalExam;
      default:
        return TaskType.assignment;
    }
  }
}

enum AssignmentStatus {
  notStarted,
  inProgress,
  done,
}

extension AssignmentStatusX on AssignmentStatus {
  String get displayName {
    switch (this) {
      case AssignmentStatus.notStarted:
        return 'Not Started';
      case AssignmentStatus.inProgress:
        return 'In Progress';
      case AssignmentStatus.done:
        return 'Done';
    }
  }

  /// Status label for a given task type: exam-prep tasks (test/midterm/final
  /// exam) read as "Not Studied / Studying / Done" instead of the assignment
  /// wording. The underlying enum values (and all business logic keyed off
  /// them, e.g. moving to History on `done`) stay the same for every type.
  String labelFor(TaskType taskType) {
    if (!taskType.isExamPrep) return displayName;
    switch (this) {
      case AssignmentStatus.notStarted:
        return 'Not Studied';
      case AssignmentStatus.inProgress:
        return 'Studying';
      case AssignmentStatus.done:
        return 'Done';
    }
  }

  /// A mid-tone accent that keeps enough contrast on both light and dark
  /// surfaces (used as text/icon color on a translucent chip of the same hue).
  Color get color {
    switch (this) {
      case AssignmentStatus.notStarted:
        return const Color(0xFFE5544B); // muted red
      case AssignmentStatus.inProgress:
        return const Color(0xFFE08A2E); // muted amber
      case AssignmentStatus.done:
        return const Color(0xFF3FA46A); // muted green
    }
  }

  IconData get icon {
    switch (this) {
      case AssignmentStatus.notStarted:
        return Icons.schedule;
      case AssignmentStatus.inProgress:
        return Icons.pending_actions;
      case AssignmentStatus.done:
        return Icons.check_circle;
    }
  }
}

/// The kind of task an [Assignment] represents. `assignment` keeps the
/// original behavior; the other three are exam-prep tasks that share the
/// same model but get a dedicated form, wording, and topics checklist.
enum TaskType {
  assignment,
  test,
  midterm,
  finalExam,
}

extension TaskTypeX on TaskType {
  String get displayName {
    switch (this) {
      case TaskType.assignment:
        return 'Assignment';
      case TaskType.test:
        return 'Test';
      case TaskType.midterm:
        return 'Midterm';
      case TaskType.finalExam:
        return 'Final Exam';
    }
  }

  /// Small glyph used on task cards and the "new task" picker.
  String get emoji {
    switch (this) {
      case TaskType.assignment:
        return '📄';
      case TaskType.test:
        return '📝';
      case TaskType.midterm:
        return '🎓';
      case TaskType.finalExam:
        return '🏆';
    }
  }

  /// Test / Midterm / Final Exam use the dedicated exam-prep form (course,
  /// date, notes, study status, topics checklist) instead of the assignment
  /// form.
  bool get isExamPrep => this != TaskType.assignment;
}

/// A single study topic within an exam-prep task's checklist.
class StudyTopic {
  final String id;
  String text;
  bool isDone;

  StudyTopic({
    required this.id,
    required this.text,
    this.isDone = false,
  });

  StudyTopic copyWith({String? text, bool? isDone}) {
    return StudyTopic(
      id: id,
      text: text ?? this.text,
      isDone: isDone ?? this.isDone,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isDone': isDone,
    };
  }

  factory StudyTopic.fromMap(Map<String, dynamic> map) {
    return StudyTopic(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      isDone: map['isDone'] ?? false,
    );
  }
}
