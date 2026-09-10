import 'package:assignment_tracker/models/models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A modern card widget displaying assignment information.
class AssignmentCard extends StatelessWidget {
  final Assignment assignment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<AssignmentStatus>? onStatusChanged;

  /// Colour of the assignment's course, used as a subtle accent.
  final Color? accentColor;

  const AssignmentCard({
    super.key,
    required this.assignment,
    required this.onEdit,
    required this.onDelete,
    this.onStatusChanged,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = accentColor ?? colorScheme.primary;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: course name and actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: _CourseChip(name: assignment.courseName, accent: accent),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Text(
                assignment.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (assignment.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  assignment.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),

              // Due date and days-remaining badge
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    assignment.dueDate != null
                        ? DateFormat('MMM dd, yyyy').format(assignment.dueDate!)
                        : 'No due date',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (assignment.dueDate != null)
                    _DaysRemainingBadge(assignment: assignment),
                ],
              ),
              const SizedBox(height: 12),

              // Status control + calendar indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (onStatusChanged != null)
                    StatusSelector(
                      status: assignment.status,
                      onChanged: onStatusChanged!,
                    )
                  else
                    StatusBadge(status: assignment.status),
                  if (assignment.hasCalendarEvent)
                    Tooltip(
                      message: 'Synced to calendar',
                      child: Icon(
                        Icons.event_available,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded course label with a coloured dot; text stays on-surface so it is
/// always readable regardless of the course colour or theme.
class _CourseChip extends StatelessWidget {
  final String name;
  final Color accent;

  const _CourseChip({required this.name, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: 0.14),
          theme.colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name.isEmpty ? 'No course' : name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget displaying days remaining until the due date.
class _DaysRemainingBadge extends StatelessWidget {
  final Assignment assignment;

  const _DaysRemainingBadge({required this.assignment});

  @override
  Widget build(BuildContext context) {
    final daysRemaining = assignment.daysRemaining;

    late final Color accent;
    late final String text;

    if (assignment.isOverdue) {
      accent = const Color(0xFFE5544B);
      text = 'Overdue';
    } else if (assignment.isDueToday) {
      accent = const Color(0xFFE08A2E);
      text = 'Due today';
    } else if (daysRemaining <= 3) {
      accent = const Color(0xFFE08A2E);
      text = '$daysRemaining day${daysRemaining == 1 ? '' : 's'}';
    } else {
      accent = const Color(0xFF3FA46A);
      text = '$daysRemaining days';
    }

    return _Pill(accent: accent, text: text);
  }
}

/// Static status badge (used where the status is not editable).
class StatusBadge extends StatelessWidget {
  final AssignmentStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return _Pill(
      accent: status.color,
      text: status.displayName,
      icon: status.icon,
    );
  }
}

/// Tappable status badge that lets the user change an assignment's status
/// (Not Started / In Progress / Done) directly from the list.
class StatusSelector extends StatelessWidget {
  final AssignmentStatus status;
  final ValueChanged<AssignmentStatus> onChanged;

  const StatusSelector({
    super.key,
    required this.status,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AssignmentStatus>(
      tooltip: 'Change status',
      initialValue: status,
      onSelected: onChanged,
      itemBuilder: (context) => AssignmentStatus.values
          .map(
            (s) => PopupMenuItem<AssignmentStatus>(
              value: s,
              child: Row(
                children: [
                  Icon(s.icon, size: 18, color: s.color),
                  const SizedBox(width: 8),
                  Text(s.displayName),
                  if (s == status) ...[
                    const Spacer(),
                    const Icon(Icons.check, size: 16),
                  ],
                ],
              ),
            ),
          )
          .toList(),
      child: _Pill(
        accent: status.color,
        text: status.displayName,
        icon: status.icon,
        trailing: Icons.arrow_drop_down,
      ),
    );
  }
}

/// Shared translucent pill used for status and due-date badges. The fill is the
/// accent hue blended onto the surface, so it reads in both light and dark.
class _Pill extends StatelessWidget {
  final Color accent;
  final String text;
  final IconData? icon;
  final IconData? trailing;

  const _Pill({
    required this.accent,
    required this.text,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.only(
        left: icon != null ? 8 : 12,
        right: trailing != null ? 4 : 12,
        top: 6,
        bottom: 6,
      ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: 0.16),
          theme.colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: accent),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (trailing != null) Icon(trailing, size: 18, color: accent),
        ],
      ),
    );
  }
}

/// Centered icon + message shown when a list has no items.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// History card showing a completed assignment.
class HistoryCard extends StatelessWidget {
  final Assignment assignment;
  final VoidCallback onDelete;
  final VoidCallback? onRestore;
  final Color? accentColor;

  const HistoryCard({
    super.key,
    required this.assignment,
    required this.onDelete,
    this.onRestore,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = accentColor ?? colorScheme.primary;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: _CourseChip(name: assignment.courseName, accent: accent),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  onSelected: (value) {
                    if (value == 'delete') {
                      onDelete();
                    } else if (value == 'restore') {
                      onRestore?.call();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'restore',
                      child: Row(
                        children: [
                          Icon(Icons.restore),
                          SizedBox(width: 8),
                          Text('Restore'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              assignment.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.lineThrough,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Icon(Icons.check_circle,
                    size: 16, color: const Color(0xFF3FA46A)),
                const SizedBox(width: 8),
                Text(
                  assignment.completedAt != null
                      ? 'Completed ${DateFormat('MMM dd, yyyy').format(assignment.completedAt!)}'
                      : 'Completed',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
