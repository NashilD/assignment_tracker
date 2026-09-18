import 'package:assignment_tracker/models/models.dart';
import 'package:assignment_tracker/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

/// Settings screen for managing courses, theme, and email configuration
class SettingsScreen extends StatefulWidget {
  final StorageService storageService;
  final ThemeMode currentTheme;
  final ValueChanged<ThemeMode> onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.storageService,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const List<int> _retentionPresets = [1, 2, 3, 5, 6, 12, 0];
  static const int _customRetentionOption = -1;
  static const int _maxRetentionMonths = 120;

  late List<Course> _courses = [];
  late String? _emailConfig;
  int _historyRetentionMonths = StorageService.defaultHistoryRetentionMonths;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final courses = await widget.storageService.getCourses();
      final email = await widget.storageService.getEmailConfig();
      final retention = await widget.storageService.getHistoryRetentionMonths();

      setState(() {
        _courses = courses;
        _emailConfig = email;
        _historyRetentionMonths = retention;
      });
    } catch (e) {
      // Error loading settings
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateHistoryRetention(int months) async {
    await widget.storageService.saveHistoryRetentionMonths(months);
    setState(() => _historyRetentionMonths = months);
  }

  String _retentionLabel(int months) {
    if (months <= 0) return 'Never';
    if (months == 1) return '1 month';
    return '$months months';
  }

  /// Dropdown items: the presets, plus the current value if it's a custom
  /// number not already in the presets, plus a trailing "Custom…" entry.
  List<DropdownMenuItem<int>> _retentionDropdownItems() {
    final values = <int>{..._retentionPresets, _historyRetentionMonths}
        .toList()
      ..sort((a, b) {
        if (a == 0) return 1;
        if (b == 0) return -1;
        return a.compareTo(b);
      });

    return [
      for (final months in values)
        DropdownMenuItem(value: months, child: Text(_retentionLabel(months))),
      const DropdownMenuItem(
        value: _customRetentionOption,
        child: Text('Custom…'),
      ),
    ];
  }

  Future<void> _handleRetentionSelected(int value) async {
    if (value == _customRetentionOption) {
      final months = await showDialog<int>(
        context: context,
        builder: (context) => _CustomRetentionDialog(
          initialMonths: _historyRetentionMonths,
          maxMonths: _maxRetentionMonths,
        ),
      );
      if (months != null) {
        await _updateHistoryRetention(months);
      }
    } else {
      await _updateHistoryRetention(value);
    }
  }

  Future<void> _addCourse() async {
    final result = await showDialog<Course>(
      context: context,
      builder: (context) => _CourseEditDialog(
        storageService: widget.storageService,
      ),
    );

    if (result != null) {
      setState(() => _courses.add(result));
      await widget.storageService.saveCourse(result);
    }
  }

  Future<void> _editCourse(Course course) async {
    final result = await showDialog<Course>(
      context: context,
      builder: (context) => _CourseEditDialog(
        storageService: widget.storageService,
        course: course,
      ),
    );

    if (result != null) {
      final index = _courses.indexWhere((c) => c.id == course.id);
      if (index >= 0) {
        setState(() => _courses[index] = result);
        await widget.storageService.saveCourse(result);
      }
    }
  }

  Future<void> _deleteCourse(Course course) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Course'),
        content: Text('Delete "${course.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _courses.removeWhere((c) => c.id == course.id));
      await widget.storageService.deleteCourse(course.id);
    }
  }

  Future<void> _updateEmailConfig() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _EmailConfigDialog(
        initialEmail: _emailConfig,
      ),
    );

    if (result != null) {
      await widget.storageService.saveEmailConfig(result);
      setState(() => _emailConfig = result);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email configuration updated')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Theme section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Appearance',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Theme',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 12),
                                SegmentedButton<ThemeMode>(
                                  segments: const [
                                    ButtonSegment(
                                      value: ThemeMode.light,
                                      label: Text('Light'),
                                      icon: Icon(Icons.light_mode),
                                    ),
                                    ButtonSegment(
                                      value: ThemeMode.dark,
                                      label: Text('Dark'),
                                      icon: Icon(Icons.dark_mode),
                                    ),
                                    ButtonSegment(
                                      value: ThemeMode.system,
                                      label: Text('System'),
                                      icon: Icon(Icons.settings_brightness),
                                    ),
                                  ],
                                  selected: {widget.currentTheme},
                                  onSelectionChanged:
                                      (Set<ThemeMode> newSelection) {
                                    widget.onThemeChanged(newSelection.first);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Courses section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Courses',
                              style: theme.textTheme.headlineSmall,
                            ),
                            FloatingActionButton.small(
                              onPressed: _addCourse,
                              child: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_courses.isEmpty)
                          Center(
                            child: Text(
                              'No courses yet',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _courses.length,
                            itemBuilder: (context, index) {
                              final course = _courses[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: course.color,
                                    child: Text(
                                      course.name[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(course.name),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _editCourse(course);
                                      } else if (value == 'delete') {
                                        _deleteCourse(course);
                                      }
                                    },
                                    itemBuilder: (BuildContext context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit),
                                            SizedBox(width: 8),
                                            Text('Edit'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete),
                                            SizedBox(width: 8),
                                            Text('Delete'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // History retention section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'History',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Auto-delete completed assignments',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Automatically remove assignments from '
                                  'History after this much time.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  key: ValueKey(_historyRetentionMonths),
                                  initialValue: _historyRetentionMonths,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  items: _retentionDropdownItems(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      _handleRetentionSelected(value);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Email configuration section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calendar Integration',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Calendar Email',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 12),
                                InkWell(
                                  onTap: _updateEmailConfig,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: colorScheme.outline,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.email,
                                          color: colorScheme.primary,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Email for calendar events',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: colorScheme.onSurface
                                                      .withValues(alpha: 0.6),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _emailConfig ??
                                                    'Not configured',
                                                style:
                                                    theme.textTheme.bodyLarge,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.edit,
                                          color: colorScheme.primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}

/// Dialog for editing course details
class _CourseEditDialog extends StatefulWidget {
  final StorageService storageService;
  final Course? course;

  const _CourseEditDialog({
    required this.storageService,
    this.course,
  });

  @override
  State<_CourseEditDialog> createState() => _CourseEditDialogState();
}

class _CourseEditDialogState extends State<_CourseEditDialog> {
  late TextEditingController _nameController;
  late Color _selectedColor;

  final List<Color> _colors = [
    const Color(0xFFEC407A),
    const Color(0xFF9C27B0),
    const Color(0xFF4CAF50),
    const Color(0xFFFFA726),
    const Color(0xFF2196F3),
    const Color(0xFF00BCD4),
    const Color(0xFFFF5722),
    const Color(0xFF673AB7),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.course?.name ?? '');
    _selectedColor = widget.course?.color ?? _colors[0];
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.course == null ? 'Add Course' : 'Edit Course'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Course Name',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Enter course name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Color',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colors.map((color) {
                final isSelected = _selectedColor == color;
                return InkWell(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: Colors.white,
                              width: 3,
                            )
                          : null,
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty) {
              final course = widget.course ??
                  Course(
                    id: const Uuid().v4(),
                    name: _nameController.text,
                    color: _selectedColor,
                    isCustom: true,
                  );

              final updatedCourse = course.copyWith(
                name: _nameController.text,
                color: _selectedColor,
              );

              Navigator.pop(context, updatedCourse);
            }
          },
          child: Text(widget.course == null ? 'Add' : 'Update'),
        ),
      ],
    );
  }
}

/// Dialog for configuring calendar email
class _EmailConfigDialog extends StatefulWidget {
  final String? initialEmail;

  const _EmailConfigDialog({this.initialEmail});

  @override
  State<_EmailConfigDialog> createState() => _EmailConfigDialogState();
}

class _EmailConfigDialogState extends State<_EmailConfigDialog> {
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return email.isEmpty ||
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
            .hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Calendar Email'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter your email for calendar synchronization:',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              hintText: 'your.email@example.com',
              prefixIcon: const Icon(Icons.email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isValidEmail(_emailController.text)
              ? () => Navigator.pop(context, _emailController.text)
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Dialog for entering a custom History retention duration, in months.
class _CustomRetentionDialog extends StatefulWidget {
  final int initialMonths;
  final int maxMonths;

  const _CustomRetentionDialog({
    required this.initialMonths,
    required this.maxMonths,
  });

  @override
  State<_CustomRetentionDialog> createState() =>
      _CustomRetentionDialogState();
}

class _CustomRetentionDialogState extends State<_CustomRetentionDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialMonths > 0 ? '${widget.initialMonths}' : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    final months = int.tryParse(text);

    if (text.isEmpty || months == null) {
      setState(() => _errorText = 'Enter a number of months');
      return;
    }
    if (months < 1) {
      setState(() => _errorText = 'Must be at least 1 month');
      return;
    }
    if (months > widget.maxMonths) {
      setState(
        () => _errorText = 'Must be ${widget.maxMonths} months or fewer',
      );
      return;
    }

    Navigator.pop(context, months);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom Duration'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: 'Months',
          hintText: 'e.g. 4',
          errorText: _errorText,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) {
          if (_errorText != null) setState(() => _errorText = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
