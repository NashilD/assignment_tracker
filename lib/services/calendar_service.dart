import 'package:assignment_tracker/models/models.dart';
import 'package:assignment_tracker/services/storage_service.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Reads and writes events on the device's calendar (Google, Samsung Calendar,
/// Exchange, ...) through the Android/iOS calendar provider.
///
/// When a "Calendar Email" is configured in Settings, events are written to the
/// calendar whose account matches that email; otherwise the device's default
/// writable calendar is used.
class CalendarService {
  CalendarService([this._storageService]);

  final StorageService? _storageService;
  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();

  static bool _timeZonesReady = false;

  bool _isInitialized = false;
  String? _calendarId;

  /// The default hour of day used for the assignment reminder event.
  static const int _eventHour = 9;

  /// Whether a writable calendar has been resolved and permissions granted.
  bool get isInitialized => _isInitialized;

  /// The id of the calendar events are written to, once resolved.
  String? get calendarId => _calendarId;

  /// Request permissions and resolve the target calendar. Safe to call multiple
  /// times; it is also called lazily by the sync methods.
  Future<bool> initialize() async {
    try {
      _ensureTimeZones();
      if (!await _ensurePermissions()) {
        return false;
      }
      _calendarId = await _resolveCalendarId();
      _isInitialized = _calendarId != null;
      return _isInitialized;
    } catch (e) {
      debugPrint('CalendarService.initialize failed: $e');
      return false;
    }
  }

  /// Create a calendar event for [assignment]. Returns the new event id, or null
  /// on failure / when the assignment has no due date.
  Future<String?> createEvent(Assignment assignment) {
    return _upsertEvent(assignment, existingEventId: null);
  }

  /// Update the calendar event linked to [assignment].
  Future<bool> updateEvent(Assignment assignment) async {
    final id = await _upsertEvent(
      assignment,
      existingEventId: assignment.calendarEventId,
    );
    return id != null;
  }

  /// Delete the calendar event with [calendarEventId].
  Future<bool> deleteEvent(String calendarEventId) async {
    try {
      if (!await _ensureReady()) return false;
      final result = await _plugin.deleteEvent(_calendarId, calendarEventId);
      return result.isSuccess && (result.data ?? false);
    } catch (e) {
      debugPrint('CalendarService.deleteEvent failed: $e');
      return false;
    }
  }

  /// Create, update or remove the calendar event for [assignment] so it matches
  /// the assignment's current state. Returns the event id it is now linked to
  /// (null if it has no event, e.g. the due date was cleared).
  Future<String?> syncAssignmentToCalendar(Assignment assignment) async {
    // A finished assignment, or one with no due date, should have no event.
    if (assignment.dueDate == null ||
        assignment.status == AssignmentStatus.done) {
      final existing = assignment.calendarEventId;
      if (existing != null) {
        await deleteEvent(existing);
      }
      return null;
    }

    if (assignment.calendarEventId != null) {
      final id = await _upsertEvent(
        assignment,
        existingEventId: assignment.calendarEventId,
      );
      return id ?? assignment.calendarEventId;
    }
    return createEvent(assignment);
  }

  // ---------------------------------------------------------------------------

  Future<String?> _upsertEvent(
    Assignment assignment, {
    required String? existingEventId,
  }) async {
    if (assignment.dueDate == null) return null;
    try {
      if (!await _ensureReady()) return null;

      final due = assignment.dueDate!;
      final start = tz.TZDateTime(
        tz.local,
        due.year,
        due.month,
        due.day,
        _eventHour,
      );
      final end = start.add(const Duration(hours: 1));

      final event = Event(
        _calendarId,
        eventId: existingEventId,
        title: _buildTitle(assignment),
        description: _buildDescription(assignment),
        start: start,
        end: end,
        reminders: [
          Reminder(minutes: 24 * 60), // 1 day before
          Reminder(minutes: 2 * 60), // 2 hours before
        ],
      );

      final result = await _plugin.createOrUpdateEvent(event);
      if (result != null && result.isSuccess && result.data != null) {
        return result.data;
      }
      debugPrint(
        'CalendarService: createOrUpdateEvent failed: '
        '${result?.errors.map((e) => e.errorMessage).join(', ')}',
      );
      return null;
    } catch (e) {
      debugPrint('CalendarService._upsertEvent failed: $e');
      return null;
    }
  }

  /// The calendar event's title: "`Course - Title`" so the entry is
  /// identifiable in the device calendar without opening it, falling back to
  /// just the title when there's no real course attached.
  String _buildTitle(Assignment assignment) {
    final title = assignment.title.isEmpty ? 'Assignment' : assignment.title;
    final course = assignment.courseName;
    if (course.isEmpty || course == 'Unknown') return title;
    return '$course - $title';
  }

  String _buildDescription(Assignment assignment) {
    final buffer = StringBuffer();
    if (assignment.courseName.isNotEmpty &&
        assignment.courseName != 'Unknown') {
      buffer.writeln('Course: ${assignment.courseName}');
    }
    if (assignment.description.isNotEmpty) {
      buffer.writeln(assignment.description);
    }
    if (assignment.taskType.isExamPrep && assignment.topics.isNotEmpty) {
      buffer.writeln('Topics to study:');
      for (final topic in assignment.topics) {
        buffer.writeln('- ${topic.text}${topic.isDone ? ' (done)' : ''}');
      }
    }
    buffer.write('Added by Assignment Tracker');
    return buffer.toString();
  }

  Future<bool> _ensureReady() async {
    if (_isInitialized && _calendarId != null) {
      _ensureTimeZones();
      return true;
    }
    return initialize();
  }

  Future<bool> _ensurePermissions() async {
    var result = await _plugin.hasPermissions();
    if (result.isSuccess && result.data == true) return true;

    result = await _plugin.requestPermissions();
    return result.isSuccess && result.data == true;
  }

  Future<String?> _resolveCalendarId() async {
    final result = await _plugin.retrieveCalendars();
    if (!result.isSuccess || result.data == null) return null;

    final writable = result.data!
        .where((c) => c.id != null && !(c.isReadOnly ?? false))
        .toList();
    if (writable.isEmpty) return null;

    final email = (await _configuredEmail())?.trim().toLowerCase();
    if (email != null && email.isNotEmpty) {
      for (final calendar in writable) {
        final account = (calendar.accountName ?? '').toLowerCase();
        final name = (calendar.name ?? '').toLowerCase();
        if (account == email || name == email) {
          return calendar.id;
        }
      }
    }

    final preferred = writable.firstWhere(
      (c) => c.isDefault ?? false,
      orElse: () => writable.first,
    );
    return preferred.id;
  }

  Future<String?> _configuredEmail() async {
    try {
      return await _storageService?.getEmailConfig();
    } catch (_) {
      return null;
    }
  }

  void _ensureTimeZones() {
    if (_timeZonesReady) return;
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(_bestLocalLocation());
    } catch (_) {
      // Fall back to whatever `tz.local` already is (UTC).
    }
    _timeZonesReady = true;
  }

  /// The `timezone` package has no way to read the device's zone without an
  /// extra plugin, so pick the first zone whose current UTC offset matches the
  /// device. Good enough for all-day-ish assignment reminders.
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
