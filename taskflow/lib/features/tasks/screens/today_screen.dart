import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/task_model.dart' as model;
import '../providers/task_provider.dart';
import 'settings_screen.dart';
import '../widgets/task_card.dart';
import '../widgets/task_editor_sheet.dart';
import '../widgets/subtasks_sheet.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

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
            startDate,
            dueDate,
            priority,
            alarmMode,
            customAlarmAt,
            reminderOffsets,
          ) async {
            if (task == null) {
              await actions.createTask(
                title: title,
                description: description,
                startDate: startDate,
                dueDate: dueDate,
                priority: priority,
                alarmMode: alarmMode,
                customAlarmAt: customAlarmAt,
                reminderOffsets: reminderOffsets,
              );
              return;
            }

            await actions.updateTask(
              task: task,
              title: title,
              description: description,
              startDate: startDate,
              dueDate: dueDate,
              priority: priority,
              alarmMode: alarmMode,
              customAlarmAt: customAlarmAt,
              reminderOffsets: reminderOffsets,
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
        content: Text(completedNow
            ? 'Task marked as complete'
            : 'Task moved back to pending'),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(todayTasksProvider);
    final now = DateTime.now();
    final dateLabel = MaterialLocalizations.of(context).formatFullDate(now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
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
              'Could not load tasks.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (tasks) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateLabel,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tasks.isEmpty
                          ? 'No tasks queued for today'
                          : '${tasks.length} task${tasks.length == 1 ? '' : 's'} to focus on',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Text(
                            'Start with one task. Keep it small and clear.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return TaskCard(
                            task: task,
                            animationIndex: index,
                            onToggle: () => _toggleTask(context, ref, task),
                            onTap: () => _openEditorSheet(
                              context,
                              ref,
                              task: task,
                            ),
                            onLongPress: () =>
                                _openSubtasksSheet(context, task),
                            onDelete: () => _deleteTask(context, ref, task),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditorSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
      ),
    );
  }
}
