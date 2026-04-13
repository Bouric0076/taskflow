import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/database/app_database.dart';
import '../providers/task_provider.dart';

class SubtasksSheet extends ConsumerStatefulWidget {
  const SubtasksSheet({
    super.key,
    required this.task,
  });

  final Task task;

  @override
  ConsumerState<SubtasksSheet> createState() => _SubtasksSheetState();
}

class _SubtasksSheetState extends ConsumerState<SubtasksSheet> {
  late final TextEditingController _controller;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addSubtask() async {
    if (_isAdding) return;
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _isAdding = true;
    });

    try {
      await ref.read(taskActionsProvider).addSubtask(
            taskId: widget.task.id,
            title: title,
          );
      _controller.clear();
    } on ArgumentError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message?.toString() ?? 'Invalid subtask.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtasksAsync = ref.watch(subtasksProvider(widget.task.id));

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Subtasks',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            widget.task.title,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addSubtask(),
                  decoration: const InputDecoration(
                    hintText: 'Add subtask',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isAdding ? null : _addSubtask,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: subtasksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Could not load subtasks.\n$error'),
              ),
              data: (subtasks) {
                if (subtasks.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No subtasks yet.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: subtasks.length,
                  itemBuilder: (context, index) {
                    final subtask = subtasks[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Checkbox(
                        value: subtask.isCompleted,
                        onChanged: (_) async {
                          await ref
                              .read(taskActionsProvider)
                              .toggleSubtask(subtask);
                        },
                      ),
                      title: Text(
                        subtask.title,
                        style: TextStyle(
                          decoration: subtask.isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                      trailing: IconButton(
                        onPressed: () async {
                          await ref
                              .read(taskActionsProvider)
                              .deleteSubtask(subtask.id);
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
