import 'package:flutter/material.dart';

import '../model/types.dart';

import '../util/time_format.dart';

class TodoListStat {
  TodoListStat(this.date);

  DateTime date;
  int tasksAdded = 0, tasksFinished = 0;
}

List<TodoListStat> getStats(TodoList todoList) {
  Map<DateTime, TodoListStat> statsByDate = {};
  var tasks = todoList.tasks;
  for (var task in tasks.tasks) {
    var added = task.addedOn;
    var addedDate = DateTime(added.year, added.month, added.day);
    statsByDate[addedDate] ??= TodoListStat(addedDate);
    statsByDate[addedDate]!.tasksAdded += 1;

    var finished = task.finished;
    if (finished != null) {
      var finishedDate = DateTime(finished.year, finished.month, finished.day);
      statsByDate[finishedDate] ??= TodoListStat(finishedDate);
      statsByDate[finishedDate]!.tasksFinished += 1;
    }
  }
  // collect all into list and sort by date
  List<TodoListStat> statList = statsByDate.values.toList();
  statList.sort((a, b) => a.date.compareTo(b.date));
  return statList;
}

class TaskStatsDialog extends Dialog {
  const TaskStatsDialog({Key? key, required this.todoList}) : super(key: key);

  final TodoList todoList;

  Widget _paddedText(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Text(text,
          style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    var stats = getStats(todoList);
    return AlertDialog(
        title: const Text("Component Stats"),
        content: SingleChildScrollView(
            child: Table(
          border: TableBorder.all(),
          children: [
            TableRow(children: [
              _paddedText("Date", bold: true),
              _paddedText("Tasks Added", bold: true),
              _paddedText("Tasks Finished", bold: true),
            ]),
            for (var stat in stats)
              TableRow(children: [
                _paddedText(formatDate(stat.date)),
                _paddedText("${stat.tasksAdded}"),
                _paddedText("${stat.tasksFinished}"),
              ]),
          ],
        )),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
          )
        ]);
  }
}
