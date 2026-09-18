import 'dart:convert';
import 'package:assignment_tracker/models/models.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing assignments and courses using SharedPreferences
class StorageService {
  static const String _assignmentsKey = 'assignments';
  static const String _coursesKey = 'courses';
  static const String _historyAssignmentsKey = 'history_assignments';
  static const String _emailConfigKey = 'email_config';
  static const String _historyRetentionMonthsKey = 'history_retention_months';

  /// Default number of months a completed assignment stays in History
  /// before it is automatically deleted.
  static const int defaultHistoryRetentionMonths = 5;

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // ========== Assignments ==========
  Future<void> saveAssignment(Assignment assignment) async {
    final assignments = await getAssignments();
    final index = assignments.indexWhere((a) => a.id == assignment.id);

    if (index >= 0) {
      assignments[index] = assignment;
    } else {
      assignments.add(assignment);
    }

    await _prefs.setString(
      _assignmentsKey,
      jsonEncode(assignments.map((a) => a.toMap()).toList()),
    );
  }

  Future<List<Assignment>> getAssignments() async {
    final json = _prefs.getString(_assignmentsKey);
    if (json == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(json);
      return decoded
          .map((item) => Assignment.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Error decoding assignments, returning empty list
      return [];
    }
  }

  Future<void> deleteAssignment(String assignmentId) async {
    final assignments = await getAssignments();
    assignments.removeWhere((a) => a.id == assignmentId);

    await _prefs.setString(
      _assignmentsKey,
      jsonEncode(assignments.map((a) => a.toMap()).toList()),
    );
  }

  Future<Assignment?> getAssignmentById(String id) async {
    final assignments = await getAssignments();
    try {
      return assignments.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  // ========== History ==========
  Future<void> moveToHistory(Assignment assignment) async {
    final history = await getHistoryAssignments();
    final updatedAssignment = assignment.copyWith(
      completedAt: DateTime.now(),
    );
    history.add(updatedAssignment);

    await _prefs.setString(
      _historyAssignmentsKey,
      jsonEncode(history.map((a) => a.toMap()).toList()),
    );

    await deleteAssignment(assignment.id);
  }

  Future<List<Assignment>> getHistoryAssignments() async {
    final json = _prefs.getString(_historyAssignmentsKey);
    if (json == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(json);
      return decoded
          .map((item) => Assignment.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Error decoding history, returning empty list
      return [];
    }
  }

  Future<void> removeFromHistory(String assignmentId) async {
    final history = await getHistoryAssignments();
    history.removeWhere((a) => a.id == assignmentId);

    await _prefs.setString(
      _historyAssignmentsKey,
      jsonEncode(history.map((a) => a.toMap()).toList()),
    );
  }

  /// How many months a completed assignment stays in History before it is
  /// automatically deleted. A value of 0 means "keep forever".
  Future<int> getHistoryRetentionMonths() async {
    return _prefs.getInt(_historyRetentionMonthsKey) ??
        defaultHistoryRetentionMonths;
  }

  Future<void> saveHistoryRetentionMonths(int months) async {
    await _prefs.setInt(_historyRetentionMonthsKey, months);
  }

  /// Permanently removes History entries older than the configured
  /// retention period. Safe to call often; it's a no-op when nothing has
  /// expired or retention is disabled.
  Future<void> purgeExpiredHistory() async {
    final retentionMonths = await getHistoryRetentionMonths();
    if (retentionMonths <= 0) return;

    final history = await getHistoryAssignments();
    final cutoff = _monthsAgo(retentionMonths);
    final remaining = history.where((a) {
      final completedAt = a.completedAt;
      return completedAt == null || completedAt.isAfter(cutoff);
    }).toList();

    if (remaining.length != history.length) {
      await _prefs.setString(
        _historyAssignmentsKey,
        jsonEncode(remaining.map((a) => a.toMap()).toList()),
      );
    }
  }

  DateTime _monthsAgo(int months) {
    final now = DateTime.now();
    var year = now.year;
    var month = now.month - months;
    while (month <= 0) {
      month += 12;
      year -= 1;
    }
    return DateTime(year, month, now.day, now.hour, now.minute, now.second);
  }

  // ========== Courses ==========
  Future<void> saveCourse(Course course) async {
    final courses = await getCourses();
    final index = courses.indexWhere((c) => c.id == course.id);

    if (index >= 0) {
      courses[index] = course;
    } else {
      courses.add(course);
    }

    await _prefs.setString(
      _coursesKey,
      jsonEncode(courses.map((c) => c.toMap()).toList()),
    );
  }

  Future<List<Course>> getCourses() async {
    final json = _prefs.getString(_coursesKey);
    if (json == null) {
      return _getDefaultCourses();
    }

    try {
      final List<dynamic> decoded = jsonDecode(json);
      return decoded
          .map((item) => Course.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Error decoding courses, returning defaults
      return _getDefaultCourses();
    }
  }

  Future<void> deleteCourse(String courseId) async {
    final courses = await getCourses();
    courses.removeWhere((c) => c.id == courseId);

    await _prefs.setString(
      _coursesKey,
      jsonEncode(courses.map((c) => c.toMap()).toList()),
    );
  }

  // ========== Email Configuration ==========
  Future<void> saveEmailConfig(String email) async {
    await _prefs.setString(_emailConfigKey, email);
  }

  Future<String?> getEmailConfig() async {
    return _prefs.getString(_emailConfigKey);
  }

  // ========== Utility Methods ==========
  Future<void> clearAll() async {
    await _prefs.clear();
  }

  List<Course> _getDefaultCourses() {
    return [
      Course(id: '1', name: 'MOSI', color: const Color(0xFFEC407A)),
      Course(id: '2', name: 'Statistics', color: const Color(0xFF9C27B0)),
      Course(id: '3', name: 'Philosophy', color: const Color(0xFF4CAF50)),
      Course(
          id: '4', name: 'Creative Thinking', color: const Color(0xFFFFA726)),
      Course(id: '5', name: 'Accounting', color: const Color(0xFF2196F3)),
    ];
  }
}
