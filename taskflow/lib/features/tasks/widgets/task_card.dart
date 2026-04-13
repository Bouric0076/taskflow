import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/task_model.dart' as model;
import '../utils/task_share_utility.dart';
import 'task_notes_panel.dart';
import '../utils/recurrence_utility.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onTap,
    this.onLongPress,
    required this.onDelete,
    required this.animationIndex,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onDelete;
  final int animationIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localizations = MaterialLocalizations.of(context);
    final dueDateLabel = task.dueDate == null
        ? 'No deadline'
        : '${localizations.formatCompactDate(task.dueDate!)} • ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(task.dueDate!))}';
    final startDateLabel = task.startDate == null
        ? null
        : 'Start ${localizations.formatCompactDate(task.startDate!)} • ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(task.startDate!))}';
    final alarmSummary = _alarmSummary(task, localizations);

    final card = Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: IconButton(
          onPressed: onToggle,
          icon: Icon(
            task.status == model.TaskStatus.completed
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            color: task.status == model.TaskStatus.completed
                ? AppColors.priorityNormal
                : (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary),
          ),
        ),
        title: Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                decoration: task.status == model.TaskStatus.completed
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((task.description ?? '').trim().isNotEmpty)
                Text(
                  task.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              if ((task.notes ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.note_outlined,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        task.notes!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
              if (task.isRecurring) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.repeat,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Repeats ${formatWeeklyRecurrenceRule(task.recurrenceRule)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  _PriorityChip(priority: task.priority),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dueDateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              if (startDateLabel != null) ...[
                const SizedBox(height: 4),
                Text(
                  startDateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 4),
              Text(
                alarmSummary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') {
              onDelete();
            } else if (value == 'share') {
              TaskShareUtility.shareTask(task);
            } else if (value == 'notes') {
              showTaskNotesPanel(context, task);
            }
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem<String>(
              value: 'notes',
              child: Row(
                children: [
                  Icon(Icons.note_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('Notes'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('Share'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return card
        .animate(delay: (60 * animationIndex).ms)
        .fadeIn(duration: 240.ms)
        .slideY(
            begin: 0.08, end: 0, duration: 240.ms, curve: Curves.easeOutCubic);
  }

  String _alarmSummary(Task task, MaterialLocalizations localizations) {
    if (!task.hasAlarm || task.alarmMode == model.AlarmMode.none) {
      return 'Alarm off';
    }

    final modeLabel = switch (task.alarmMode) {
      model.AlarmMode.none => 'off',
      model.AlarmMode.atStart => 'at start',
      model.AlarmMode.atDue => 'at due',
      model.AlarmMode.customTime => 'custom',
    };

    final offsets = (task.reminderOffsets ?? '')
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .where((e) => e > 0)
        .toList()
      ..sort();

    final offsetText = offsets.isEmpty
        ? 'none'
        : offsets.take(2).map((m) => '${m}m').join(', ');

    if (task.alarmMode == model.AlarmMode.customTime && task.alarmAt != null) {
      final when =
          '${localizations.formatCompactDate(task.alarmAt!)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(task.alarmAt!))}';
      return 'Alarm $modeLabel ($when) • Reminders $offsetText';
    }

    return 'Alarm $modeLabel • Reminders $offsetText';
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});

  final model.Priority priority;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color fg;
    String label;

    switch (priority) {
      case model.Priority.normal:
        bg = isDark
            ? AppColors.darkPriorityNormalBg
            : AppColors.priorityNormalBg;
        fg = AppColors.priorityNormal;
        label = 'Normal';
        break;
      case model.Priority.important:
        bg = isDark
            ? AppColors.darkPriorityImportantBg
            : AppColors.priorityImportantBg;
        fg = AppColors.priorityImportant;
        label = 'Important';
        break;
      case model.Priority.critical:
        bg = isDark
            ? AppColors.darkPriorityCriticalBg
            : AppColors.priorityCriticalBg;
        fg = AppColors.priorityCritical;
        label = 'Critical';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
