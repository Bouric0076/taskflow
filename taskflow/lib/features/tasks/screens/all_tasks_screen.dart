import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/task_model.dart' as model;
import '../providers/task_provider.dart';
import 'settings_screen.dart';
import '../widgets/task_card.dart';
import '../widgets/task_editor_sheet.dart';
import '../widgets/subtasks_sheet.dart';

class AllTasksScreen extends ConsumerWidget {
  const AllTasksScreen({super.key});

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

  List<Task> _applyFilterSortSearch(
    List<Task> tasks,
    TaskFilter filter,
    TaskSort sort,
    String query,
  ) {
    final q = query.trim().toLowerCase();

    final filtered = tasks.where((task) {
      if (filter == TaskFilter.pending &&
          task.status == model.TaskStatus.completed) {
        return false;
      }

      if (filter == TaskFilter.completed &&
          task.status != model.TaskStatus.completed) {
        return false;
      }

      if (q.isEmpty) return true;
      final title = task.title.toLowerCase();
      final description = (task.description ?? '').toLowerCase();
      return title.contains(q) || description.contains(q);
    }).toList();

    filtered.sort((a, b) {
      switch (sort) {
        case TaskSort.dueDate:
          final ad = a.dueDate ?? DateTime(9999);
          final bd = b.dueDate ?? DateTime(9999);
          final compare = ad.compareTo(bd);
          if (compare != 0) return compare;
          return b.priority.index.compareTo(a.priority.index);
        case TaskSort.priority:
          final compare = b.priority.index.compareTo(a.priority.index);
          if (compare != 0) return compare;
          final ad = a.dueDate ?? DateTime(9999);
          final bd = b.dueDate ?? DateTime(9999);
          return ad.compareTo(bd);
        case TaskSort.createdAt:
          return b.createdAt.compareTo(a.createdAt);
      }
    });

    return filtered;
  }

  String _filterLabel(TaskFilter filter) {
    switch (filter) {
      case TaskFilter.all:
        return 'All';
      case TaskFilter.pending:
        return 'Pending';
      case TaskFilter.completed:
        return 'Completed';
    }
  }

  String _sortLabel(TaskSort sort) {
    switch (sort) {
      case TaskSort.dueDate:
        return 'Due date';
      case TaskSort.priority:
        return 'Priority';
      case TaskSort.createdAt:
        return 'Created';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(allTasksProvider);
    final filter = ref.watch(taskFilterProvider);
    final sort = ref.watch(taskSortProvider);
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Tasks'),
        actions: [
          IconButton(
            onPressed: () => _openSettings(context),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              onChanged: (value) =>
                  ref.read(searchQueryProvider.notifier).state = value,
              decoration: InputDecoration(
                hintText: 'Search tasks',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: () =>
                            ref.read(searchQueryProvider.notifier).state = '',
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: TaskFilter.values
                          .map(
                            (value) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(_filterLabel(value)),
                                selected: filter == value,
                                onSelected: (_) => ref
                                    .read(taskFilterProvider.notifier)
                                    .state = value,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<TaskSort>(
                  value: sort,
                  items: TaskSort.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_sortLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    ref.read(taskSortProvider.notifier).state = value;
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: tasksAsync.when(
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
                final result =
                    _applyFilterSortSearch(tasks, filter, sort, query);
                if (result.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Text(
                        'No tasks match your current filters.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                  itemCount: result.length,
                  itemBuilder: (context, index) {
                    final task = result[index];
                    return TaskCard(
                      task: task,
                      animationIndex: index,
                      onToggle: () => _toggleTask(context, ref, task),
                      onTap: () => _openEditorSheet(context, ref, task: task),
                      onLongPress: () => _openSubtasksSheet(context, task),
                      onDelete: () => _deleteTask(context, ref, task),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditorSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
      ),
    );
  }
}
