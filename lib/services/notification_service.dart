import 'package:assignment_tracker/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules local reminder notifications before an assignment's due date.
///
/// A reminder fires (at 9am local time) when the assignment is 5, 3, 2 and 1
/// days away. Reminders are re-scheduled whenever the assignment changes and
/// cancelled when it is completed or deleted.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _timeZonesReady = false;
  bool _initialized = false;

  /// Days-before-due at which a reminder is sent.
  static const List<int> reminderDaysBefore = [5, 3, 2, 1];

  /// Local hour of day the reminders fire at.
  static const int _hourOfDay = 9;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'assignment_reminders',
    'Assignment reminders',
    channelDescription: 'Reminders before an assignment is due',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const NotificationDetails _details = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(),
  );

  /// Set up the plugin and ask for notification permission. Safe to call more
  /// than once; the scheduling methods call it lazily too.
  Future<void> initialize() async {
    if (_initialized) return;
    _ensureTimeZones();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  /// (Re)schedule every reminder for [assignment], clearing any previous ones.
  Future<void> scheduleForAssignment(Assignment assignment) async {
    try {
      await initialize();
    } catch (e) {
      debugPrint('NotificationService.initialize failed: $e');
      return;
    }

    await cancelForAssignmentId(assignment.id);

    final due = assignment.dueDate;
    if (due == null || assignment.status == AssignmentStatus.done) return;

    _ensureTimeZones();
    final now = tz.TZDateTime.now(tz.local);
    final dueAtHour = tz.TZDateTime(
      tz.local,
      due.year,
      due.month,
      due.day,
      _hourOfDay,
    );

    for (final daysBefore in reminderDaysBefore) {
      final fireAt = dueAtHour.subtract(Duration(days: daysBefore));
      if (!fireAt.isAfter(now)) continue;

      final title = assignment.courseName.isEmpty
          ? 'Assignment due soon'
          : '${assignment.courseName} · due soon';
      final body = daysBefore == 1
          ? '"${assignment.title}" is due tomorrow'
          : '"${assignment.title}" is due in $daysBefore days';

      try {
        await _plugin.zonedSchedule(
          _notificationId(assignment.id, daysBefore),
          title,
          body,
          fireAt,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        debugPrint('Failed to schedule reminder ($daysBefore d before): $e');
      }
    }
  }

  Future<void> cancelForAssignment(Assignment assignment) =>
      cancelForAssignmentId(assignment.id);

  Future<void> cancelForAssignmentId(String assignmentId) async {
    for (final daysBefore in reminderDaysBefore) {
      try {
        await _plugin.cancel(_notificationId(assignmentId, daysBefore));
      } catch (e) {
        debugPrint('Failed to cancel reminder: $e');
      }
    }
  }

  /// Deterministic, positive 31-bit notification id for an assignment + a
  /// specific days-before milestone.
  int _notificationId(String assignmentId, int daysBefore) {
    final base = assignmentId.hashCode & 0x00FFFFFF;
    return base * 10 + daysBefore;
  }

  void _ensureTimeZones() {
    if (_timeZonesReady) return;
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(_bestLocalLocation());
    } catch (_) {
      // Keep the default (UTC).
    }
    _timeZonesReady = true;
  }

  /// The `timezone` package can't read the device zone without an extra plugin,
  /// so pick the first zone whose current offset matches the device.
  tz.Location _bestLocalLocation() {
    final offset = DateTime.now().timeZoneOffset;
    for (final location in tz.timeZoneDatabase.locations.values) {
      if (tz.TZDateTime.now(location).timeZoneOffset == offset) {
        return location;
      }
    }
    return tz.getLocation('UTC');
  }
}
