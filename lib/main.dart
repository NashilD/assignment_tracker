import 'package:assignment_tracker/models/models.dart';
import 'package:assignment_tracker/screens/assignments_screen.dart';
import 'package:assignment_tracker/screens/history_screen.dart';
import 'package:assignment_tracker/screens/settings_screen.dart';
import 'package:assignment_tracker/services/calendar_service.dart';
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
      _calendarService = CalendarService();

      // Initialize calendar service (non-blocking)
      _calendarService.initialize().catchError((_) {
        // Calendar initialization optional, app continues without it
        return false;
      });

      setState(() => _isInitialized = true);
    } catch (e) {
      // Error initializing services, app continues with minimal functionality
      setState(() => _isInitialized = true);
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
  final ValueChanged<ThemeMode> onThemeChanged;

  const Home({
    super.key,
    required this.storageService,
    required this.calendarService,
    required this.onThemeChanged,
  });

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkAndMoveDoneAssignments();
  }

  Future<void> _checkAndMoveDoneAssignments() async {
    try {
      final assignments = await widget.storageService.getAssignments();
      for (final assignment in assignments) {
        if (assignment.status == AssignmentStatus.done) {
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
      ),
      HistoryScreen(
        storageService: widget.storageService,
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
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          if (index == 0) {
            _checkAndMoveDoneAssignments();
          }
        },
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
