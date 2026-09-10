// Widget and service tests for the Assignment Tracker app.

import 'package:assignment_tracker/main.dart';
import 'package:assignment_tracker/models/models.dart';
import 'package:assignment_tracker/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Give SharedPreferences an in-memory backing store for every test.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('MyApp', () {
    testWidgets('boots into a MaterialApp', (tester) async {
      await tester.pumpWidget(const MyApp());

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('shows the bottom navigation once services initialize',
        (tester) async {
      await tester.pumpWidget(const MyApp());

      // Pump frames until initialization completes (or give up after ~2s).
      var found = false;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(NavigationBar).evaluate().isNotEmpty) {
          found = true;
          break;
        }
      }

      expect(found, isTrue, reason: 'NavigationBar never appeared');
      expect(find.text('Assignments'), findsWidgets);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });
  });

  group('StorageService', () {
    late StorageService storage;

    setUp(() async {
      storage = await StorageService.create();
    });

    test('starts with no assignments', () async {
      expect(await storage.getAssignments(), isEmpty);
    });

    test('saves and reads back an assignment', () async {
      final assignment = Assignment(
        id: 'a1',
        courseId: '1',
        courseName: 'MOSI',
        title: 'Essay draft',
        description: 'First draft of the essay',
        dueDate: DateTime(2026, 9, 20),
      );

      await storage.saveAssignment(assignment);

      final stored = await storage.getAssignments();
      expect(stored, hasLength(1));
      expect(stored.single.id, 'a1');
      expect(stored.single.title, 'Essay draft');
      expect(stored.single.dueDate, DateTime(2026, 9, 20));
    });

    test('updates an existing assignment in place', () async {
      final assignment = Assignment(
        id: 'a1',
        courseId: '1',
        courseName: 'MOSI',
        title: 'Essay draft',
        description: '',
      );
      await storage.saveAssignment(assignment);
      await storage.saveAssignment(
        assignment.copyWith(title: 'Essay final', status: AssignmentStatus.done),
      );

      final stored = await storage.getAssignments();
      expect(stored, hasLength(1));
      expect(stored.single.title, 'Essay final');
      expect(stored.single.status, AssignmentStatus.done);
    });

    test('moveToHistory removes from the active list and adds to history',
        () async {
      final assignment = Assignment(
        id: 'a1',
        courseId: '1',
        courseName: 'MOSI',
        title: 'Essay draft',
        description: '',
      );
      await storage.saveAssignment(assignment);

      await storage.moveToHistory(assignment);

      expect(await storage.getAssignments(), isEmpty);
      final history = await storage.getHistoryAssignments();
      expect(history, hasLength(1));
      expect(history.single.id, 'a1');
      expect(history.single.completedAt, isNotNull);
    });

    test('provides default courses when none are stored', () async {
      final courses = await storage.getCourses();
      expect(courses, isNotEmpty);
      expect(courses.map((c) => c.name), contains('MOSI'));
    });
  });
}
