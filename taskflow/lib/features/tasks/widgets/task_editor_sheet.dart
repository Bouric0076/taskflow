import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/task_model.dart' as model;
import '../providers/task_provider.dart';
import '../utils/recurrence_utility.dart';

class TaskEditorSheet extends ConsumerStatefulWidget {
  const TaskEditorSheet({
    super.key,
    this.initialTask,
    this.onSubmit,
  });

  final Task? initialTask;
  final Future<void> Function(
    String title,
    String? description,
    String? notes,
    DateTime? startDate,
    DateTime? dueDate,
    model.Priority priority,
    model.AlarmMode alarmMode,
    DateTime? customAlarmAt,
    List<int> reminderOffsets,
    bool isRecurring,
    String? recurrenceRule,
  )? onSubmit;

  bool get isEditing => initialTask != null;

  @override
  ConsumerState<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends ConsumerState<TaskEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _notesController;

  DateTime? _startDate;
  DateTime? _dueDate;
  DateTime? _customAlarmAt;
  model.Priority _priority = model.Priority.normal;
  model.AlarmMode _alarmMode = model.AlarmMode.none;
  bool _isRecurring = false;
  final Set<int> _selectedWeekdays = {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  };
  int? _selectedTemplateId;
  final Set<int> _selectedReminderOffsets = {
    AppConstants.defaultReminderMinutes
  };
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.initialTask?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.initialTask?.description ?? '');
    _notesController =
        TextEditingController(text: widget.initialTask?.notes ?? '');

    final task = widget.initialTask;
    _startDate = task?.startDate;
    _dueDate = task?.dueDate;
    _priority = task?.priority ?? model.Priority.normal;
    _alarmMode = task?.alarmMode ?? model.AlarmMode.none;
    _customAlarmAt =
        task?.alarmMode == model.AlarmMode.customTime ? task?.alarmAt : null;

    _isRecurring = task?.isRecurring ?? false;
    final fromRule = parseWeeklyRecurrenceRule(task?.recurrenceRule);
    if (fromRule.isNotEmpty) {
      _selectedWeekdays
        ..clear()
        ..addAll(fromRule);
    }

    final fromStorage = (task?.reminderOffsets ?? '')
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .where((e) => e > 0)
        .toList();

    if (fromStorage.isNotEmpty) {
      _selectedReminderOffsets
        ..clear()
        ..addAll(fromStorage);
    }

    _normalizeAlarmModeAfterDateChange();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime({required DateTime? currentValue}) async {
    final now = DateTime.now();
    final baseDate = currentValue ?? now;

    final selectedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: baseDate,
    );

    if (selectedDate == null || !mounted) return null;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(baseDate),
    );

    if (!mounted) return null;

    final time = selectedTime ?? TimeOfDay.fromDateTime(baseDate);
    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      time.hour,
      time.minute,
    );
  }

  List<model.AlarmMode> _availableAlarmModes() {
    final result = <model.AlarmMode>[model.AlarmMode.none];
    if (_startDate != null) {
      result.add(model.AlarmMode.atStart);
    }
    if (_dueDate != null) {
      result.add(model.AlarmMode.atDue);
    }
    if (_startDate != null || _dueDate != null) {
      result.add(model.AlarmMode.customTime);
    }
    return result;
  }

  void _normalizeAlarmModeAfterDateChange() {
    final modes = _availableAlarmModes();
    if (!modes.contains(_alarmMode)) {
      _alarmMode = model.AlarmMode.none;
      _customAlarmAt = null;
    }

    if (_alarmMode != model.AlarmMode.customTime) {
      _customAlarmAt = null;
    }
  }

  String _weekdayLabel(int weekday) {
    return switch (weekday) {
      DateTime.monday => 'Mon',
      DateTime.tuesday => 'Tue',
      DateTime.wednesday => 'Wed',
      DateTime.thursday => 'Thu',
      DateTime.friday => 'Fri',
      DateTime.saturday => 'Sat',
      DateTime.sunday => 'Sun',
      _ => '',
    };
  }

  DateTime? _resolveAlarmAnchor() {
    switch (_alarmMode) {
      case model.AlarmMode.none:
        return null;
      case model.AlarmMode.atStart:
        return _startDate ?? _dueDate;
      case model.AlarmMode.atDue:
        return _dueDate ?? _startDate;
      case model.AlarmMode.customTime:
        return _customAlarmAt ?? _startDate ?? _dueDate;
    }
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required.')),
      );
      return;
    }

    if (_startDate != null &&
        _dueDate != null &&
        _dueDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Due time must be after start time.')),
      );
      return;
    }

    if (_alarmMode == model.AlarmMode.customTime && _customAlarmAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a custom alarm time.')),
      );
      return;
    }

    if (_alarmMode == model.AlarmMode.customTime &&
        _customAlarmAt != null &&
        _startDate != null &&
        _dueDate != null &&
        (_customAlarmAt!.isBefore(_startDate!) ||
            _customAlarmAt!.isAfter(_dueDate!))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Custom alarm must be between start and due time.'),
        ),
      );
      return;
    }

    final alarmAnchor = _resolveAlarmAnchor();
    if (_alarmMode != model.AlarmMode.none &&
        alarmAnchor != null &&
        !_isRecurring &&
        !alarmAnchor.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alarm time must be in the future.')),
      );
      return;
    }

    final recurrenceRule =
        _isRecurring ? serializeWeeklyRecurrenceRule(_selectedWeekdays) : null;

    if (_isRecurring && recurrenceRule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one weekday.')),
      );
      return;
    }

    if (_isRecurring && _startDate == null && _dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Weekly repeat needs a start or due time.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSubmit?.call(
        _titleController.text,
        _descriptionController.text,
        _notesController.text,
        _startDate,
        _dueDate,
        _priority,
        _alarmMode,
        _customAlarmAt,
        _selectedReminderOffsets.toList()..sort(),
        _isRecurring,
        recurrenceRule,
      );
      if (!mounted) return;

      FocusScope.of(context).unfocus();
      await Future<void>.delayed(Duration.zero);
      if (mounted) Navigator.of(context).pop();
    } on ArgumentError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message?.toString() ?? 'Invalid task data.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save task. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _priorityLabel(model.Priority priority) {
    switch (priority) {
      case model.Priority.normal:
        return 'Normal';
      case model.Priority.important:
        return 'Important';
      case model.Priority.critical:
        return 'Critical';
    }
  }

  String _alarmModeLabel(model.AlarmMode mode) {
    switch (mode) {
      case model.AlarmMode.none:
        return 'No alarm';
      case model.AlarmMode.atStart:
        return 'At start time';
      case model.AlarmMode.atDue:
        return 'At due time';
      case model.AlarmMode.customTime:
        return 'At custom time';
    }
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'Not set';
    return '${MaterialLocalizations.of(context).formatCompactDate(value)} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
  }

  String _validationHintText() {
    if (_startDate != null &&
        _dueDate != null &&
        _dueDate!.isBefore(_startDate!)) {
      return 'Due should be after start.';
    }

    if (_alarmMode == model.AlarmMode.customTime && _customAlarmAt == null) {
      return 'Custom alarm needs a time.';
    }

    if (_alarmMode != model.AlarmMode.none) {
      final anchor = _resolveAlarmAnchor();
      if (anchor != null && !anchor.isAfter(DateTime.now())) {
        return 'Alarm should be in the future.';
      }
    }

    return 'Set start, due, and alarm timing as needed.';
  }

  void _applyTemplate(TaskTemplate template) {
    final offsets = (template.reminderOffsets ?? '')
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .where((e) => e > 0)
        .toSet();

    setState(() {
      _titleController.text = template.title;
      _descriptionController.text = template.description ?? '';
      _priority = template.priority;
      _alarmMode = model.AlarmMode.none;
      _customAlarmAt = null;
      _selectedReminderOffsets
        ..clear()
        ..addAll(
            offsets.isEmpty ? {AppConstants.defaultReminderMinutes} : offsets);
    });
  }

  Future<void> _saveCurrentAsTemplate() async {
    final nameController = TextEditingController();

    try {
      final templateName = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Save as template'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Template name',
              hintText: 'Daily Standup',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(nameController.text),
              child: const Text('Save'),
            ),
          ],
        ),
      );

      if (templateName == null || templateName.trim().isEmpty) return;

      await ref.read(taskActionsProvider).saveTaskTemplate(
            name: templateName,
            title: _titleController.text,
            description: _descriptionController.text,
            priority: _priority,
            reminderOffsets: _selectedReminderOffsets.toList()..sort(),
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template saved.')),
      );
    } on ArgumentError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message?.toString() ?? 'Invalid template.')),
      );
    } finally {
      nameController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(taskTemplatesProvider);
    final viewInsets = MediaQuery.of(context).viewInsets;
    final availableAlarmModes = _availableAlarmModes();
    final alarmAnchor = _resolveAlarmAnchor();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: viewInsets.bottom + 16,
      ),
      child: Form(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isEditing ? 'Edit task' : 'New task',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              templatesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (templates) {
                  if (templates.isEmpty) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _saveCurrentAsTemplate,
                        icon: const Icon(Icons.bookmark_add_outlined),
                        label: const Text('Save template'),
                      ),
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedTemplateId,
                          decoration: const InputDecoration(
                            labelText: 'Apply template',
                          ),
                          items: templates
                              .map(
                                (t) => DropdownMenuItem<int>(
                                  value: t.id,
                                  child: Text(t.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            final template = templates.firstWhere(
                              (t) => t.id == value,
                            );
                            _applyTemplate(template);
                            setState(() {
                              _selectedTemplateId = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _saveCurrentAsTemplate,
                        icon: const Icon(Icons.bookmark_add_outlined),
                        tooltip: 'Save template',
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _titleController,
                autofocus: !widget.isEditing,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Finish Sprint 3 implementation',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Optional notes',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Add observations or additional details',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<model.Priority>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: model.Priority.values
                    .map(
                      (p) => DropdownMenuItem<model.Priority>(
                        value: p,
                        child: Text(_priorityLabel(p)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _priority = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await _pickDateTime(currentValue: _startDate);
                  if (picked == null || !mounted) return;
                  setState(() {
                    _startDate = picked;
                    _normalizeAlarmModeAfterDateChange();
                  });
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text('Start: ${_formatDateTime(_startDate)}'),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _startDate == null
                      ? null
                      : () {
                          setState(() {
                            _startDate = null;
                            _normalizeAlarmModeAfterDateChange();
                          });
                        },
                  child: const Text('Clear start'),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await _pickDateTime(currentValue: _dueDate);
                  if (picked == null || !mounted) return;
                  setState(() {
                    _dueDate = picked;
                    _normalizeAlarmModeAfterDateChange();
                  });
                },
                icon: const Icon(Icons.schedule_outlined),
                label: Text('Due: ${_formatDateTime(_dueDate)}'),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _dueDate == null
                      ? null
                      : () {
                          setState(() {
                            _dueDate = null;
                            _normalizeAlarmModeAfterDateChange();
                          });
                        },
                  child: const Text('Clear due'),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<model.AlarmMode>(
                initialValue: _alarmMode,
                decoration: const InputDecoration(labelText: 'Alarm timing'),
                items: availableAlarmModes
                    .map(
                      (m) => DropdownMenuItem<model.AlarmMode>(
                        value: m,
                        child: Text(_alarmModeLabel(m)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _alarmMode = value;
                    _normalizeAlarmModeAfterDateChange();
                  });
                },
              ),
              if (_alarmMode == model.AlarmMode.customTime) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await _pickDateTime(
                        currentValue: _customAlarmAt ?? _dueDate ?? _startDate);
                    if (picked == null || !mounted) return;
                    setState(() {
                      _customAlarmAt = picked;
                    });
                  },
                  icon: const Icon(Icons.alarm),
                  label:
                      Text('Custom alarm: ${_formatDateTime(_customAlarmAt)}'),
                ),
              ],
              if (alarmAnchor != null &&
                  _alarmMode != model.AlarmMode.none) ...[
                const SizedBox(height: 12),
                Text(
                  'Reminders before alarm',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppConstants.reminderOffsets
                      .map(
                        (minutes) => FilterChip(
                          label: Text('${minutes}m'),
                          selected: _selectedReminderOffsets.contains(minutes),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedReminderOffsets.add(minutes);
                              } else {
                                _selectedReminderOffsets.remove(minutes);
                              }
                              if (_selectedReminderOffsets.isEmpty) {
                                _selectedReminderOffsets
                                    .add(AppConstants.defaultReminderMinutes);
                              }
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                _validationHintText(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Repeat weekly'),
                subtitle: Text(_isRecurring
                    ? 'Advances to the next selected weekday after completion.'
                    : 'Keep this task on a weekly cycle.'),
                value: _isRecurring,
                onChanged: (value) {
                  setState(() {
                    _isRecurring = value;
                    if (_selectedWeekdays.isEmpty) {
                      _selectedWeekdays.addAll({
                        DateTime.monday,
                        DateTime.tuesday,
                        DateTime.wednesday,
                        DateTime.thursday,
                        DateTime.friday,
                        DateTime.saturday,
                        DateTime.sunday,
                      });
                    }
                  });
                },
              ),
              if (_isRecurring) ...[
                const SizedBox(height: 8),
                Text(
                  'Repeat on',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    DateTime.monday,
                    DateTime.tuesday,
                    DateTime.wednesday,
                    DateTime.thursday,
                    DateTime.friday,
                    DateTime.saturday,
                    DateTime.sunday,
                  ].map((weekday) {
                    final selected = _selectedWeekdays.contains(weekday);
                    return FilterChip(
                      label: Text(_weekdayLabel(weekday)),
                      selected: selected,
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _selectedWeekdays.add(weekday);
                          } else {
                            _selectedWeekdays.remove(weekday);
                          }
                          if (_selectedWeekdays.isEmpty) {
                            _selectedWeekdays.addAll({
                              DateTime.monday,
                              DateTime.tuesday,
                              DateTime.wednesday,
                              DateTime.thursday,
                              DateTime.friday,
                              DateTime.saturday,
                              DateTime.sunday,
                            });
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                child: Text(_isSaving
                    ? 'Saving...'
                    : (widget.isEditing ? 'Save changes' : 'Create task')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
