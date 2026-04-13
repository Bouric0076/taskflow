import 'package:drift/drift.dart';

enum Priority { normal, important, critical }

enum TaskStatus { pending, inProgress, completed }

enum AlarmMode { none, atStart, atDue, customTime }

class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  TextColumn get notes => text().nullable()(); // Additional notes/observations
  IntColumn get priority => intEnum<Priority>()();
  IntColumn get status => intEnum<TaskStatus>()();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  BoolColumn get hasAlarm => boolean().withDefault(const Constant(false))();
  IntColumn get alarmMode =>
      intEnum<AlarmMode>().withDefault(const Constant(0))();
  DateTimeColumn get alarmAt => dateTime().nullable()();
  TextColumn get reminderOffsets =>
      text().nullable()(); // comma-separated minutes
  IntColumn get reminderMinutes => integer().nullable()();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  TextColumn get recurrenceRule => text().nullable()();
  TextColumn get tags => text().nullable()(); // comma-separated
  BoolColumn get isAlarmScheduled =>
      boolean().withDefault(const Constant(false))(); // Persistence tracking
  DateTimeColumn get lastAlarmRestoreAt =>
      dateTime().nullable()(); // For debugging alarm restore
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
}

class Subtasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId => integer().references(Tasks, #id)();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class TaskTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  IntColumn get priority => intEnum<Priority>()();
  TextColumn get reminderOffsets => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
