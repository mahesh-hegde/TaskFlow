import 'package:flutter/material.dart';

import '../model/types.dart';

import '../util/validators.dart';

import 'datetime_chip.dart';

// just to avoid mutable member warning
class _DeadlineStore {
  _DeadlineStore(this.dateTime);
  DateTime? dateTime;
}

class TaskEditor extends StatefulWidget {
  const TaskEditor({Key? key, required this.task, required this.isEditing})
      : super(key: key);

  final TodoTask task;
  final bool isEditing;

  @override
  _TaskEditorState createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  @override
  void initState() {
    super.initState();
    var task = widget.task;
    _nameCtrl.text = task.name;
    _infoCtrl.text = task.info;
    _deadline = _DeadlineStore(task.deadline);
  }

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController(),
      _infoCtrl = TextEditingController();
  late final _DeadlineStore _deadline;

  Widget _form(BuildContext context) {
    return Form(
        key: _formKey,
        child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
            controller: _nameCtrl,
            autofocus: true,
            validator: (s) => checkNotEmpty(s,
                errorMessage: "Task name should not be empty!"),
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
        ])));
  }

  Widget _label(String text) {
    return Padding(
        child: Text(text,
            style: TextStyle(fontSize: 12.0, color: Colors.grey[400])),
        padding: const EdgeInsets.only(top: 12.0, bottom: 6.0));
  }

  @override
  Widget build(BuildContext context) {
    void closeReturning(TodoTask? res) {
      Navigator.pop(context, res);
      // _nameCtrl.dispose();
      // _infoCtrl.dispose();
    }

    var task = widget.task;
    return AlertDialog(
      title: Text(widget.isEditing ? 'Edit Task' : 'Add Task'),
      content: SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _form(context),
        _label("Deadline"),
        DateTimeChip(
          initialValue: _deadline.dateTime,
          onChange: (v) => setState(() {
            var _old = _deadline.dateTime;
            _deadline.dateTime = v;
            if (_old != null && v == null) {
              task.notifications.clear();
            }
            if (_old != null && v != null) {
              var diff = v.difference(_old);
              for (var notif in task.notifications) {
                if (notif.isRelative) {
                  notif.notifyAt = notif.notifyAt.add(diff);
                }
              }
            }
          }),
          backgroundColor: Colors.deepPurple,
        ),
        if (_deadline.dateTime != null) ...[
          _label("Notifications"),
          NotificationSelector(
            taskId: task.id,
            deadline: _deadline.dateTime!,
            notifications: task.notifications,
          )
        ]
      ])),
      actions: <Widget>[
        TextButton(
          onPressed: () => closeReturning(null),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            task.name = _nameCtrl.text;
            task.info = _infoCtrl.text;
            task.deadline = _deadline.dateTime;
            closeReturning(task);
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

// Note: We are not changing the set elements until user submits the form
// Thus, just pass a defensive copy of notifications set to this widget
// later remove entries in old set from DB and add all in this set

class NotificationSelector extends StatefulWidget {
  const NotificationSelector(
      {Key? key,
      required this.taskId,
      required this.deadline,
      required this.notifications})
      : super(key: key);

  final Set<TaskNotification> notifications;
  final DateTime deadline;
  final int? taskId;

  @override
  _NotificationSelectorState createState() => _NotificationSelectorState();
}

class _NotificationSelectorState extends State<NotificationSelector> {
  var notificationTimes = {
    "5 Minutes": const Duration(minutes: 5),
    "15 Minutes": const Duration(minutes: 15),
    "30 Minutes": const Duration(minutes: 30),
    "1 Hour": const Duration(hours: 1),
    "2 Hours": const Duration(hours: 2),
    "1 Day": const Duration(days: 1),
    "2 Days": const Duration(days: 2),
  };

  @override
  Widget build(BuildContext context) {
    var impossibleTime = DateTime.fromMillisecondsSinceEpoch(0);
    Future<void> addCustomDateTimeNotification() async {
      var now = DateTime.now();
      var date = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: now,
        lastDate: widget.deadline,
        confirmText: "NEXT",
      );
      if (date == null) {
        return;
      }
      var time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, w) => MediaQuery(
          child: w!,
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        ),
      );
      if (time == null) {
        return;
      }
      var nTime = date.add(Duration(hours: time.hour, minutes: time.minute));
      var notif = TaskNotification(
          taskId: widget.taskId, notifyAt: nTime, isRelative: false);
      setState(() => widget.notifications.add(notif));
    }

    var addButton = PopupMenuButton<TaskNotification>(
      padding: const EdgeInsets.all(4.0),
      icon: Icon(Icons.add_circle, color: Colors.green[200]),
      tooltip: "Add Notification",
      itemBuilder: (context) => <PopupMenuItem<TaskNotification>>[
        for (var i in notificationTimes.keys)
          PopupMenuItem(
            value: TaskNotification(
                notifyAt: widget.deadline.subtract(notificationTimes[i]!),
                isRelative: true,
                taskId: widget.taskId),
            child: Text(i),
          ),
        PopupMenuItem(
          child: const Text("Custom Date & Time"),
          // Dart coalesces ?? into ?
          // Thus some circus to handle this case
          value: TaskNotification(
              taskId: -1, notifyAt: impossibleTime, isRelative: false),
        )
      ],
      onSelected: (v) {
        if (v.taskId == -1) {
          addCustomDateTimeNotification();
        } else {
          setState(() => widget.notifications.add(v));
        }
      },
    );
    var notifList =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var notif in widget.notifications)
        Container(
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            child: Chip(
              onDeleted: () =>
                  setState(() => widget.notifications.remove(notif)),
              deleteIcon: const Icon(Icons.delete_outlined),
              label: Text(notif.repr(widget.deadline)),
              backgroundColor:
                  notif.isRelative ? Colors.green[800] : Colors.purple[800],
            )),
      addButton,
    ]);
    return notifList;
  }
}
