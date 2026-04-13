import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/task_model.dart' as model;
import '../providers/task_provider.dart';
import 'settings_screen.dart';
import '../widgets/task_card.dart';
import '../widgets/task_editor_sheet.dart';
import '../widgets/subtasks_sheet.dart';

class UpcomingScreen extends ConsumerWidget {
  const UpcomingScreen({super.key});

  Future<void> _openEditorSheet(
    BuildContext context,
    WidgetRef ref, {
    Task? task,
  }) async {
    final actions = ref.read(taskActionsProvider);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return TaskEditorSheet(
          initialTask: task,
          onSubmit: (
            title,
            description,
            notes,
            startDate,
            dueDate,
            priority,
            alarmMode,
            customAlarmAt,
            reminderOffsets,
            isRecurring,
            recurrenceRule,
          ) async {
            if (task == null) {
              await actions.createTask(
                title: title,
                description: description,
                notes: notes,
                startDate: startDate,
                dueDate: dueDate,
                priority: priority,
                alarmMode: alarmMode,
                customAlarmAt: customAlarmAt,
                reminderOffsets: reminderOffsets,
                isRecurring: isRecurring,
                recurrenceRule: recurrenceRule,
              );
              return;
            }

            await actions.updateTask(
              task: task,
              title: title,
              description: description,
              notes: notes,
              startDate: startDate,
              dueDate: dueDate,
              priority: priority,
              alarmMode: alarmMode,
              customAlarmAt: customAlarmAt,
              reminderOffsets: reminderOffsets,
              isRecurring: isRecurring,
              recurrenceRule: recurrenceRule,
            );
          },
        );
      },
    );
  }

  Future<void> _toggleTask(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    await ref.read(taskActionsProvider).toggleCompletion(task);

    if (!context.mounted) return;
    final completedNow = task.status != model.TaskStatus.completed;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(task.isRecurring
            ? 'Recurring task advanced to the next occurrence'
            : (completedNow
                ? 'Task marked as complete'
                : 'Task moved back to pending')),
        duration: const Duration(milliseconds: 1100),
      ),
    );
  }

  Future<void> _deleteTask(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    await ref.read(taskActionsProvider).deleteTask(task.id);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${task.title}"'),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  Future<void> _openSubtasksSheet(
    BuildContext context,
    Task task,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SubtasksSheet(task: task),
    );
  }

  Future<void> _openSettings(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  DateTime _bucketDate(Task task) {
    final base = task.startDate ?? task.dueDate ?? task.createdAt;
    return DateTime(base.year, base.month, base.day);
  }

  DateTime _sortAnchor(Task task) {
    return task.startDate ?? task.dueDate ?? task.createdAt;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(upcomingTasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upcoming'),
        actions: [
          IconButton(
            onPressed: () => _openSettings(context),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Could not load upcoming tasks.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (tasks) {
          if (tasks.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  'No upcoming tasks in the next 7 days.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            );
          }

          final sorted = [...tasks]..sort((a, b) {
              final compare = _sortAnchor(a).compareTo(_sortAnchor(b));
              if (compare != 0) return compare;
              return b.priority.index.compareTo(a.priority.index);
            });

          final buckets = <DateTime, List<Task>>{};
          for (final task in sorted) {
            final key = _bucketDate(task);
            buckets.putIfAbsent(key, () => []).add(task);
          }

          final orderedKeys = buckets.keys.toList()..sort();
          final widgets = <Widget>[];
          var animationIndex = 0;

          for (final day in orderedKeys) {
            final label = MaterialLocalizations.of(context).formatFullDate(day);
            widgets.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            );

            for (final task in buckets[day]!) {
              widgets.add(
                TaskCard(
                  task: task,
                  animationIndex: animationIndex++,
                  onToggle: () => _toggleTask(context, ref, task),
                  onTap: () => _openEditorSheet(context, ref, task: task),
                  onLongPress: () => _openSubtasksSheet(context, task),
                  onDelete: () => _deleteTask(context, ref, task),
                ),
              );
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
            children: widgets,
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'upcoming-fab',
        onPressed: () => _openEditorSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
      ),
    );
  }
}
