import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../models/task_model.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Tasks, Subtasks, TaskTemplates])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(tasks, tasks.startDate);
            await m.addColumn(tasks, tasks.alarmMode);
            await m.addColumn(tasks, tasks.alarmAt);
            await m.addColumn(tasks, tasks.reminderOffsets);

            await customStatement('''
              UPDATE tasks
              SET alarm_mode = ${AlarmMode.atDue.index},
                  alarm_at = due_date,
                  has_alarm = CASE WHEN due_date IS NOT NULL THEN 1 ELSE has_alarm END,
                  reminder_offsets = CASE
                    WHEN reminder_minutes IS NOT NULL THEN CAST(reminder_minutes AS TEXT)
                    ELSE reminder_offsets
                  END
              WHERE due_date IS NOT NULL
            ''');
          }

          if (from < 3) {
            await m.createTable(taskTemplates);
          }

          if (from < 4) {
            await m.addColumn(tasks, tasks.notes);
            await m.addColumn(tasks, tasks.isAlarmScheduled);
            await m.addColumn(tasks, tasks.lastAlarmRestoreAt);
          }
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'taskflow');
  }

  // ── Tasks ──────────────────────────────────────────────

  Future<List<Task>> getAllTasks() => select(tasks).get();

  Stream<List<Task>> watchAllTasks() => select(tasks).watch();

  Stream<List<Task>> watchTodayTasks() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return (select(tasks)
          ..where((t) =>
              t.startDate.isBetweenValues(startOfDay, endOfDay) |
              t.dueDate.isBetweenValues(startOfDay, endOfDay) |
              (t.startDate.isNull() & t.dueDate.isNull()))
          ..where((t) =>
              t.status.equals(TaskStatus.pending.index) |
              t.status.equals(TaskStatus.inProgress.index))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.priority, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.dueDate),
          ]))
        .watch();
  }

  Stream<List<Task>> watchUpcomingTasks() {
    final now = DateTime.now();
    final startOfTomorrow = DateTime(now.year, now.month, now.day + 1);
    final endOfWeek = startOfTomorrow.add(const Duration(days: 7));

    return (select(tasks)
          ..where((t) =>
              t.startDate.isBetweenValues(startOfTomorrow, endOfWeek) |
              t.dueDate.isBetweenValues(startOfTomorrow, endOfWeek))
          ..where((t) =>
              t.status.equals(TaskStatus.pending.index) |
              t.status.equals(TaskStatus.inProgress.index))
          ..orderBy([
            (t) => OrderingTerm(expression: t.dueDate),
            (t) =>
                OrderingTerm(expression: t.priority, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Stream<List<Task>> watchOverdueTasks() {
    final now = DateTime.now();
    return (select(tasks)
          ..where((t) =>
              t.startDate.isSmallerThanValue(now) |
              t.dueDate.isSmallerThanValue(now))
          ..where((t) =>
              t.status.equals(TaskStatus.pending.index) |
              t.status.equals(TaskStatus.inProgress.index))
          ..orderBy([
            (t) => OrderingTerm(expression: t.dueDate),
          ]))
        .watch();
  }

  Future<Task> getTaskById(int id) =>
      (select(tasks)..where((t) => t.id.equals(id))).getSingle();

  Future<int> insertTask(TasksCompanion task) => into(tasks).insert(task);

  Future<bool> updateTask(TasksCompanion task) => update(tasks).replace(task);

  Future<int> patchTask(int id, TasksCompanion task) =>
      (update(tasks)..where((t) => t.id.equals(id))).write(task);

  Future<int> deleteTask(int id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  Future completeTask(int id) {
    return (update(tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        status: const Value(TaskStatus.completed),
        completedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future rescheduleOverdueTasks() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 9, 0);
    return (update(tasks)
          ..where((t) => t.dueDate.isSmallerThanValue(now))
          ..where((t) => t.status.equals(TaskStatus.pending.index)))
        .write(TasksCompanion(
      dueDate: Value(tomorrow),
      updatedAt: Value(now),
    ));
  }

  Future<int> getCompletedTodayCount() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final result = await (select(tasks)
          ..where((t) => t.completedAt.isBetweenValues(startOfDay, endOfDay)))
        .get();
    return result.length;
  }

  // ── Alarm Persistence ───────────────────────────────────

  /// Mark that an alarm has been scheduled for this task
  Future<void> markAlarmScheduled(int taskId) {
    return (update(tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        isAlarmScheduled: const Value(true),
        lastAlarmRestoreAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Mark that an alarm has been cancelled for this task
  Future<void> markAlarmCancelled(int taskId) {
    return (update(tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        isAlarmScheduled: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Get all tasks with active alarms (for restoration on app startup)
  Future<List<Task>> getTasksWithActiveAlarms() {
    return (select(tasks)
          ..where((t) => t.isAlarmScheduled.equals(true))
          ..where((t) =>
              t.status.equals(TaskStatus.pending.index) |
              t.status.equals(TaskStatus.inProgress.index)))
        .get();
  }

  /// Update task notes
  Future<void> updateTaskNotes(int taskId, String notes) {
    return (update(tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        notes: Value(notes.isNotEmpty ? notes : null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ── Subtasks ───────────────────────────────────────────

  Stream<List<Subtask>> watchSubtasksForTask(int taskId) => (select(subtasks)
        ..where((s) => s.taskId.equals(taskId))
        ..orderBy([(s) => OrderingTerm(expression: s.sortOrder)]))
      .watch();

  Future<int> insertSubtask(SubtasksCompanion subtask) =>
      into(subtasks).insert(subtask);

  Future<bool> updateSubtask(SubtasksCompanion subtask) =>
      update(subtasks).replace(subtask);

  Future<int> deleteSubtask(int id) =>
      (delete(subtasks)..where((s) => s.id.equals(id))).go();

  Future toggleSubtask(int id, bool isCompleted) =>
      (update(subtasks)..where((s) => s.id.equals(id))).write(
        SubtasksCompanion(isCompleted: Value(isCompleted)),
      );

  Future deleteSubtasksForTask(int taskId) =>
      (delete(subtasks)..where((s) => s.taskId.equals(taskId))).go();

  // ── Templates ──────────────────────────────────────────

  Stream<List<TaskTemplate>> watchTaskTemplates() => (select(taskTemplates)
        ..orderBy([
          (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
        ]))
      .watch();

  Future<int> insertTaskTemplate(TaskTemplatesCompanion template) =>
      into(taskTemplates).insert(template);

  Future<int> deleteTaskTemplate(int id) =>
      (delete(taskTemplates)..where((t) => t.id.equals(id))).go();
}
