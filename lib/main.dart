import 'dart:async';

import 'package:assignment_tracker/models/models.dart';
import 'package:assignment_tracker/screens/assignments_screen.dart';
import 'package:assignment_tracker/screens/history_screen.dart';
import 'package:assignment_tracker/screens/settings_screen.dart';
import 'package:assignment_tracker/services/calendar_service.dart';
import 'package:assignment_tracker/services/notification_service.dart';
import 'package:assignment_tracker/services/storage_service.dart';
import 'package:assignment_tracker/theme/app_theme.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late StorageService _storageService;
  late CalendarService _calendarService;
  final NotificationService _notificationService = NotificationService();
  ThemeMode _themeMode = ThemeMode.system;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      _storageService = await StorageService.create();
      _calendarService = CalendarService(_storageService);

      // Initialize calendar service (non-blocking)
      _calendarService.initialize().catchError((_) {
        // Calendar initialization optional, app continues without it
        return false;
      });

      // Set up reminders (non-blocking, best effort).
      unawaited(_setUpReminders());

      setState(() => _isInitialized = true);
    } catch (e) {
      // Error initializing services, app continues with minimal functionality
      setState(() => _isInitialized = true);
    }
  }

  /// Ask for notification permission and (re)schedule reminders for every
  /// active assignment, so they survive reinstalls and clock changes.
  Future<void> _setUpReminders() async {
    try {
      await _notificationService.initialize();
      final assignments = await _storageService.getAssignments();
      for (final assignment in assignments) {
        if (assignment.status != AssignmentStatus.done) {
          await _notificationService.scheduleForAssignment(assignment);
        }
      }
    } catch (e) {
      debugPrint('Reminder setup skipped: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        title: 'Assignment Tracker',
        theme: AppTheme.getLightTheme(),
        darkTheme: AppTheme.getDarkTheme(),
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      title: 'Assignment Tracker',
      theme: AppTheme.getLightTheme(),
      darkTheme: AppTheme.getDarkTheme(),
      themeMode: _themeMode,
      home: Home(
        storageService: _storageService,
        calendarService: _calendarService,
        notificationService: _notificationService,
        onThemeChanged: (theme) {
          setState(() => _themeMode = theme);
        },
      ),
    );
  }
}

class Home extends StatefulWidget {
  final StorageService storageService;
  final CalendarService calendarService;
  final NotificationService notificationService;
  final ValueChanged<ThemeMode> onThemeChanged;

  const Home({
    super.key,
    required this.storageService,
    required this.calendarService,
    required this.notificationService,
    required this.onThemeChanged,
  });

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _checkAndMoveDoneAssignments();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    if (index == 0) {
      _checkAndMoveDoneAssignments();
    }
  }

  void _onPageChanged(int index) {
    setState(() => _selectedIndex = index);
    if (index == 0) {
      _checkAndMoveDoneAssignments();
    }
  }

  Future<void> _checkAndMoveDoneAssignments() async {
    try {
      final assignments = await widget.storageService.getAssignments();
      for (final assignment in assignments) {
        if (assignment.status == AssignmentStatus.done) {
          if (assignment.calendarEventId != null) {
            await widget.calendarService
                .deleteEvent(assignment.calendarEventId!);
          }
          await widget.notificationService
              .cancelForAssignmentId(assignment.id);
          await widget.storageService.moveToHistory(assignment);
        }
      }
    } catch (e) {
      // Error checking assignments
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      AssignmentsScreen(
        storageService: widget.storageService,
        calendarService: widget.calendarService,
        notificationService: widget.notificationService,
      ),
      HistoryScreen(
        storageService: widget.storageService,
        calendarService: widget.calendarService,
        notificationService: widget.notificationService,
      ),
      SettingsScreen(
        storageService: widget.storageService,
        currentTheme: Theme.of(context).brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        onThemeChanged: widget.onThemeChanged,
      ),
    ];

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.assignment),
            label: 'Assignments',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
