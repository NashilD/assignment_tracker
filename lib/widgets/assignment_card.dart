import 'package:assignment_tracker/models/models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A modern card widget displaying assignment information
class AssignmentCard extends StatelessWidget {
  final Assignment assignment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onStatusChanged;

  const AssignmentCard({
    super.key,
    required this.assignment,
    required this.onEdit,
    required this.onDelete,
    this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Course name and actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Course badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: assignment.courseName != 'Unknown'
                          ? Colors.grey.shade300
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      assignment.courseName,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Actions menu
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'delete') {
                        onDelete();
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
                ],
              ),
              const SizedBox(height: 12),

              // Assignment title
              Text(
                assignment.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                assignment.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Due date and days remaining
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 16,
                      color: colorScheme.onSurface.withValues(alpha: 0.7)),
                  const SizedBox(width: 8),
                  if (assignment.dueDate != null)
                    Text(
                      DateFormat('MMM dd, yyyy').format(assignment.dueDate!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    )
                  else
                    Text(
                      'No due date',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  const Spacer(),
                  // Days remaining badge
                  if (assignment.dueDate != null)
                    _DaysRemainingBadge(assignment: assignment),
                ],
              ),
              const SizedBox(height: 12),

              // Status badge and actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatusBadge(status: assignment.status),
                  if (assignment.hasCalendarEvent)
                    Tooltip(
                      message: 'Synced to calendar',
                      child: Icon(
                        Icons.check_circle,
                        size: 20,
                        color: Colors.green.shade600,
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

/// Widget displaying days remaining until due date
class _DaysRemainingBadge extends StatelessWidget {
  final Assignment assignment;

  const _DaysRemainingBadge({required this.assignment});

  @override
  Widget build(BuildContext context) {
    final daysRemaining = assignment.daysRemaining;
    final isOverdue = assignment.isOverdue;
    final isDueToday = assignment.isDueToday;

    Color badgeColor;
    String text;

    if (isOverdue) {
      badgeColor = Colors.red.shade100;
      text = 'Overdue';
    } else if (isDueToday) {
      badgeColor = Colors.orange.shade100;
      text = 'Due Today';
    } else if (daysRemaining <= 3) {
      badgeColor = Colors.orange.shade100;
      text = '$daysRemaining day${daysRemaining == 1 ? '' : 's'}';
    } else {
      badgeColor = Colors.green.shade100;
      text = '$daysRemaining days';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isOverdue ? Colors.red.shade700 : Colors.orange.shade700,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// Status badge showing assignment status
class StatusBadge extends StatelessWidget {
  final AssignmentStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: status.color.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status.icon,
            size: 16,
            color: status.color,
          ),
          const SizedBox(width: 6),
          Text(
            status.displayName,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: status.color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

/// History card showing completed assignment
class HistoryCard extends StatelessWidget {
  final Assignment assignment;
  final VoidCallback onDelete;
  final VoidCallback? onRestore;

  const HistoryCard({
    super.key,
    required this.assignment,
    required this.onDelete,
    this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    assignment.courseName,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      onDelete();
                    } else if (value == 'restore') {
                      onRestore?.call();
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(
                      value: 'restore',
                      child: Row(
                        children: [
                          Icon(Icons.restore),
                          SizedBox(width: 8),
                          Text('Restore'),
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
              ],
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              assignment.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(height: 12),

            // Completion info
            Row(
              children: [
                Icon(Icons.check_circle,
                    size: 16, color: Colors.green.shade600),
                const SizedBox(width: 8),
                if (assignment.completedAt != null)
                  Text(
                    'Completed: ${DateFormat('MMM dd, yyyy').format(assignment.completedAt!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
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
