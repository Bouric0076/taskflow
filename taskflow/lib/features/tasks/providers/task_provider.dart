import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:drift/drift.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/notification_service.dart';
import '../../../core/utils/task_schedule_service.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/task_model.dart' as model;
import '../utils/recurrence_utility.dart';

// ── DB instance ──────────────────────────────────────────

final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// ── Task streams ─────────────────────────────────────────

final todayTasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(dbProvider).watchTodayTasks();
});

final upcomingTasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(dbProvider).watchUpcomingTasks();
});

final overdueTasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(dbProvider).watchOverdueTasks();
});

final allTasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(dbProvider).watchAllTasks();
});

final taskTemplatesProvider = StreamProvider<List<TaskTemplate>>((ref) {
  return ref.watch(dbProvider).watchTaskTemplates();
});

final subtasksProvider =
    StreamProvider.family<List<Subtask>, int>((ref, taskId) {
  return ref.watch(dbProvider).watchSubtasksForTask(taskId);
});

// ── Filter state ─────────────────────────────────────────

enum TaskFilter { all, pending, completed }

enum TaskSort { dueDate, priority, createdAt }

final taskFilterProvider = StateProvider<TaskFilter>((ref) => TaskFilter.all);
final taskSortProvider = StateProvider<TaskSort>((ref) => TaskSort.dueDate);
final searchQueryProvider = StateProvider<String>((ref) => '');

// ── Settings ─────────────────────────────────────────

// Import from settings_provider
// Use appSettingsProvider.select((settings) => settings.asData?.value.isDarkMode ?? false)
// for the theme

final taskScheduleServiceProvider = Provider<TaskScheduleService>((ref) {
  final db = ref.watch(dbProvider);
  return TaskScheduleService(NotificationService(), database: db);
});

final taskActionsProvider = Provider<TaskActions>((ref) {
  return TaskActions(
    ref.watch(dbProvider),
    ref.watch(taskScheduleServiceProvider),
  );
});

class TaskActions {
  TaskActions(this._db, this._scheduler);

  final AppDatabase _db;
  final TaskScheduleService _scheduler;

  model.AlarmMode _resolveAlarmMode({
    required DateTime? startDate,
    required DateTime? dueDate,
    model.AlarmMode? requestedMode,
  }) {
    if (requestedMode != null) return requestedMode;

    if (startDate != null && dueDate != null) return model.AlarmMode.atStart;
    if (dueDate != null) return model.AlarmMode.atDue;
    return model.AlarmMode.none;
  }

  DateTime? _resolveAlarmAt({
    required model.AlarmMode alarmMode,
    required DateTime? startDate,
    required DateTime? dueDate,
    DateTime? customAlarmAt,
  }) {
    switch (alarmMode) {
      case model.AlarmMode.none:
        return null;
      case model.AlarmMode.atStart:
        return startDate ?? dueDate;
      case model.AlarmMode.atDue:
        return dueDate ?? startDate;
      case model.AlarmMode.customTime:
        return customAlarmAt ?? startDate ?? dueDate;
    }
  }

  String? _validateSchedule({
    required DateTime? startDate,
    required DateTime? dueDate,
    required model.AlarmMode alarmMode,
    required DateTime? alarmAt,
    required DateTime? customAlarmAt,
    required bool isRecurring,
  }) {
    if (startDate != null && dueDate != null && dueDate.isBefore(startDate)) {
      return 'Due time must be after start time.';
    }

    if (alarmMode == model.AlarmMode.customTime && customAlarmAt == null) {
      return 'Custom alarm requires a selected time.';
    }

    if (alarmMode == model.AlarmMode.customTime &&
        customAlarmAt != null &&
        startDate != null &&
        dueDate != null &&
        (customAlarmAt.isBefore(startDate) || customAlarmAt.isAfter(dueDate))) {
      return 'Custom alarm must be between start and due time.';
    }

    if (alarmMode != model.AlarmMode.none &&
        alarmAt != null &&
        !isRecurring &&
        !alarmAt.isAfter(DateTime.now())) {
      return 'Alarm time must be in the future.';
    }

    return null;
  }

  String? _serializeReminderOffsets(List<int>? reminderOffsets) {
    final values = (reminderOffsets ?? [AppConstants.defaultReminderMinutes])
        .where((e) => e > 0)
        .toSet()
        .toList()
      ..sort();

    if (values.isEmpty) return null;
    return values.join(',');
  }

  Future<int> createTask({
    required String title,
    String? description,
    String? notes,
    DateTime? startDate,
    DateTime? dueDate,
    model.Priority priority = model.Priority.normal,
    model.AlarmMode? alarmMode,
    DateTime? customAlarmAt,
    List<int>? reminderOffsets,
    bool isRecurring = false,
    String? recurrenceRule,
  }) async {
    final trimmedTitle = title.trim();
    final trimmedDescription = description?.trim();
    final trimmedNotes = notes?.trim();
    final resolvedMode = _resolveAlarmMode(
      startDate: startDate,
      dueDate: dueDate,
      requestedMode: alarmMode,
    );
    final resolvedAlarmAt = _resolveAlarmAt(
      alarmMode: resolvedMode,
      startDate: startDate,
      dueDate: dueDate,
      customAlarmAt: customAlarmAt,
    );
    final normalizedRecurrenceRule = serializeWeeklyRecurrenceRule(
      parseWeeklyRecurrenceRule(recurrenceRule),
    );
    final recurringEnabled = isRecurring && normalizedRecurrenceRule != null;

    final validationError = _validateSchedule(
      startDate: startDate,
      dueDate: dueDate,
      alarmMode: resolvedMode,
      alarmAt: resolvedAlarmAt,
      customAlarmAt: customAlarmAt,
      isRecurring: recurringEnabled,
    );
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    if (isRecurring &&
        normalizedRecurrenceRule == null) {
      throw ArgumentError('Pick at least one day for the weekly repeat.');
    }

    final serializedOffsets = _serializeReminderOffsets(reminderOffsets);
    final firstReminder = serializedOffsets == null
        ? null
        : int.tryParse(serializedOffsets.split(',').first);
    final hasAlarm =
        resolvedMode != model.AlarmMode.none && resolvedAlarmAt != null;

    final newTaskId = await _db.insertTask(
      TasksCompanion.insert(
        title: trimmedTitle,
        description: Value(
            trimmedDescription?.isEmpty == true ? null : trimmedDescription),
        notes: Value(trimmedNotes?.isEmpty == true ? null : trimmedNotes),
        startDate: Value(startDate),
        dueDate: Value(dueDate),
        priority: priority,
        status: model.TaskStatus.pending,
        hasAlarm: Value(hasAlarm),
        isRecurring: Value(recurringEnabled),
        recurrenceRule: Value(normalizedRecurrenceRule),
        alarmMode: Value(resolvedMode),
        alarmAt: Value(resolvedAlarmAt),
        reminderOffsets: Value(serializedOffsets),
        reminderMinutes: Value(firstReminder),
      ),
    );

    final createdTask = await _db.getTaskById(newTaskId);
    await _scheduler.syncForTask(createdTask);

    return newTaskId;
  }

  Future<bool> updateTask({
    required Task task,
    required String title,
    String? description,
    String? notes,
    DateTime? startDate,
    DateTime? dueDate,
    required model.Priority priority,
    model.AlarmMode? alarmMode,
    DateTime? customAlarmAt,
    List<int>? reminderOffsets,
    bool isRecurring = false,
    String? recurrenceRule,
  }) async {
    final trimmedTitle = title.trim();
    final trimmedDescription = description?.trim();
    final trimmedNotes = notes?.trim();
    final resolvedMode = _resolveAlarmMode(
      startDate: startDate,
      dueDate: dueDate,
      requestedMode: alarmMode,
    );
    final resolvedAlarmAt = _resolveAlarmAt(
      alarmMode: resolvedMode,
      startDate: startDate,
      dueDate: dueDate,
      customAlarmAt: customAlarmAt,
    );
    final normalizedRecurrenceRule = serializeWeeklyRecurrenceRule(
      parseWeeklyRecurrenceRule(recurrenceRule),
    );
    final recurringEnabled = isRecurring && normalizedRecurrenceRule != null;

    final validationError = _validateSchedule(
      startDate: startDate,
      dueDate: dueDate,
      alarmMode: resolvedMode,
      alarmAt: resolvedAlarmAt,
      customAlarmAt: customAlarmAt,
      isRecurring: recurringEnabled,
    );
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    if (isRecurring && normalizedRecurrenceRule == null) {
      throw ArgumentError('Pick at least one day for the weekly repeat.');
    }

    final serializedOffsets = _serializeReminderOffsets(reminderOffsets);
    final firstReminder = serializedOffsets == null
        ? null
        : int.tryParse(serializedOffsets.split(',').first);
    final hasAlarm =
        resolvedMode != model.AlarmMode.none && resolvedAlarmAt != null;

    await _db.patchTask(
      task.id,
      TasksCompanion(
        title: Value(trimmedTitle),
        description: Value(
            trimmedDescription?.isEmpty == true ? null : trimmedDescription),
        notes: Value(trimmedNotes?.isEmpty == true ? null : trimmedNotes),
        startDate: Value(startDate),
        dueDate: Value(dueDate),
        priority: Value(priority),
        hasAlarm: Value(hasAlarm),
        isRecurring: Value(recurringEnabled),
        recurrenceRule: Value(normalizedRecurrenceRule),
        alarmMode: Value(resolvedMode),
        alarmAt: Value(resolvedAlarmAt),
        reminderOffsets: Value(serializedOffsets),
        reminderMinutes: Value(firstReminder),
        updatedAt: Value(DateTime.now()),
      ),
    );

    final updatedTask = await _db.getTaskById(task.id);
    await _scheduler.syncForTask(updatedTask);

    return true;
  }

  Future<void> toggleCompletion(Task task) async {
    if (task.isRecurring) {
      await _advanceRecurringTask(task);
      return;
    }

    final nextStatus = task.status == model.TaskStatus.completed
        ? model.TaskStatus.pending
        : model.TaskStatus.completed;

    await _db.patchTask(
      task.id,
      TasksCompanion(
        status: Value(nextStatus),
        completedAt: Value(
          nextStatus == model.TaskStatus.completed ? DateTime.now() : null,
        ),
        updatedAt: Value(DateTime.now()),
      ),
    );

    final updatedTask = await _db.getTaskById(task.id);
    if (updatedTask.status == model.TaskStatus.completed) {
      await _scheduler.cancelForTask(task.id);
    } else {
      await _scheduler.syncForTask(updatedTask);
    }
  }

  Future<void> _advanceRecurringTask(Task task) async {
    final weekdays = parseWeeklyRecurrenceRule(task.recurrenceRule);
    final selectedWeekdays = weekdays.isEmpty
        ? {
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
            DateTime.saturday,
            DateTime.sunday,
          }
        : weekdays;

    final baseStart = task.startDate;
    final baseDue = task.dueDate;
    final baseAlarmAt = task.alarmAt;

    final reference = baseStart ?? baseDue ?? baseAlarmAt ?? DateTime.now();
    final nextReference = nextWeeklyOccurrenceAfter(
      reference,
      selectedWeekdays,
      after: DateTime.now(),
    );

    final shift = nextReference.difference(
      DateTime(
        reference.year,
        reference.month,
        reference.day,
        reference.hour,
        reference.minute,
        reference.second,
        reference.millisecond,
        reference.microsecond,
      ),
    );

    final nextStart = baseStart?.add(shift);
    final nextDue = baseDue?.add(shift);
    final nextAlarmAt = task.alarmMode == model.AlarmMode.customTime &&
            baseAlarmAt != null
        ? baseAlarmAt.add(shift)
        : null;

    await _db.patchTask(
      task.id,
      TasksCompanion(
        status: const Value(model.TaskStatus.pending),
        startDate: Value(nextStart),
        dueDate: Value(nextDue),
        alarmAt: Value(nextAlarmAt),
        completedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );

    final updatedTask = await _db.getTaskById(task.id);
    await _scheduler.syncForTask(updatedTask);
  }

  Future<int> deleteTask(int taskId) async {
    await _scheduler.cancelForTask(taskId);
    return _db.deleteTask(taskId);
  }

  Future<int> addSubtask({
    required int taskId,
    required String title,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('Subtask title cannot be empty.');
    }

    return _db.insertSubtask(
      SubtasksCompanion.insert(
        taskId: taskId,
        title: trimmedTitle,
        sortOrder: Value(DateTime.now().microsecondsSinceEpoch),
      ),
    );
  }

  Future<void> toggleSubtask(Subtask subtask) async {
    await _db.toggleSubtask(subtask.id, !subtask.isCompleted);
  }

  Future<void> deleteSubtask(int subtaskId) async {
    await _db.deleteSubtask(subtaskId);
  }

  Future<int> saveTaskTemplate({
    required String name,
    required String title,
    String? description,
    required model.Priority priority,
    List<int>? reminderOffsets,
  }) async {
    final trimmedName = name.trim();
    final trimmedTitle = title.trim();
    final trimmedDescription = description?.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError('Template name is required.');
    }
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('Task title is required for a template.');
    }

    return _db.insertTaskTemplate(
      TaskTemplatesCompanion.insert(
        name: trimmedName,
        title: trimmedTitle,
        description: Value(
          trimmedDescription?.isEmpty == true ? null : trimmedDescription,
        ),
        priority: priority,
        reminderOffsets: Value(_serializeReminderOffsets(reminderOffsets)),
      ),
    );
  }

  Future<void> deleteTaskTemplate(int templateId) async {
    await _db.deleteTaskTemplate(templateId);
  }
}
