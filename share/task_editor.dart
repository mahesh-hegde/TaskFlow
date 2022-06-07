import 'package:flutter/material.dart';

import 'model/types.dart';

import 'datetime_picker.dart';

class TaskEditor extends Dialog {
  TaskEditor({Key? key, required this.task, this.isEditing = false})
      : super(key: key) {
	// the debug mode assertion initialValue == null || controller == null
	// to prevent that, set the default text in the constructor.
	_nameCtrl.text = task.name;
	_infoCtrl.text = task.info;
	_deadlineCtrl = DateTimePickerController(dateTime: task.deadline);
  }
  final TodoTask task;
  final bool isEditing;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController(),
      _infoCtrl = TextEditingController();
  late final DateTimePickerController _deadlineCtrl;

  Widget _form(BuildContext context) {
	return Form(
        key: _formKey,
        child: SingleChildScrollView(child: Column(
		  mainAxisSize: MainAxisSize.min,
		  children: [
          TextFormField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Task',
            ),
          ),
          TextFormField(
              controller: _infoCtrl,
              maxLines: 4,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Description',
              )),
		  DateTimePicker(controller: _deadlineCtrl),
		
        ])));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? 'Edit Task' : 'Add Task'),
      content: _form(context),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            task.name = _nameCtrl.text;
            task.info = _infoCtrl.text;
			task.deadline = _deadlineCtrl.datetime;
            Navigator.pop(context, task);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}

Future<TodoTask?> showTaskEditor(
    {required BuildContext context,
    required TodoTask task,
    bool isEditing = false}) async {
  return showDialog<TodoTask?>(
      context: context,
      builder: (context) => TaskEditor(task: task, isEditing: isEditing),
      barrierDismissible: false);
}
