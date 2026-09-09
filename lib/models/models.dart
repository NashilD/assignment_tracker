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

/// Represents an assignment in the system
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
  }) : createdAt = createdAt ?? DateTime.now();

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

  Color get color {
    switch (this) {
      case AssignmentStatus.notStarted:
        return Colors.red;
      case AssignmentStatus.inProgress:
        return Colors.orange;
      case AssignmentStatus.done:
        return Colors.green;
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
