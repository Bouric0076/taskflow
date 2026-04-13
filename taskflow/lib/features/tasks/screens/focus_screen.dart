import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/task_model.dart' as model;
import 'settings_screen.dart';
import '../providers/focus_provider.dart';
import '../providers/morning_prompt_provider.dart';
import '../providers/stats_provider.dart';
import '../providers/task_provider.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  Task? _activeTaskForSession(List<Task> tasks, int? taskId) {
    if (taskId == null) return null;

    for (final task in tasks) {
      if (task.id == taskId && task.status != model.TaskStatus.completed) {
        return task;
      }
    }

    return null;
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Color _phaseColor(BuildContext context, FocusPhase phase) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (phase == FocusPhase.focus) {
      return AppColors.accent;
    }
    return isDark ? AppColors.priorityImportant : AppColors.priorityImportant;
  }

  Future<void> _chooseTask(
    BuildContext context,
    WidgetRef ref,
    List<Task> tasks,
  ) async {
    final pendingTasks = tasks
        .where((task) => task.status != model.TaskStatus.completed)
        .toList();

    if (pendingTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a task before starting focus mode.')),
      );
      return;
    }

    final selectedId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Choose active task',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: pendingTasks.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final task = pendingTasks[index];
                      final subtitle = task.dueDate == null
                          ? 'No due date'
                          : 'Due ${MaterialLocalizations.of(context).formatCompactDate(task.dueDate!)}';
                      return ListTile(
                        title: Text(task.title),
                        subtitle: Text(subtitle),
                        trailing: task.priority == model.Priority.critical
                            ? const Icon(Icons.warning_amber_rounded)
                            : null,
                        onTap: () => Navigator.of(context).pop(task.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedId == null || !context.mounted) return;
    ref.read(focusSessionProvider.notifier).selectTask(selectedId);
  }

  Widget _buildPresetChip(
    BuildContext context,
    WidgetRef ref,
    FocusSessionState state,
    int focusMinutes,
    int breakMinutes,
  ) {
    final isSelected = state.focusMinutes == focusMinutes &&
        state.breakMinutes == breakMinutes;
    return ChoiceChip(
      label: Text('$focusMinutes/$breakMinutes'),
      selected: isSelected,
      onSelected: (_) {
        ref.read(focusSessionProvider.notifier).setPresetDurations(
              focusMinutes: focusMinutes,
              breakMinutes: breakMinutes,
            );
      },
    );
  }

  Future<void> _openSettings(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<Task>>>(allTasksProvider, (previous, next) {
      final currentSession = ref.read(focusSessionProvider);
      if (currentSession.taskId == null) return;

      final tasks = next.asData?.value;
      if (tasks == null) return;

      final selectedTask =
          _activeTaskForSession(tasks, currentSession.taskId);
      if (selectedTask == null) {
        ref.read(focusSessionProvider.notifier).selectTask(null);
      }
    });

    final tasksAsync = ref.watch(allTasksProvider);
    final todayAsync = ref.watch(todayTasksProvider);
    final session = ref.watch(focusSessionProvider);
    final stats = ref.watch(productivityStatsProvider);
    final morningPrompt = ref.watch(morningPromptProvider);
    final tasks = tasksAsync.asData?.value ?? const <Task>[];
    final pendingTodayCount = todayAsync.asData?.value.length ?? 0;
    final activeTask = _activeTaskForSession(tasks, session.taskId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus'),
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
              'Could not load focus tasks.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (_) {
          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildPresetChip(context, ref, session, 25, 5),
                          const SizedBox(width: 8),
                          _buildPresetChip(context, ref, session, 50, 10),
                          const SizedBox(width: 8),
                          _buildPresetChip(context, ref, session, 90, 15),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: 240.ms,
                      child: activeTask == null
                          ? _EmptyFocusState(
                              taskCount: tasks
                                  .where((task) =>
                                      task.status != model.TaskStatus.completed)
                                  .length,
                              onChooseTask: () =>
                                  _chooseTask(context, ref, tasks),
                            )
                          : Column(
                              key: ValueKey(activeTask.id),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _ActiveTaskCard(
                                  task: activeTask,
                                  onClear: () {
                                    ref
                                        .read(focusSessionProvider.notifier)
                                        .selectTask(null);
                                  },
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        session.phase == FocusPhase.focus
                                            ? 'Focus'
                                            : 'Break',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              color: _phaseColor(
                                                  context, session.phase),
                                            ),
                                      ).animate().fadeIn(duration: 200.ms),
                                      const SizedBox(height: 10),
                                      Text(
                                        _formatDuration(
                                            session.remainingDuration),
                                        style: Theme.of(context)
                                            .textTheme
                                            .displayLarge
                                            ?.copyWith(
                                          fontSize: 64,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ).animate().fadeIn(duration: 180.ms),
                                      const SizedBox(height: 14),
                                      Text(
                                        session.phase == FocusPhase.focus
                                            ? 'Stay on one task. No switching.'
                                            : 'Take a short break, then return.',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                      const SizedBox(height: 24),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        alignment: WrapAlignment.center,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: () => ref
                                                .read(focusSessionProvider
                                                    .notifier)
                                                .toggleRunning(),
                                            icon: Icon(session.isRunning
                                                ? Icons.pause
                                                : Icons.play_arrow),
                                            label: Text(session.isRunning
                                                ? 'Pause'
                                                : 'Start'),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed: () => ref
                                                .read(focusSessionProvider
                                                    .notifier)
                                                .reset(),
                                            icon:
                                                const Icon(Icons.restart_alt),
                                            label: const Text('Reset'),
                                          ),
                                          TextButton.icon(
                                            onPressed: () => ref
                                                .read(focusSessionProvider
                                                    .notifier)
                                                .skipPhase(),
                                            icon: const Icon(Icons.skip_next),
                                            label: const Text('Skip'),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Completed focus sessions: ${session.completedFocusSessions}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _chooseTask(context, ref, tasks),
                      icon: const Icon(Icons.task_alt),
                      label: Text(
                        activeTask == null
                            ? 'Choose active task'
                            : 'Change active task',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _StatsCard(stats: stats),
                    const SizedBox(height: 12),
                    _MorningPromptCard(
                      settings: morningPrompt,
                      onToggle: (enabled) {
                        ref
                            .read(morningPromptProvider.notifier)
                            .setEnabled(enabled, taskCount: pendingTodayCount);
                      },
                      onPickTime: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: morningPrompt.time,
                        );
                        if (picked == null || !context.mounted) return;

                        await ref
                            .read(morningPromptProvider.notifier)
                            .setTime(picked, taskCount: pendingTodayCount);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyFocusState extends StatelessWidget {
  const _EmptyFocusState({
    required this.taskCount,
    required this.onChooseTask,
  });

  final int taskCount;
  final VoidCallback onChooseTask;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('empty-focus-state'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.center_focus_strong,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Focus Mode',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            taskCount == 0
                ? 'No active tasks yet. Create one and come back.'
                : 'Pick one task to block out distractions and start a Pomodoro session.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onChooseTask,
            child: const Text('Choose task'),
          ),
        ],
      ),
    );
  }
}

class _ActiveTaskCard extends StatelessWidget {
  const _ActiveTaskCard({
    required this.task,
    required this.onClear,
  });

  final Task task;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final dueText = task.dueDate == null
        ? 'No due date'
        : 'Due ${MaterialLocalizations.of(context).formatCompactDate(task.dueDate!)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Active task',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              task.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if ((task.description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                task.description!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Text(
              dueText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final ProductivityStats stats;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxCount = stats.last7DaysCompletions.isEmpty
        ? 1
        : math.max(1, stats.last7DaysCompletions.reduce(math.max));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.divider,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Productivity',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _StatPill(label: 'Today', value: '${stats.completedToday}'),
                _StatPill(
                    label: 'This week', value: '${stats.completedThisWeek}'),
                _StatPill(label: 'Streak', value: '${stats.currentStreak}d'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: stats.last7DaysCompletions
                    .map(
                      (value) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: math.max(6, 52 * (value / maxCount)),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _MorningPromptCard extends StatelessWidget {
  const _MorningPromptCard({
    required this.settings,
    required this.onToggle,
    required this.onPickTime,
  });

  final MorningPromptSettings settings;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.divider,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Daily morning prompt',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Switch(
                  value: settings.enabled,
                  onChanged: onToggle,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Reminder time: ${settings.time.format(context)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onPickTime,
              icon: const Icon(Icons.schedule),
              label: const Text('Set time'),
            ),
          ],
        ),
      ),
    );
  }
}
